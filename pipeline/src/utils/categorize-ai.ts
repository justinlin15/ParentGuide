/**
 * AI-powered event category classification using Claude.
 *
 * Falls back to the existing keyword system if:
 * - ANTHROPIC_API_KEY is not set
 * - The API call fails
 * - The response cannot be parsed
 */

import Anthropic from "@anthropic-ai/sdk";
import { type PipelineEvent, categorizeEvent } from "../normalize.js";
import { log } from "./logger.js";

// All valid EventCategory values — must match iOS app enum exactly
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

// How many events to classify in a single Claude API call
const BATCH_SIZE = 25;

// Only re-classify events in this set — "Other" always gets AI pass;
// misclassified events often stay at "Other" with keyword matching anyway.
// Setting to true re-classifies ALL events (more accurate, slightly slower).
const RECLASSIFY_ALL = false;

let client: Anthropic | null = null;

function getClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  if (!client) {
    client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return client;
}

interface BatchItem {
  id: string;
  title: string;
  description: string;
  locationName?: string;
  currentCategory: string;
}

/**
 * Ask Claude to classify a batch of events.
 * Returns a map of event id → category string.
 */
async function classifyBatch(
  batch: BatchItem[]
): Promise<Map<string, EventCategory>> {
  const ai = getClient();
  if (!ai) return new Map();

  const prompt = `You are classifying family events for a children's events app.

Classify each event into EXACTLY one of these categories:
- Storytime: library/bookstore story readings, book clubs for kids
- Farmers Market: outdoor markets, farm stands, produce markets
- Free Movie: outdoor movie screenings, drive-in movies, movie nights
- Toddler Activity: playgroups, mommy-and-me, classes for babies/toddlers under 5
- Craft: arts & crafts, painting, pottery, DIY workshops, creative classes
- Music: concerts, live music, sing-alongs, music classes, performances
- Fire Station Tour: fire station open houses, first responder events
- Museum: museum exhibits, science centers, discovery centers, aquariums, zoos
- Outdoor: nature hikes, beach days, outdoor adventures, camping, park events
- Food & Dining: food festivals, cooking classes, restaurant events, tastings, food trucks
- Sports: sports games, leagues, swim meets, gymnastics, athletic events
- Education: STEM, coding, academic workshops, tutoring, school events, science fairs
- Festival: multicultural festivals, fairs, carnivals, parades, holiday festivals
- Seasonal: Halloween events, Christmas/holiday events, Easter egg hunts, summer camps
- Other: anything that doesn't fit above

Events to classify (JSON array):
${JSON.stringify(
  batch.map((e) => ({
    id: e.id,
    title: e.title,
    description: e.description.slice(0, 300),
    venue: e.locationName || "",
  })),
  null,
  2
)}

Respond with ONLY a JSON object mapping each id to its category string, like:
{"event-1": "Storytime", "event-2": "Festival", ...}

Use EXACTLY the category names listed above. No explanations.`;

  try {
    const response = await ai.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      messages: [{ role: "user", content: prompt }],
    });

    const text =
      response.content[0].type === "text" ? response.content[0].text : "";

    // Extract JSON from response (Claude sometimes wraps in markdown)
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return new Map();

    const parsed = JSON.parse(jsonMatch[0]) as Record<string, string>;
    const result = new Map<string, EventCategory>();

    for (const [id, category] of Object.entries(parsed)) {
      if (VALID_CATEGORIES.includes(category as EventCategory)) {
        result.set(id, category as EventCategory);
      }
    }

    return result;
  } catch (err) {
    log.warn("categorize-ai", `Claude API call failed: ${String(err)}`);
    return new Map();
  }
}

/**
 * Classify events using Claude AI, with keyword fallback.
 *
 * By default only re-classifies events currently in "Other".
 * Set RECLASSIFY_ALL=true to re-classify everything (more accurate).
 *
 * Modifies events in place.
 */
export async function categorizeEventsWithAI(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  const ai = getClient();

  if (!ai) {
    log.info(
      "categorize-ai",
      "ANTHROPIC_API_KEY not set — skipping AI classification (keyword matching already applied)"
    );
    return events;
  }

  // Select which events need AI classification
  const toClassify = RECLASSIFY_ALL
    ? events
    : events.filter((e) => e.category === "Other");

  if (toClassify.length === 0) {
    log.info("categorize-ai", "No events need AI classification ✓");
    return events;
  }

  log.info(
    "categorize-ai",
    `AI-classifying ${toClassify.length} events in batches of ${BATCH_SIZE}...`
  );

  // Build id → event map for quick lookup
  const eventMap = new Map(events.map((e) => [e.sourceId, e]));

  // Build batch items
  const batchItems: BatchItem[] = toClassify.map((e) => ({
    id: e.sourceId,
    title: e.title,
    description: e.description,
    locationName: e.locationName,
    currentCategory: e.category,
  }));

  let classified = 0;
  let unchanged = 0;
  let failed = 0;

  // Process in batches
  for (let i = 0; i < batchItems.length; i += BATCH_SIZE) {
    const batch = batchItems.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(batchItems.length / BATCH_SIZE);

    if (totalBatches > 1) {
      log.info(
        "categorize-ai",
        `  Batch ${batchNum}/${totalBatches} (${batch.length} events)...`
      );
    }

    const results = await classifyBatch(batch);

    for (const item of batch) {
      const newCategory = results.get(item.id);
      const event = eventMap.get(item.id);

      if (!event) continue;

      if (newCategory) {
        if (newCategory !== event.category) {
          log.info(
            "categorize-ai",
            `  [${event.category} → ${newCategory}] "${event.title.slice(0, 60)}"`
          );
          event.category = newCategory;
          classified++;
        } else {
          unchanged++;
        }
      } else {
        // Claude didn't return this event — keep keyword result or "Other"
        failed++;
      }
    }

    // Small delay between batches to be respectful of rate limits
    if (i + BATCH_SIZE < batchItems.length) {
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }

  log.success(
    "categorize-ai",
    `AI classification complete: ${classified} re-classified, ${unchanged} confirmed, ${failed} fallback to keyword`
  );

  return events;
}
