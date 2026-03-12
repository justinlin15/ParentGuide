import { config, type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
import { delay } from "../utils/geocoder.js";

interface YelpEvent {
  id: string;
  name: string;
  description: string;
  time_start: string;
  time_end?: string;
  is_free: boolean;
  cost?: number;
  cost_max?: number;
  event_site_url: string;
  image_url?: string;
  category?: string;
  is_canceled: boolean;
  location: {
    display_address: string[];
    city: string;
    state: string;
    zip_code: string;
    address1?: string;
  };
  latitude?: number;
  longitude?: number;
}

interface YelpResponse {
  events: YelpEvent[];
  total: number;
}

export async function fetchYelpEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (!config.yelp.apiKey) {
    log.warn("yelp", "No API key configured, skipping");
    return [];
  }

  const events: PipelineEvent[] = [];
  let offset = 0;
  const limit = 50;
  const maxResults = 300;

  log.info("yelp", `Fetching events for ${metro.name}...`);

  while (offset < maxResults) {
    try {
      const params = new URLSearchParams({
        latitude: String(metro.latitude),
        longitude: String(metro.longitude),
        radius: String(Math.min(metro.radiusMiles * 1609, 40000)), // Yelp uses meters, max 40km
        limit: String(limit),
        offset: String(offset),
        sort_on: "time_start",
        sort_by: "asc",
        start_date: Math.floor(Date.now() / 1000).toString(),
      });

      const url = `${config.yelp.baseUrl}/events?${params}`;
      const res = await fetch(url, {
        headers: {
          Authorization: `Bearer ${config.yelp.apiKey}`,
        },
      });

      if (res.status === 429) {
        log.warn("yelp", "Rate limited, waiting 5s...");
        await delay(5000);
        continue;
      }

      if (!res.ok) {
        log.error("yelp", `HTTP ${res.status}: ${await res.text()}`);
        break;
      }

      const data = (await res.json()) as YelpResponse;
      if (data.events.length === 0) break;

      for (const raw of data.events) {
        if (!raw.is_canceled) {
          events.push(normalizeYelpEvent(raw, metro));
        }
      }

      offset += limit;
      if (offset >= data.total) break;

      await delay(300);
    } catch (err) {
      log.error("yelp", `Error fetching offset ${offset}`, err);
      break;
    }
  }

  log.success("yelp", `Found ${events.length} events for ${metro.name}`);
  return events;
}

function normalizeYelpEvent(
  raw: YelpEvent,
  metro: MetroArea
): PipelineEvent {
  return {
    sourceId: `yelp:${raw.id}`,
    source: "yelp",
    title: raw.name,
    description: cleanDescription(raw.description || ""),
    startDate: raw.time_start,
    endDate: raw.time_end,
    isAllDay: false,
    category: categorizeEvent(raw.name, raw.description, [
      raw.category || "",
    ]),
    city: raw.location.city,
    address: raw.location.address1 || raw.location.display_address.join(", "),
    latitude: raw.latitude,
    longitude: raw.longitude,
    locationName: undefined,
    imageURL: raw.image_url || undefined,
    externalURL: raw.event_site_url,
    isFeatured: false,
    isRecurring: false,
    tags: [raw.category, raw.is_free ? "free" : "paid"].filter(
      Boolean
    ) as string[],
    metro: metro.id,
  };
}
