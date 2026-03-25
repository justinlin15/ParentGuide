import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";
import { getRandomUserAgent } from "./utils/user-agents.js";
import { delay } from "./utils/geocoder.js";
import { lookupVenueUrl } from "./utils/venue-urls.js";

// Scraper source domains that should NEVER appear as the user-facing link.
// When a user taps "More Information" in the app, they should see the
// actual event/venue page — not the blog that we scraped.
const SCRAPER_DOMAINS = [
  "mommypoppins.com",
  "macaronikid.com",
  "national.macaronikid.com",
  "atlantaparent.com",
  "www.atlantaparent.com",
  "dfwchild.com",
  "mykidlist.com",
  "events.newyorkfamily.com",
  "orangecountyparentguide.com",
  "www.orangecountyparentguide.com",
];

/**
 * Check if a URL belongs to one of our scraper sources.
 */
function isScraperUrl(url: string): boolean {
  try {
    const hostname = new URL(url).hostname.replace(/^www\./, "");
    return SCRAPER_DOMAINS.some(
      (d) => hostname === d || hostname === d.replace(/^www\./, "")
    );
  } catch {
    return false;
  }
}

/**
 * Build a Google search URL for an event — used as fallback when
 * no direct event/venue URL is available.
 */
function buildGoogleSearchUrl(event: PipelineEvent): string {
  const parts = [event.title];
  if (event.locationName) parts.push(event.locationName);
  if (event.city) parts.push(event.city);
  const query = parts.join(" ").slice(0, 150);
  return `https://www.google.com/search?q=${encodeURIComponent(query)}`;
}

// ─── Price extraction from event pages ──────────────────────────────────────

const PRICE_PATTERNS = [
  // "$15", "$15.00", "$15-$25", "$15 - $25"
  /\$\d+(?:\.\d{2})?(?:\s*[-–]\s*\$\d+(?:\.\d{2})?)?/,
  // "Free", "FREE", "free admission", "free event"
  /\bfree\b/i,
  // "Included with admission", "included with park admission"
  /included with (?:park |museum )?admission/i,
  // "No charge"
  /no charge/i,
  // "Donation", "suggested donation"
  /(?:suggested )?donation/i,
];

/**
 * Extract price info from text (description, title, or fetched HTML).
 */
function extractPrice(text: string): string | null {
  if (!text) return null;

  // Check for free indicators first
  if (/\bfree\b/i.test(text) && !/free\s*(?:parking|wifi|with)/i.test(text)) {
    return "Free";
  }
  if (/no charge/i.test(text) || /complimentary/i.test(text)) {
    return "Free";
  }
  if (/included with (?:park |museum )?admission/i.test(text)) {
    return "Included with admission";
  }

  // Look for dollar amounts
  const priceMatch = text.match(
    /\$(\d+(?:\.\d{2})?)\s*(?:[-–]\s*\$(\d+(?:\.\d{2})?))?/
  );
  if (priceMatch) {
    if (priceMatch[2]) {
      return `$${priceMatch[1]} - $${priceMatch[2]}`;
    }
    return `$${priceMatch[1]}`;
  }

  // "Donation" / "Suggested donation"
  if (/suggested\s+donation/i.test(text)) return "Suggested donation";
  if (/\bdonation\b/i.test(text)) return "Donation";

  return null;
}

// ─── Fetch event page to extract venue URL and price ────────────────────────

interface PageEnrichment {
  venueUrl?: string;
  price?: string;
}

/**
 * Fetch a scraper article page and look for:
 * 1. An outbound link to the actual event/venue (for externalURL replacement)
 * 2. Price information
 */
