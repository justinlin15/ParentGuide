import Anthropic from "@anthropic-ai/sdk";
import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";
import {
  honeypotCacheKey,
  getCachedHoneypot,
  setCachedHoneypot,
} from "./utils/ai-cache.js";

/**
 * Assign a publication status to each event based on source trustworthiness.
 *
 * "published" — safe to show immediately in the app
 * "draft"     — needs admin review (suspected honeypot / could not verify)
 *
 * Three-layer strategy:
 *
 * Layer 1 — Trusted API sources (Ticketmaster, SeatGeek, Yelp, Eventbrite,
 *   Kidsguide) are authorized data partners → always published immediately.
 *
 * Layer 2 — URL verification for all scrapers (including OC Parent Guide).
 *   If the enricher found a real venue/event website (websiteURL or externalURL
 *   that isn't the aggregator domain or a Google search) → published.
 *   OC Parent Guide events set externalURL to their own calendar page, which
 *   is an aggregator domain, so they typically fall through to Layer 3.
 *
 * Layer 3 — Claude AI plausibility check for events that failed URL verification.
 *   Claude evaluates each event's title, description, category, city, and source
 *   to determine whether it reads like a genuine local family event or a likely
 *   honeypot watermark (implausible detail, nonsensical content, obviously fake).
 *   - Plausible → published
 *   - Suspected honeypot / insufficient detail → draft for admin review
 */

// ─── Layer 1: Trusted API sources ────────────────────────────────────────────

// Only API partners with contractual data-sharing agreements are auto-trusted.
// Scrapers — even credentialed ones like OC Parent Guide — go through verification
// because any site could embed honeypot events to detect scraping activity.
const TRUSTED_API_SOURCES = new Set([
  "ticketmaster",
  "seatgeek",
  "yelp",
  "eventbrite",
  "kidsguide",
  "libcal",
  // Direct venue scrapers — trusted because they scrape the venue's own website
  "venue-kidspace",
  "venue-southcoastplaza",
  "venue-academy",
  "venue-nhm",
  "venue-skirball",
  "venue-discoverycube",
  "venue-underwood",
  "venue-autry",
  // Theme parks, museums, and other direct sources
  "themeparks",
  "venue-expopark",
  "pretend-city",
  "la-parent",
  // Church community event scrapers — direct venue websites
  "church-mariners",
  "church-saddleback",
  "church-rockharbor",
  "church-oceans",
  "church-mosaic",
  "church-realityla",
]);

// ─── Layer 2: URL verification ────────────────────────────────────────────────

// Aggregator domains — URLs pointing back here don't count as a verified venue link
const AGGREGATOR_DOMAINS = [
  "mommypoppins.com",
  "macaronikid.com",
  "atlantaparent.com",
  "dfwchild.com",
  "mykidlist.com",
  "nycfamily.com",
  "ocparentguide.com",
  "orangecountyparentguide.com",
  "kidsguidemagazine.com",
];

function isAggregatorUrl(url: string): boolean {
  try {
    const hostname = new URL(url).hostname.replace(/^www\./, "");
    return AGGREGATOR_DOMAINS.some((domain) => hostname.includes(domain));
  } catch {
    return false;
  }
}

function isGoogleSearchUrl(url: string): boolean {
  try {
    return new URL(url).hostname.includes("google.com");
  } catch {
    return false;
  }
}

function hasVerifiedUrl(event: PipelineEvent): boolean {
  // websiteURL is always a direct venue/event site (set by enricher)
  if (event.websiteURL && !isAggregatorUrl(event.websiteURL)) return true;

  // externalURL might be a real venue page or a Google search fallback
  if (event.externalURL) {
    if (isGoogleSearchUrl(event.externalURL)) return false;
    if (isAggregatorUrl(event.externalURL)) return false;
    return true;
  }

  return false;
}

// ─── Layer 2b: Known venue / event pattern verification ─────────────────────
// Many legitimate events lack extractable venue URLs (especially from OC Parent
// Guide), but their titles reference well-known, real venues. Auto-publish these.

const KNOWN_VENUES = [
  // OC venues
  "disneyland", "disney california adventure", "knott's berry farm", "knott's",
  "south coast plaza", "discovery cube", "pretend city", "irvine park railroad",
  "bowers museum", "segerstrom center", "marconi automotive museum",
  "orange county great park", "oc great park", "irvine spectrum",
  "dana point harbor", "laguna beach", "san clemente pier",
  "angel stadium", "honda center", "pacific symphony",
  "aquarium of the pacific", "the lab anti-mall", "the camp",
  "centennial farm", "tanaka farms", "adventure playground",
  "heritage hill", "old town irvine", "balboa island",
  // LA venues
  "griffith observatory", "la zoo", "the broad", "getty center", "getty villa",
  "natural history museum", "california science center", "exposition park",
  "the grove", "santa monica pier", "venice beach",
  "academy museum", "hammer museum", "lacma",
  "hollywood bowl", "greek theatre", "walt disney concert hall",
  "universal studios", "legoland", "six flags magic mountain",
  // Common event types that are virtually never honeypots
  "farmers market", "library", "storytime", "story time",
];

