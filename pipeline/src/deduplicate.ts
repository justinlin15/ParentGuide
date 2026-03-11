import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

// Deduplicate events from multiple sources
export function deduplicateEvents(events: PipelineEvent[]): PipelineEvent[] {
  const unique = new Map<string, PipelineEvent>();

  for (const event of events) {
    const key = generateDedupeKey(event);
    const existing = unique.get(key);

    if (!existing) {
      // Also check fuzzy match against existing keys
      const fuzzyMatch = findFuzzyMatch(event, unique);
      if (fuzzyMatch) {
        unique.set(fuzzyMatch.key, pickBetter(fuzzyMatch.event, event));
      } else {
        unique.set(key, event);
      }
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
  const normalizedTitle = normalizeTitle(event.title);
  const dateKey = event.startDate.slice(0, 10); // YYYY-MM-DD
  const cityKey = event.city.toLowerCase().replace(/\s+/g, "");
  return `${dateKey}:${cityKey}:${normalizedTitle}`;
}

/**
 * Aggressively normalize title for dedup comparison:
 * - Lowercase
 * - Remove parenthetical info like ($12), (Free), (Register)
 * - Remove "in CityName" suffixes
 * - Remove punctuation, collapse spaces
 */
function normalizeTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/\s*\([^)]*\)/g, "")           // remove (...) parenthetical
    .replace(/\s+(?:in|at)\s+[\w\s]+$/i, "") // remove trailing "in CityName"
    .replace(/[^a-z0-9\s]/g, "")             // remove punctuation
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Fuzzy match: find an existing event that's nearly identical.
 * Checks same date + similar title (Levenshtein distance ≤ 5 or one is substring of other).
 */
function findFuzzyMatch(
  event: PipelineEvent,
  existing: Map<string, PipelineEvent>
): { key: string; event: PipelineEvent } | null {
  const eventTitle = normalizeTitle(event.title);
  const eventDate = event.startDate.slice(0, 10);

  if (eventTitle.length < 10) return null; // too short to fuzzy match

  for (const [key, candidate] of existing) {
    const candidateDate = candidate.startDate.slice(0, 10);
    if (candidateDate !== eventDate) continue;

    const candidateTitle = normalizeTitle(candidate.title);

    // Check if one title is a substring of the other
    if (
      eventTitle.includes(candidateTitle) ||
      candidateTitle.includes(eventTitle)
    ) {
      return { key, event: candidate };
    }

    // Check Levenshtein distance for similar-length titles
    if (
      Math.abs(eventTitle.length - candidateTitle.length) < 10 &&
      levenshtein(eventTitle, candidateTitle) <= 5
    ) {
      return { key, event: candidate };
    }
  }

  return null;
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

/**
 * Simple Levenshtein distance (edit distance) between two strings.
 * Capped at max 200 chars to keep it fast.
 */
function levenshtein(a: string, b: string): number {
  const aSlice = a.slice(0, 200);
  const bSlice = b.slice(0, 200);
  const m = aSlice.length;
  const n = bSlice.length;

  const dp: number[][] = Array.from({ length: m + 1 }, () =>
    Array(n + 1).fill(0)
  );

  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      if (aSlice[i - 1] === bSlice[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] = 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
      }
    }
  }

  return dp[m][n];
}
