import { config } from "./config.js";
import { type PipelineEvent } from "./normalize.js";
import { searchForEventImage } from "./utils/web-enricher.js";
import { log } from "./utils/logger.js";
import { delay } from "./utils/geocoder.js";

// Category → search keywords for stock photo APIs
// Keys MUST match the iOS EventCategory rawValues (Title Case)
const CATEGORY_SEARCH_TERMS: Record<string, string> = {
  Storytime: "children reading books library",
  "Farmers Market": "farmers market family outdoor",
  "Free Movie": "family movie night cinema",
  "Toddler Activity": "toddler playing activity",
  Craft: "kids arts crafts painting",
  Music: "family music concert kids",
  "Fire Station Tour": "fire station tour kids",
  Museum: "children museum exhibit",
  Outdoor: "family outdoor hiking nature",
  "Food & Dining": "family cooking kids food",
  Sports: "kids sports activity",
  Education: "children learning classroom stem",
  Festival: "family festival fair carnival",
  Seasonal: "family holiday celebration",
  Other: "family kids activity fun",
};

// Cache: category → list of image URLs we've already fetched
const imageCache = new Map<string, string[]>();

// Track consecutive auth failures to avoid spamming broken APIs
let unsplashDisabled = false;
let pexelsDisabled = false;

interface UnsplashResult {
  results: Array<{
    urls: {
      regular: string;
      small: string;
    };
    alt_description?: string;
  }>;
}

interface PexelsResult {
  photos: Array<{
    src: {
      large: string;
      medium: string;
    };
    alt?: string;
  }>;
}

// Aggregator source identifiers — events from these scrapers carry images
// from the aggregator's own CDN, not the actual venue.
const AGGREGATOR_SOURCES_IMG = new Set([
  "mommypoppins",
  "macaronikid",
  "ocparentguide",
]);

// Hostname patterns belonging to aggregator CDNs.
// Any imageURL hosted on these domains is branded aggregator content
// and must be replaced with a real venue/stock photo.
const AGGREGATOR_IMAGE_HOSTNAMES = [
  "mommypoppins.com",
  "macaronikid.com",
  "cdn.macaronikid.com",
  "orangecountyparentguide.com",
  "www.orangecountyparentguide.com",
];

/**
 * Returns true if the imageURL is hosted on an aggregator's CDN.
 * Aggregator-sourced events also get their Squarespace CDN images cleared
 * because scrapers like MommyPoppins (Squarespace-hosted) embed their own
 * site imagery, not the actual event venue photo.
 */
function isAggregatorImage(imageURL: string, source: string): boolean {
  try {
    const hostname = new URL(imageURL).hostname.replace(/^www\./, "");

    // Always block known aggregator hostnames
    if (AGGREGATOR_IMAGE_HOSTNAMES.some((d) => hostname === d || hostname.endsWith(`.${d}`))) {
      return true;
    }

    // For aggregator-sourced events, also block Squarespace CDN URLs —
    // these are the aggregator's own site assets, not venue photos.
    if (AGGREGATOR_SOURCES_IMG.has(source)) {
      if (hostname.includes("squarespace.com") || hostname.includes("sqsp.net")) {
        return true;
      }
    }

    return false;
  } catch {
    return false; // Invalid URL — leave it alone; other validation will catch it
  }
}

