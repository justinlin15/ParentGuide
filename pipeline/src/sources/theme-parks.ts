/**
 * theme-parks.ts — Theme park event scrapers
 *
 * Fetches events from theme park APIs for OC/LA metro areas:
 *  - ThemeParks.wiki API (Disneyland, DCA, Universal, Six Flags, Knott's, LEGOLAND)
 *  - Exposition Park REST API (California Science Center, Coliseum, CAAM, etc.)
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

// ─── Park Definitions ────────────────────────────────────────────────────────

interface ThemePark {
  entityId: string;
  name: string;
  metro: string;
  city: string;
  address: string;
  latitude: number;
  longitude: number;
  websiteURL: string;
}

const THEME_PARKS: ThemePark[] = [
  {
    entityId: "7340550b-c14d-4def-80bb-acdb51d49a66",
    name: "Disneyland Park",
    metro: "orange-county",
    city: "Anaheim",
    address: "1313 Disneyland Dr, Anaheim, CA 92802",
    latitude: 33.8121,
    longitude: -117.919,
    websiteURL: "https://disneyland.disney.go.com/",
  },
  {
    entityId: "832fcd51-ea19-4e77-85c7-75d5843b127c",
    name: "Disney California Adventure",
    metro: "orange-county",
    city: "Anaheim",
    address: "1313 Disneyland Dr, Anaheim, CA 92802",
    latitude: 33.8069,
    longitude: -117.9189,
    websiteURL: "https://disneyland.disney.go.com/destinations/disney-california-adventure/",
  },
  {
    entityId: "bc4005c5-8c7e-41d7-b349-cdddf1796427",
    name: "Universal Studios Hollywood",
    metro: "los-angeles",
    city: "Universal City",
    address: "100 Universal City Plaza, Universal City, CA 91608",
    latitude: 34.1381,
    longitude: -118.3534,
    websiteURL: "https://www.universalstudioshollywood.com/",
  },
  {
    entityId: "c6073ab0-83aa-4e25-8d60-12c8f25684bc",
    name: "Six Flags Magic Mountain",
    metro: "los-angeles",
    city: "Valencia",
    address: "26101 Magic Mountain Pkwy, Valencia, CA 91355",
    latitude: 34.4254,
    longitude: -118.5972,
    websiteURL: "https://www.sixflags.com/magicmountain",
  },
  {
    entityId: "0a6123bb-1e8c-4b18-a2d3-2696cf2451f5",
    name: "Knott's Berry Farm",
    metro: "orange-county",
    city: "Buena Park",
    address: "8039 Beach Blvd, Buena Park, CA 90620",
    latitude: 33.8443,
    longitude: -117.9986,
    websiteURL: "https://www.knotts.com/",
  },
  {
    entityId: "722116aa-56be-4466-8c6f-a5acbac05da2",
    name: "LEGOLAND California",
    metro: "los-angeles",
    city: "Carlsbad",
    address: "1 Legoland Dr, Carlsbad, CA 92008",
    latitude: 33.1264,
    longitude: -117.3112,
    websiteURL: "https://www.legoland.com/california/",
  },
];

// ─── Shared Helpers ──────────────────────────────────────────────────────────

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

function isFutureDate(dateStr: string): boolean {
  const d = new Date(dateStr);
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return d >= now;
}

function sixtyDaysFromNow(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 60);
  return d;
}

/** Format a Date to YYYY-MM-DD */
function formatDate(d: Date): string {
  return d.toISOString().split("T")[0];
}

/** Format hours like "10:00 AM - 10:00 PM" from ISO times */
function formatTimeRange(openingTime: string, closingTime: string): string {
  try {
    const fmt = (iso: string) => {
      const d = new Date(iso);
      if (isNaN(d.getTime())) return "";
      return d.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
        timeZone: "America/Los_Angeles",
      });
    };
    const open = fmt(openingTime);
    const close = fmt(closingTime);
    if (open && close) return `${open} - ${close}`;
    return "";
  } catch {
    return "";
  }
}

// ─── ThemeParks.wiki API Types ───────────────────────────────────────────────

interface ScheduleEntry {
  date: string; // "2026-03-25"
  type: string; // "OPERATING" | "TICKETED_EVENT" | "EXTRA_HOURS" | "INFO"
  openingTime?: string; // ISO 8601
  closingTime?: string; // ISO 8601
  description?: string;
}

