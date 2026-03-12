import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// mykidlist.com - WordPress + Kidlist Deluxe (Chicago)
// Excellent JSON-LD with @type: "ChildrensEvent" and ItemList on list pages
// Date-based navigation: /event/event-slug/YYYY-MM-DD

export async function scrapeMyKidList(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "chicago") return [];

  log.info("mykidlist", "Scraping mykidlist.com/events/...");
  const events: PipelineEvent[] = [];

  // Scrape the next 30 days
  for (let dayOffset = 0; dayOffset < 30; dayOffset++) {
    const date = new Date();
    date.setDate(date.getDate() + dayOffset);
    const dateStr = date.toISOString().split("T")[0];

    try {
      const dayEvents = await scrapeDayPage(dateStr, metro);
      events.push(...dayEvents);
      await delay(2000);
    } catch (err) {
      log.error("mykidlist", `Error scraping ${dateStr}`, err);
    }
  }

  log.success("mykidlist", `Found ${events.length} events`);
  return events;
}

async function scrapeDayPage(
  dateStr: string,
  metro: MetroArea
): Promise<PipelineEvent[]> {
  // mykidlist date navigation uses the date in the URL
  const url = `https://mykidlist.com/events/?kd_date=${dateStr}`;

  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      Accept: "text/html",
    },
  });

  if (!res.ok) {
    log.warn("mykidlist", `  HTTP ${res.status} for ${dateStr}`);
    return [];
  }

  const html = await res.text();
  const events: PipelineEvent[] = [];

  // First try JSON-LD (this site has excellent structured data)
  const jsonLdEvents = extractJsonLd(html, metro);
  if (jsonLdEvents.length > 0) {
    events.push(...jsonLdEvents);
    log.info("mykidlist", `  ${dateStr}: ${events.length} events (JSON-LD)`);
    return events;
  }

  // Fallback: parse event cards
  // .kidlist-deluxe-event-card with .kidlist-deluxe-event-title
  const cardPattern =
    /class="kidlist-deluxe-event-card"[\s\S]*?<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
  let match;

  while ((match = cardPattern.exec(html)) !== null) {
    const eventUrl = match[1];
    const innerHtml = match[2];

    const title = innerHtml.replace(/<[^>]*>/g, "").trim();
    if (!title || title.length < 3) continue;

    // Look for time
    const timeMatch = html
      .slice(match.index, match.index + 500)
      .match(/(\d{1,2}:\d{2}\s*(?:AM|PM))/i);

    const startDate = timeMatch
      ? `${dateStr}T${parseTime(timeMatch[1])}`
      : `${dateStr}T00:00:00`;

    // Look for image
    const imgMatch = html
      .slice(Math.max(0, match.index - 300), match.index + 100)
      .match(/<img[^>]*src="([^"]*)"[^>]*>/i);

    events.push({
      sourceId: `mykidlist:${eventUrl}`,
      source: "mykidlist",
      title,
      description: "",
      startDate,
      isAllDay: !timeMatch,
      category: categorizeEvent(title, "", []),
      city: "Chicago",
      imageURL: imgMatch ? imgMatch[1] : undefined,
      externalURL: eventUrl.startsWith("http")
        ? eventUrl
        : `https://mykidlist.com${eventUrl}`,
      isFeatured: false,
      isRecurring: false,
      tags: ["mykidlist"],
      metro: metro.id,
    });
  }

  if (events.length > 0) {
    log.info("mykidlist", `  ${dateStr}: ${events.length} events (HTML)`);
  }

  return events;
}

function extractJsonLd(html: string, metro: MetroArea): PipelineEvent[] {
  const events: PipelineEvent[] = [];
  const jsonLdPattern =
    /<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = jsonLdPattern.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1]);
      const items = Array.isArray(data) ? data : [data];

      for (const item of items) {
        // mykidlist uses @type: "ChildrensEvent" or "Event"
        if (
          (item["@type"] === "ChildrensEvent" || item["@type"] === "Event") &&
          item.name &&
          item.startDate
        ) {
          const location = item.location as Record<string, unknown> | undefined;
          const address = location?.address as
            | Record<string, string>
            | undefined;
          const geo = location?.geo as
            | { latitude?: number; longitude?: number }
            | undefined;

          events.push({
            sourceId: `mykidlist:${(item.url as string) || (item.name as string).slice(0, 50)}`,
            source: "mykidlist",
            title: item.name as string,
            description: cleanDescription(
              (item.description as string) || ""
            ),
            startDate: item.startDate as string,
            endDate: item.endDate as string | undefined,
            isAllDay: !(item.startDate as string).includes("T"),
            category: categorizeEvent(
              item.name as string,
              (item.description as string) || "",
              []
            ),
            city: address?.addressLocality || "Chicago",
            address: address?.streetAddress,
            latitude: geo?.latitude,
            longitude: geo?.longitude,
            locationName: (location?.name as string) || undefined,
            imageURL: (item.image as string) || undefined,
            externalURL: (item.url as string) || undefined,
            isFeatured: false,
            isRecurring: false,
            tags: ["mykidlist", "chicago"],
            metro: metro.id,
          });
        }

        // Also handle ItemList wrapping events
        if (item["@type"] === "ItemList" && item.itemListElement) {
          for (const listItem of item.itemListElement as Array<{
            item?: Record<string, unknown>;
          }>) {
            const eventItem = listItem.item;
            if (!eventItem || !eventItem.name || !eventItem.startDate)
              continue;

            const location = eventItem.location as
              | Record<string, unknown>
              | undefined;
            const address = location?.address as
              | Record<string, string>
              | undefined;

            events.push({
              sourceId: `mykidlist:${(eventItem.url as string) || (eventItem.name as string).slice(0, 50)}`,
              source: "mykidlist",
              title: eventItem.name as string,
              description: cleanDescription(
                (eventItem.description as string) || ""
              ),
              startDate: eventItem.startDate as string,
              endDate: eventItem.endDate as string | undefined,
              isAllDay: !(eventItem.startDate as string).includes("T"),
              category: categorizeEvent(
                eventItem.name as string,
                (eventItem.description as string) || "",
                []
              ),
              city: address?.addressLocality || "Chicago",
              address: address?.streetAddress,
              locationName: (location?.name as string) || undefined,
              imageURL: (eventItem.image as string) || undefined,
              externalURL: (eventItem.url as string) || undefined,
              isFeatured: false,
              isRecurring: false,
              tags: ["mykidlist", "chicago"],
              metro: metro.id,
            });
          }
        }
      }
    } catch {
      // JSON parse error
    }
  }

  return events;
}

function parseTime(timeStr: string): string {
  const match = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
  if (!match) return "00:00:00";

  let hours = parseInt(match[1]);
  const minutes = match[2];
  const period = match[3].toUpperCase();

  if (period === "PM" && hours !== 12) hours += 12;
  if (period === "AM" && hours === 12) hours = 0;

  return `${hours.toString().padStart(2, "0")}:${minutes}:00`;
}
