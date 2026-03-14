import { type MetroArea } from "../../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../../normalize.js";
import { log } from "../../utils/logger.js";
import { geocodeAddress, delay } from "../../utils/geocoder.js";
import {
  searchForVenueLocation,
  searchForEventImage,
  extractAddressFromText,
} from "../../utils/web-enricher.js";

// MommyPoppins covers all 5 metros with identical Drupal template.
// Listing pages show events for a given date. We scrape multiple days
// to build a 2-week calendar of events, then enrich unique events
// by fetching their detail pages for price, age, description, etc.

const REGION_MAP: Record<string, { id: number; slug: string }> = {
  "los-angeles": { id: 115, slug: "los-angeles" },
  "orange-county": { id: 115, slug: "los-angeles" }, // Shares MommyPoppins region with LA; city-level filtering in iOS
  "new-york": { id: 118, slug: "new-york-city" },
  "dallas": { id: 2479, slug: "dallas-fort-worth" },
  "chicago": { id: 1424, slug: "chicago" },
  "atlanta": { id: 1574, slug: "atlanta" },
};

const DAYS_AHEAD = 13; // 14 total days
const DETAIL_FETCH_LIMIT = 60; // max detail pages per metro
const DETAIL_DELAY_MS = 500; // delay between detail fetches
const GEOCODE_LIMIT = 40; // max geocode requests per metro (Nominatim rate limit: 1/sec)
const GEOCODE_DELAY_MS = 1100; // slightly over 1 second for Nominatim
const WEB_ENRICH_LIMIT = 30; // max web lookups for missing addresses/images per metro
const IMAGE_FETCH_DELAY_MS = 600; // delay between og:image fetches

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml",
};

export async function scrapeMommyPoppins(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  // Orange County shares the same MommyPoppins region (115) as Los Angeles.
  // Scraping it again produces identical events that get deduped in favor of
  // the LA copies (which are processed first), leaving zero OC events.
  // Instead, we skip OC here and rely on the city/coordinate-based
  // reassignment in index.ts to move LA events into OC.
  if (metro.id === "orange-county") {
    log.info("mommy-poppins", `Skipping ${metro.name} (shares LA region — OC events reassigned in post-processing)`);
    return [];
  }

  const region = REGION_MAP[metro.id];
  if (!region) {
    log.warn("mommy-poppins", `No region mapping for ${metro.id}`);
    return [];
  }

  log.info("mommy-poppins", `Scraping events for ${metro.name}...`);

  // Phase 1: Collect events from listing pages (14 days)
  const allEvents: PipelineEvent[] = [];
  const seenIds = new Set<string>();
  const dates = getDatesAhead(DAYS_AHEAD);

  for (const dateStr of dates) {
    const dayEvents = await scrapeDatePage(region, metro, dateStr, seenIds);
    allEvents.push(...dayEvents);
    if (dateStr !== dates[dates.length - 1]) {
      await delay(1000);
    }
  }

  log.info(
    "mommy-poppins",
    `  ${metro.id}: ${allEvents.length} events from listing pages`
  );

  // Phase 2: Enrich unique events with detail page data
  await enrichEventsFromDetailPages(allEvents);

  // Phase 3: Geocode events with addresses but no coordinates
  await geocodeEvents(allEvents);

  // Phase 4: Web search fallback for events still missing addresses or images
  await enrichMissingFromWeb(allEvents, metro.id);

  log.info(
    "mommy-poppins",
    `  ${metro.id}: ${allEvents.length} events across ${dates.length} days`
  );
  log.success(
    "mommy-poppins",
    `Found ${allEvents.length} events for ${metro.name}`
  );
  return allEvents;
}

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

// ─── Listing page parsing ──────────────────────────────────────────────────

