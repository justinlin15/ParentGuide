/**
 * libcal.ts — LibCal Public AJAX Scraper
 *
 * Fetches family-friendly library events directly from LibCal calendar
 * instances used by Orange County public libraries. Uses the unauthenticated
 * AJAX JSON endpoint that powers the public calendar pages.
 *
 * Endpoint: GET {host}/ajax/calendar/list?c={calId}&date={YYYY-MM-DD}&page={n}
 * Returns: { total_results, perpage, status, results: LibCalEvent[] }
 *
 * Covers:
 *  - OC Public Libraries (OCPL): 29 branches
 *  - Huntington Beach Public Library: 5 branches
 *  - Anaheim Public Library: multiple branches
 *  - Mission Viejo, Fullerton, Yorba Linda, Orange, Buena Park, Santa Ana, etc.
 */

import { type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
import { delay } from "../utils/geocoder.js";
import { getRandomHeaders } from "../utils/user-agents.js";

// ─── LibCal AJAX Response Types ───────────────────────────────────────────────

interface LibCalEvent {
  id: number;
  title: string;
  description?: string;
  shortdesc?: string;
  start: string;        // "10:30 AM"
  end: string;          // "11:30 AM"
  startdt: string;      // "2026-03-26 10:30:00"
  enddt: string;        // "2026-03-26 17:00:00"
  date: string;         // "Thursday, March 26, 2026"
  all_day: boolean;
  url: string;          // "https://ocpl.libcal.com/event/15623674"
  location: string;     // "El Toro"
  calendar: string;     // "El Toro"
  color?: string;
  featured_image?: string;
  recurring_event: boolean;
  registration_enabled: boolean;
  registration_cost?: string;
  seats?: number;
  more_info?: string;
}

interface LibCalResponse {
  total_results: number;
  perpage: number;
  status: number;
  results: LibCalEvent[];
}

// ─── Library Instance Configuration ───────────────────────────────────────────

interface LibCalInstance {
  /** Display name for logging */
  name: string;
  /** Base URL (e.g., "https://ocpl.libcal.com") */
  host: string;
  /** Calendar IDs to query. Use [0] or [-1] for "all calendars" if supported. */
  calendarIds: number[];
  /** Map calendar location names → actual city for the iOS app */
  cityOverrides?: Record<string, string>;
  /** Default city when location can't be mapped */
  defaultCity: string;
}

// OCPL branch calendar IDs (from https://ocpl.libcal.com/calendars)
// Individual branch IDs required — system-wide ID 19162 only has system events.
const OCPL_INSTANCES: LibCalInstance = {
  name: "OC Public Libraries",
  host: "https://ocpl.libcal.com",
  calendarIds: [
    19125, // Aliso Viejo
    19126, // Brea
    19131, // Costa Mesa Donald Dungan
    19132, // Costa Mesa Mesa Verde
    19133, // Cypress
    19134, // Dana Point
    19135, // El Toro
    19136, // Foothill Ranch
    19137, // Fountain Valley
    19138, // Garden Grove Chapman
    19139, // Garden Grove Main
    19140, // Garden Grove Tibor Rubin
    19144, // La Habra
    19145, // La Palma
    19146, // Ladera Ranch
    19147, // Laguna Beach
    19148, // Laguna Hills
    19149, // Laguna Niguel
    19150, // Laguna Woods
    19151, // Library of the Canyons
    19152, // Los Alamitos-Rossmoor
    19153, // Rancho Santa Margarita
    19154, // San Clemente
    19155, // San Juan Capistrano
    19156, // Seal Beach
    19157, // Stanton
    19158, // Tustin
    19159, // Villa Park
    19160, // Westminster
  ],
  cityOverrides: {
    "aliso viejo": "Aliso Viejo",
    "brea": "Brea",
    "costa mesa donald dungan": "Costa Mesa",
    "costa mesa - donald dungan": "Costa Mesa",
    "costa mesa mesa verde": "Costa Mesa",
    "costa mesa - mesa verde": "Costa Mesa",
    "study room": "Orange County",
    "cypress": "Cypress",
    "dana point": "Dana Point",
    "el toro": "Lake Forest",
    "foothill ranch": "Lake Forest",
    "fountain valley": "Fountain Valley",
    "garden grove chapman": "Garden Grove",
    "garden grove main": "Garden Grove",
    "garden grove tibor rubin": "Garden Grove",
    "la habra": "La Habra",
    "la palma": "La Palma",
    "ladera ranch": "Ladera Ranch",
    "laguna beach": "Laguna Beach",
    "laguna hills": "Laguna Hills",
    "laguna niguel": "Laguna Niguel",
    "laguna woods": "Laguna Woods",
    "library of the canyons": "Silverado",
    "los alamitos-rossmoor": "Los Alamitos",
    "los alamitos rossmoor": "Los Alamitos",
    "los alamitos": "Los Alamitos",
    "rancho santa margarita": "Rancho Santa Margarita",
    "san clemente": "San Clemente",
    "san juan capistrano": "San Juan Capistrano",
    "seal beach": "Seal Beach",
    "stanton": "Stanton",
    "tustin": "Tustin",
    "villa park": "Villa Park",
    "westminster": "Westminster",
    "katie wheeler": "Irvine",
  },
  defaultCity: "Orange County",
};

const HB_INSTANCE: LibCalInstance = {
  name: "Huntington Beach Public Library",
  host: "https://hbpl.libcal.com",
  calendarIds: [6565, 5188],
  cityOverrides: {
    "central library": "Huntington Beach",
    "main street": "Huntington Beach",
    "main street library": "Huntington Beach",
    "oak view": "Huntington Beach",
    "oakview": "Huntington Beach",
    "banning": "Huntington Beach",
    "murphy": "Huntington Beach",
    "helen murphy": "Huntington Beach",
  },
  defaultCity: "Huntington Beach",
};

const ANAHEIM_INSTANCE: LibCalInstance = {
  name: "Anaheim Public Library",
  host: "https://anaheim.libcal.com",
  calendarIds: [22106, 22409, 22411, 22410, 22413, 22415], // Central, Canyon Hills, East Anaheim, Euclid, Haskett, Sunkist
  cityOverrides: {
    "central": "Anaheim",
    "central library": "Anaheim",
    "canyon hills": "Anaheim",
    "east anaheim": "Anaheim",
    "euclid": "Anaheim",
    "sunkist": "Anaheim",
    "haskett": "Anaheim",
  },
  defaultCity: "Anaheim",
};

const MISSION_VIEJO_INSTANCE: LibCalInstance = {
  name: "Mission Viejo Library",
  host: "https://cityofmissionviejo.libcal.com",
  calendarIds: [20496],
  defaultCity: "Mission Viejo",
};

const FULLERTON_INSTANCE: LibCalInstance = {
  name: "Fullerton Public Library",
  host: "https://fullertonlibrary.libcal.com",
  calendarIds: [16707],
  cityOverrides: {
    "main library": "Fullerton",
    "hunt": "Fullerton",
    "hunt branch": "Fullerton",
  },
  defaultCity: "Fullerton",
};

const YORBA_LINDA_INSTANCE: LibCalInstance = {
  name: "Yorba Linda Public Library",
  host: "https://ylpl.libcal.com",
  calendarIds: [11139, 19851], // Children's Programs, Adult and Teen Programs
  defaultCity: "Yorba Linda",
};

const ORANGE_INSTANCE: LibCalInstance = {
  name: "Orange Public Library",
  host: "https://orangepubliclibrary.libcal.com",
  calendarIds: [20904],
  cityOverrides: {
    "main": "Orange",
    "taft": "Orange",
    "el modena": "Orange",
  },
  defaultCity: "Orange",
};

// All OC LibCal instances to query
const OC_LIBCAL_INSTANCES: LibCalInstance[] = [
  OCPL_INSTANCES,
  HB_INSTANCE,
  ANAHEIM_INSTANCE,
  MISSION_VIEJO_INSTANCE,
  FULLERTON_INSTANCE,
  YORBA_LINDA_INSTANCE,
  ORANGE_INSTANCE,
];

// ─── Adult/Non-Family Event Filter ────────────────────────────────────────────

/** Keywords that indicate an adult-only or non-family event */
const ADULT_KEYWORDS = [
  // Language/citizenship classes
  "esl conversation", "esl class", "english as a second",
  "citizenship", "naturalization", "immigration",
  // Job/career
  "job help", "job search", "resume", "career workshop", "career fair",
  // Tax/legal/financial
  "tax prep", "tax preparation", "notary", "legal clinic", "financial planning",
  // Senior-specific
  "aarp", "senior", "seniors only", "medicare", "social security",
  "bingo", "bridge club",
  // Adult programs
  "book club for adults", "adult book", "adult coloring", "adult craft",
  "adult enrichment", "adult program", "adult workshop", "adult class",
  "for adults", "makerspace for adults", "adults only",
  // Health/wellness (adult-targeted)
  "knitting circle", "crochet circle", "quilting",
  "meditation for adults", "yoga for adults",
  "blood pressure", "health screening", "caregiver",
  "dementia", "alzheimer", "grief support", "bereavement",
  // Technology classes (typically for seniors/adults)
  "computer class", "computer basics", "tech help", "drop in tech",
  "drop-in tech", "smartphone basics", "iphone basics", "ipad basics",
  "internet basics", "email basics",
  // Networking/professional
  "networking event", "business workshop", "professional development",
  // Board/admin meetings
  "board meeting", "board of trustees", "friends of the library meeting",
  // Veteran/military
  "veterans resource", "veterans day event",
  // Cancelled events
  "cancelled", "canceled",
  // Wellness/yoga (adult)
  "wellness workshop", "mental wellness", "life balance",
  // Other adult activities
  "genealogy", "memoir writing", "watercolor for adults",
];

function isFamilyFriendly(event: LibCalEvent): boolean {
  const titleLower = event.title.toLowerCase();
  const descLower = (event.shortdesc || event.description || "").toLowerCase();
  const combined = `${titleLower} ${descLower}`;

  // Reject if title matches adult keywords
  for (const keyword of ADULT_KEYWORDS) {
    if (titleLower.includes(keyword)) return false;
  }

  // Keep events that are explicitly for kids/families/teens
  const familyKeywords = [
    "storytime", "story time", "baby", "toddler", "preschool",
    "kids", "children", "family", "teen", "tween", "youth",
    "play and learn", "lego", "craft", "homework",
    "summer reading", "reading program", "puppet",
    "sensory", "music and movement", "rhyme time",
  ];

  for (const keyword of familyKeywords) {
    if (combined.includes(keyword)) return true;
  }

  // For events that don't clearly match family OR adult keywords,
  // include them (err on side of inclusion — AI enrichment will fix categories)
  return true;
}

// ─── Date Helpers ─────────────────────────────────────────────────────────────

/** Generate date strings for the next N days */
function getDateRange(days: number): string[] {
  const dates: string[] = [];
  const today = new Date();
  for (let i = 0; i < days; i++) {
    const d = new Date(today);
    d.setDate(d.getDate() + i);
    dates.push(d.toISOString().split("T")[0]);
  }
  return dates;
}

/** Convert LibCal "2026-03-26 10:30:00" to ISO 8601 */
function toISO(libcalDt: string): string {
  // LibCal format: "2026-03-26 10:30:00" (local time, America/Los_Angeles)
  // Convert to ISO with timezone offset
  const [datePart, timePart] = libcalDt.split(" ");
  if (!datePart || !timePart) return libcalDt;
  return `${datePart}T${timePart}`;
}

/** Strip HTML tags from description */
function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// ─── Main Scraper ─────────────────────────────────────────────────────────────

/**
 * Fetch family-friendly library events from all OC LibCal instances.
 * Only runs for orange-county metro.
 */
export async function fetchLibCalEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  // LibCal instances are OC-only
  if (metro.id !== "orange-county") return [];

  const allEvents: PipelineEvent[] = [];
  const seenIds = new Set<number>();

  for (const instance of OC_LIBCAL_INSTANCES) {
    const instanceEvents = await fetchFromInstance(instance, seenIds);
    allEvents.push(...instanceEvents);
  }

  log.success(
    "libcal",
    `Total: ${allEvents.length} family-friendly library events from ${OC_LIBCAL_INSTANCES.length} instances`
  );

  return allEvents;
}

