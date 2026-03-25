/**
 * Comprehensive AI enrichment using Claude.
 *
 * One pass over every event to simultaneously:
 *  1. Rewrite the description — fresh, unique, engaging 2-3 sentences
 *  2. Validate / correct the category
 *  3. Extract missing structured fields: price, ageRange, locationName, address
 *
 * Replaces the template-based rewrite.ts and the separate categorize-ai.ts step.
 * Falls back gracefully when ANTHROPIC_API_KEY is not set.
 */

import Anthropic from "@anthropic-ai/sdk";
import { type PipelineEvent, isAggregatorSource } from "../normalize.js";
import { log } from "./logger.js";
import {
  enrichmentCacheKey,
  getCachedEnrichment,
  setCachedEnrichment,
} from "./ai-cache.js";

const VALID_CATEGORIES = [
  "Storytime",
  "Farmers Market",
  "Free Movie",
  "Toddler Activity",
  "Craft",
  "Music",
  "Fire Station Tour",
  "Museum",
  "Outdoor",
  "Food & Dining",
  "Sports",
  "Education",
  "Festival",
  "Seasonal",
  "Other",
] as const;

type EventCategory = (typeof VALID_CATEGORIES)[number];

// Events per Claude API call. Smaller = more accurate; larger = faster.
const BATCH_SIZE = 15;

let client: Anthropic | null = null;

function getClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  if (!client) {
    client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return client;
}

// ─── Types ───────────────────────────────────────────────────────────────────

interface AiResult {
  description: string;
  category: EventCategory;
  price?: string | null;
  ageRange?: string | null;
  locationName?: string | null;
  address?: string | null;
}

type BatchResults = Record<string, AiResult>;

// ─── Prompt ──────────────────────────────────────────────────────────────────

function buildPrompt(
  batch: Array<{
    id: string;
    title: string;
    description: string;
    category: string;
    locationName?: string;
    address?: string;
    city: string;
    price?: string;
    ageRange?: string;
  }>
): string {
  return `You are enriching family event listings for a children's events mobile app in Orange County / Los Angeles.

For EACH event below, return a JSON object with these fields:
- "description": Write a fresh, engaging 2–3 sentence description in your own words. Keep factual info (venue names, prices, age ranges). Do NOT start with "Join us", "Don't miss", or "Come enjoy". Do NOT mention any scraper/aggregator websites (Mommy Poppins, Macaroni KID, OC Parent Guide, etc.). Make it warm, family-focused, and specific.
- "category": Choose the BEST fit from this exact list:
  Storytime | Farmers Market | Free Movie | Toddler Activity | Craft | Music | Fire Station Tour | Museum | Outdoor | Food & Dining | Sports | Education | Festival | Seasonal | Other
  IMPORTANT: "Free Movie" is ONLY for movie screenings that are genuinely FREE to attend (no ticket price). If the event title starts with a dollar amount (e.g. "$6 Movie Day") or the description/price field shows a cost, do NOT use "Free Movie" — use "Other" instead.
- "price": Extract a price string ONLY if explicitly mentioned in the description or title (e.g. "Free", "$10", "$5–$15", "Included with admission"). Return null if no price is stated — do NOT guess or infer. CRITICAL RULES:
  1. If the event title contains "($)" or a dollar amount like "($29)", the event is PAID — never return "Free". Extract the dollar amount.
  2. Events at theaters, concert venues, stadiums, or ticketed performance spaces are almost NEVER free — return null unless the description explicitly says "free" or "$0".
  3. Do NOT return "Free" just because no price is mentioned. No price stated = return null. "Free" should only be returned when the event explicitly says it's free, no cost, complimentary, or $0.
  4. If the existing price field already has a value, return null (don't override it).
- "ageRange": Extract target age range if mentioned (e.g. "All ages", "2–5 years", "6–12", "18 months–5 years"). Return null if not stated.
- "locationName": The venue name where this event takes place. If the description or title mentions a specific venue and the provided locationName is empty or wrong, provide the correct name. Use your knowledge for well-known venues (e.g. if the title says "at Kape Coffee Laguna Niguel", use "Kape Coffee Roasters" — the real venue name). Return null only if already correct.
- "address": The street address of the venue in the given city. Use your knowledge for recognizable venues (coffee shops, libraries, parks, community centers). If the provided address is blank or seems wrong for the city, provide the correct address. Return null only if you genuinely don't know it.

IMPORTANT: The "city" field tells you exactly where this event takes place. locationName and address MUST be in that city. If the current address is in a different city from the event's city field, correct it.

Events (JSON array):
${JSON.stringify(
  batch.map((e) => ({
    id: e.id,
    title: e.title,
    description: e.description.slice(0, 500),
    currentCategory: e.category,
    locationName: e.locationName || null,
    address: e.address || null,
    city: e.city,
    price: e.price || null,
    ageRange: e.ageRange || null,
  })),
  null,
  2
)}

Respond with ONLY a JSON object keyed by event id. Example format:
{
  "event-id-1": {
    "description": "Fresh description here...",
    "category": "Storytime",
    "price": "Free",
    "ageRange": "2–6 years",
    "locationName": null,
    "address": null
  }
}`;
}

