import { config } from "./config.js";
import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";
import { delay } from "./utils/geocoder.js";

// Category → search keywords for stock photo APIs
const CATEGORY_SEARCH_TERMS: Record<string, string> = {
  storytime: "children reading books library",
  farmersMarket: "farmers market family outdoor",
  freeMovie: "family movie night cinema",
  toddlerActivity: "toddler playing activity",
  craft: "kids arts crafts painting",
  music: "family music concert kids",
  fireStationTour: "fire station tour kids",
  museum: "children museum exhibit",
  outdoorAdventure: "family outdoor hiking nature",
  food: "family cooking kids food",
  sports: "kids sports activity",
  education: "children learning classroom stem",
  festival: "family festival fair carnival",
  seasonal: "family holiday celebration",
  other: "family kids activity fun",
};

// Cache: category → list of image URLs we've already fetched
const imageCache = new Map<string, string[]>();

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

export async function fillMissingImages(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  const needImages = events.filter((e) => !e.imageURL);
  if (needImages.length === 0) {
    log.info("images", "All events already have images");
    return events;
  }

  log.info(
    "images",
    `${needImages.length} events need fallback images`
  );

  // Group by category to batch image lookups
  const byCategory = new Map<string, PipelineEvent[]>();
  for (const event of needImages) {
    const cat = event.category || "other";
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

  const filled = needImages.filter((e) => e.imageURL).length;
  log.success("images", `Filled ${filled}/${needImages.length} missing images`);

  return events;
}

async function getCategoryImages(category: string): Promise<string[]> {
  // Check cache first
  const cached = imageCache.get(category);
  if (cached) return cached;

  const searchTerm =
    CATEGORY_SEARCH_TERMS[category] || CATEGORY_SEARCH_TERMS.other;
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

async function searchUnsplash(query: string): Promise<string[]> {
  if (!config.unsplash.accessKey) return [];

  try {
    const params = new URLSearchParams({
      query,
      per_page: "10",
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
      log.warn("images", `Unsplash HTTP ${res.status}`);
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

async function searchPexels(query: string): Promise<string[]> {
  if (!config.pexels.apiKey) return [];

  try {
    const params = new URLSearchParams({
      query,
      per_page: "10",
      orientation: "landscape",
    });

    const res = await fetch(`${config.pexels.baseUrl}/search?${params}`, {
      headers: {
        Authorization: config.pexels.apiKey,
      },
    });

    if (!res.ok) {
      log.warn("images", `Pexels HTTP ${res.status}`);
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