async function fetchFromInstance(
  instance: LibCalInstance,
  seenIds: Set<number>
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const dates = getDateRange(60);

  log.info("libcal", `Fetching from ${instance.name} (${instance.host})...`);

  // For each calendar ID, fetch events for 60 days
  // We batch dates in groups of 7 (weekly) to reduce requests
  for (const calId of instance.calendarIds) {
    let totalFetched = 0;
    currentCalendarId = calId;

    // Fetch week by week (every 7th date) — LibCal returns multiple days per page
    for (let i = 0; i < dates.length; i += 7) {
      const date = dates[i];

      try {
        // Fetch page 1 (usually sufficient for a week of events per branch)
        const url = `${instance.host}/ajax/calendar/list?c=${calId}&date=${date}&audience=&cats=&camps=&inc=0&page=1`;

        const res = await fetch(url, {
          headers: {
            ...getRandomHeaders(),
            Accept: "application/json",
            Referer: `${instance.host}/calendar`,
          },
        });

        if (!res.ok) {
          if (res.status === 429) {
            log.warn("libcal", `Rate limited on ${instance.name}, waiting 3s...`);
            await delay(3000);
            continue;
          }
          log.warn("libcal", `HTTP ${res.status} from ${instance.name} for ${date}`);
          continue;
        }

        const data = (await res.json()) as LibCalResponse;

        if (!data.results || data.results.length === 0) continue;

        for (const raw of data.results) {
          // Skip if already seen (dedup across calendars/dates)
          if (seenIds.has(raw.id)) continue;
          seenIds.add(raw.id);

          // Skip non-family events
          if (!isFamilyFriendly(raw)) continue;

          const normalized = normalizeLibCalEvent(raw, instance);
          if (normalized) {
            events.push(normalized);
            totalFetched++;
          }
        }

        // If there are more pages, fetch them
        if (data.total_results > data.perpage) {
          const totalPages = Math.ceil(data.total_results / data.perpage);
          for (let page = 2; page <= Math.min(totalPages, 5); page++) {
            await delay(200);
            const pageUrl = `${instance.host}/ajax/calendar/list?c=${calId}&date=${date}&audience=&cats=&camps=&inc=0&page=${page}`;
            try {
              const pageRes = await fetch(pageUrl, {
                headers: {
                  ...getRandomHeaders(),
                  Accept: "application/json",
                  Referer: `${instance.host}/calendar`,
                },
              });
              if (!pageRes.ok) break;
              const pageData = (await pageRes.json()) as LibCalResponse;
              if (!pageData.results || pageData.results.length === 0) break;

              for (const raw of pageData.results) {
                if (seenIds.has(raw.id)) continue;
                seenIds.add(raw.id);
                if (!isFamilyFriendly(raw)) continue;
                const normalized = normalizeLibCalEvent(raw, instance);
                if (normalized) {
                  events.push(normalized);
                  totalFetched++;
                }
              }
            } catch {
              break;
            }
          }
        }

        await delay(250); // Rate limit: ~4 req/sec
      } catch (err) {
        log.warn("libcal", `Error fetching ${instance.name} ${date}: ${err}`);
      }
    }

    log.info("libcal", `  ${instance.name} cal ${calId}: ${totalFetched} events`);
  }

  return events;
}