function hasKnownVenue(event: PipelineEvent): boolean {
  const titleLower = (event.title || "").toLowerCase();
  const locationLower = (event.locationName || "").toLowerCase();
  const combined = `${titleLower} ${locationLower}`;
  return KNOWN_VENUES.some((venue) => combined.includes(venue));
}

// ─── Layer 3: Claude AI plausibility check ───────────────────────────────────

// Batch size for Claude API calls — balance speed vs accuracy
const AI_VERIFY_BATCH_SIZE = 20;

let client: Anthropic | null = null;

function getClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  if (!client) {
    client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return client;
}

interface AIVerdict {
  index: number;
  plausible: boolean;
  reason: string;
}

/**
 * Ask Claude to evaluate a batch of events for honeypot risk.
 * Returns a verdict for each: plausible (true → publish) or suspicious (false → draft).
 */
async function aiVerifyBatch(
  events: PipelineEvent[],
  anthropic: Anthropic
): Promise<AIVerdict[]> {
  const eventList = events
    .map(
      (e, i) =>
        `[${i}] title: "${e.title}" | source: ${e.source} | city: ${e.city || "unknown"} | category: ${e.category} | description: "${(e.description || "").slice(0, 200)}"`
    )
    .join("\n");

  const prompt = `You are a content moderator for a family events app in Southern California (Orange County and Los Angeles). Your ONLY job is to identify honeypot/watermark events — fake events that scraper-detection services embed to catch unauthorized scrapers.

IMPORTANT: The vast majority of these events are REAL. You should default to marking events as plausible. Only flag something as a honeypot if it is clearly fake.

Real events (mark plausible=true):
- Any event at a recognizable venue, park, library, museum, school, church, or business
- Storytime, farmers markets, concerts, festivals, craft fairs, open gyms, classes
- Events with specific details like times, prices, registration info, or age ranges
- Events in real Southern California cities (Irvine, Costa Mesa, Anaheim, Long Beach, etc.)
- Events with short or missing descriptions — this is normal for calendar scrapers, NOT a sign of a honeypot
- Free community events, holiday events, seasonal activities

Honeypots (mark plausible=false) — ONLY flag if CLEARLY fake:
- Completely nonsensical titles (random characters, gibberish)
- Events that are obviously promotional copy for a website rather than a real activity
- Implausible combinations that could not exist (e.g., "Deep Sea Diving" in a landlocked desert town)
- Titles that look auto-generated to test scraping (random strings, test data patterns)

When in doubt, ALWAYS mark as plausible. A real event incorrectly flagged is much worse than a honeypot getting through.

Evaluate each event below. For each, respond with a JSON array entry:
{ "index": <number>, "plausible": <true|false>, "reason": "<brief reason>" }

Events to evaluate:
${eventList}

Respond with ONLY a JSON array, no other text:`;

  const response = await anthropic.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 2048,
    messages: [{ role: "user", content: prompt }],
  });

  const text =
    response.content[0].type === "text" ? response.content[0].text : "[]";

  try {
    const match = text.match(/\[[\s\S]*\]/);
    if (!match) throw new Error("No JSON array found in response");
    return JSON.parse(match[0]) as AIVerdict[];
  } catch (err) {
    log.warn("verify", `AI verdict parse error: ${err} — defaulting all to plausible`);
    // On parse failure, default to publishing (don't block real events)
    return events.map((_, i) => ({ index: i, plausible: true, reason: "parse error fallback" }));
  }
}

