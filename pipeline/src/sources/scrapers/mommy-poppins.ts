import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// MommyPoppins covers all 5 metros with identical Drupal template.
// Listing pages show events for a given date. We scrape multiple days
// to build a 2-week calendar of events.
//
// URL pattern (date-specific):
//   /events/{regionId}/{regionSlug}/all/tag/all/age/{YYYY-MM-DD}/all/all/type/0/deals/0/near/all
//
// Each event card is structured as:
//   <div class="views-field views-field-field-image">  -- image
//   <div class="views-field views-field-title">         -- title, venue, tags
//   <div class="views-field views-field-field-event-date"> -- <time datetime="...">

const REGION_MAP: Record<string, { id: number; slug: string }> = {
  "los-angeles": { id: 115, slug: "los-angeles" },
  "new-york": { id: 118, slug: "new-york-city" },
  "dallas": { id: 2479, slug: "dallas-fort-worth" },
  "chicago": { id: 1424, slug: "chicago" },
  "atlanta": { id: 1574, slug: "atlanta" },
};

/** Number of days ahead to scrape (today + DAYS_AHEAD). */
const DAYS_AHEAD = 13; // 14 total days

export async function scrapeMommyPoppins(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const region = REGION_MAP[metro.id];
  if (!region) {
    log.warn("mommy-poppins", `No region mapping for ${metro.id}`);
    return [];
  }

  log.info("mommy-poppins", `Scraping events for ${metro.name}...`);

  const allEvents: PipelineEvent[] = [];
  const seenIds = new Set<string>();

  // Generate date strings for today through today+DAYS_AHEAD
  const dates = getDatesAhead(DAYS_AHEAD);

  for (const dateStr of dates) {
    const dayEvents = await scrapeDatePage(region, metro, dateStr, seenIds);
    allEvents.push(...dayEvents);
    // Be polite: 1s delay between requests
    if (dateStr !== dates[dates.length - 1]) {
      await delay(1000);
    }
  }

  log.info("mommy-poppins", `  ${metro.id}: ${allEvents.length} events across ${dates.length} days`);
  log.success("mommy-poppins", `Found ${allEvents.length} events for ${metro.name}`);
  return allEvents;
}

/** Return array of "YYYY-MM-DD" strings from today to today+daysAhead. */
function getDatesAhead(daysAhead: number): string[] {
  const dates: string[] = [];
  const now = new Date();
  for (let i = 0; i <= daysAhead; i++) {
    const d = new Date(now);
    d.setDate(d.getDate() + i);
    dates.push(d.toISOString().split("T")[0]);
  }
  return dates;
}

async function scrapeDatePage(
  region: { id: number; slug: string },
  metro: MetroArea,
  dateStr: string,
  seenIds: Set<string>
): Promise<PipelineEvent[]> {
  // Date-specific URL
  const url = `https://mommypoppins.com/events/${region.id}/${region.slug}/all/tag/all/age/${dateStr}/all/all/type/0/deals/0/near/all`;

  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      Accept: "text/html,application/xhtml+xml",
    },
  });

  if (!res.ok) {
    log.warn("mommy-poppins", `  HTTP ${res.status} for ${region.slug} on ${dateStr}`);
    return [];
  }

  const html = await res.text();
  const events: PipelineEvent[] = [];

  // Strategy 1: Parse event cards by splitting on views-field blocks
  const cardEvents = parseEventCards(html, metro, dateStr, seenIds);
  events.push(...cardEvents);

  // Strategy 2: Also extract from JSON-LD if present (may have different/extra events)
  const jsonLdEvents = extractJsonLdEvents(html, metro, seenIds);
  events.push(...jsonLdEvents);

  return events;
}

/**
 * Parse event cards from the listing page HTML.
 *
 * The page structure repeats blocks of:
 *   views-field-field-image → views-field-title → views-field-field-event-date
 *
 * We split on title blocks and look forward for dates and backward for images.
 */
