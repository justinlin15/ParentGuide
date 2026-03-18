import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { getRandomHeaders } from "../../utils/user-agents.js";

// Kidsguide Magazine — OC/LA family events
// Uses The Events Calendar WordPress plugin with a public REST API.
// No authentication, no Playwright — just JSON pagination.

const SOURCE = "kidsguide";
const API_BASE = "https://kidsguidemagazine.com/wp-json/tribe/events/v1/events";
const PER_PAGE = 50;
const MAX_PAGES = 10; // Safety limit

// Kidsguide covers OC + LA only
const SUPPORTED_METROS = ["orange-county", "los-angeles"];

interface TribeVenue {
  venue?: string;
  address?: string;
  city?: string;
  state?: string;
  zip?: string;
  phone?: string;
  website?: string;
}

interface TribeCategory {
  name?: string;
  slug?: string;
}

interface TribeImage {
  url?: string;
  sizes?: Record<string, { url?: string; width?: number; height?: number }>;
}

interface TribeEvent {
  id: number;
  title: string;
  description?: string;
  start_date?: string;
  end_date?: string;
  all_day?: boolean;
  cost?: string;
  website?: string;
  url?: string;
  venue?: TribeVenue;
  categories?: TribeCategory[];
  image?: TribeImage | false;
}

export async function scrapeKidsguide(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (!SUPPORTED_METROS.includes(metro.id)) return [];

  // Only scrape once for LA (both LA and OC events come from same feed).
  // The pipeline's OC reassignment logic in index.ts handles splitting.
  if (metro.id === "orange-county") {
    log.info(SOURCE, `Skipping ${metro.name} (events fetched under LA, reassigned in post-processing)`);
    return [];
  }

  log.info(SOURCE, `Fetching events from kidsguidemagazine.com...`);

  const today = new Date().toISOString().split("T")[0];
  const allEvents: PipelineEvent[] = [];
  const seenIds = new Set<number>();
  let page = 1;
  let hasMore = true;

  while (hasMore && page <= MAX_PAGES) {
    const url = `${API_BASE}?per_page=${PER_PAGE}&start_date=${today}&page=${page}`;

    try {
      const res = await fetch(url, {
        headers: getRandomHeaders(),
        signal: AbortSignal.timeout(15000),
      });

      if (!res.ok) {
        if (res.status === 404 || res.status === 400) {
          // No more pages
          hasMore = false;
          break;
        }
        log.warn(SOURCE, `HTTP ${res.status} on page ${page}`);
        break;
      }

      const data = await res.json();
      const events: TribeEvent[] = data.events || data || [];

      if (!Array.isArray(events) || events.length === 0) {
        hasMore = false;
        break;
      }

      for (const event of events) {
        if (seenIds.has(event.id)) continue;
        seenIds.add(event.id);

        const parsed = parseEvent(event, metro);
        if (parsed) allEvents.push(parsed);
      }

      log.info(SOURCE, `  Page ${page}: ${events.length} events`);

      // If we got fewer than requested, no more pages
      if (events.length < PER_PAGE) {
        hasMore = false;
      }

      page++;

      // Be polite
      await new Promise((r) => setTimeout(r, 800));
    } catch (err) {
      log.warn(SOURCE, `Page ${page} failed: ${err}`);
      break;
    }
  }

  log.success(SOURCE, `Found ${allEvents.length} events`);
  return allEvents;
}

function parseEvent(raw: TribeEvent, metro: MetroArea): PipelineEvent | null {
  if (!raw.title || !raw.start_date) return null;

  // Clean title — Kidsguide titles often include "| Venue, City"
  const title = raw.title.replace(/<[^>]*>/g, "").trim();
  if (!title || title.length < 3) return null;

  // Parse dates
  const startDate = normalizeDate(raw.start_date);
  const endDate = raw.end_date ? normalizeDate(raw.end_date) : undefined;
  const isAllDay = raw.all_day ?? (!raw.start_date.includes("T") || raw.start_date.includes("00:00:00"));

  // Venue
  const venue = raw.venue;
  const locationName = venue?.venue?.replace(/<[^>]*>/g, "").trim();
  const city = venue?.city || extractCityFromTitle(title) || metro.name;
  const address = buildAddress(venue);

  // Description — strip HTML
  const description = raw.description
    ? cleanDescription(raw.description.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim(), 800)
    : "";

  // Image
  let imageURL: string | undefined;
  if (raw.image && typeof raw.image === "object") {
    // Prefer medium-large size
    const sizes = raw.image.sizes;
    imageURL = sizes?.["medium_large"]?.url
      || sizes?.["large"]?.url
      || sizes?.["medium"]?.url
      || raw.image.url;
  }

  // Categories
  const categories = (raw.categories || [])
    .map((c) => c.name?.replace(/^[•*]\s*/, "").trim() || "")
    .filter(Boolean);

  // Price
  const price = raw.cost && raw.cost.trim() ? raw.cost.trim() : undefined;

  return {
    sourceId: `${SOURCE}:${raw.id}`,
    source: SOURCE,
    title,
    description,
    startDate,
    endDate,
    isAllDay,
    category: categorizeEvent(title, description, categories),
    city,
    address,
    locationName,
    imageURL,
    externalURL: raw.url || `https://kidsguidemagazine.com/event/${raw.id}/`,
    websiteURL: raw.website || venue?.website,
    phone: venue?.phone,
    price,
    isFeatured: categories.some((c) => /editor/i.test(c)),
    isRecurring: false,
    tags: [SOURCE, ...categories.map((c) => c.toLowerCase())],
    metro: metro.id,
  };
}

function normalizeDate(dateStr: string): string {
  // Input: "2026-03-20 00:00:00" or "2026-03-20T00:00:00"
  return dateStr.replace(" ", "T");
}

function buildAddress(venue?: TribeVenue): string | undefined {
  if (!venue) return undefined;
  const parts: string[] = [];
  if (venue.address) parts.push(venue.address);
  if (venue.city) {
    let cityLine = venue.city;
    if (venue.state) cityLine += `, ${venue.state}`;
    if (venue.zip) cityLine += ` ${venue.zip}`;
    parts.push(cityLine);
  }
  return parts.length > 0 ? parts.join(", ") : undefined;
}

function extractCityFromTitle(title: string): string | undefined {
  // Kidsguide titles: "Event Name | Venue, City"
  const pipeMatch = title.match(/\|\s*[^,]+,\s*(.+)$/);
  if (pipeMatch) return pipeMatch[1].trim();
  return undefined;
}