interface ScheduleResponse {
  id: string;
  name: string;
  schedule: ScheduleEntry[];
}

// ─── Main Entry Point ────────────────────────────────────────────────────────

/**
 * Fetch events from theme park APIs and Exposition Park for the given metro.
 */
export async function fetchThemeParkEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const allEvents: PipelineEvent[] = [];

  // ThemeParks.wiki
  const parks = THEME_PARKS.filter((p) => p.metro === metro.id);
  if (parks.length > 0) {
    log.info("theme-parks", `Fetching schedules for ${parks.length} theme parks in ${metro.name}...`);
    for (const park of parks) {
      try {
        const events = await fetchParkSchedule(park);
        if (events.length > 0) {
          log.info("theme-parks", `  ${park.name}: ${events.length} events`);
          allEvents.push(...events);
        }
      } catch (err) {
        log.warn("theme-parks", `  ${park.name} failed: ${err}`);
      }
      await delay(500);
    }
  }

  // Exposition Park (LA only)
  if (metro.id === "los-angeles") {
    try {
      const expoEvents = await fetchExpositionParkEvents();
      if (expoEvents.length > 0) {
        log.info("theme-parks", `  Exposition Park: ${expoEvents.length} events`);
        allEvents.push(...expoEvents);
      }
    } catch (err) {
      log.warn("theme-parks", `  Exposition Park failed: ${err}`);
    }
  }

  log.success("theme-parks", `Total: ${allEvents.length} theme park events for ${metro.name}`);
  return allEvents;
}

// ─── ThemeParks.wiki Schedule Fetcher ────────────────────────────────────────