// ─── Normalize ────────────────────────────────────────────────────────────────

function normalizeLibCalEvent(
  raw: LibCalEvent,
  instance: LibCalInstance
): PipelineEvent | null {
  if (!raw.title || !raw.startdt) return null;

  // Resolve city from location name
  const locationLower = (raw.location || raw.calendar || "").toLowerCase().trim();
  const city = resolveCity(locationLower, instance);

  // Build location name (add "Library" suffix if not present)
  let locationName = raw.location || raw.calendar || "";
  if (locationName && !locationName.toLowerCase().includes("library")) {
    locationName = `${locationName} Library`;
  }

  // Extract description, strip HTML
  const rawDesc = raw.shortdesc || raw.description || "";
  const description = cleanDescription(stripHtml(rawDesc));

  // Extract price from registration_cost
  let price: string | undefined;
  if (raw.registration_cost) {
    const costStr = raw.registration_cost.trim();
    if (costStr && costStr !== "0" && costStr !== "$0" && costStr !== "$0.00") {
      price = costStr;
    }
  }
  // Most library events are free
  if (!price) {
    price = "Free";
  }

  return {
    sourceId: `libcal:${raw.id}`,
    source: "libcal",
    title: raw.title.trim(),
    description,
    startDate: toISO(raw.startdt),
    endDate: raw.enddt ? toISO(raw.enddt) : undefined,
    isAllDay: raw.all_day ?? false,
    category: categorizeEvent(raw.title, description, []),
    city,
    locationName,
    externalURL: raw.url,
    websiteURL: raw.url,
    imageURL: raw.featured_image || undefined,
    isFeatured: false,
    isRecurring: raw.recurring_event ?? false,
    tags: [],
    metro: "orange-county",
    price,
  };
}

