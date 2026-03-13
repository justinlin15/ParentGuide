import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// events.newyorkfamily.com - WordPress + The Events Calendar (Tribe Events)
// The page uses:
//   - <h2 class="magma-separator-date ..."> for date headers (e.g. "Friday March 13, 2026")
//   - <article class="event-container ..."> for each event card
//   - <h3 class="tribe-events-list-event-title ..."> with inner <a> for title + link
//   - <div class="tribe-event-schedule-details ..."> for time (e.g. "10 am - 4 pm", "Various")
//   - <a href="/venue/..."> for venue name
//   - <a href="/communities/..."> for location/neighborhood
//   - <a href="/things-to-do/..."> inside .event-taxonomy for categories
//   - <a class="magma-event-thumbnail"><img> for event image
// Pagination: ?tribe_paged=N

export async function scrapeNYCFamily(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "new-york") return [];

  log.info("nyc-family", "Scraping events.newyorkfamily.com...");
  const events: PipelineEvent[] = [];
  const maxPages = 15;

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

  // Strategy: Split by date headers, then parse article blocks within each section
  //
  // Date headers look like:
  //   <h2 class="magma-separator-date tribe-events-list-separator-month section-title">
  //     <span>Friday</span> <span>March 13, 2026</span>
  //   </h2>
  //
  // But the text content is: "Friday March 13, 2026" or "Saturday March 14, 2026"

  // Find all date header positions
  const dateHeaderRegex =
    /<h2[^>]*class="[^"]*magma-separator-date[^"]*"[^>]*>([\s\S]*?)<\/h2>/gi;
  const datePositions: Array<{ date: string; index: number }> = [];
  let dateMatch;

  while ((dateMatch = dateHeaderRegex.exec(html)) !== null) {
    const headerHtml = dateMatch[1];
    // Extract text, stripping tags
    const headerText = headerHtml.replace(/<[^>]*>/g, " ").trim();
    // Parse: "Friday March 13, 2026" => extract the date part
    const dateTextMatch = headerText.match(
      /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(.+)/i
    );
    if (dateTextMatch) {
      try {
        const parsed = new Date(dateTextMatch[1].trim());
        if (!isNaN(parsed.getTime())) {
          datePositions.push({
            date: parsed.toISOString().split("T")[0],
            index: dateMatch.index,
          });
        }
      } catch {
        continue;
      }
    }
  }

  // If no date headers found, try a more lenient pattern for any h2 with a date
  if (datePositions.length === 0) {
    const fallbackDateRegex =
      /<h2[^>]*>([\s\S]*?)<\/h2>/gi;
    let fallbackMatch;
    while ((fallbackMatch = fallbackDateRegex.exec(html)) !== null) {
      const text = fallbackMatch[1].replace(/<[^>]*>/g, " ").trim();
      const dateCheck = text.match(
        /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\w+\s+\d{1,2},?\s+\d{4})/i
      );
      if (dateCheck) {
        try {
          const parsed = new Date(dateCheck[1]);
          if (!isNaN(parsed.getTime())) {
            datePositions.push({
              date: parsed.toISOString().split("T")[0],
              index: fallbackMatch.index,
            });
          }
        } catch {
          continue;
        }
      }
    }
  }

  if (datePositions.length === 0) {
    log.info("nyc-family", `  Page ${page}: no date headers found`);
    // Fall back to parsing articles without date context
    const articleEvents = parseArticlesFromHtml(html, "", metro);
    log.info("nyc-family", `  Page ${page}: ${articleEvents.length} events (no date context)`);
    return articleEvents;
  }

  // Process each date section
  for (let i = 0; i < datePositions.length; i++) {
    const currentDate = datePositions[i].date;
    const sectionStart = datePositions[i].index;
    const sectionEnd =
      i + 1 < datePositions.length
        ? datePositions[i + 1].index
        : html.length;
    const sectionHtml = html.slice(sectionStart, sectionEnd);

    const sectionEvents = parseArticlesFromHtml(sectionHtml, currentDate, metro);
    events.push(...sectionEvents);
  }

  log.info("nyc-family", `  Page ${page}: ${events.length} events`);
  return events;
}

