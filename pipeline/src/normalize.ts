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
}

// Category mapping: keywords → app EventCategory raw values
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  storytime: ["storytime", "story time", "reading", "book"],
  farmersMarket: ["farmers market", "farm market", "market day"],
  freeMovie: ["movie", "film", "cinema", "screening"],
  toddlerActivity: ["toddler", "baby", "infant", "preschool", "tot"],
  craft: ["craft", "art", "paint", "drawing", "pottery", "diy"],
  music: ["music", "concert", "live band", "sing", "song", "jam"],
  fireStationTour: ["fire station", "fire department", "firefighter"],
  museum: ["museum", "exhibit", "gallery"],
  outdoorAdventure: [
    "outdoor",
    "hike",
    "hiking",
    "nature",
    "park",
    "beach",
    "camping",
    "garden",
  ],
  food: ["food", "dining", "eat", "restaurant", "tasting", "cooking", "chef"],
  sports: [
    "sport",
    "soccer",
    "baseball",
    "basketball",
    "swim",
    "tennis",
    "gymnastics",
    "cheer",
  ],
  education: [
    "education",
    "class",
    "workshop",
    "learning",
    "stem",
    "science",
    "coding",
    "school",
    "tutoring",
  ],
  festival: [
    "festival",
    "fair",
    "carnival",
    "parade",
    "celebration",
    "fiesta",
  ],
  seasonal: [
    "holiday",
    "christmas",
    "halloween",
    "easter",
    "thanksgiving",
    "summer camp",
    "spring break",
    "valentine",
  ],
  other: [],
};

export function categorizeEvent(
  title: string,
  description: string,
  sourceCategories: string[] = []
): string {
  const searchText = `${title} ${description} ${sourceCategories.join(" ")}`.toLowerCase();

  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (category === "other") continue;
    if (keywords.some((kw) => searchText.includes(kw))) {
      return category;
    }
  }

  return "other";
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
