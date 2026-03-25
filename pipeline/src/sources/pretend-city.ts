/**
 * pretend-city.ts — Pretend City Children's Museum scraper
 *
 * Uses the WordPress Tribe Events REST API at:
 *   https://pretendcity.org/wp-json/tribe/events/v1/events
 *
 * ~147 family events (toddler hours, workshops, music, neurodivergent nights).
 * Trusted API source — auto-published.
 */

import { type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
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

interface TribeEvent {
  id: number;
  title: string;
  description: string;
  url: string;
  start_date: string;
  end_date: string;
  all_day: boolean;
  cost: string;
  image?: { url: string } | false;
  venue?: {
    venue: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    phone: string;
  };
  categories?: Array<{ name: string }>;
}

interface TribeResponse {
  events: TribeEvent[];
  total: number;
  total_pages: number;
}

export async function fetchPretendCityEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "orange-county") return [];

  const events: PipelineEvent[] = [];
  const today = new Date().toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 60 * 86400000).toISOString().split("T")[0];

  let page = 1;
  let totalPages = 1;

  while (page <= totalPages && page <= 5) {
    const url = `https://pretendcity.org/wp-json/tribe/events/v1/events?per_page=50&start_date=${today}&end_date=${endDate}&page=${page}`;

    try {
      const res = await fetch(url, {
        headers: { ...getRandomHeaders(), Accept: "application/json" },
      });

      if (!res.ok) {
        if (page === 1) log.warn("pretend-city", `HTTP ${res.status}`);
        break;
      }

      const data = (await res.json()) as TribeResponse;
      if (!data.events || data.events.length === 0) break;

      totalPages = data.total_pages || 1;

      for (const raw of data.events) {
        const title = stripHtml(raw.title || "");
        if (!title) continue;

        const desc = cleanDescription(stripHtml(raw.description || ""));

        events.push({
          sourceId: `pretendcity:${raw.id}`,
          source: "pretend-city",
          title,
          description: desc,
          startDate: raw.start_date,
          endDate: raw.end_date || undefined,
          isAllDay: raw.all_day ?? false,
          category: categorizeEvent(title, desc, []),
          city: "Irvine",
          locationName: raw.venue?.venue || "Pretend City Children's Museum",
          address: raw.venue
            ? `${raw.venue.address}, ${raw.venue.city}, ${raw.venue.state} ${raw.venue.zip}`
            : "29 Hubble, Irvine, CA 92618",
          latitude: 33.6846,
          longitude: -117.7986,
          externalURL: raw.url,
          websiteURL: raw.url,
          imageURL: raw.image ? (raw.image as { url: string }).url : undefined,
          isFeatured: false,
          isRecurring: false,
          tags: [],
          metro: "orange-county",
          price: raw.cost || undefined,
          phone: raw.venue?.phone || "949-428-3900",
        });
      }

      page++;
    } catch (err) {
      log.warn("pretend-city", `Page ${page} failed: ${err}`);
      break;
    }
  }

  if (events.length > 0) {
    log.info("pretend-city", `${events.length} events from Pretend City`);
  }

  return events;
}