async function aiVerifyAll(
  events: PipelineEvent[]
): Promise<Map<string, boolean>> {
  const result = new Map<string, boolean>();

  // ── Serve cached verdicts first ──────────────────────────────────────────
  const needsVerification: PipelineEvent[] = [];
  let cacheHits = 0;

  for (const event of events) {
    const key = honeypotCacheKey(event.sourceId, event.title);
    const cached = getCachedHoneypot(key);
    if (cached) {
      result.set(event.sourceId, cached.plausible);
      cacheHits++;
    } else {
      needsVerification.push(event);
    }
  }

  if (cacheHits > 0) {
    log.info("verify", `  Cache: ${cacheHits} verdicts from cache, ${needsVerification.length} need AI verification`);
  }

  if (needsVerification.length === 0) return result;

  // ── Verify uncached events via Claude API ────────────────────────────────
  const anthropic = getClient();
  if (!anthropic) {
    log.warn(
      "verify",
      "ANTHROPIC_API_KEY not set — skipping AI verification, defaulting all to plausible"
    );
    for (const e of needsVerification) result.set(e.sourceId, true);
    return result;
  }

  log.info("verify", `AI-verifying ${needsVerification.length} events without confirmed URLs...`);

  for (let i = 0; i < needsVerification.length; i += AI_VERIFY_BATCH_SIZE) {
    const batch = needsVerification.slice(i, i + AI_VERIFY_BATCH_SIZE);
    const batchNum = Math.floor(i / AI_VERIFY_BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(needsVerification.length / AI_VERIFY_BATCH_SIZE);

    try {
      const verdicts = await aiVerifyBatch(batch, anthropic);
      for (const verdict of verdicts) {
        const event = batch[verdict.index];
        if (event) {
          result.set(event.sourceId, verdict.plausible);
          // Cache the verdict so future runs skip re-verification
          setCachedHoneypot(honeypotCacheKey(event.sourceId, event.title), {
            plausible: verdict.plausible,
            reason: verdict.reason,
          });
          if (!verdict.plausible) {
            log.warn(
              "verify",
              `  Honeypot suspected [${event.source}] "${event.title}" — ${verdict.reason}`
            );
          }
        }
      }
      // Fill any missing verdicts with plausible (safety default) and cache them
      for (const event of batch) {
        if (!result.has(event.sourceId)) {
          result.set(event.sourceId, true);
          setCachedHoneypot(honeypotCacheKey(event.sourceId, event.title), {
            plausible: true,
            reason: "missing verdict fallback",
          });
        }
      }
      log.info("verify", `  AI batch ${batchNum}/${totalBatches} complete`);
    } catch (err) {
      log.warn("verify", `  AI batch ${batchNum}/${totalBatches} failed: ${err} — defaulting to plausible`);
      for (const event of batch) result.set(event.sourceId, true);
      // Don't cache error fallbacks — let them be retried next run
    }

    // Brief pause between batches to respect rate limits
    if (i + AI_VERIFY_BATCH_SIZE < needsVerification.length) {
      await new Promise((r) => setTimeout(r, 500));
    }
  }

  return result;
}

// ─── Main export ─────────────────────────────────────────────────────────────

export async function verifyEvents(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  let publishedByApi = 0;
  let publishedByUrl = 0;
  let publishedByVenue = 0;
  let publishedByAi = 0;
  let draftCount = 0;

  // Layer 1 + 2 + 2b: synchronous, no API call needed
  const needsAiCheck: PipelineEvent[] = [];
  const prelimResult = new Map<string, "published" | "needs-ai">();

  for (const event of events) {
    if (TRUSTED_API_SOURCES.has(event.source)) {
      prelimResult.set(event.sourceId, "published");
      publishedByApi++;
    } else if (hasVerifiedUrl(event)) {
      prelimResult.set(event.sourceId, "published");
      publishedByUrl++;
    } else if (hasKnownVenue(event)) {
      // Layer 2b: event references a well-known venue — auto-publish
      prelimResult.set(event.sourceId, "published");
      publishedByVenue++;
    } else {
      prelimResult.set(event.sourceId, "needs-ai");
      needsAiCheck.push(event);
    }
  }

  // Layer 3: AI verification for events without confirmed URLs
  const aiVerdicts =
    needsAiCheck.length > 0
      ? await aiVerifyAll(needsAiCheck)
      : new Map<string, boolean>();

  // Assemble final results
  const result = events.map((event) => {
    const prelim = prelimResult.get(event.sourceId);

    if (prelim === "published") {
      return { ...event, status: "published" as const };
    }

    // Needs-AI path
    const isPlausible = aiVerdicts.get(event.sourceId) ?? true;
    if (isPlausible) {
      publishedByAi++;
      return { ...event, status: "published" as const };
    } else {
      draftCount++;
      return { ...event, status: "draft" as const };
    }
  });

  log.info(
    "verify",
    `Published: ${publishedByApi} (API) + ${publishedByUrl} (verified URL) + ${publishedByVenue} (known venue) + ${publishedByAi} (AI-cleared) = ${publishedByApi + publishedByUrl + publishedByVenue + publishedByAi} total`
  );
  if (draftCount > 0) {
    log.info("verify", `Draft (suspected honeypot): ${draftCount} — queued for admin review`);
  }

  return result;
}