export async function fillMissingImages(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  // ── Pre-processing: strip aggregator CDN images ──────────────────────────
  // Scrapers embed images from their own site (MommyPoppins, OC Parent Guide,
  // etc.). These are branded/copyrighted graphics, not real event photos.
  // Clear them so the fallback chain (og:image → venue search → stock) can run.
  let clearedAggregatorImages = 0;
  for (const event of events) {
    if (event.imageURL && isAggregatorImage(event.imageURL, event.source)) {
      event.imageURL = undefined;
      clearedAggregatorImages++;
    }
  }
  if (clearedAggregatorImages > 0) {
    log.info(
      "images",
      `Cleared ${clearedAggregatorImages} aggregator CDN images — replacing with venue/stock photos`
    );
  }

  const needImages = events.filter((e) => !e.imageURL);
  if (needImages.length === 0) {
    log.info("images", "All events already have images");
    return events;
  }

  log.info(
    "images",
    `${needImages.length} events need fallback images`
  );

  // Log which image APIs are configured
  const apis = [];
  if (config.unsplash.accessKey) apis.push("Unsplash");
  if (config.pexels.apiKey) apis.push("Pexels");
  if (apis.length === 0) {
    log.warn("images", "No image API keys configured — skipping image fill");
    return events;
  }
  log.info("images", `Image APIs available: ${apis.join(", ")}`);

  // Step 0: Extract og:image from event's own website URL (best quality, event-specific)
  // Skip aggregator sources — their og:images are generic/copyrighted site graphics.
  // Only extract og:image from the event's own website or non-aggregator pages.
  //
  // Key optimisation: deduplicate by URL before fetching. Many recurring events
  // (e.g. 50 instances of "Eggstravaganza at Disneyland") share the same websiteURL —
  // fetch the og:image once and reuse it for every matching event. This prevents
  // wasted HTTP requests and ensures all instances get the same correct image.
  const AGGREGATOR_SOURCES = new Set(["mommypoppins", "macaronikid"]);
  let ogFilled = 0;

  const ogCandidates = needImages.filter((e) => {
    if (e.imageURL) return false;
    if (AGGREGATOR_SOURCES.has(e.source)) return !!e.websiteURL;
    return !!(e.externalURL || e.websiteURL);
  });

  if (ogCandidates.length > 0) {
    log.info("images", `Trying og:image extraction for ${ogCandidates.length} events (deduped by URL)...`);

    // Build a map of unique URLs → og:image result (fetched once per URL)
    const urlImageCache = new Map<string, string | null>();
    const uniqueURLs = new Set(
      ogCandidates.map((e) =>
        AGGREGATOR_SOURCES.has(e.source) ? e.websiteURL! : (e.websiteURL || e.externalURL!)
      )
    );

    for (const url of uniqueURLs) {
      // Always pass the URL as websiteURL param — it's already the best available
      // URL for this event (websiteURL for aggregators, websiteURL || externalURL
      // for others). searchForEventImage tries it to extract og:image.
      const ogImage = await searchForEventImage(undefined, url);
      urlImageCache.set(url, ogImage || null);
      await delay(500); // Rate limit web fetches
    }

    // Apply cached results to all matching events
    for (const event of ogCandidates) {
      const url = AGGREGATOR_SOURCES.has(event.source)
        ? event.websiteURL!
        : (event.websiteURL || event.externalURL!);
      const cached = urlImageCache.get(url);
      if (cached) {
        event.imageURL = cached;
        ogFilled++;
      }
    }
    log.info("images", `og:image extraction: fetched ${uniqueURLs.size} unique URLs → filled ${ogFilled} events`);
  }

  // Step 1: Try event-specific image search using venue/event name
  let filled = 0;
  for (const event of needImages) {
    if (event.imageURL) continue;

    // Build a specific search query from venue name or event title
    const venueQuery = event.locationName
      ? `${event.locationName} ${event.city}`
      : null;
    const titleQuery = buildEventSearchQuery(event.title);

    // Try venue-specific search first (more likely to find relevant images)
    if (venueQuery) {
      const venueImages = await searchEventImage(venueQuery);
      if (venueImages.length > 0) {
        event.imageURL = venueImages[0];
        filled++;
        continue;
      }
    }

    // Then try title-based search
    if (titleQuery) {
      const titleImages = await searchEventImage(titleQuery);
      if (titleImages.length > 0) {
        event.imageURL = titleImages[0];
        filled++;
        continue;
      }
    }
  }
  log.info("images", `Event-specific search filled ${filled} images`);

  // Step 2: Fill remaining with category-based stock photos (rotated for variety)
  const stillNeed = needImages.filter((e) => !e.imageURL);
  const byCategory = new Map<string, PipelineEvent[]>();
  for (const event of stillNeed) {
    const cat = event.category || "Other";
    const list = byCategory.get(cat) || [];
    list.push(event);
    byCategory.set(cat, list);
  }

  for (const [category, categoryEvents] of byCategory) {
    const images = await getCategoryImages(category);
    if (images.length === 0) continue;

    for (let i = 0; i < categoryEvents.length; i++) {
      // Rotate through available images for variety
      categoryEvents[i].imageURL = images[i % images.length];
    }
  }

  const totalFilled = needImages.filter((e) => e.imageURL).length;
  log.success("images", `Filled ${totalFilled}/${needImages.length} missing images`);

  return events;
}