function parseArticlesFromHtml(
  html: string,
  currentDate: string,
  metro: MetroArea
): PipelineEvent[] {
  const events: PipelineEvent[] = [];

  // Match each <article class="...event-container..."> ... </article>
  const articleRegex =
    /<article[^>]*class="[^"]*event-container[^"]*"[^>]*>([\s\S]*?)<\/article>/gi;
  let articleMatch;
  const seenPaths = new Set<string>();

  while ((articleMatch = articleRegex.exec(html)) !== null) {
    const articleHtml = articleMatch[1];

    // Extract title and link from <h3><a href="...">Title</a></h3>
    const titleLinkMatch = articleHtml.match(
      /<h3[^>]*>[\s\S]*?<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?<\/h3>/i
    );
    if (!titleLinkMatch) continue;

    const eventUrl = titleLinkMatch[1];
    const title = titleLinkMatch[2].replace(/<[^>]*>/g, "").trim();
    if (!title || title.length < 3 || title.length > 200) continue;

    // Deduplicate by URL path
    const pathMatch = eventUrl.match(/\/event\/([^/]+)/);
    const path = pathMatch ? pathMatch[1] : eventUrl;
    if (seenPaths.has(path)) continue;
    seenPaths.add(path);

    // Extract time from .tribe-event-schedule-details
    const timeMatch = articleHtml.match(
      /class="[^"]*tribe-event-schedule-details[^"]*"[^>]*>([\s\S]*?)<\//i
    );
    const timeText = timeMatch
      ? timeMatch[1].replace(/<[^>]*>/g, "").trim()
      : "";

    // Extract venue from <a href="/venue/...">
    const venueMatch = articleHtml.match(
      /<a[^>]*href="[^"]*\/venue\/[^"]*"[^>]*>([\s\S]*?)<\/a>/i
    );
    const venue = venueMatch
      ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    // Extract location from <a href="/communities/...">
    const locationMatch = articleHtml.match(
      /<a[^>]*href="[^"]*\/communities\/[^"]*"[^>]*>([\s\S]*?)<\/a>/i
    );
    const location = locationMatch
      ? locationMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    // Extract categories from links to /things-to-do/
    const catRegex =
      /<a[^>]*href="[^"]*\/things-to-do\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
    const categories: string[] = [];
    let catMatch;
    while ((catMatch = catRegex.exec(articleHtml)) !== null) {
      const cat = catMatch[1].replace(/<[^>]*>/g, "").trim();
      if (cat && cat.length > 0 && cat.length < 50) categories.push(cat);
    }

    // Extract image from <img> inside the article
    const imgMatch = articleHtml.match(
      /<img[^>]*src="([^"]*)"[^>]*>/i
    );
    const imageURL = imgMatch ? imgMatch[1] : undefined;

    // Extract age range
    const ageMatch = articleHtml.match(/Ages?:\s*([\s\S]*?)<\//i);
    const ageText = ageMatch
      ? ageMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    // Build start date
    let startDate: string;
    const parsedTime = parseTime(timeText);
    if (currentDate) {
      startDate = parsedTime
        ? `${currentDate}T${parsedTime}`
        : `${currentDate}T00:00:00`;
    } else {
      startDate = new Date().toISOString();
    }

    // Resolve event URL to absolute
    const fullUrl = eventUrl.startsWith("http")
      ? eventUrl
      : `https://events.newyorkfamily.com${eventUrl.startsWith("/") ? "" : "/"}${eventUrl}`;

    events.push({
      sourceId: `nycfamily:${path}`,
      source: "nycfamily",
      title,
      description: "",
      startDate,
      isAllDay: !parsedTime,
      category: categorizeEvent(title, "", categories),
      city: location || "New York",
      locationName: venue,
      imageURL,
      externalURL: fullUrl,
      isFeatured: false,
      isRecurring: false,
      tags: [
        ...categories.filter((c) => c.length > 0),
        ...(ageText ? [`ages:${ageText}`] : []),
      ],
      metro: metro.id,
    });
  }

  return events;
}

function parseTime(timeStr: string): string | null {
  if (!timeStr || timeStr.toLowerCase() === "various" || timeStr.toLowerCase() === "all day") {
    return null;
  }

  // Match patterns like "10 am", "10:30 am", "10 am - 4 pm", "10 – 11 am"
  const match = timeStr.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)/i);
  if (!match) return null;

  let hours = parseInt(match[1]);
  const minutes = match[2] || "00";
  const period = match[3].toLowerCase();

  if (period === "pm" && hours !== 12) hours += 12;
  if (period === "am" && hours === 12) hours = 0;

  return `${hours.toString().padStart(2, "0")}:${minutes}:00`;
}
