import { config, type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
import { delay } from "../utils/geocoder.js";

interface TicketmasterEvent {
  id: string;
  name: string;
  url?: string;
  info?: string;
  pleaseNote?: string;
  dates: {
    start: {
      localDate?: string;
      localTime?: string;
      dateTime?: string;
    };
    end?: {
      localDate?: string;
      localTime?: string;
      dateTime?: string;
    };
    status?: { code: string };
  };
  classifications?: Array<{
    segment?: { name: string };
    genre?: { name: string };
    subGenre?: { name: string };
  }>;
  priceRanges?: Array<{
    type: string;
    currency: string;
    min: number;
    max: number;
  }>;
  images?: Array<{
    url: string;
    width: number;
    height: number;
    ratio: string;
  }>;
  _embedded?: {
    venues?: Array<{
      name: string;
      city?: { name: string };
      state?: { stateCode: string };
      address?: { line1: string };
      location?: { latitude: string; longitude: string };
    }>;
  };
}

interface TicketmasterResponse {
  _embedded?: {
    events: TicketmasterEvent[];
  };
  page?: {
    totalElements: number;
    totalPages: number;
    number: number;
  };
}

// Additional queries to catch kids events not classified under "Family"
// These use keyword searches to find children's events in other segments
const CHILDREN_KEYWORD_QUERIES = [
  "Children's Theatre",
  "Children's Music",
  "Children's Festival",
];

export async function fetchTicketmasterEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (!config.ticketmaster.apiKey) {
    log.warn("ticketmaster", "No API key configured, skipping");
    return [];
  }

  log.info("ticketmaster", `Fetching family events for ${metro.name}...`);

  const seenIds = new Set<string>();
  const events: PipelineEvent[] = [];

  // Primary query: Family classification
  const familyEvents = await fetchTicketmasterPage(metro, {
    classificationName: "Family",
  });
  for (const e of familyEvents) {
    if (!seenIds.has(e.sourceId)) {
      seenIds.add(e.sourceId);
      events.push(e);
    }
  }

  // Supplemental queries: keyword searches for children's events
  // in non-Family segments (e.g., Arts & Theatre, Music)
  for (const keyword of CHILDREN_KEYWORD_QUERIES) {
    const keywordEvents = await fetchTicketmasterPage(metro, {
      keyword,
    }, 3); // Limit to 3 pages per keyword query
    for (const e of keywordEvents) {
      if (!seenIds.has(e.sourceId)) {
        seenIds.add(e.sourceId);
        events.push(e);
      }
    }
  }

  log.success(
    "ticketmaster",
    `Found ${events.length} events for ${metro.name}`
  );
  return events;
}

async function fetchTicketmasterPage(
  metro: MetroArea,
  extraParams: Record<string, string>,
  maxPages = 10,
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  let page = 0;
  let rateLimitRetries = 0;
  const maxRateLimitRetries = 5;

  while (page < maxPages) {
    try {
      const params = new URLSearchParams({
        apikey: config.ticketmaster.apiKey,
        latlong: `${metro.latitude},${metro.longitude}`,
        radius: String(metro.radiusMiles),
        unit: "miles",
        size: "50",
        page: String(page),
        sort: "date,asc",
        // 60-day window: today → 60 days out
        startDateTime: new Date().toISOString().split(".")[0] + "Z",
        endDateTime: (() => { const d = new Date(); d.setDate(d.getDate() + 60); return d.toISOString().split(".")[0] + "Z"; })(),
        ...extraParams,
      });

      const url = `${config.ticketmaster.baseUrl}/events.json?${params}`;
      const res = await fetch(url);

      if (res.status === 429) {
        rateLimitRetries++;
        if (rateLimitRetries > maxRateLimitRetries) {
          log.error("ticketmaster", "Max rate limit retries exceeded, stopping");
          break;
        }
        log.warn("ticketmaster", `Rate limited, waiting 2s... (retry ${rateLimitRetries}/${maxRateLimitRetries})`);
        await delay(2000);
        continue;
      }
      rateLimitRetries = 0; // Reset on successful request

      if (!res.ok) {
        log.error("ticketmaster", `HTTP ${res.status}: ${await res.text()}`);
        break;
      }

      const data = (await res.json()) as TicketmasterResponse;
      const pageEvents = data._embedded?.events || [];

      if (pageEvents.length === 0) break;

      for (const raw of pageEvents) {
        const normalized = normalizeTicketmasterEvent(raw, metro);
        if (normalized) events.push(normalized);
      }

      const totalPages = data.page?.totalPages || 0;
      page++;
      if (page >= totalPages) break;

      // Rate limit: 5 requests/second
      await delay(250);
    } catch (err) {
      log.error("ticketmaster", `Error fetching page ${page}`, err);
      break;
    }
  }

  return events;
}

function normalizeTicketmasterEvent(
  raw: TicketmasterEvent,
  metro: MetroArea
): PipelineEvent | null {
  // Skip cancelled events
  if (raw.dates.status?.code === "cancelled") return null;

  const venue = raw._embedded?.venues?.[0];
  const classifications = raw.classifications || [];
  const sourceCategories = classifications.map(
    (c) =>
      [c.segment?.name, c.genre?.name, c.subGenre?.name]
        .filter(Boolean)
        .join(" ")
  );

  // Pick the best image (prefer 16:9 ratio, largest width)
  const image = raw.images
    ?.filter((img) => img.ratio === "16_9")
    .sort((a, b) => b.width - a.width)[0] || raw.images?.[0];

  const startDate =
    raw.dates.start.dateTime ||
    (raw.dates.start.localDate
      ? `${raw.dates.start.localDate}T${raw.dates.start.localTime || "00:00:00"}`
      : null);

  if (!startDate) return null;

  const endDate = raw.dates.end?.localDate
    ? `${raw.dates.end.localDate}T${raw.dates.end.localTime || "23:59:59"}`
    : undefined;

  // Extract price range
  let price: string | undefined;
  if (raw.priceRanges && raw.priceRanges.length > 0) {
    const pr = raw.priceRanges[0];
    if (pr.min === 0 && pr.max === 0) {
      price = "Free";
    } else if (pr.min === pr.max) {
      price = `$${pr.min}`;
    } else {
      price = `$${pr.min}-$${pr.max}`;
    }
  }

  return {
    sourceId: `ticketmaster:${raw.id}`,
    source: "ticketmaster",
    title: raw.name,
    description: cleanDescription(raw.info || raw.pleaseNote || ""),
    startDate,
    endDate,
    isAllDay: !raw.dates.start.localTime,
    category: categorizeEvent(raw.name, raw.info || "", sourceCategories),
    city: venue?.city?.name || "",
    address: venue?.address?.line1,
    latitude: venue?.location
      ? parseFloat(venue.location.latitude)
      : undefined,
    longitude: venue?.location
      ? parseFloat(venue.location.longitude)
      : undefined,
    locationName: venue?.name,
    imageURL: image?.url,
    externalURL: raw.url,
    isFeatured: false,
    isRecurring: false,
    tags: sourceCategories.filter(Boolean),
    metro: metro.id,
    price,
  };
}