// OCPL calendar ID → city (most reliable mapping since we know the branch)
const OCPL_CALENDAR_CITY: Record<number, string> = {
  19125: "Aliso Viejo",
  19126: "Brea",
  19131: "Costa Mesa",
  19132: "Costa Mesa",
  19133: "Cypress",
  19134: "Dana Point",
  19135: "Lake Forest",    // El Toro branch is in Lake Forest
  19136: "Lake Forest",    // Foothill Ranch is in Lake Forest
  19137: "Fountain Valley",
  19138: "Garden Grove",
  19139: "Garden Grove",
  19140: "Garden Grove",
  19144: "La Habra",
  19145: "La Palma",
  19146: "Ladera Ranch",
  19147: "Laguna Beach",
  19148: "Laguna Hills",
  19149: "Laguna Niguel",
  19150: "Laguna Woods",
  19151: "Silverado",
  19152: "Los Alamitos",
  19153: "Rancho Santa Margarita",
  19154: "San Clemente",
  19155: "San Juan Capistrano",
  19156: "Seal Beach",
  19157: "Stanton",
  19158: "Tustin",
  19159: "Villa Park",
  19160: "Westminster",
};

/** Resolve city from location name, with calendarId fallback for OCPL */
let currentCalendarId = 0; // Set before each batch fetch

function resolveCity(locationLower: string, instance: LibCalInstance): string {
  // Check instance-specific overrides
  if (instance.cityOverrides) {
    // Exact match first
    if (instance.cityOverrides[locationLower]) {
      return instance.cityOverrides[locationLower];
    }
    // Partial match — check if location contains any override key
    for (const [key, city] of Object.entries(instance.cityOverrides)) {
      if (locationLower.includes(key) || key.includes(locationLower)) {
        return city;
      }
    }
  }
  // Fallback: use OCPL calendar ID → city mapping
  if (instance.host.includes("ocpl.libcal.com") && OCPL_CALENDAR_CITY[currentCalendarId]) {
    return OCPL_CALENDAR_CITY[currentCalendarId];
  }

  return instance.defaultCity;
}
