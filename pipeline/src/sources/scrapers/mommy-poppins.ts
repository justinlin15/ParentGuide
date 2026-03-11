import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { delay } from "../../utils/geocoder.js";

// MommyPoppins covers all 5 metros with identical Drupal template.
// URL pattern: /events/{regionId}/{regionSlug}/all/tag/all/age/{date}/all/type/0/deals/0/near/all
// Detail pages have JSON-LD @type: "Event"

const REGION_MAP: Record<string, { id: number; slug: string }> = {
  "los-angeles": { id: 115, slug: "los-angeles" },
  "new-york": { id: 118, slug: "new-york-city" },
  "dallas": { id: 2479, slug: "dallas-fort-worth" },
  "chicago": { id: 1424, slug: "chicago" },
  "atlanta": { id: 1574, slug: "atlanta" },
};

export async function scrapeMommyPoppins(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const region = REGION_MAP[metro.id];
  if (!region) {
    log.warn("mommy-poppins", `No region mapping for ${metro.id}`);
    return [];
  }

  log.info("mommy-poppins", `Scraping events for ${metro.name}...`);

  const events = await scrapeRegionPage(region, metro);

  log.success(
    "mommy-poppins",
    `Found ${events.length} events for ${metro.name}`
  );
  return events;
}

async function scrapeRegionPage(
  region: { id: number; slug: string },
  metro: MetroArea
): Promise<PipelineEvent[]> {
  // Correct URL format: three "all" segments after age filter
  const url = `https://mommypoppins.com/events/${region.id}/${region.slug}/all/tag/all/age/all/all/all/type/0/deals/0/near/all`;

  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      Accept: "text/html,application/xhtml+xml",
    },
  });

  if (!res.ok) {
    log.warn("mommy-poppins", `  HTTP ${res.status} for ${region.slug}`);
    return [];
  }

  const html = await res.text();
  const events: PipelineEvent[] = [];

  // MommyPoppins structure:
  // <div class="views-field views-field-title">
  //   <a href="/region-kids/event/events/slug"><span>Title</span></a>
  //   <p>Venue Name</p>
  //   <div class="tags-and-deal"><ul><li>Category</li></ul></div>
  // </div>
  // Images are in preceding <picture>/<img> tags

  // Extract event links with context
  const eventLinkPattern =
    /<a[^>]*href="(\/[^"]*-kids\/event\/[^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
  let match;
  const seenUrls = new Set<string>();
  const today = new Date().toISOString().split("T")[0];

  while ((match = eventLinkPattern.exec(html)) !== null) {
    const path = match[1];
    if (seenUrls.has(path)) continue;
    seenUrls.add(path);

    const innerHtml = match[2];

    // Extract title from <span> inside the link
    const title = innerHtml.replace(/<[^>]*>/g, "").trim();
    if (!title || title.length < 3 || title.length > 200) continue;
    // Skip navigation links like "Login", "Sign Up", etc.
    if (/^(login|sign up|register|subscribe|menu|home|search)$/i.test(title)) continue;

    // Look for venue in <p> after the link
    const afterLink = html.slice(match.index + match[0].length, match.index + match[0].length + 300);
    const venueMatch = afterLink.match(/<p>([\s\S]*?)<\/p>/i);
    const venue = venueMatch
      ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    // Look for image before this event card
    const beforeLink = html.slice(Math.max(0, match.index - 500), match.index);
    const imgMatch = beforeLink.match(
      /src="([^"]*(?:\.jpg|\.jpeg|\.png|\.webp)[^"]*)"/gi
    );
    const imageURL = imgMatch
      ? imgMatch[imgMatch.length - 1].replace(/^src="/, "").replace(/"$/, "")
      : undefined;
    const fullImageURL = imageURL?.startsWith("/")
      ? `https://mommypoppins.com${imageURL}`
      : imageURL;

    // Look for category tags
    const tagsMatch = afterLink.match(/<li>([\s\S]*?)<\/li>/gi);
    const tags = tagsMatch
      ? tagsMatch.map((t) => t.replace(/<[^>]*>/g, "").trim()).filter(Boolean)
      : [];

    events.push({
      sourceId: `mommypoppins:${path}`,
      source: "mommypoppins",
      title,
      description: "",
      startDate: `${today}T00:00:00`,
      isAllDay: true,
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

  // Also try to extract from JSON-LD if present
  const jsonLdEvents = extractJsonLdEvents(html, metro);
  events.push(...jsonLdEvents);

  if (events.length > 0) {
    log.info("mommy-poppins", `  ${region.slug}: ${events.length} events`);
  }

  return events;
}

function extractJsonLdEvents(
  html: string,
  metro: MetroArea
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
          const location = item.location as Record<string, unknown> | undefined;
          const address = location?.address as
            | Record<string, string>
            | undefined;

          events.push({
            sourceId: `mommypoppins:jsonld:${(item.name as string).slice(0, 50)}`,
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
