import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// events.newyorkfamily.com - WordPress + The Events Calendar (Tribe Events)
// Paginated HTML list with event cards containing title, date, venue, categories

export async function scrapeNYCFamily(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "new-york") return [];

  log.info("nyc-family", "Scraping events.newyorkfamily.com...");
  const events: PipelineEvent[] = [];
  const maxPages = 5;

  for (let page = 1; page <= maxPages; page++) {
    try {
      const pageEvents = await scrapePage(page, metro);
      if (pageEvents.length === 0) break;
      events.push(...pageEvents);
      await delay(2000);
    } catch (err) {
      log.error("nyc-family", `Error on page ${page}`, err);
      break;
    }
  }

  log.success("nyc-family", `Found ${events.length} events`);
  return events;
}

async function scrapePage(
  page: number,
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const url =
    page === 1
      ? "https://events.newyorkfamily.com"
      : `https://events.newyorkfamily.com?tribe_paged=${page}`;

  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      Accept: "text/html",
    },
  });

  if (!res.ok) {
    log.warn("nyc-family", `HTTP ${res.status} on page ${page}`);
    return [];
  }

  const html = await res.text();
  const events: PipelineEvent[] = [];

  // Parse date headers: <h2>Wednesday March 11, 2026</h2>
  // Then event blocks under each date
  let currentDate = "";

  // Split by date headers
  const dateHeaderPattern = /<h2[^>]*>\s*((?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+\w+\s+\d{1,2},?\s+\d{4})\s*<\/h2>/gi;
  const dateSections = html.split(dateHeaderPattern);

  for (let i = 1; i < dateSections.length; i += 2) {
    const dateText = dateSections[i];
    const sectionHtml = dateSections[i + 1] || "";

    try {
      currentDate = new Date(dateText).toISOString().split("T")[0];
    } catch {
      continue;
    }

    // Parse event links within this date section
    // Pattern: <a href="/event/event-slug/">Event Title</a>
    const eventPattern =
      /<a[^>]*href="(\/event\/[^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
    let match;
    const seenPaths = new Set<string>();

    while ((match = eventPattern.exec(sectionHtml)) !== null) {
      const path = match[1];
      if (seenPaths.has(path)) continue;
      seenPaths.add(path);

      const innerHtml = match[2];
      const title = innerHtml.replace(/<[^>]*>/g, "").trim();
      if (!title || title.length < 3 || title.length > 200) continue;

      // Look for time near this match
      const timeMatch = sectionHtml
        .slice(Math.max(0, match.index - 200), match.index + 500)
        .match(/(\d{1,2}:\d{2}\s*(?:am|pm))/i);

      // Look for venue
      const venueMatch = sectionHtml
        .slice(match.index, match.index + 500)
        .match(/class="[^"]*venue[^"]*"[^>]*>([\s\S]*?)<\//i);

      // Look for image
      const imgMatch = sectionHtml
        .slice(Math.max(0, match.index - 500), match.index + 200)
        .match(/<img[^>]*src="([^"]*)"[^>]*>/i);

      // Look for categories
      const catMatches = sectionHtml
        .slice(match.index, match.index + 500)
        .match(
          /class="[^"]*categor[^"]*"[^>]*>([\s\S]*?)<\/(?:a|span|div)/gi
        );
      const categories = catMatches
        ? catMatches.map((m) => m.replace(/<[^>]*>/g, "").trim())
        : [];

      const startDate = timeMatch
        ? `${currentDate}T${parseTime(timeMatch[1])}`
        : `${currentDate}T00:00:00`;

      events.push({
        sourceId: `nycfamily:${path}`,
        source: "nycfamily",
        title,
        description: "",
        startDate,
        isAllDay: !timeMatch,
        category: categorizeEvent(title, "", categories),
        city: venueMatch
          ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
          : "New York",
        locationName: venueMatch
          ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
          : undefined,
        imageURL: imgMatch ? imgMatch[1] : undefined,
        externalURL: `https://events.newyorkfamily.com${path}`,
        isFeatured: false,
        isRecurring: false,
        tags: categories.filter((c) => c.length > 0),
        metro: metro.id,
      });
    }
  }

  log.info("nyc-family", `  Page ${page}: ${events.length} events`);
  return events;
}

function parseTime(timeStr: string): string {
  const match = timeStr.match(/(\d{1,2}):(\d{2})\s*(am|pm)/i);
  if (!match) return "00:00:00";

  let hours = parseInt(match[1]);
  const minutes = match[2];
  const period = match[3].toLowerCase();

  if (period === "pm" && hours !== 12) hours += 12;
  if (period === "am" && hours === 12) hours = 0;

  return `${hours.toString().padStart(2, "0")}:${minutes}:00`;
}