async function scrapeDatePage(
  region: { id: number; slug: string },
  metro: MetroArea,
  dateStr: string,
  seenIds: Set<string>
): Promise<PipelineEvent[]> {
  const url = `https://mommypoppins.com/events/${region.id}/${region.slug}/all/tag/all/age/${dateStr}/all/all/type/0/deals/0/near/all`;

  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) {
    log.warn(
      "mommy-poppins",
      `  HTTP ${res.status} for ${region.slug} on ${dateStr}`
    );
    return [];
  }

  const html = await res.text();
  const events: PipelineEvent[] = [];

  const cardEvents = parseEventCards(html, metro, dateStr, seenIds);
  events.push(...cardEvents);

  const jsonLdEvents = extractJsonLdEvents(html, metro, seenIds);
  events.push(...jsonLdEvents);

  return events;
}

function parseEventCards(
  html: string,
  metro: MetroArea,
  fallbackDate: string,
  seenIds: Set<string>
): PipelineEvent[] {
  const events: PipelineEvent[] = [];
  const titlePattern =
    /<div class="views-field views-field-title">([\s\S]*?)<\/div>\s*<\/div>/gi;
  let titleMatch;

  while ((titleMatch = titlePattern.exec(html)) !== null) {
    const titleBlock = titleMatch[1];
    const titleBlockEnd = titleMatch.index + titleMatch[0].length;

    const linkMatch = titleBlock.match(
      /<a[^>]*href="(\/[^"]+)"[^>]*>\s*<span>([\s\S]*?)<\/span>/i
    );
    if (!linkMatch) continue;

    const path = linkMatch[1];
    const title = linkMatch[2].replace(/<[^>]*>/g, "").trim();
    if (!title || title.length < 3 || title.length > 200) continue;
    if (/^(login|sign up|register|subscribe|menu|home|search)$/i.test(title))
      continue;

    const sourceId = `mommypoppins:${path}:${fallbackDate}`;
    if (seenIds.has(sourceId)) continue;
    seenIds.add(sourceId);

    const venueMatch = titleBlock.match(/<p>([\s\S]*?)<\/p>/i);
    const venue = venueMatch
      ? venueMatch[1].replace(/<[^>]*>/g, "").trim()
      : undefined;

    const tagsMatch = titleBlock.match(/<li>([\s\S]*?)<\/li>/gi);
    const tags = tagsMatch
      ? tagsMatch
          .map((t) => t.replace(/<[^>]*>/g, "").trim())
          .filter((t) => t && !/^pick$/i.test(t))
      : [];

    const afterTitle = html.slice(titleBlockEnd, titleBlockEnd + 600);
    const timeMatch = afterTitle.match(/<time\s+datetime="([^"]+)"[^>]*>/i);
    let startDate: string;
    let endDate: string | undefined;
    let isAllDay = false;

    if (timeMatch) {
      startDate = timeMatch[1];
      const endTimeMatch = afterTitle.match(
        /<time\s+datetime="[^"]+"[^>]*>[^<]*<\/time>\s*-\s*<time\s+datetime="([^"]+)"[^>]*>/i
      );
      if (endTimeMatch) endDate = endTimeMatch[1];
    } else {
      startDate = `${fallbackDate}T00:00:00`;
      isAllDay = true;
    }

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
      sourceId: `mommypoppins:${path}:${fallbackDate}`,
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

// ─── Detail page enrichment ────────────────────────────────────────────────

interface DetailData {
  description?: string;
  price?: string;
  ageRange?: string;
  address?: string;
  city?: string;
  websiteURL?: string;
  phone?: string;
  contactEmail?: string;
  imageURL?: string;
  locationName?: string;
  category?: string;
}

/**
 * Fetch detail pages for unique events and enrich all instances.
 * Groups events by their base sourceId (without date suffix),
 * fetches each unique detail page once, and applies data to all instances.
 */
async function enrichEventsFromDetailPages(
  events: PipelineEvent[]
): Promise<void> {
  // Group events by their externalURL (unique events)
  const urlToEvents = new Map<string, PipelineEvent[]>();
  for (const event of events) {
    if (!event.externalURL) continue;
    const url = event.externalURL;
    const list = urlToEvents.get(url) || [];
    list.push(event);
    urlToEvents.set(url, list);
  }

  const uniqueUrls = Array.from(urlToEvents.keys());
  const toFetch = uniqueUrls.slice(0, DETAIL_FETCH_LIMIT);

  if (toFetch.length === 0) return;

  log.info(
    "mommy-poppins",
    `  Fetching ${toFetch.length} detail pages (of ${uniqueUrls.length} unique)...`
  );

  let enriched = 0;
  for (const url of toFetch) {
    try {
      const detail = await fetchDetailPage(url);
      if (detail) {
        const targetEvents = urlToEvents.get(url) || [];
        for (const event of targetEvents) {
          applyDetailData(event, detail);
        }
        enriched++;
      }
    } catch {
      // Skip failed detail fetches silently
    }
    await delay(DETAIL_DELAY_MS);
  }

  log.info("mommy-poppins", `  Enriched ${enriched}/${toFetch.length} events from detail pages`);
}

async function fetchDetailPage(url: string): Promise<DetailData | null> {
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) return null;

  const html = await res.text();
  const detail: DetailData = {};

  // Price: <div class="event-info field field--name-field-price ...">text</div>
  const priceMatch = html.match(
    /field--name-field-price[^>]*>([\s\S]*?)(?:<\/div>\s*\n|<\/div>\s*<\/div>)/i
  );
  if (priceMatch) {
    const price = priceMatch[1].replace(/<[^>]*>/g, "").trim();
    if (price && price.length < 200) detail.price = price;
  }

  // Age: <div class="event-info field field--name-field-age ...">
  //        <div>Age:</div> <div>VALUE</div>
  const ageMatch = html.match(
    /field--name-field-age[^>]*>[\s\S]*?<\/div>\s*<div>([\s\S]*?)<\/div>/i
  );
  if (ageMatch) {
    const age = ageMatch[1].replace(/<[^>]*>/g, "").trim();
    if (age && age.length < 100) detail.ageRange = age;
  }

  // Description: body field or JSON-LD
  const bodyMatch = html.match(
    /field--name-body[\s\S]*?<div class="clearfix text-formatted[\s\S]*?">([\s\S]*?)<\/div>\s*<\/div>\s*<\/div>/i
  );
  if (bodyMatch) {
    const desc = bodyMatch[1]
      .replace(/<[^>]*>/g, "")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 800);
    if (desc.length > 10) detail.description = desc;
  }

  // Fallback: JSON-LD description
  if (!detail.description) {
    const jsonLdMatch = html.match(
      /<script type="application\/ld\+json">([\s\S]*?)<\/script>/i
    );
    if (jsonLdMatch) {
      try {
        const data = JSON.parse(jsonLdMatch[1]);
        const graph = data["@graph"] || [data];
        for (const item of graph) {
          if (item["@type"] === "Event" && item.description) {
            const desc = cleanDescription(item.description as string, 800);
            if (desc.length > 10) detail.description = desc;
          }
        }
      } catch {
        // skip
      }
    }
  }

  // Location with address
  const locationMatch = html.match(
    /field--name-field-location[^>]*>([\s\S]*?)(?:<\/div>\s*<\/div>\s*<\/div>)/i
  );
  if (locationMatch) {
    const locHtml = locationMatch[1];
    // Extract structured parts
    const parts = locHtml
      .replace(/<[^>]*>/g, "\n")
      .split("\n")
      .map((s) => s.trim())
      .filter((s) => s && s.length > 1);

    if (parts.length > 0) {
      // First meaningful part is usually the venue name
      detail.locationName = parts[0];
      // Look for address-like parts (contain numbers or street keywords)
      const addressParts = parts.filter(
        (p) => /\d/.test(p) && !/^(US|United States)$/i.test(p)
      );
      if (addressParts.length > 0) {
        detail.address = addressParts.join(", ");
      }
      // Look for city, state
      const cityState = parts.find((p) =>
        /,\s*[A-Z]{2}/.test(p)
      );
      if (cityState) {
        const city = cityState.split(",")[0].trim();
        if (city) detail.city = city;
      }
    }
  }

  // Website URL
  const websiteMatch = html.match(
    /field--name-field-website[\s\S]*?href="([^"]+)"/i
  );
  if (websiteMatch) {
    detail.websiteURL = websiteMatch[1];
  }

  // Phone
  const phoneMatch = html.match(
    /field--name-field-location-phone[^>]*>[\s\S]*?<div[^>]*>([\s\S]*?)<\/div>/i
  );
  if (phoneMatch) {
    const phone = phoneMatch[1].replace(/<[^>]*>/g, "").trim();
    if (phone && /[\d-()+ ]{7,}/.test(phone)) detail.phone = phone;
  }

  // Contact email
  const emailMatch = html.match(
    /field--name-field-contact-email[^>]*>[\s\S]*?<div[^>]*>([\s\S]*?)<\/div>/i
  );
  if (emailMatch) {
    const email = emailMatch[1].replace(/<[^>]*>/g, "").trim();
    if (email && email.includes("@")) detail.contactEmail = email;
  }

  // Category
  const catMatch = html.match(
    /field--name-field-activity-category[^>]*>[\s\S]*?<div[^>]*>([\s\S]*?)<\/div>/i
  );
  if (catMatch) {
    const cat = catMatch[1].replace(/<[^>]*>/g, "").trim();
    if (cat) detail.category = cat;
  }

  // Better image from detail page (larger)
  const imgMatch = html.match(
    /field--name-field-images[\s\S]*?src="([^"]+)"/i
  );
  if (imgMatch) {
    const imgUrl = imgMatch[1].startsWith("/")
      ? `https://mommypoppins.com${imgMatch[1]}`
      : imgMatch[1];
    detail.imageURL = imgUrl;
  }

  return detail;
}