function parseEventCards(
  html: string,
  metro: MetroArea,
  fallbackDate: string,
  seenIds: Set<string>
): PipelineEvent[] {
  const events: PipelineEvent[] = [];

  // Split into event card chunks by the title div
  const titlePattern = /<div class="views-field views-field-title">([\s\S]*?)<\/div>\s*<\/div>/gi;
  let titleMatch;

  while ((titleMatch = titlePattern.exec(html)) !== null) {
    const titleBlock = titleMatch[1];
    const titleBlockEnd = titleMatch.index + titleMatch[0].length;

    // --- Extract title and path ---
    const linkMatch = titleBlock.match(
      /<a[^>]*href="(\/[^"]+)"[^>]*>\s*<span>([\s\S]*?)<\/span>/i
    );
    if (!linkMatch) continue;

    const path = linkMatch[1];
    const title = linkMatch[2].replace(/<[^>]*>/g, "").trim();
    if (!title || title.length < 3 || title.length > 200) continue;
    if (/^(login|sign up|register|subscribe|menu|home|search)$/i.test(title))
      continue;

    // Deduplicate by source path
    const sourceId = `mommypoppins:${path}:${fallbackDate}`;
    if (seenIds.has(sourceId)) continue;
    seenIds.add(sourceId);

    // --- Extract venue from <p> ---
    const venueMatch = titleBlock.match(/<p>([\s\S]*?)<\/p>/i);
    const venue = venueMatch
      ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    // --- Extract category tags ---
    const tagsMatch = titleBlock.match(/<li>([\s\S]*?)<\/li>/gi);
    const tags = tagsMatch
      ? tagsMatch
          .map((t) => t.replace(/<[^>]*>/g, "").trim())
          .filter((t) => t && !/^pick$/i.test(t))
      : [];

    // --- Extract date from the next views-field-field-event-date block ---
    const afterTitle = html.slice(titleBlockEnd, titleBlockEnd + 600);
    const timeMatch = afterTitle.match(
      /<time\s+datetime="([^"]+)"[^>]*>/i
    );
    let startDate: string;
    let endDate: string | undefined;
    let isAllDay = false;

    if (timeMatch) {
      // Parse the ISO datetime from the <time> element
      const dt = timeMatch[1]; // e.g. "2026-03-13T18:00:00Z"
      startDate = dt;

      // Check for end time (pattern: <time>start</time>-<time>end</time>)
      const endTimeMatch = afterTitle.match(
        /<time\s+datetime="[^"]+"[^>]*>[^<]*<\/time>\s*-\s*<time\s+datetime="([^"]+)"[^>]*>/i
      );
      if (endTimeMatch) {
        endDate = endTimeMatch[1];
      }
    } else {
      // Fallback: use the date we're scraping with midnight
      startDate = `${fallbackDate}T00:00:00`;
      isAllDay = true;
    }

    // --- Extract image from preceding HTML ---
    const beforeTitle = html.slice(
      Math.max(0, titleMatch.index - 800),
      titleMatch.index
    );
    const imgMatch = beforeTitle.match(
      /src="([^"]*(?:\.jpg|\.jpeg|\.png|\.webp)[^"]*)"/gi
    );
    const imageURL = imgMatch
      ? imgMatch[imgMatch.length - 1]
          .replace(/^src="/, "")
          .replace(/"$/, "")
      : undefined;
    const fullImageURL = imageURL?.startsWith("/")
      ? `https://mommypoppins.com${imageURL}`
      : imageURL;

    events.push({
      sourceId: `mommypoppins:${path}`,
      source: "mommypoppins",
      title,
      description: "",
      startDate,
      endDate,
      isAllDay,
      category: categorizeEvent(title, "", tags),
      city: venue || metro.name,
      locationName: venue,
      imageURL: fullImageURL,
      externalURL: `https://mommypoppins.com${path}`,
      isFeatured: false,
      isRecurring: false,
      tags: ["mommypoppins", ...tags],
      metro: metro.id,
    });
  }

  return events;
}

function extractJsonLdEvents(
  html: string,
  metro: MetroArea,
  seenIds: Set<string>
): PipelineEvent[] {
  const events: PipelineEvent[] = [];
  const jsonLdPattern =
    /<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = jsonLdPattern.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1]);
      const items = Array.isArray(data) ? data : [data];

      for (const item of items) {
        if (item["@type"] === "Event" && item.name && item.startDate) {
          const id = `mommypoppins:jsonld:${(item.name as string).slice(0, 50)}`;
          if (seenIds.has(id)) continue;
          seenIds.add(id);

          const location = item.location as
            | Record<string, unknown>
            | undefined;
          const address = location?.address as
            | Record<string, string>
            | undefined;

          events.push({
            sourceId: id,
            source: "mommypoppins",
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
            city: address?.addressLocality || metro.name,
            address: address?.streetAddress,
            locationName: location?.name as string | undefined,
            imageURL: (item.image as string) || undefined,
            externalURL: (item.url as string) || undefined,
            isFeatured: false,
            isRecurring: false,
            tags: ["mommypoppins"],
            metro: metro.id,
          });
        }
      }
    } catch {
      // JSON parse error, skip
    }
  }

  return events;
}
