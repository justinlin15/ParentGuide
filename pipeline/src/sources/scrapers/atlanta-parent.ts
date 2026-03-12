import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// atlantaparent.com - WordPress + The Events Calendar (Tribe Events)
// List of event links on /topevents/, detail pages have JSON-LD @type: "Event"

export async function scrapeAtlantaParent(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "atlanta") return [];

  log.info("atlanta-parent", "Scraping atlantaparent.com...");
  const events: PipelineEvent[] = [];

  try {
    // Fetch the top events listing page
    const res = await fetch("https://www.atlantaparent.com/topevents/", {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        Accept: "text/html",
      },
    });

    if (!res.ok) {
      log.warn("atlanta-parent", `HTTP ${res.status}`);
      return [];
    }

    const html = await res.text();

    // Extract event detail links
    const linkPattern =
      /<a[^>]*href="(https?:\/\/www\.atlantaparent\.com\/event\/[^"]*)"[^>]*>/gi;
    let match;
    const eventUrls = new Set<string>();

    while ((match = linkPattern.exec(html)) !== null) {
      eventUrls.add(match[1]);
    }

    // Also try relative links
    const relPattern = /<a[^>]*href="(\/event\/[^"]*)"[^>]*>/gi;
    while ((match = relPattern.exec(html)) !== null) {
      eventUrls.add(`https://www.atlantaparent.com${match[1]}`);
    }

    log.info("atlanta-parent", `  Found ${eventUrls.size} event links`);

    // Fetch detail pages for JSON-LD (limit to 60)
    let count = 0;
    for (const eventUrl of eventUrls) {
      if (count >= 60) break;
      try {
        const event = await scrapeDetailPage(eventUrl, metro);
        if (event) events.push(event);
        count++;
        await delay(2000);
      } catch (err) {
        log.error("atlanta-parent", `Error fetching ${eventUrl}`, err);
      }
    }
  } catch (err) {
    log.error("atlanta-parent", "Error scraping listing", err);
  }

  // Also try the main events calendar
  try {
    const calEvents = await scrapeEventsCalendar(metro);
    events.push(...calEvents);
  } catch (err) {
    log.error("atlanta-parent", "Error scraping calendar", err);
  }

  log.success("atlanta-parent", `Found ${events.length} events`);
  return events;
}

async function scrapeEventsCalendar(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const seenUrls = new Set<string>();

  // Scrape calendar in weekly chunks for the next 30 days
  for (let weekOffset = 0; weekOffset < 5; weekOffset++) {
    const date = new Date();
    date.setDate(date.getDate() + weekOffset * 7);
    const dateStr = date.toISOString().split("T")[0];

    const url = `https://www.atlantaparent.com/events/list/?tribe-bar-date=${dateStr}`;

    try {
      const res = await fetch(url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          Accept: "text/html",
        },
      });

      if (!res.ok) continue;

      const html = await res.text();

      // Tribe Events list view has event articles with class "tribe_events"
      const eventPattern =
        /<a[^>]*href="(https?:\/\/www\.atlantaparent\.com\/event\/[^"]*)"[^>]*class="[^"]*tribe[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
      let match;

      while ((match = eventPattern.exec(html)) !== null) {
        const eventUrl = match[1];
        if (seenUrls.has(eventUrl)) continue;
        seenUrls.add(eventUrl);

        try {
          const event = await scrapeDetailPage(eventUrl, metro);
          if (event) events.push(event);
          await delay(2000);
        } catch {
          // skip
        }
      }

      await delay(2000);
    } catch (err) {
      log.error("atlanta-parent", `Error scraping calendar week ${weekOffset}`, err);
    }
  }

  return events;
}

async function scrapeDetailPage(
  url: string,
  metro: MetroArea
): Promise<PipelineEvent | null> {
  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      Accept: "text/html",
    },
  });

  if (!res.ok) return null;
  const html = await res.text();

  // Extract JSON-LD
  const jsonLdPattern =
    /<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = jsonLdPattern.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1]);
      const items = Array.isArray(data) ? data : [data];

      for (const item of items) {
        if (item["@type"] === "Event" && item.name && item.startDate) {
          const location = item.location as Record<string, unknown> | undefined;
          const address = location?.address as
            | Record<string, string>
            | undefined;
          const geo = location?.geo as
            | { latitude?: string | number; longitude?: string | number }
            | undefined;

          const image = item.image as
            | string
            | string[]
            | { url?: string }
            | undefined;
          let imageURL: string | undefined;
          if (typeof image === "string") imageURL = image;
          else if (Array.isArray(image)) imageURL = image[0];
          else if (image && typeof image === "object") imageURL = image.url;

          return {
            sourceId: `atlantaparent:${url.split("/event/")[1]?.replace(/\/$/, "") || url}`,
            source: "atlantaparent",
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
            city: address?.addressLocality || "Atlanta",
            address: address?.streetAddress,
            latitude: geo?.latitude ? Number(geo.latitude) : undefined,
            longitude: geo?.longitude ? Number(geo.longitude) : undefined,
            locationName: (location?.name as string) || undefined,
            imageURL,
            externalURL: url,
            isFeatured: false,
            isRecurring: false,
            tags: ["atlantaparent"],
            metro: metro.id,
          };
        }
      }
    } catch {
      // JSON parse error
    }
  }

  // Fallback: extract title from HTML
  const titleMatch = html.match(
    /<h1[^>]*class="[^"]*tribe-events-single-event-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i
  );
  if (titleMatch) {
    const title = titleMatch[1].replace(/<[^>]*>/g, "").trim();
    return {
      sourceId: `atlantaparent:${url.split("/event/")[1]?.replace(/\/$/, "") || url}`,
      source: "atlantaparent",
      title,
      description: "",
      startDate: new Date().toISOString(),
      isAllDay: true,
      category: categorizeEvent(title, "", []),
      city: "Atlanta",
      externalURL: url,
      isFeatured: false,
      isRecurring: false,
      tags: ["atlantaparent"],
      metro: metro.id,
    };
  }

  return null;
}