/** Apply enriched detail data to an event, preserving existing non-empty fields. */
function applyDetailData(event: PipelineEvent, detail: DetailData): void {
  if (detail.description && !event.description) {
    event.description = detail.description;
  }
  if (detail.price) {
    event.price = detail.price;
  }
  if (detail.ageRange) {
    event.ageRange = detail.ageRange;
  }
  if (detail.address && !event.address) {
    event.address = detail.address;
  }
  if (detail.city && !event.city) {
    event.city = detail.city;
  }
  if (detail.locationName && !event.locationName) {
    event.locationName = detail.locationName;
  }
  if (detail.websiteURL) {
    event.websiteURL = detail.websiteURL;
  }
  if (detail.phone) {
    event.phone = detail.phone;
  }
  if (detail.contactEmail) {
    event.contactEmail = detail.contactEmail;
  }
  if (detail.imageURL) {
    event.imageURL = detail.imageURL;
  }
  // Re-categorize with enriched data
  if (detail.description || detail.category) {
    event.category = categorizeEvent(
      event.title,
      event.description,
      detail.category ? [detail.category] : event.tags
    );
  }
}

// ─── Geocoding ─────────────────────────────────────────────────────────────

async function geocodeEvents(events: PipelineEvent[]): Promise<void> {
  // Build unique addresses to geocode
  const addressToEvents = new Map<string, PipelineEvent[]>();

  for (const event of events) {
    // Skip events that already have coordinates
    if (event.latitude && event.longitude) continue;

    // Build a geocodable address string
    const addressParts: string[] = [];
    if (event.address) addressParts.push(event.address);
    else if (event.locationName) addressParts.push(event.locationName);
    else continue; // nothing to geocode

    // Add city if not already in address
    if (event.city && !addressParts[0].includes(event.city)) {
      addressParts.push(event.city);
    }

    const fullAddress = addressParts.join(", ");
    const list = addressToEvents.get(fullAddress) || [];
    list.push(event);
    addressToEvents.set(fullAddress, list);
  }

  const uniqueAddresses = Array.from(addressToEvents.keys());
  const toGeocode = uniqueAddresses.slice(0, GEOCODE_LIMIT);

  if (toGeocode.length === 0) return;

  log.info("mommy-poppins", `  Geocoding ${toGeocode.length} unique addresses...`);

  let geocoded = 0;
  for (const address of toGeocode) {
    const result = await geocodeAddress(address);
    if (result) {
      const targetEvents = addressToEvents.get(address) || [];
      for (const event of targetEvents) {
        event.latitude = result.latitude;
        event.longitude = result.longitude;
      }
      geocoded++;
    }
    await delay(GEOCODE_DELAY_MS);
  }

  log.info("mommy-poppins", `  Geocoded ${geocoded}/${toGeocode.length} addresses`);
}

