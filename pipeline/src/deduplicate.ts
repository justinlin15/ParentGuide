import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

// Deduplicate events from multiple sources
export function deduplicateEvents(events: PipelineEvent[]): PipelineEvent[] {
  const unique = new Map<string, PipelineEvent>();

  for (const event of events) {
    const key = generateDedupeKey(event);
    const existing = unique.get(key);

    if (!existing) {
      unique.set(key, event);
    } else {
      // Keep the more complete version
      unique.set(key, pickBetter(existing, event));
    }
  }

  const deduped = Array.from(unique.values());
  const removed = events.length - deduped.length;

  if (removed > 0) {
    log.info("dedup", `Removed ${removed} duplicates (${events.length} → ${deduped.length})`);
  }

  return deduped;
}

function generateDedupeKey(event: PipelineEvent): string {
  // Normalize title for comparison: lowercase, remove punctuation, collapse spaces
  const normalizedTitle = event.title
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  // Use date (day only) + normalized title as key
  const dateKey = event.startDate.slice(0, 10); // YYYY-MM-DD

  // Include city for location-based dedup
  const cityKey = event.city.toLowerCase().replace(/\s+/g, "");

  return `${dateKey}:${cityKey}:${normalizedTitle}`;
}

// Pick the event with more complete data
function pickBetter(a: PipelineEvent, b: PipelineEvent): PipelineEvent {
  const scoreA = completenessScore(a);
  const scoreB = completenessScore(b);
  return scoreB > scoreA ? b : a;
}

function completenessScore(event: PipelineEvent): number {
  let score = 0;
  if (event.description && event.description.length > 10) score += 2;
  if (event.imageURL) score += 3;
  if (event.latitude && event.longitude) score += 2;
  if (event.address) score += 1;
  if (event.locationName) score += 1;
  if (event.externalURL) score += 1;
  return score;
}
