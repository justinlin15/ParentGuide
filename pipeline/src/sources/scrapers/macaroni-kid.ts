import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";
import { getRandomHeaders, randomDelay } from "../../utils/user-agents.js";

// Macaroni KID consolidated all local editions (e.g. atlanta.macaronikid.com)
// into national.macaronikid.com. The /events page shows a weekly view of
// server-rendered events. Each event links to a detail page at
// /events/{id}/{slug} with full event info.
//
// Since the national site only shows online/national events (not local ones),
// we now scrape individual event detail pages linked from the weekly listing
// and also navigate through weeks using #eventload-next anchors (which map to
// the server-side week offset parameter).

const BASE_URL = "https://national.macaronikid.com";

export async function scrapeMacaroniKid(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  log.info("macaroni-kid", `Scraping national.macaronikid.com events for ${metro.name}...`);

  try {
    // Scrape the current week
    const currentWeekEvents = await scrapeWeekPage(`${BASE_URL}/events`, metro);
    events.push(...currentWeekEvents);
    log.info("macaroni-kid", `  Current week: ${currentWeekEvents.length} events`);

    // Also try next week and the week after for broader coverage
    // The site uses week offset: /events?week=1 for next week, etc.
    for (let weekOffset = 1; weekOffset <= 3; weekOffset++) {
      await randomDelay(1500, 3000);
      const weekEvents = await scrapeWeekPage(
        `${BASE_URL}/events?week=${weekOffset}`,
        metro
      );
      events.push(...weekEvents);
      log.info("macaroni-kid", `  Week +${weekOffset}: ${weekEvents.length} events`);
      if (weekEvents.length === 0) break;
    }
  } catch (err) {
    log.error("macaroni-kid", "Failed to scrape national events page", err);
  }

  // Deduplicate by sourceId (same event can appear across weeks)
  const seen = new Set<string>();
  const unique = events.filter((e) => {
    if (seen.has(e.sourceId)) return false;
    seen.add(e.sourceId);
    return true;
  });

  log.success(
    "macaroni-kid",
    `Found ${unique.length} events for ${metro.name}`
  );
  return unique;
}

