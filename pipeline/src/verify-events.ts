import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

/**
 * Assign a publication status to each event based on source trustworthiness.
 *
 * "published" — safe to show immediately in the app
 * "draft"     — needs admin review before publishing (honeypot / no verified URL)
 *
 * Strategy:
 * - API sources (Ticketmaster, SeatGeek, Yelp, Eventbrite, Kidsguide) are
 *   authorized data partners → always published.
 * - Scrapers: if we found a real venue/event website (websiteURL or externalURL
 *   that isn't an aggregator or Google search) → published.
 * - Scrapers with only a Google search fallback URL or no URL at all → draft.
 *   These events could be honeypot watermarks injected by the source site to
 *   detect scrapers. Admin review prevents fake events from reaching users.
 */

// Sources that are verified API partners — no honeypot risk
const TRUSTED_API_SOURCES = new Set([
  "ticketmaster",
  "seatgeek",
  "yelp",
  "eventbrite",
  "kidsguide",
]);

// Aggregator domains — URLs from these sites don't count as "verified"
const AGGREGATOR_DOMAINS = [
  "mommypoppins.com",
  "macaronikid.com",
  "atlantaparent.com",
  "dfwchild.com",
  "mykidlist.com",
  "nycfamily.com",
  "ocparentguide.com",
  "orangecountyparentguide.com",
  "kidsguidemagazine.com",
];

function isAggregatorUrl(url: string): boolean {
  try {
    const hostname = new URL(url).hostname.replace(/^www\./, "");
    return AGGREGATOR_DOMAINS.some((domain) => hostname.includes(domain));
  } catch {
    return false;
  }
}

function isGoogleSearchUrl(url: string): boolean {
  try {
    const hostname = new URL(url).hostname;
    return hostname.includes("google.com");
  } catch {
    return false;
  }
}

function hasVerifiedUrl(event: PipelineEvent): boolean {
  // websiteURL is always a direct venue/event site (set by enricher)
  if (event.websiteURL && !isAggregatorUrl(event.websiteURL)) {
    return true;
  }

  // externalURL might be a real venue page or a Google search fallback
  if (event.externalURL) {
    if (isGoogleSearchUrl(event.externalURL)) return false;
    if (isAggregatorUrl(event.externalURL)) return false;
    return true; // It's a real external URL
  }

  return false;
}

export function verifyEvents(events: PipelineEvent[]): PipelineEvent[] {
  let publishedCount = 0;
  let draftCount = 0;

  const result = events.map((event) => {
    // API sources — always trusted
    if (TRUSTED_API_SOURCES.has(event.source)) {
      publishedCount++;
      return { ...event, status: "published" as const };
    }

    // Scrapers — verify via URL
    if (hasVerifiedUrl(event)) {
      publishedCount++;
      return { ...event, status: "published" as const };
    }

    // No verified URL → draft for admin review
    draftCount++;
    return { ...event, status: "draft" as const };
  });

  log.info(
    "verify",
    `Status assigned: ${publishedCount} published, ${draftCount} draft (pending admin review)`
  );

  return result;
}
