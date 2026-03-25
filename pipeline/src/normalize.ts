// Unified event schema that all sources normalize into
export interface PipelineEvent {
  sourceId: string; // e.g., "ticketmaster:Z7r9jZ1A7xGZa"
  source: string; // "ticketmaster" | "seatgeek" | "yelp" | "macaronikid"
  title: string;
  description: string;
  startDate: string; // ISO 8601
  endDate?: string;
  isAllDay: boolean;
  category: string; // mapped to app's EventCategory enum
  city: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  locationName?: string;
  imageURL?: string;
  externalURL?: string;
  isFeatured: boolean;
  isRecurring: boolean;
  tags: string[];
  metro: string; // "los-angeles" | "new-york" | etc.

  // Enriched fields (from detail pages)
  price?: string; // e.g. "Free", "$15-$25", "Child: $38; Adult: $25"
  ageRange?: string; // e.g. "All ages", "3-10", "18-24 months"
  websiteURL?: string; // official event/venue website
  phone?: string; // venue phone number
  contactEmail?: string; // event contact email

  // Moderation status (assigned by verify-events.ts)
  // "published" = safe to show; "draft" = needs admin review; "rejected" = hidden
  status?: "published" | "draft" | "rejected";
}

/**
 * Aggregator sources whose content (descriptions, titles, images) must be
 * rewritten to avoid copyright/legal issues. Events from direct venue sources,
 * APIs, and official calendars should preserve their original content.
 */
const AGGREGATOR_SOURCES = new Set([
  "oc-parent-guide",
  "mommypoppins",
  "macaronikid",
]);

/** Returns true if the event source is an aggregator site whose content needs rewriting. */
export function isAggregatorSource(source: string): boolean {
  return AGGREGATOR_SOURCES.has(source);
}