async function fetchScraperPage(url: string): Promise<PageEnrichment | null> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const res = await fetch(url, {
      headers: {
        "User-Agent": getRandomUserAgent(),
        Accept: "text/html,application/xhtml+xml",
      },
      signal: controller.signal,
      redirect: "follow",
    });
    clearTimeout(timeout);

    if (!res.ok) return null;

    const reader = res.body?.getReader();
    if (!reader) return null;

    let html = "";
    const decoder = new TextDecoder();
    // Read enough to find links and price info (body content)
    while (html.length < 100000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += decoder.decode(value, { stream: true });
    }
    reader.cancel().catch(() => {});

    const result: PageEnrichment = {};

    // Extract outbound venue/event links
    // Look for patterns like "visit website", "event website", "buy tickets",
    // "register", "more info", "official site" link text
    const linkPatterns = [
      // Common "official website" / "event page" link patterns
      /<a[^>]*href="(https?:\/\/[^"]+)"[^>]*>[\s\S]*?(?:visit\s+(?:the\s+)?(?:official\s+)?website|event\s+website|official\s+site|buy\s+tickets?|register|sign\s+up|more\s+info|book\s+now|get\s+tickets?|rsvp|event\s+page)[\s\S]*?<\/a>/gi,
      // field--name-field-website (MommyPoppins specific)
      /field--name-field-website[\s\S]*?href="([^"]+)"/i,
      // JSON-LD url field
      /"url"\s*:\s*"(https?:\/\/[^"]+)"/i,
    ];

    for (const pattern of linkPatterns) {
      const match = html.match(pattern);
      if (match) {
        const url = match[1];
        if (url && !isScraperUrl(url)) {
          result.venueUrl = url;
          break;
        }
      }
    }

    // Extract price from the page content
    const bodyText = html
      .replace(/<script[\s\S]*?<\/script>/gi, "")
      .replace(/<style[\s\S]*?<\/style>/gi, "")
      .replace(/<[^>]*>/g, " ")
      .replace(/\s+/g, " ");
    const price = extractPrice(bodyText);
    if (price) result.price = price;

    return result;
  } catch {
    return null;
  }
}

// ─── Main enrichment pipeline step ──────────────────────────────────────────

const ENRICH_BATCH_SIZE = 80; // max pages to fetch per run

/**
 * Post-scraping enrichment step:
 * 1. Sanitize externalURL — replace scraper source links with actual event/venue URLs
 * 2. Extract/validate price when missing
 * 3. Strip scraper source names from tags
 *
 * This runs AFTER deduplication and description rewriting, BEFORE geocoding/images.
 */