async function fetchParkSchedule(park: ThemePark): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const allEntries: ScheduleEntry[] = [];
  const maxDate = sixtyDaysFromNow();

  // Fetch current schedule
  try {
    const res = await fetch(
      `https://api.themeparks.wiki/v1/entity/${park.entityId}/schedule`,
      { headers: { Accept: "application/json" } }
    );
    if (res.ok) {
      const data = (await res.json()) as ScheduleResponse;
      if (data.schedule) {
        allEntries.push(...data.schedule);
      }
    } else {
      log.warn("theme-parks", `  ${park.name} schedule HTTP ${res.status}`);
    }
  } catch (err) {
    log.warn("theme-parks", `  ${park.name} schedule fetch error: ${err}`);
  }

  await delay(300);

  // Fetch next 2 months for extended coverage
  const now = new Date();
  for (let i = 1; i <= 2; i++) {
    const future = new Date(now.getFullYear(), now.getMonth() + i, 1);
    const year = future.getFullYear();
    const month = future.getMonth() + 1; // 1-indexed
    try {
      const res = await fetch(
        `https://api.themeparks.wiki/v1/entity/${park.entityId}/schedule/${year}/${month}`,
        { headers: { Accept: "application/json" } }
      );
      if (res.ok) {
        const data = (await res.json()) as ScheduleResponse;
        if (data.schedule) {
          allEntries.push(...data.schedule);
        }
      }
    } catch {
      // Silently skip — future months may not be available yet
    }
    await delay(300);
  }

  // Deduplicate entries by date+type (overlapping fetches may return same days)
  const seen = new Set<string>();
  const uniqueEntries = allEntries.filter((entry) => {
    const key = `${entry.date}:${entry.type}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  // Process entries — only create events for TICKETED_EVENT and EXTRA_HOURS
  for (const entry of uniqueEntries) {
    if (!entry.date || !isFutureDate(entry.date)) continue;
    if (new Date(entry.date) > maxDate) continue;

    if (entry.type === "TICKETED_EVENT") {
      const timeRange = entry.openingTime && entry.closingTime
        ? formatTimeRange(entry.openingTime, entry.closingTime)
        : "";
      const description = entry.description
        ? `${entry.description}. ${timeRange ? `Hours: ${timeRange}.` : ""} Special ticketed event at ${park.name} — separate admission required.`
        : `Special ticketed event at ${park.name}. ${timeRange ? `Hours: ${timeRange}.` : ""} Separate admission required.`;

      events.push({
        sourceId: `themeparks:${park.entityId.slice(0, 8)}:ticketed:${entry.date}`,
        source: "themeparks",
        title: `${park.name} Special Ticketed Event`,
        description: cleanDescription(description),
        startDate: entry.openingTime || `${entry.date}T00:00:00`,
        endDate: entry.closingTime || undefined,
        isAllDay: !entry.openingTime,
        category: categorizeEvent(`${park.name} Special Event`, description, []),
        city: park.city,
        locationName: park.name,
        address: park.address,
        latitude: park.latitude,
        longitude: park.longitude,
        externalURL: park.websiteURL,
        websiteURL: park.websiteURL,
        isFeatured: false,
        isRecurring: false,
        tags: ["theme-park", "ticketed-event"],
        metro: park.metro,
      });
    } else if (entry.type === "EXTRA_HOURS") {
      const timeRange = entry.openingTime && entry.closingTime
        ? formatTimeRange(entry.openingTime, entry.closingTime)
        : "";
      const description = `Extended hours at ${park.name}. ${timeRange ? `Hours: ${timeRange}.` : ""} Extra time to enjoy the park with fewer crowds.`;

      events.push({
        sourceId: `themeparks:${park.entityId.slice(0, 8)}:extra:${entry.date}`,
        source: "themeparks",
        title: `${park.name} Extra Hours`,
        description: cleanDescription(description),
        startDate: entry.openingTime || `${entry.date}T00:00:00`,
        endDate: entry.closingTime || undefined,
        isAllDay: !entry.openingTime,
        category: categorizeEvent(`${park.name} Extra Hours`, description, []),
        city: park.city,
        locationName: park.name,
        address: park.address,
        latitude: park.latitude,
        longitude: park.longitude,
        externalURL: park.websiteURL,
        websiteURL: park.websiteURL,
        isFeatured: false,
        isRecurring: false,
        tags: ["theme-park", "extra-hours"],
        metro: park.metro,
      });
    }
  }

  return events;
}

// ─── Exposition Park REST API (WordPress Tribe Events) ───────────────────────
// https://expositionpark.ca.gov/wp-json/tribe/events/v1/events

interface TribeEvent {
  id: number;
  title: string;
  description: string;
  url: string;
  start_date: string;
  end_date: string;
  all_day: boolean;
  cost: string;
  image?: { url: string };
  venue?: {
    venue: string;
    address: string;
    city: string;
    state: string;
    zip: string;
  };
  categories?: Array<{ name: string }>;
}

interface TribeResponse {
  events: TribeEvent[];
  total: number;
  total_pages: number;
}

/** Keywords that indicate non-family events to skip */
const EXPO_SKIP_KEYWORDS = [
  "gala",
  "fundraiser",
  "private event",
  "corporate",
  "wine tasting",
  "cocktail",
  "black tie",
  "21+",
  "21 and over",
  "adults only",
];

async function fetchExpositionParkEvents(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const today = formatDate(new Date());
  const endDate = formatDate(sixtyDaysFromNow());

  const url = `https://expositionpark.ca.gov/wp-json/tribe/events/v1/events?per_page=50&start_date=${today}&end_date=${endDate}`;

  const res = await fetch(url, {
    headers: { ...getRandomHeaders(), Accept: "application/json" },
  });

  if (!res.ok) {
    log.warn("theme-parks", `Exposition Park HTTP ${res.status}`);
    return [];
  }

  const data = (await res.json()) as TribeResponse;
  if (!data.events) return [];

  for (const raw of data.events) {
    const titleText = stripHtml(raw.title || "");
    if (!titleText) continue;

    // Skip non-family events
    const combined = `${titleText} ${raw.description || ""}`.toLowerCase();
    if (EXPO_SKIP_KEYWORDS.some((kw) => combined.includes(kw))) continue;

    const desc = cleanDescription(stripHtml(raw.description || ""));
    const city = raw.venue?.city || "Los Angeles";
    const locationName = raw.venue?.venue || "Exposition Park";
    const address = raw.venue
      ? `${raw.venue.address}, ${raw.venue.city}, ${raw.venue.state} ${raw.venue.zip}`
      : "700 Exposition Park Dr, Los Angeles, CA 90037";

    events.push({
      sourceId: `expopark:${raw.id}`,
      source: "venue-expopark",
      title: titleText,
      description: desc,
      startDate: raw.start_date,
      endDate: raw.end_date || undefined,
      isAllDay: raw.all_day ?? false,
      category: categorizeEvent(titleText, desc, []),
      city,
      locationName,
      address,
      externalURL: raw.url,
      websiteURL: raw.url,
      imageURL: raw.image?.url,
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: "los-angeles",
      price: raw.cost || undefined,
    });
  }

  return events;
}