async function scrapeWeekPage(
  url: string,
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  try {
    const res = await fetch(url, {
      headers: getRandomHeaders(),
      redirect: "follow",
    });

    if (!res.ok) {
      log.warn("macaroni-kid", `  HTTP ${res.status} for ${url}`);
      return [];
    }

    const html = await res.text();

    // Extract event links from the weekly listing.
    // Events are rendered as: <a href="/events/{id}/{slug}">Title</a>
    // surrounded by date badges and time/price/location info.
    const eventLinkPattern =
      /<a[^>]*href="(\/events\/[a-f0-9]{20,}\/[^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
    let match;
    const seenPaths = new Set<string>();

    while ((match = eventLinkPattern.exec(html)) !== null) {
      const path = match[1];
      if (seenPaths.has(path)) continue;
      seenPaths.add(path);

      const innerHtml = match[2];
      const title = innerHtml.replace(/<[^>]*>/g, "").trim();
      if (!title || title.length < 3) continue;

      // Extract surrounding context for date, time, location
      const contextStart = Math.max(0, match.index - 300);
      const contextEnd = Math.min(html.length, match.index + match[0].length + 500);
      const context = html.slice(contextStart, contextEnd);

      // Look for date badge: <span>Mar</span><span>12</span> or similar
      // Date badges often appear as "Mar\n12" or "Mar12" in text
      const dateBadgeMatch = context.match(
        />(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*<[^>]*>\s*(\d{1,2})\s*</i
      );

      // Look for time info near the event link
      const timeMatch = context.match(
        /(\d{1,2}:\d{2}\s*(?:AM|PM)(?:\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM))?)/i
      );

      // Look for location info (e.g., "Online Event" or city name)
      const locationMatch = context.match(
        /(?:Online\s+Event|Virtual|In-Person|(?:in\s+)?([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*))/i
      );

      // Build the date
      let startDate: string;
      if (dateBadgeMatch) {
        const monthStr = dateBadgeMatch[1];
        const dayStr = dateBadgeMatch[2];
        const year = new Date().getFullYear();
        const monthDate = new Date(`${monthStr} ${dayStr}, ${year}`);
        if (!isNaN(monthDate.getTime())) {
          if (timeMatch) {
            const timeParsed = parseTimeString(timeMatch[1]);
            startDate = `${monthDate.toISOString().split("T")[0]}T${timeParsed}`;
          } else {
            startDate = monthDate.toISOString();
          }
        } else {
          startDate = new Date().toISOString();
        }
      } else {
        startDate = new Date().toISOString();
      }

      const isOnline = /online\s+event|virtual/i.test(context);

      events.push({
        sourceId: `macaronikid:national:${path}`,
        source: "macaronikid",
        title,
        description: "",
        startDate,
        isAllDay: !timeMatch,
        category: categorizeEvent(title, "", []),
        city: isOnline ? "Online" : locationMatch?.[1] || metro.name,
        metro: metro.id,
        imageURL: undefined,
        externalURL: `${BASE_URL}${path}`,
        isFeatured: false,
        isRecurring: false,
        tags: ["macaronikid"],
      });
    }

    // If we found event links, try to enrich a subset with detail page data
    if (events.length > 0) {
      const toEnrich = events.slice(0, 10); // Limit detail fetches
      for (const event of toEnrich) {
        try {
          await randomDelay(1200, 2500);
          await enrichEventFromDetailPage(event);
        } catch {
          // Detail enrichment is best-effort
        }
      }
    }
  } catch (err) {
    log.error("macaroni-kid", `  Failed to fetch ${url}`, err);
  }

  return events;
}

async function enrichEventFromDetailPage(
  event: PipelineEvent
): Promise<void> {
  if (!event.externalURL) return;

  const res = await fetch(event.externalURL, {
    headers: getRandomHeaders(),
    redirect: "follow",
  });

  if (!res.ok) return;

  const html = await res.text();

  // Try to extract description from meta tags or page content
  const metaDescMatch = html.match(
    /<meta[^>]*name="description"[^>]*content="([^"]*)"[^>]*>/i
  );
  if (metaDescMatch && metaDescMatch[1]) {
    event.description = cleanDescription(metaDescMatch[1]);
  }

  // Try to extract image from og:image
  const ogImageMatch = html.match(
    /<meta[^>]*property="og:image"[^>]*content="([^"]*)"[^>]*>/i
  );
  if (ogImageMatch && ogImageMatch[1]) {
    event.imageURL = ogImageMatch[1];
  }

  // Try to extract a more precise date from the detail page
  // Look for patterns like "Thursday, March 12, 2026" or "March 12, 2026 at 10:00 AM"
  const detailDateMatch = html.match(
    /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})(?:\s+at\s+(\d{1,2}:\d{2}\s*(?:AM|PM)))?/i
  );
  if (detailDateMatch) {
    try {
      const dateStr = detailDateMatch[1];
      const d = new Date(dateStr);
      if (!isNaN(d.getTime())) {
        if (detailDateMatch[2]) {
          const time = parseTimeString(detailDateMatch[2]);
          event.startDate = `${d.toISOString().split("T")[0]}T${time}`;
          event.isAllDay = false;
        } else {
          event.startDate = d.toISOString();
        }
      }
    } catch {
      // Keep existing date
    }
  }

  // Try to get age range info
  const ageMatch = html.match(/Ages?\s+(\d{1,2})\s*[-–]\s*(\d{1,2})/i);
  if (ageMatch) {
    event.tags = [...(event.tags || []), `ages-${ageMatch[1]}-${ageMatch[2]}`];
  }

  // Try to detect cost info
  const freeMatch = html.match(/\bFREE\b/i);
  if (freeMatch) {
    event.tags = [...(event.tags || []), "free"];
  }
}

function parseTimeString(timeStr: string): string {
  // Parse "10:00 AM" or "2:00 PM" into "HH:MM:00"
  const match = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
  if (!match) return "00:00:00";

  let hours = parseInt(match[1]);
  const minutes = match[2];
  const period = match[3].toUpperCase();

  if (period === "PM" && hours !== 12) hours += 12;
  if (period === "AM" && hours === 12) hours = 0;

  return `${hours.toString().padStart(2, "0")}:${minutes}:00`;
}
