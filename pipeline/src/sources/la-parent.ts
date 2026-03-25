/**
 * la-parent.ts — LA Parent Calendar scraper
 *
 * Fetches family events from calendar.laparent.com (SceneThink platform).
 * Uses the discovered search.json API endpoint directly — no Playwright needed.
 *
 * API: GET https://calendar.laparent.com/l-a-parent/search.json?page={n}&ongoing=true
 * Returns ~489 events across 5 pages (100/page).
 * Covers both LA and OC regions.
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

// OC cities for metro classification
const OC_CITIES = new Set([
  "anaheim", "irvine", "santa ana", "huntington beach", "garden grove",
  "orange", "fullerton", "costa mesa", "mission viejo", "lake forest",
  "laguna beach", "laguna niguel", "laguna hills", "newport beach",
  "tustin", "yorba linda", "san clemente", "san juan capistrano",
  "dana point", "aliso viejo", "rancho santa margarita", "brea",
  "buena park", "cypress", "fountain valley", "la habra", "la palma",
  "placentia", "seal beach", "stanton", "westminster", "los alamitos",
]);

// ─── Main Entry Point ────────────────────────────────────────────────────────

export async function fetchLAParentEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const allEvents: PipelineEvent[] = [];
  const maxDate = new Date();
  maxDate.setDate(maxDate.getDate() + 60);
  const now = new Date();
  now.setHours(0, 0, 0, 0);

  let page = 1;
  let totalPages = 5; // Will be updated from API response

  while (page <= totalPages && page <= 10) {
    try {
      const url = `https://calendar.laparent.com/l-a-parent/search.json?page=${page}&ongoing=true`;
      const res = await fetch(url, {
        headers: { ...getRandomHeaders(), Accept: "application/json" },
      });

      if (!res.ok) {
        log.warn("la-parent", `HTTP ${res.status} on page ${page}`);
        break;
      }

      const data = await res.json() as {
        events: Array<{ _source: SceneThinkEvent }>;
        total: number;
        pages: number;
        current: number;
      };

      if (!data.events || data.events.length === 0) break;
      totalPages = data.pages || 1;

      for (const { _source: raw } of data.events) {
        const title = (raw.name || "").trim();
        if (!title) continue;

        // Parse dates
        const startDate = raw.starttime ? new Date(raw.starttime) : null;
        if (!startDate || isNaN(startDate.getTime())) continue;

        // For ongoing events (exhibitions, etc.), check if they're still active
        const endDate = raw.endtime ? new Date(raw.endtime) : null;
        if (endDate && endDate < now) continue; // Already ended

        // If start is far past but end is future, use today as effective start
        let effectiveStart = startDate;
        if (startDate < now && endDate && endDate > now) {
          effectiveStart = now;
        }

        // Skip if beyond our window
        if (effectiveStart > maxDate) continue;

        // Determine metro based on venue city
        const venueCity = raw.venue?.city || "";
        const isOC = OC_CITIES.has(venueCity.toLowerCase());
        const eventMetro = isOC ? "orange-county" : "los-angeles";

        // Only include events matching the requested metro
        if (eventMetro !== metro.id) continue;

        const desc = cleanDescription(stripHtml(raw.description || raw.summary || ""));
        const imageUrl = raw.multimedia?.[0]?.image || raw.multimedia?.[0]?.id;

        // Build event URL
        const eventUrl = raw.moreinfo || raw.ticketurl
          || `https://calendar.laparent.com/cal/${raw.id}`;

        allEvents.push({
          sourceId: `laparent:${raw.id}`,
          source: "la-parent",
          title,
          description: desc,
          startDate: effectiveStart.toISOString(),
          endDate: endDate ? endDate.toISOString() : undefined,
          isAllDay: raw.allday ?? false,
          category: categorizeEvent(title, desc, raw.categories?.map(c => c.name) || []),
          city: venueCity || (isOC ? "Orange County" : "Los Angeles"),
          locationName: raw.venue?.name || undefined,
          address: raw.venue?.address || undefined,
          latitude: raw.geo?.[1] || raw.venue?.latitude,
          longitude: raw.geo?.[0] || raw.venue?.longitude,
          externalURL: eventUrl,
          websiteURL: raw.moreinfo || raw.ticketurl || undefined,
          imageURL: imageUrl,
          isFeatured: false,
          isRecurring: !!raw.recurring_id,
          tags: raw.tags?.map(t => t.name).filter(Boolean) || [],
          metro: eventMetro,
          price: raw.ticketurl ? undefined : undefined, // Price not in API; AI enrichment will extract
        });
      }

      page++;
      await delay(500);
    } catch (err) {
      log.warn("la-parent", `Page ${page} failed: ${err}`);
      break;
    }
  }

  if (allEvents.length > 0) {
    log.info("la-parent", `${allEvents.length} events from LA Parent Calendar (${metro.name})`);
  }

  return allEvents;
}

// ─── SceneThink API Types ────────────────────────────────────────────────────

interface SceneThinkEvent {
  id: number;
  calendar_id: number;
  name: string;
  description: string;
  summary: string;
  starttime: string;
  endtime: string;
  allday: boolean;
  slug: string | null;
  ticketurl: string;
  moreinfo: string;
  recurring_id: number | null;
  status: string;
  restrictions: string;
  multimedia: Array<{ source: string; id: string; type: string; image: string }>;
  geo: [number, number] | null; // [lng, lat]
  categories: Array<{ id: number; name: string }>;
  lists: Array<{ id: number; name: string }>;
  tags: Array<{ name: string }>;
  venue: {
    id: number;
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    latitude: number;
    longitude: number;
    timezone: string;
  } | null;
}
