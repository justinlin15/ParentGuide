import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// Macaroni KID has 500+ local editions with consistent URL structure:
// https://{slug}.macaronikid.com/events
// Each edition covers a specific area within a metro.

export async function scrapeMacaroniKid(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  log.info("macaroni-kid", `Scraping events for ${metro.name}...`);

  for (const slug of metro.macaroniKidSlugs) {
    try {
      const slugEvents = await scrapeEdition(slug, metro);
      events.push(...slugEvents);
      // Rate limit: 3 seconds between editions
      await delay(3000);
    } catch (err) {
      log.error("macaroni-kid", `Error scraping ${slug}`, err);
    }
  }

  log.success(
    "macaroni-kid",
    `Found ${events.length} events for ${metro.name}`
  );
  return events;
}

async function scrapeEdition(
  slug: string,
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const baseUrl = `https://${slug}.macaronikid.com`;

  log.info("macaroni-kid", `  Fetching ${slug}.macaronikid.com/events...`);

  try {
    // First, check robots.txt
    const robotsRes = await fetch(`${baseUrl}/robots.txt`, {
      headers: { "User-Agent": "ParentGuide-Pipeline/1.0" },
    });
    if (robotsRes.ok) {
      const robotsTxt = await robotsRes.text();
      if (robotsTxt.includes("Disallow: /events")) {
        log.warn("macaroni-kid", `  ${slug}: /events disallowed by robots.txt`);
        return [];
      }
    }

    // Fetch the events page
    const res = await fetch(`${baseUrl}/events`, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        Accept: "text/html,application/xhtml+xml",
      },
    });

    if (!res.ok) {
      log.warn("macaroni-kid", `  ${slug}: HTTP ${res.status}`);
      return [];
    }

    const html = await res.text();
    const parsed = parseEventsFromHtml(html, slug, metro);
    events.push(...parsed);

    log.info("macaroni-kid", `  ${slug}: found ${parsed.length} events`);
  } catch (err) {
    log.error("macaroni-kid", `  Failed to scrape ${slug}`, err);
  }

  return events;
}

function parseEventsFromHtml(
  html: string,
  slug: string,
  metro: MetroArea
): PipelineEvent[] {
  const events: PipelineEvent[] = [];

  // Macaroni KID typically uses structured event cards with consistent patterns
  // Look for JSON-LD structured data first (most reliable)
  const jsonLdMatches = html.match(
    /<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi
  );

  if (jsonLdMatches) {
    for (const match of jsonLdMatches) {
      try {
        const jsonStr = match
          .replace(/<script type="application\/ld\+json">/i, "")
          .replace(/<\/script>/i, "");
        const data = JSON.parse(jsonStr);

        // Handle single event or array
        const items = Array.isArray(data) ? data : [data];
        for (const item of items) {
          if (item["@type"] === "Event") {
            const event = parseJsonLdEvent(item, slug, metro);
            if (event) events.push(event);
          }
        }
      } catch {
        // JSON-LD parse error, skip
      }
    }
  }

  // Fallback: parse event links and titles from HTML
  if (events.length === 0) {
    const eventLinkPattern =
      /<a[^>]*href="(\/calendar\/[^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
    let linkMatch;

    while ((linkMatch = eventLinkPattern.exec(html)) !== null) {
      const path = linkMatch[1];
      const innerHtml = linkMatch[2];

      // Extract title text from the link
      const titleText = innerHtml.replace(/<[^>]*>/g, "").trim();
      if (!titleText || titleText.length < 3) continue;

      // Try to find associated date
      const dateMatch = html
        .slice(Math.max(0, linkMatch.index - 200), linkMatch.index + 500)
        .match(
          /(\w+\s+\d{1,2},?\s+\d{4})|(\d{1,2}\/\d{1,2}\/\d{2,4})|(\d{4}-\d{2}-\d{2})/
        );

      const startDate = dateMatch
        ? parseDateString(dateMatch[0])
        : new Date().toISOString();

      // Try to find associated image
      const imgMatch = html
        .slice(Math.max(0, linkMatch.index - 500), linkMatch.index + 500)
        .match(/<img[^>]*src="([^"]*)"[^>]*>/i);

      events.push({
        sourceId: `macaronikid:${slug}:${path}`,
        source: "macaronikid",
        title: titleText,
        description: "",
        startDate,
        isAllDay: true,
        category: categorizeEvent(titleText, "", []),
        city: slug,
        metro: metro.id,
        imageURL: imgMatch ? resolveUrl(imgMatch[1], slug) : undefined,
        externalURL: `https://${slug}.macaronikid.com${path}`,
        isFeatured: false,
        isRecurring: false,
        tags: ["macaronikid"],
      });
    }
  }

  return events;
}

function parseJsonLdEvent(
  data: Record<string, unknown>,
  slug: string,
  metro: MetroArea
): PipelineEvent | null {
  const name = data.name as string | undefined;
  const startDate = data.startDate as string | undefined;

  if (!name || !startDate) return null;

  const location = data.location as
    | {
        name?: string;
        address?: { streetAddress?: string; addressLocality?: string };
        geo?: { latitude?: number; longitude?: number };
      }
    | undefined;

  const image = data.image as string | string[] | undefined;
  const imageUrl = Array.isArray(image) ? image[0] : image;

  return {
    sourceId: `macaronikid:${slug}:${name.slice(0, 50)}`,
    source: "macaronikid",
    title: name,
    description: cleanDescription((data.description as string) || ""),
    startDate,
    endDate: data.endDate as string | undefined,
    isAllDay: !(startDate || "").includes("T"),
    category: categorizeEvent(name, (data.description as string) || "", []),
    city: location?.address?.addressLocality || slug,
    address: location?.address?.streetAddress,
    latitude: location?.geo?.latitude,
    longitude: location?.geo?.longitude,
    locationName: location?.name,
    imageURL: imageUrl,
    externalURL: (data.url as string) || `https://${slug}.macaronikid.com`,
    isFeatured: false,
    isRecurring: false,
    tags: ["macaronikid"],
    metro: metro.id,
  };
}

function parseDateString(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    if (!isNaN(d.getTime())) return d.toISOString();
  } catch {
    // fall through
  }
  return new Date().toISOString();
}

function resolveUrl(url: string, slug: string): string {
  if (url.startsWith("http")) return url;
  if (url.startsWith("//")) return `https:${url}`;
  if (url.startsWith("/"))
    return `https://${slug}.macaronikid.com${url}`;
  return url;
}
