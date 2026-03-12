import { config, type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
import { delay } from "../utils/geocoder.js";

interface SeatGeekEvent {
  id: number;
  title: string;
  description?: string;
  url: string;
  datetime_local: string;
  datetime_utc: string;
  type: string;
  taxonomies: Array<{ name: string }>;
  venue: {
    name: string;
    city: string;
    state: string;
    address?: string;
    location: { lat: number; lon: number };
  };
  performers: Array<{
    name: string;
    image?: string;
    images?: Record<string, string>;
  }>;
}

interface SeatGeekResponse {
  events: SeatGeekEvent[];
  meta: { total: number; page: number; per_page: number };
}

// SeatGeek taxonomies that are family-friendly
const FAMILY_TAXONOMIES = [
  "family",
  "theater",
  "circus",
  "comedy",
  "dance_performance_tour",
  "festival",
  "music_festival",
];

export async function fetchSeatGeekEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (!config.seatgeek.clientId) {
    log.warn("seatgeek", "No client ID configured, skipping");
    return [];
  }

  const events: PipelineEvent[] = [];
  let page = 1;
  const maxPages = 5;

  log.info("seatgeek", `Fetching family events for ${metro.name}...`);

  while (page <= maxPages) {
    try {
      const params = new URLSearchParams({
        client_id: config.seatgeek.clientId,
        lat: String(metro.latitude),
        lon: String(metro.longitude),
        range: `${metro.radiusMiles}mi`,
        per_page: "50",
        page: String(page),
        sort: "datetime_local.asc",
        "datetime_local.gte": new Date().toISOString().split("T")[0],
      });

      // Add taxonomy filter for family-friendly events
      for (const tax of FAMILY_TAXONOMIES) {
        params.append("taxonomies.name", tax);
      }

      const url = `${config.seatgeek.baseUrl}/events?${params}`;
      const res = await fetch(url);

      if (!res.ok) {
        log.error("seatgeek", `HTTP ${res.status}: ${await res.text()}`);
        break;
      }

      const data = (await res.json()) as SeatGeekResponse;
      if (data.events.length === 0) break;

      for (const raw of data.events) {
        events.push(normalizeSeatGeekEvent(raw, metro));
      }

      const totalPages = Math.ceil(data.meta.total / data.meta.per_page);
      if (page >= totalPages) break;
      page++;

      await delay(300);
    } catch (err) {
      log.error("seatgeek", `Error fetching page ${page}`, err);
      break;
    }
  }

  log.success("seatgeek", `Found ${events.length} events for ${metro.name}`);
  return events;
}

function normalizeSeatGeekEvent(
  raw: SeatGeekEvent,
  metro: MetroArea
): PipelineEvent {
  const taxonomyNames = raw.taxonomies.map((t) => t.name);

  // Get the best performer image
  const performerImage =
    raw.performers[0]?.images?.huge ||
    raw.performers[0]?.images?.large ||
    raw.performers[0]?.image;

  return {
    sourceId: `seatgeek:${raw.id}`,
    source: "seatgeek",
    title: raw.title,
    description: cleanDescription(raw.description || ""),
    startDate: raw.datetime_utc,
    isAllDay: false,
    category: categorizeEvent(raw.title, raw.description || "", taxonomyNames),
    city: raw.venue.city,
    address: raw.venue.address,
    latitude: raw.venue.location.lat,
    longitude: raw.venue.location.lon,
    locationName: raw.venue.name,
    imageURL: performerImage,
    externalURL: raw.url,
    isFeatured: false,
    isRecurring: false,
    tags: taxonomyNames,
    metro: metro.id,
  };
}
