import { log } from "./logger.js";
import { geocodeAddress, delay } from "./geocoder.js";

// ─── Address extraction from text ──────────────────────────────────────────

const METRO_CITIES: Record<string, string> = {
  "los-angeles": "Los Angeles, CA",
  "orange-county": "Irvine, CA",
  "new-york": "New York, NY",
  dallas: "Dallas, TX",
  chicago: "Chicago, IL",
  atlanta: "Atlanta, GA",
};

/**
 * Extract street-address-like strings from free text.
 * Matches patterns like "123 Main St", "4500 Los Feliz Blvd, Los Angeles, CA 90027", etc.
 */
export function extractAddressFromText(text: string): string | null {
  if (!text) return null;

  // Pattern: number + street name + optional suffix (St, Ave, Blvd, Dr, etc.)
  const addressPattern =
    /\b(\d{1,6}\s+(?:[NSEW]\.?\s+)?[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){0,3}\s+(?:St(?:reet)?|Ave(?:nue)?|Blvd|Boulevard|Dr(?:ive)?|Rd|Road|Ln|Lane|Way|Pl(?:ace)?|Ct|Court|Pkwy|Parkway|Cir(?:cle)?|Hwy|Highway|Trail|Ter(?:race)?)\.?(?:,?\s+(?:Suite|Ste|Apt|#)\s*\d+)?(?:\s*,\s*[A-Z][a-zA-Z\s]+)?(?:\s*,\s*[A-Z]{2})?(?:\s+\d{5}(?:-\d{4})?)?)\b/i;

  const match = text.match(addressPattern);
  if (match) return match[1].trim();

  // Fallback: look for zip code with surrounding context
  const zipPattern = /([A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})/;
  const zipMatch = text.match(zipPattern);
  if (zipMatch) return zipMatch[1].trim();

  return null;
}

// ─── Improved venue location search ────────────────────────────────────────

interface LocationResult {
  address?: string;
  latitude: number;
  longitude: number;
}

/**
 * Multi-strategy search for a venue's location.
 * Tries progressively broader queries until one succeeds.
 */
export async function searchForVenueLocation(
  venueName: string,
  description: string,
  metro: string
): Promise<LocationResult | null> {
  const metroCity = METRO_CITIES[metro] || metro;

  // Strategy 1: Extract address from description text
  const extractedAddress = extractAddressFromText(description);
  if (extractedAddress) {
    const result = await geocodeAddress(extractedAddress);
    if (result) {
      log.info(
        "web-enricher",
        `  ✓ Found via description address: ${extractedAddress}`
      );
      return { address: extractedAddress, ...result };
    }
    await delay(1100);
  }

  // Strategy 2: Venue name + metro city (e.g. "Central Park, New York, NY")
  if (venueName && venueName.length > 2) {
    const query = `${venueName}, ${metroCity}`;
    const result = await geocodeAddress(query);
    if (result) {
      log.info("web-enricher", `  ✓ Found via venue+city: ${query}`);
      return result;
    }
    await delay(1100);
  }

  // Strategy 3: Extract venue/location hints from description
  // Look for "at <Venue Name>" or "located at" patterns
  const atVenueMatch = description.match(
    /(?:at|@|held at|located at|venue:\s*)\s+([A-Z][A-Za-z'\- ]{2,40}(?:Park|Museum|Center|Centre|Library|Hall|Arena|Stadium|Theater|Theatre|Zoo|Garden|Gallery|Church|School|Academy|Institute|Pavilion|Plaza|Square|Beach|Pool|Farm|Ranch|Brewery|Restaurant|Cafe|Studios?)?)/i
  );
  if (atVenueMatch) {
    const venueFromDesc = atVenueMatch[1].trim();
    const query = `${venueFromDesc}, ${metroCity}`;
    const result = await geocodeAddress(query);
    if (result) {
      log.info(
        "web-enricher",
        `  ✓ Found via description venue: ${venueFromDesc}`
      );
      return result;
    }
    await delay(1100);
  }

  return null;
}

// ─── Image search from venue websites ──────────────────────────────────────

const IMAGE_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml",
};

/**
 * Try to find an image for an event by fetching its webpage and extracting
 * og:image, twitter:image, or the first large image.
 */
export async function searchForEventImage(
  externalURL?: string,
  websiteURL?: string
): Promise<string | null> {
  // Try the venue's own website first, then the event page
  const urlsToTry = [websiteURL, externalURL].filter(Boolean) as string[];

  for (const url of urlsToTry) {
    try {
      const imageUrl = await fetchOgImage(url);
      if (imageUrl) return imageUrl;
    } catch {
      // Skip failed fetches
    }
  }

  return null;
}

/**
 * Fetch a webpage and extract the og:image or twitter:image meta tag.
 * These are high-quality social-sharing images that work well as hero images.
 */
async function fetchOgImage(url: string): Promise<string | null> {
  try {
    // Only fetch the first 50KB to find meta tags quickly
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const res = await fetch(url, {
      headers: IMAGE_HEADERS,
      signal: controller.signal,
      redirect: "follow",
    });
    clearTimeout(timeout);

    if (!res.ok) return null;

    // Read just enough to find meta tags (they're in <head>)
    const reader = res.body?.getReader();
    if (!reader) return null;

    let html = "";
    const decoder = new TextDecoder();
    while (html.length < 50000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += decoder.decode(value, { stream: true });
      // Stop once we've passed </head>
      if (html.includes("</head>")) break;
    }
    reader.cancel().catch(() => {});

    // Try og:image first (highest quality)
    const ogMatch = html.match(
      /<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i
    );
    if (ogMatch) {
      return resolveUrl(ogMatch[1], url);
    }

    // Try reverse attribute order
    const ogMatch2 = html.match(
      /<meta[^>]*content=["']([^"']+)["'][^>]*property=["']og:image["']/i
    );
    if (ogMatch2) {
      return resolveUrl(ogMatch2[1], url);
    }

    // Try twitter:image
    const twitterMatch = html.match(
      /<meta[^>]*(?:name|property)=["']twitter:image["'][^>]*content=["']([^"']+)["']/i
    );
    if (twitterMatch) {
      return resolveUrl(twitterMatch[1], url);
    }

    // Reverse order for twitter:image
    const twitterMatch2 = html.match(
      /<meta[^>]*content=["']([^"']+)["'][^>]*(?:name|property)=["']twitter:image["']/i
    );
    if (twitterMatch2) {
      return resolveUrl(twitterMatch2[1], url);
    }

    return null;
  } catch {
    return null;
  }
}

/** Resolve a potentially relative URL against a base URL */
function resolveUrl(imageUrl: string, baseUrl: string): string | null {
  try {
    if (imageUrl.startsWith("//")) {
      return `https:${imageUrl}`;
    }
    if (imageUrl.startsWith("http")) {
      return imageUrl;
    }
    if (imageUrl.startsWith("/")) {
      const base = new URL(baseUrl);
      return `${base.origin}${imageUrl}`;
    }
    return new URL(imageUrl, baseUrl).toString();
  } catch {
    return null;
  }
}