// Category mapping: keys are iOS EventCategory raw values (Title Case)
// These MUST match the EventCategory enum in the iOS app exactly.
// Keywords are checked against the full event text (title + description + source categories).
// Scoring: each keyword match adds 1 point; the category with the highest score wins.
// Title matches are weighted 3x to prioritize what the event is explicitly called.
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  Storytime: [
    "storytime", "story time", "story hour", "read aloud", "read-aloud",
    "bedtime story", "picture book", "book reading", "library reading",
    "tales for tots", "storybook", "literacy", "bilingual storytime",
    "reading program", "reading challenge", "reading club", "summer reading",
  ],
  "Farmers Market": [
    "farmers market", "farmers' market", "farm market", "farm stand",
    "market day", "artisan market", "flea market", "swap meet",
    "growers market", "produce market", "fresh market",
  ],
  "Free Movie": [
    "movie night", "movie screening", "film screening", "outdoor movie",
    "drive-in", "drive in movie", "cinema night", "movie in the park",
    "free movie", "movies in the park", "movie under the stars",
    "family film", "film festival", "movie festival",
  ],
  "Toddler Activity": [
    "toddler", "baby", "infant", "preschool", "tot ", "tots",
    "mommy and me", "mommy & me", "mom and me", "parent and me",
    "lap time", "babies and books", "wiggle worms", "little ones",
    "littles", "0-3", "1-3 years", "under 5", "playgroup",
    "sensory play", "sensory class", "sensory time",
  ],
  Craft: [
    "craft", "crafts", "art class", "painting", "pottery", "ceramics",
    "drawing class", "diy ", "make your own", "jewelry making",
    "origami", "tie-dye", "tie dye", "watercolor", "sculpt",
    "knitting", "sewing", "fiber arts", "printmaking", "collage",
    "creative workshop", "art workshop", "art project",
  ],
  Music: [
    "concert", "live music", "live band", "sing-along", "sing along",
    "music class", "music performance", "musical performance",
    "orchestra", "symphony", "choir", "choral", "recital",
    "jazz", "bluegrass", "folk music", "drum circle",
    "music festival", "open mic", "karaoke", "ukulele",
    "guitar", "piano recital", "music night",
  ],
  "Fire Station Tour": [
    "fire station", "fire department", "firefighter", "fire truck",
    "fire engine", "first responder", "open house at fire",
  ],
  Museum: [
    "museum", "science center", "natural history", "discovery center",
    "children's museum", "kids museum", "art museum", "aquarium",
    "zoo", "botanical garden", "planetarium", "observatory",
    "history center", "heritage center", "science museum",
    "interactive exhibit", "hands-on exhibit", "permanent collection",
  ],
  Outdoor: [
    "outdoor", "nature hike", "hiking", "hike", "trail walk",
    "nature walk", "nature program", "birdwatching", "bird walk",
    "beach day", "tide pools", "camping", "campfire",
    "outdoor class", "garden tour", "botanical", "arboretum",
    "state park", "national park", "nature reserve", "wildlife",
    "stargazing", "astronomy night", "outdoor yoga", "outdoor fitness",
    "kayak", "paddleboard", "surfing lesson", "fishing",
    "corn maze", "petting zoo", "farm tour",
  ],
  "Food & Dining": [
    "food festival", "food fair", "tasting event", "wine tasting",
    "beer festival", "cooking class", "baking class", "chef demonstration",
    "culinary", "restaurant week", "food tour", "farm-to-table",
    "harvest dinner", "pop-up dinner", "food truck", "food truck festival",
    "chili cook-off", "bbq competition", "pie eating", "ice cream social",
    "chocolate", "dessert", "brunch event", "pizza making",
  ],
  Sports: [
    "soccer", "baseball", "basketball", "football", "softball",
    "swimming", "swim meet", "gymnastics", "cheerleading",
    "tennis", "volleyball", "lacrosse", "rugby", "track and field",
    "martial arts", "karate", "taekwondo", "judo", "wrestling",
    "roller skating", "ice skating", "skateboarding", "cycling race",
    "5k", "fun run", "race day", "sports camp", "sports clinic",
    "little league", "youth league", "youth sports", "sports tryout",
    "dance performance", "dance recital", "dance competition",
  ],
  Education: [
    "stem", "stem class", "science class", "coding class", "robotics",
    "math workshop", "reading workshop", "writing workshop",
    "educational program", "learning workshop", "academic",
    "tutoring", "homework help", "college prep", "sat prep",
    "engineering", "technology class", "computer class",
    "financial literacy", "language class", "foreign language",
    "homeschool", "home school", "enrichment class", "enrichment program",
    "science experiment", "lab day", "science fair", "explorer",
    "science", "coding", "robotics camp", "maker", "makerspace",
  ],
  Festival: [
    "festival", "cultural festival", "street fair", "block party",
    "carnival", "fun fair", "parade", "celebrat",
    "fiesta", "gala", "jubilee", "lantern festival",
    "harvest festival", "spring festival", "summer festival",
    "multicultural", "heritage festival", "arts festival",
    "night market", "moonlight market",
  ],
  Seasonal: [
    "halloween", "trick or treat", "trunk or treat", "haunted",
    "pumpkin patch", "fall festival", "christmas", "holiday",
    "winter wonderland", "santa", "hanukkah", "kwanzaa",
    "easter", "egg hunt", "easter egg", "spring break",
    "summer camp", "day camp", "thanksgiving", "fourth of july",
    "independence day", "valentine", "mother's day", "father's day",
    "new year", "mardi gras", "st. patrick", "corn maze",
    "harvest", "fall activities", "holiday event",
  ],
  Other: [],
};

export function categorizeEvent(
  title: string,
  description: string,
  sourceCategories: string[] = []
): string {
  const titleLower = title.toLowerCase();
  const bodyLower = `${description} ${sourceCategories.join(" ")}`.toLowerCase();

  // Score-based matching: count keyword hits, weight title matches 3x
  const scores: Record<string, number> = {};

  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (category === "Other") continue;
    let score = 0;
    for (const kw of keywords) {
      if (titleLower.includes(kw)) score += 3;  // title match is stronger signal
      else if (bodyLower.includes(kw)) score += 1;
    }
    if (score > 0) scores[category] = score;
  }

  if (Object.keys(scores).length === 0) return "Other";

  // Return the highest-scoring category
  return Object.entries(scores).sort((a, b) => b[1] - a[1])[0][0];
}

// Clean up HTML and truncate description
export function cleanDescription(raw: string, maxLength = 500): string {
  return raw
    .replace(/<[^>]*>/g, "") // strip HTML tags
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ") // collapse whitespace
    .trim()
    .slice(0, maxLength);
}