// ─── API call ─────────────────────────────────────────────────────────────────

async function processBatch(
  batch: PipelineEvent[]
): Promise<BatchResults> {
  const ai = getClient();
  if (!ai) return {};

  const items = batch.map((e) => ({
    id: e.sourceId,
    title: e.title,
    description: e.description,
    category: e.category,
    locationName: e.locationName,
    address: e.address,
    city: e.city,
    price: e.price,
    ageRange: e.ageRange,
  }));

  try {
    const response = await ai.messages.create({
      model: "claude-sonnet-4-5",
      max_tokens: 4096,
      messages: [{ role: "user", content: buildPrompt(items) }],
    });

    const text =
      response.content[0].type === "text" ? response.content[0].text : "";

    // Extract JSON blob (Claude sometimes wraps in markdown fences)
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      log.warn("ai-enricher", "Could not parse AI response as JSON");
      return {};
    }

    return JSON.parse(jsonMatch[0]) as BatchResults;
  } catch (err) {
    log.warn("ai-enricher", `Batch failed: ${String(err)}`);
    return {};
  }
}

// ─── Apply results ────────────────────────────────────────────────────────────

function applyResult(event: PipelineEvent, result: AiResult): void {
  const aggregator = isAggregatorSource(event.source);

  // Description — only rewrite for aggregator sources (legal protection)
  // Direct sources keep their original descriptions
  if (aggregator && result.description && result.description.length > 20) {
    event.description = result.description;
  }

  // Category — update if AI provides a valid one (applies to all sources)
  if (
    result.category &&
    VALID_CATEGORIES.includes(result.category as EventCategory) &&
    result.category !== event.category
  ) {
    event.category = result.category;
  }

  // Price — only fill if not already set (applies to all sources)
  if (result.price && !event.price) {
    event.price = result.price;
  }

  // Age range — fill if missing (applies to all sources)
  if (result.ageRange && !event.ageRange) {
    event.ageRange = result.ageRange;
  }

  // Location name — only correct for aggregator sources or fill if missing
  if (result.locationName && (aggregator || !event.locationName)) {
    event.locationName = result.locationName;
  }

  // Address — only correct for aggregator sources or fill if missing
  if (result.address && (aggregator || !event.address)) {
    event.address = result.address;
  }
}

// ─── Main export ─────────────────────────────────────────────────────────────

/**
 * AI-powered enrichment pass over all events.
 *
 * Simultaneously rewrites descriptions, corrects categories,
 * and extracts missing structured fields (price, ageRange, location, address).
 *
 * Results are cached by sourceId + content hash so unchanged events are served
 * from cache on subsequent pipeline runs, avoiding redundant API calls.
 *
 * Falls back to existing data when ANTHROPIC_API_KEY is not set or API fails.
 */
