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

  const prompt = `You are a content moderator for a family events app. Your job is to identify honeypot/watermark events that scraper-detection services embed in their calendars to catch unauthorized scrapers.

Real events have:
- Plausible titles for local family activities (storytime, farmers market, concerts, festivals, etc.)
- Coherent descriptions with specific details (time, venue, activity)
- Recognizable cities in Southern California (for OC/LA sources) or other US metro areas
- Categories that match the title

Honeypot events often have:
- Nonsensical or overly generic titles
- Empty, very short, or incoherent descriptions
- Implausible combinations (e.g. a "Storytime" in an industrial city with no libraries)
- Randomly generated-looking names or dates
- Titles that are clearly promotional copy for the aggregator site itself

Evaluate each event below. For each, respond with a JSON array entry:
{ "index": <number>, "plausible": <true|false>, "reason": "<brief reason>" }

Be GENEROUS — only flag as honeypot if you are fairly confident it's not a real event. When in doubt, mark as plausible.

Events to evaluate:
${eventList}

Respond with ONLY a JSON array, no other text:`;

  const response = await anthropic.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 1024,
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
  let publishedByAi = 0;
  let draftCount = 0;

  // Layer 1 + 2: synchronous, no API call needed
  const needsAiCheck: PipelineEvent[] = [];
  const prelimResult = new Map<string, "published" | "needs-ai">();

  for (const event of events) {
    if (TRUSTED_API_SOURCES.has(event.source)) {
      prelimResult.set(event.sourceId, "published");
      publishedByApi++;
    } else if (hasVerifiedUrl(event)) {
      prelimResult.set(event.sourceId, "published");
      publishedByUrl++;
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
    `Published: ${publishedByApi} (API) + ${publishedByUrl} (verified URL) + ${publishedByAi} (AI-cleared) = ${publishedByApi + publishedByUrl + publishedByAi} total`
  );
  if (draftCount > 0) {
    log.info("verify", `Draft (suspected honeypot): ${draftCount} — queued for admin review`);
  }

  return result;
}
