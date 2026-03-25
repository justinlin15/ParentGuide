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
 * - Remove leading city/region names (e.g. "San Diego Comic-Con" → "Comic-Con")
 * - Remove trailing year (e.g. "Comic-Con 2026" → "Comic-Con")
 * - Remove punctuation, collapse spaces
 */
function normalizeTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/\s*\([^)]*\)/g, "")           // remove (...) parenthetical
    .replace(/\s+(?:in|at)\s+[\w\s]+$/i, "") // remove trailing "in CityName"
    .replace(/^(?:san diego|los angeles|orange county|anaheim|long beach|irvine|santa ana|pasadena|glendale|burbank|costa mesa|huntington beach|newport beach|laguna beach|fullerton|torrance|santa monica|san juan capistrano|dana point|san clemente|mission viejo|lake forest|tustin|yorba linda|brea|la habra|placentia|buena park|garden grove|westminster|fountain valley|cypress|stanton|la palma|cerritos|lakewood|downey|whittier|pomona|ontario|rancho cucamonga|riverside|temecula|carlsbad|oceanside|escondido|encinitas|del mar)\s+/i, "")
    .replace(/\s+20\d{2}$/i, "")             // remove trailing year
    .replace(/[^a-z0-9\s]/g, "")             // remove punctuation
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Check if two normalized titles are similar enough to be duplicates.
 */
function titlesMatch(titleA: string, titleB: string): boolean {
  if (titleA === titleB) return true;

  const shorter = Math.min(titleA.length, titleB.length);
  const longer = Math.max(titleA.length, titleB.length);

  // Check if one title is a substring of the other,
  // but only if the shorter title is > 50% the length of the longer one.
  if (
    shorter / longer > 0.5 &&
    (titleA.includes(titleB) || titleB.includes(titleA))
  ) {
    return true;
  }

  // Check Levenshtein distance with a proportional threshold:
  // Allow at most 15% of the shorter title's length as edit distance,
  // capped at a maximum of 6 edits.
  const maxDistance = Math.min(6, Math.floor(shorter * 0.15));
  if (
    Math.abs(titleA.length - titleB.length) < 10 &&
    levenshtein(titleA, titleB) <= maxDistance
  ) {
    return true;
  }

  return false;
}

/**
 * Fuzzy match: find an existing event that's nearly identical.
 * Checks same date + similar title using proportional thresholds
 * to avoid over-aggressive deduplication.
 *
 * Also matches across cities when the same venue/location hosts the event
 * (handles cases where sources disagree on city names).
 */
function findFuzzyMatch(
  event: PipelineEvent,
  existing: Map<string, PipelineEvent>
): { key: string; event: PipelineEvent } | null {
  const eventTitle = normalizeTitle(event.title);
  const eventDate = event.startDate.slice(0, 10);

  // Require title to be long enough for fuzzy matching
  if (eventTitle.length < 10) return null;

  for (const [key, candidate] of existing) {
    const candidateDate = candidate.startDate.slice(0, 10);
    if (candidateDate !== eventDate) continue;

    const candidateTitle = normalizeTitle(candidate.title);
    if (candidateTitle.length < 10) continue;

    if (titlesMatch(eventTitle, candidateTitle)) {
      return { key, event: candidate };
    }

    // Also check with venue/location name stripped from titles.
    // Some sources prepend or append the venue name to event titles,
    // e.g. "Anaheim Convention Center - Comic Con" vs "Comic Con"
    if (event.locationName && candidate.locationName) {
      const venueA = event.locationName.toLowerCase().replace(/[^a-z0-9\s]/g, "").trim();
      const venueB = candidate.locationName.toLowerCase().replace(/[^a-z0-9\s]/g, "").trim();
      // If same venue, use more relaxed title matching
      if (venueA === venueB && venueA.length > 3) {
        const strippedA = eventTitle.replace(new RegExp(venueA.replace(/\s+/g, "\\s*"), "gi"), "").trim();
        const strippedB = candidateTitle.replace(new RegExp(venueB.replace(/\s+/g, "\\s*"), "gi"), "").trim();
        if (strippedA.length >= 5 && strippedB.length >= 5 && titlesMatch(strippedA, strippedB)) {
          return { key, event: candidate };
        }
      }
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

// Source priority: direct API sources with real URLs are preferred over scrapers.
// Higher = better. Sources not listed default to 0.
const SOURCE_PRIORITY: Record<string, number> = {
  ticketmaster: 5,
  seatgeek: 5,
  eventbrite: 5,
  libcal: 4,       // Direct library calendar — real event URLs
  kidsguide: 3,    // WordPress API — decent URLs
  yelp: 3,
  // Direct venue scrapers — real event URLs from the venue itself
  "venue-kidspace": 4,
  "venue-southcoastplaza": 4,
  "venue-academy": 4,
  "venue-nhm": 4,
  "venue-skirball": 4,
  "venue-discoverycube": 4,
  "venue-underwood": 4,
  // Theme parks, museums, and other direct sources
  "themeparks": 4,
  "venue-expopark": 4,
  "pretend-city": 4,
  "la-parent": 3,    // Aggregator but high-quality family events
  mommypoppins: 1, // Scraper — has websiteURLs but aggregator
  "oc-parent-guide": 0, // Scraper — Google Search fallback URLs
  macaronikid: 0,
};

function completenessScore(event: PipelineEvent): number {
  let score = 0;
  if (event.description && event.description.length > 10) score += 2;
  if (event.imageURL) score += 3;
  if (event.latitude && event.longitude) score += 2;
  if (event.address) score += 1;
  if (event.locationName) score += 1;
  if (event.externalURL && !event.externalURL.includes("google.com/search")) score += 2;
  if (event.websiteURL && !event.websiteURL.includes("google.com/search")) score += 2;
  // Source priority bonus
  score += SOURCE_PRIORITY[event.source] ?? 0;
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