/**
 * Build a concise search query from event title.
 * Strip generic words to focus on the unique event name.
 */
function buildEventSearchQuery(title: string): string | null {
  // Remove common filler words and "Presents:" patterns
  const cleaned = title
    .replace(/presents?:?\s*/gi, "")
    .replace(/\b(the|a|an|at|in|on|for|and|of|with)\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
  // Only search if we have enough meaningful words
  return cleaned.length >= 5 ? cleaned : null;
}

/**
 * Search for a specific event/venue image. Uses a separate cache keyed by query.
 */
const eventImageCache = new Map<string, string[]>();

async function searchEventImage(query: string): Promise<string[]> {
  const cacheKey = query.toLowerCase().slice(0, 50);
  const cached = eventImageCache.get(cacheKey);
  if (cached) return cached;

  // Search with the venue/event query directly — appending generic terms like
  // "family kids" dilutes the search and returns irrelevant stock photos
  // (e.g. "Tustin Farmers Market family kids" → Huntington Beach pier shot).
  // Venue-specific queries find actual venue photos or event flyers.
  let images = await searchUnsplash(query, 3);
  if (images.length === 0) {
    images = await searchPexels(query, 3);
  }

  eventImageCache.set(cacheKey, images);
  return images;
}

async function getCategoryImages(category: string): Promise<string[]> {
  // Check cache first
  const cached = imageCache.get(category);
  if (cached) return cached;

  const searchTerm =
    CATEGORY_SEARCH_TERMS[category] || CATEGORY_SEARCH_TERMS["Other"];
  let images: string[] = [];

  // Try Unsplash first
  images = await searchUnsplash(searchTerm);

  // Fallback to Pexels if Unsplash returns nothing
  if (images.length === 0) {
    images = await searchPexels(searchTerm);
  }

  if (images.length > 0) {
    imageCache.set(category, images);
  }

  return images;
}

async function searchUnsplash(query: string, perPage = 10): Promise<string[]> {
  if (!config.unsplash.accessKey || unsplashDisabled) return [];

  try {
    const params = new URLSearchParams({
      query,
      per_page: String(perPage),
      orientation: "landscape",
      content_filter: "high", // Safe for all audiences
    });

    const res = await fetch(
      `${config.unsplash.baseUrl}/search/photos?${params}`,
      {
        headers: {
          Authorization: `Client-ID ${config.unsplash.accessKey}`,
        },
      }
    );

    if (!res.ok) {
      if (res.status === 401 || res.status === 403) {
        const body = await res.text().catch(() => "");
        log.warn("images", `Unsplash HTTP ${res.status} — disabling. Key starts with: "${config.unsplash.accessKey?.slice(0, 8)}…" Response: ${body.slice(0, 200)}`);
        unsplashDisabled = true;
      } else {
        log.warn("images", `Unsplash HTTP ${res.status}`);
      }
      return [];
    }

    const data = (await res.json()) as UnsplashResult;
    await delay(1500); // Rate limit: ~40 req/hr on free tier

    return data.results.map((r) => r.urls.regular);
  } catch (err) {
    log.error("images", "Unsplash search failed", err);
    return [];
  }
}

async function searchPexels(query: string, perPage = 10): Promise<string[]> {
  if (!config.pexels.apiKey || pexelsDisabled) return [];

  try {
    const params = new URLSearchParams({
      query,
      per_page: String(perPage),
      orientation: "landscape",
    });

    const res = await fetch(`${config.pexels.baseUrl}/search?${params}`, {
      headers: {
        Authorization: config.pexels.apiKey,
      },
    });

    if (!res.ok) {
      if (res.status === 401 || res.status === 403) {
        const body = await res.text().catch(() => "");
        log.warn("images", `Pexels HTTP ${res.status} — disabling. Key starts with: "${config.pexels.apiKey?.slice(0, 8)}…" Response: ${body.slice(0, 200)}`);
        pexelsDisabled = true;
      } else {
        log.warn("images", `Pexels HTTP ${res.status}`);
      }
      return [];
    }

    const data = (await res.json()) as PexelsResult;
    await delay(1500);

    return data.photos.map((p) => p.src.large);
  } catch (err) {
    log.error("images", "Pexels search failed", err);
    return [];
  }
}
