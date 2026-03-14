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

// Category mapping: keys are iOS EventCategory raw values (Title Case)
// These MUST match the EventCategory enum in the iOS app exactly.
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  Storytime: ["storytime", "story time", "reading", "book"],
  "Farmers Market": ["farmers market", "farm market", "market day"],
  "Free Movie": ["movie", "film", "cinema", "screening"],
  "Toddler Activity": ["toddler", "baby", "infant", "preschool", "tot"],
  Craft: ["craft", "art", "paint", "drawing", "pottery", "diy"],
  Music: ["music", "concert", "live band", "sing", "song", "jam"],
  "Fire Station Tour": ["fire station", "fire department", "firefighter"],
  Museum: ["museum", "exhibit", "gallery"],
  Outdoor: [
    "outdoor",
    "hike",
    "hiking",
    "nature",
    "park",
    "beach",
    "camping",
    "garden",
  ],
  "Food & Dining": [
    "food",
    "dining",
    "eat",
    "restaurant",
    "tasting",
    "cooking",
    "chef",
  ],
  Sports: [
    "sport",
    "soccer",
    "baseball",
    "basketball",
    "swim",
    "tennis",
    "gymnastics",
    "cheer",
  ],
  Education: [
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
  Festival: [
    "festival",
    "fair",
    "carnival",
    "parade",
    "celebration",
    "fiesta",
  ],
  Seasonal: [
    "holiday",
    "christmas",
    "halloween",
    "easter",
    "thanksgiving",
    "summer camp",
    "spring break",
    "valentine",
  ],
  Other: [],
};

export function categorizeEvent(
  title: string,
  description: string,
  sourceCategories: string[] = []
): string {
  const searchText = `${title} ${description} ${sourceCategories.join(" ")}`.toLowerCase();

  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (category === "Other") continue;
    if (keywords.some((kw) => searchText.includes(kw))) {
      return category;
    }
  }

  return "Other";
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
