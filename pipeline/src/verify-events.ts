import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

/**
 * Assign a publication status to each event based on source trustworthiness.
 *
 * "published" — safe to show immediately in the app
 * "draft"     — needs admin review before publishing (honeypot / no verified URL)
 *
 * Strategy:
 * - Trusted sources (API partners + OC Parent Guide with credentialed login)
 *   are always published — no honeypot risk.
 * - Unauthenticated scrapers (MommyPoppins, MacaroniKid, etc.): if we found a
 *   real venue/event website (websiteURL or externalURL that isn't the aggregator
 *   site or a Google search) → published.
 * - Unauthenticated scrapers with only a Google search fallback URL or no URL
 *   → draft for admin review. These could be honeypot watermarks injected by
 *   the source site to detect scrapers.
 */

// Sources that are fully trusted — no honeypot risk.
// Includes authorized API partners AND scrapers with authenticated/credentialed access.
const TRUSTED_SOURCES = new Set([
  // Authorized API partners
  "ticketmaster",
  "seatgeek",
  "yelp",
  "eventbrite",
  "kidsguide",
  // Credentialed member scraper — we log in with a paid account,
  // so OC Parent Guide explicitly knows we're accessing their calendar.
  // No honeypot risk; they are the primary OC source.
  "oc-parent-guide",
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
    // Trusted sources (API partners + credentialed scrapers) — always published
    if (TRUSTED_SOURCES.has(event.source)) {
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