// ─── Web search fallback for missing data ─────────────────────────────────

/**
 * Phase 4: For events still missing addresses or images after detail enrichment
 * and geocoding, search the web using the event description and venue name.
 */
async function enrichMissingFromWeb(
  events: PipelineEvent[],
  metroId: string
): Promise<void> {
  // Find events missing coordinates or images (deduplicate by externalURL)
  const needsLocation: PipelineEvent[] = [];
  const needsImage: PipelineEvent[] = [];
  const seenUrls = new Set<string>();

  for (const event of events) {
    const url = event.externalURL || event.sourceId;
    if (seenUrls.has(url)) continue;
    seenUrls.add(url);

    if (!event.latitude || !event.longitude) {
      needsLocation.push(event);
    }
    if (!event.imageURL || event.imageURL.trim() === "") {
      needsImage.push(event);
    }
  }

  const locationBatch = needsLocation.slice(0, WEB_ENRICH_LIMIT);
  const imageBatch = needsImage.slice(0, WEB_ENRICH_LIMIT);

  if (locationBatch.length === 0 && imageBatch.length === 0) return;

  log.info(
    "mommy-poppins",
    `  Web enrichment: ${locationBatch.length} need locations, ${imageBatch.length} need images`
  );

  // ── Address/location fallback ──
  let locationsFound = 0;
  for (const event of locationBatch) {
    // Try extracting address from description first (no API call needed)
    const descAddress = extractAddressFromText(event.description || "");
    if (descAddress && !event.address) {
      event.address = descAddress;
    }

    // Build search context from all available text
    const searchName = event.locationName || event.title;
    const searchDesc = [
      event.description || "",
      event.address || "",
      event.city || "",
    ].join(" ");

    const result = await searchForVenueLocation(searchName, searchDesc, metroId);
    if (result) {
      if (result.address && !event.address) event.address = result.address;
      event.latitude = result.latitude;
      event.longitude = result.longitude;

      // Apply to all instances of this event (different dates)
      const url = event.externalURL;
      if (url) {
        for (const e of events) {
          if (e.externalURL === url && (!e.latitude || !e.longitude)) {
            if (result.address && !e.address) e.address = result.address;
            e.latitude = result.latitude;
            e.longitude = result.longitude;
          }
        }
      }
      locationsFound++;
    }
  }

  // ── Image fallback ──
  let imagesFound = 0;
  for (const event of imageBatch) {
    const imageUrl = await searchForEventImage(
      event.externalURL,
      event.websiteURL
    );
    if (imageUrl) {
      event.imageURL = imageUrl;
      // Apply to all instances
      const url = event.externalURL;
      if (url) {
        for (const e of events) {
          if (
            e.externalURL === url &&
            (!e.imageURL || e.imageURL.trim() === "")
          ) {
            e.imageURL = imageUrl;
          }
        }
      }
      imagesFound++;
    }
    await delay(IMAGE_FETCH_DELAY_MS);
  }

  log.info(
    "mommy-poppins",
    `  Web enrichment: found ${locationsFound}/${locationBatch.length} locations, ${imagesFound}/${imageBatch.length} images`
  );
}
