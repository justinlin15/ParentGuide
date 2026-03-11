import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// dfwchild.com - WordPress + GeoDirectory plugin
// Calendar page with event cards, detail pages have excellent JSON-LD

export async function scrapeDFWChild(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "dallas") return [];

  log.info("dfw-child", "Scraping dfwchild.com/calendar/...");
  const events: PipelineEvent[] = [];

  try {
    // Fetch the calendar listing page
    const res = await fetch("https://dfwchild.com/calendar/", {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        Accept: "text/html",
      },
    });

    if (!res.ok) {
      log.warn("dfw-child", `HTTP ${res.status}`);
      return [];
    }

    const html = await res.text();

    // Extract event detail links
    const linkPattern = /<a[^>]*href="(https?:\/\/dfwchild\.com\/events\/[^"]*)"[^>]*>/gi;
    let match;
    const eventUrls = new Set<string>();

    while ((match = linkPattern.exec(html)) !== null) {
      eventUrls.add(match[1]);
    }

    // Also check for relative links
    const relLinkPattern = /<a[^>]*href="(\/events\/[^"]*)"[^>]*>/gi;
    while ((match = relLinkPattern.exec(html)) !== null) {
      eventUrls.add(`https://dfwchild.com${match[1]}`);
    }

    log.info("dfw-child", `  Found ${eventUrls.size} event links`);

    // Fetch detail pages for JSON-LD (limit to 30 to be respectful)
    let count = 0;
    for (const eventUrl of eventUrls) {
      if (count >= 30) break;
      try {
        const event = await scrapeDetailPage(eventUrl, metro);
        if (event) events.push(event);
        count++;
        await delay(2000);
      } catch (err) {
        log.error("dfw-child", `Error fetching ${eventUrl}`, err);
      }
    }
  } catch (err) {
    log.error("dfw-child", "Error scraping calendar", err);
  }

  log.success("dfw-child", `Found ${events.length} events`);
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
            | { latitude?: number; longitude?: number }
            | undefined;

          // Extract image
          const image = item.image as
            | string
            | string[]
            | { url?: string }
            | undefined;
          let imageURL: string | undefined;
          if (typeof image === "string") imageURL = image;
          else if (Array.isArray(image)) imageURL = image[0];
          else if (image && typeof image === "object")
            imageURL = image.url;

          return {
            sourceId: `dfwchild:${url.split("/").pop() || url}`,
            source: "dfwchild",
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
            city: address?.addressLocality || "Dallas",
            address: address?.streetAddress,
            latitude: geo?.latitude,
            longitude: geo?.longitude,
            locationName: (location?.name as string) || undefined,
            imageURL,
            externalURL: url,
            isFeatured: false,
            isRecurring: false,
            tags: ["dfwchild"],
            metro: metro.id,
          };
        }
      }
    } catch {
      // JSON parse error
    }
  }

  // Fallback: extract from HTML if no JSON-LD
  const titleMatch = html.match(
    /<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i
  );
  if (titleMatch) {
    const title = titleMatch[1].replace(/<[^>]*>/g, "").trim();

    // Try to find date
    const dateMatch = html.match(
      /(\w+\s+\d{1,2},?\s+\d{4})|(\d{4}-\d{2}-\d{2})/
    );
    const startDate = dateMatch
      ? new Date(dateMatch[0]).toISOString()
      : new Date().toISOString();

    return {
      sourceId: `dfwchild:${url.split("/").pop() || url}`,
      source: "dfwchild",
      title,
      description: "",
      startDate,
      isAllDay: true,
      category: categorizeEvent(title, "", []),
      city: "Dallas",
      externalURL: url,
      isFeatured: false,
      isRecurring: false,
      tags: ["dfwchild"],
      metro: metro.id,
    };
  }

  return null;
}