export async function aiEnrichEvents(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  const ai = getClient();

  if (!ai) {
    log.info(
      "ai-enricher",
      "ANTHROPIC_API_KEY not set — skipping AI enrichment (using keyword categorization + template rewrites)"
    );
    return events;
  }

  // ── Split into cached vs. needs-processing ───────────────────────────────
  const needsProcessing: PipelineEvent[] = [];
  let cacheHits = 0;
  let descRewritten = 0;
  let categoryChanged = 0;
  let pricesFound = 0;
  let ageRangesFound = 0;
  let locationsFound = 0;
  let addressesFound = 0;
  let failed = 0;

  for (const event of events) {
    const cacheKey = enrichmentCacheKey(
      event.sourceId,
      event.title,
      event.description,
      event.category
    );
    const cached = getCachedEnrichment(cacheKey);
    if (cached) {
      // Apply cached result directly — no API call needed
      const prevDesc = event.description;
      const prevCat = event.category;
      const prevPrice = event.price;
      const prevAgeRange = event.ageRange;
      const prevLocationName = event.locationName;
      const prevAddress = event.address;
      applyResult(event, cached);
      if (event.description !== prevDesc) descRewritten++;
      if (event.category !== prevCat) categoryChanged++;
      if (event.price !== prevPrice) pricesFound++;
      if (event.ageRange !== prevAgeRange) ageRangesFound++;
      if (event.locationName !== prevLocationName) locationsFound++;
      if (event.address !== prevAddress) addressesFound++;
      cacheHits++;
    } else {
      needsProcessing.push(event);
    }
  }

  log.info(
    "ai-enricher",
    `Cache: ${cacheHits} hits, ${needsProcessing.length} events need AI processing`
  );

  // ── Process uncached events via Claude API ───────────────────────────────
  if (needsProcessing.length > 0) {
    log.info(
      "ai-enricher",
      `AI enriching ${needsProcessing.length} events in batches of ${BATCH_SIZE}...`
    );
    const totalBatches = Math.ceil(needsProcessing.length / BATCH_SIZE);

    for (let i = 0; i < needsProcessing.length; i += BATCH_SIZE) {
      const batch = needsProcessing.slice(i, i + BATCH_SIZE);
      const batchNum = Math.floor(i / BATCH_SIZE) + 1;

      if (totalBatches > 3) {
        log.info(
          "ai-enricher",
          `  Batch ${batchNum}/${totalBatches} (${batch.length} events)...`
        );
      }

      const results = await processBatch(batch);

      for (const event of batch) {
        const result = results[event.sourceId];
        if (!result) {
          failed++;
          continue;
        }

        // Compute cache key BEFORE applyResult mutates the event
        const cacheKey = enrichmentCacheKey(
          event.sourceId,
          event.title,
          event.description,
          event.category
        );

        const prevDesc = event.description;
        const prevCat = event.category;
        const prevPrice = event.price;
        const prevAgeRange = event.ageRange;
        const prevLocationName = event.locationName;
        const prevAddress = event.address;

        applyResult(event, result);

        if (event.description !== prevDesc) descRewritten++;
        if (event.category !== prevCat) categoryChanged++;
        if (event.price !== prevPrice) pricesFound++;
        if (event.ageRange !== prevAgeRange) ageRangesFound++;
        if (event.locationName !== prevLocationName) locationsFound++;
        if (event.address !== prevAddress) addressesFound++;

        // Save enriched result to cache so future runs skip this event
        setCachedEnrichment(cacheKey, {
          description: event.description,
          category: event.category,
          price: event.price ?? null,
          ageRange: event.ageRange ?? null,
          locationName: event.locationName ?? null,
          address: event.address ?? null,
        });
      }

      // Polite delay between batches
      if (i + BATCH_SIZE < needsProcessing.length) {
        await new Promise((resolve) => setTimeout(resolve, 600));
      }
    }
  }

  log.success("ai-enricher", `AI enrichment complete:`);
  log.info("ai-enricher", `  ${cacheHits} served from cache (no API call)`);
  log.info("ai-enricher", `  ${descRewritten} descriptions rewritten`);
  log.info("ai-enricher", `  ${categoryChanged} categories corrected`);
  log.info("ai-enricher", `  ${pricesFound} prices extracted`);
  log.info("ai-enricher", `  ${ageRangesFound} age ranges found`);
  log.info("ai-enricher", `  ${locationsFound} location names discovered`);
  log.info("ai-enricher", `  ${addressesFound} addresses discovered`);
  if (failed > 0) {
    log.info("ai-enricher", `  ${failed} events fell back to existing data`);
  }

  return events;
}