export async function enrichEvents(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  log.info("enrich", "Starting post-scrape enrichment...");

  // ─── Step 1: Identify events with scraper URLs ──────────────────────────
  const needsUrlFix: PipelineEvent[] = [];
  const needsPrice: PipelineEvent[] = [];
  let alreadyGood = 0;

  for (const event of events) {
    const extUrl = event.externalURL;

    // Clear websiteURL if it's a scraper URL — the iOS app prefers websiteURL
    // over externalURL, so a scraper websiteURL would bypass our URL fix entirely.
    if (event.websiteURL && isScraperUrl(event.websiteURL)) {
      event.websiteURL = undefined;
    }

    // If websiteURL exists and isn't a scraper URL, it's the best link
    if (event.websiteURL && !isScraperUrl(event.websiteURL)) {
      // websiteURL is good — use it as externalURL if needed
      if (extUrl && isScraperUrl(extUrl)) {
        event.externalURL = event.websiteURL;
      }
      alreadyGood++;
    } else if (extUrl && isScraperUrl(extUrl)) {
      needsUrlFix.push(event);
    } else {
      alreadyGood++;
    }

    if (!event.price) {
      // Try extracting price from description first (no network call)
      const descPrice = extractPrice(
        `${event.title} ${event.description || ""}`
      );
      if (descPrice) {
        event.price = descPrice;
      } else {
        needsPrice.push(event);
      }
    }
  }

  log.info(
    "enrich",
    `URLs: ${alreadyGood} already good, ${needsUrlFix.length} need scraper URL replacement`
  );

  // ─── Step 2: Fetch scraper pages to find real event URLs ────────────────
  // Deduplicate by externalURL to avoid fetching the same page multiple times
  const urlToEvents = new Map<string, PipelineEvent[]>();
  for (const event of needsUrlFix) {
    const url = event.externalURL!;
    const list = urlToEvents.get(url) || [];
    list.push(event);
    urlToEvents.set(url, list);
  }

  const uniqueUrls = Array.from(urlToEvents.keys()).slice(0, ENRICH_BATCH_SIZE);
  let urlsFixed = 0;
  let pricesFound = 0;

  if (uniqueUrls.length > 0) {
    log.info(
      "enrich",
      `Fetching ${uniqueUrls.length} scraper pages for URL extraction...`
    );

    for (const scraperUrl of uniqueUrls) {
      const enrichment = await fetchScraperPage(scraperUrl);
      const targetEvents = urlToEvents.get(scraperUrl) || [];

      if (enrichment?.venueUrl) {
        // Replace scraper URL with venue URL for all instances
        for (const event of targetEvents) {
          event.externalURL = enrichment.venueUrl;
        }
        urlsFixed++;
      }

      if (enrichment?.price) {
        for (const event of targetEvents) {
          if (!event.price) {
            event.price = enrichment.price;
            pricesFound++;
          }
        }
      }

      await delay(400);
    }

    log.info(
      "enrich",
      `URL extraction: found ${urlsFixed}/${uniqueUrls.length} venue URLs`
    );
  }

  // ─── Step 3: Apply known venue URL mapping ─────────────────────────────
  // For events that still have scraper/Google URLs, check our curated venue
  // mapping (libraries, parks, museums, etc.) before falling back to Google.
  let venueUrlsApplied = 0;
  for (const event of events) {
    const hasGoodUrl =
      event.websiteURL && !isScraperUrl(event.websiteURL) && !event.websiteURL.includes("google.com/search");
    if (hasGoodUrl) continue; // Already has a real URL

    const venueEntry = lookupVenueUrl(event.locationName);
    if (venueEntry) {
      if (!event.websiteURL || isScraperUrl(event.websiteURL) || event.websiteURL.includes("google.com/search")) {
        event.websiteURL = venueEntry.websiteURL ?? venueEntry.url;
      }
      if (!event.externalURL || isScraperUrl(event.externalURL) || event.externalURL.includes("google.com/search")) {
        event.externalURL = venueEntry.url;
      }
      venueUrlsApplied++;
    }
  }
  if (venueUrlsApplied > 0) {
    log.info(
      "enrich",
      `Applied known venue URLs for ${venueUrlsApplied} events`
    );
  }

  // ─── Step 4: Apply Google search fallback for remaining scraper URLs ─────
  let googleFallbacks = 0;
  for (const event of events) {
    if (event.externalURL && isScraperUrl(event.externalURL)) {
      event.externalURL = buildGoogleSearchUrl(event);
      googleFallbacks++;
    }
    // If no externalURL at all, add Google search
    if (!event.externalURL) {
      event.externalURL = buildGoogleSearchUrl(event);
      googleFallbacks++;
    }
  }
  if (googleFallbacks > 0) {
    log.info(
      "enrich",
      `Applied Google search fallback for ${googleFallbacks} events`
    );
  }

  // ─── Step 5: Strip scraper source names from tags ─────────────────────────
  const scraperTags = new Set([
    "mommypoppins",
    "macaronikid",
    "atlantaparent",
    "dfwchild",
    "mykidlist",
    "nycfamily",
    "ocparentguide",
  ]);
  for (const event of events) {
    event.tags = event.tags.filter((t) => !scraperTags.has(t.toLowerCase()));
  }

  // ─── Step 5: Validate price extraction from descriptions ──────────────────
  // For events that still need price and weren't covered by page fetching
  let descPrices = 0;
  for (const event of events) {
    if (!event.price && event.description) {
      const price = extractPrice(event.description);
      if (price) {
        event.price = price;
        descPrices++;
      }
    }
  }

  // ─── Summary ──────────────────────────────────────────────────────────────
  const withPrice = events.filter((e) => e.price).length;
  const withUrl = events.filter(
    (e) => e.externalURL && !isScraperUrl(e.externalURL)
  ).length;

  log.success(
    "enrich",
    `Enrichment complete: ${withUrl}/${events.length} have clean URLs, ${withPrice}/${events.length} have price data`
  );

  return events;
}
