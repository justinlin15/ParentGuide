import { METRO_AREAS, config } from "./config.js";
import { type PipelineEvent } from "./normalize.js";
import { fetchTicketmasterEvents } from "./sources/ticketmaster.js";
import { fetchSeatGeekEvents } from "./sources/seatgeek.js";
import { fetchYelpEvents } from "./sources/yelp.js";
import { scrapeMacaroniKid } from "./sources/scrapers/macaroni-kid.js";
import { scrapeMommyPoppins } from "./sources/scrapers/mommy-poppins.js";
import { scrapeNYCFamily } from "./sources/scrapers/nyc-family.js";
import { scrapeDFWChild } from "./sources/scrapers/dfw-child.js";
import { scrapeMyKidList } from "./sources/scrapers/mykidlist.js";
import { scrapeAtlantaParent } from "./sources/scrapers/atlanta-parent.js";
import { scrapeOCParentGuide } from "./sources/scrapers/oc-parent-guide.js";
import { deduplicateEvents } from "./deduplicate.js";
import { fillMissingImages } from "./images.js";
import { cleanDescriptions } from "./clean-descriptions.js";
import { rewriteDescriptions } from "./rewrite.js";
import { uploadToCloudKit } from "./cloudkit.js";
import { log } from "./utils/logger.js";

async function main() {
  const startTime = Date.now();

  log.divider();
  log.info("pipeline", "ParentGuide Event Pipeline starting...");
  log.info("pipeline", `Mode: ${config.dryRun ? "DRY RUN" : "LIVE"}`);
  log.info("pipeline", `Metros: ${METRO_AREAS.map((m) => m.name).join(", ")}`);
  log.divider();

  const allEvents: PipelineEvent[] = [];

  for (const metro of METRO_AREAS) {
    log.divider();
    log.info("pipeline", `Processing ${metro.name}...`);

    const metroEvents: PipelineEvent[] = [];

    if (!config.scrapersOnly) {
      // Fetch from APIs (run in parallel per metro)
      const [ticketmaster, seatgeek, yelp] = await Promise.all([
        fetchTicketmasterEvents(metro).catch((err) => {
          log.error("pipeline", "Ticketmaster failed", err);
          return [] as PipelineEvent[];
        }),
        fetchSeatGeekEvents(metro).catch((err) => {
          log.error("pipeline", "SeatGeek failed", err);
          return [] as PipelineEvent[];
        }),
        fetchYelpEvents(metro).catch((err) => {
          log.error("pipeline", "Yelp failed", err);
          return [] as PipelineEvent[];
        }),
      ]);

      metroEvents.push(...ticketmaster, ...seatgeek, ...yelp);
    }

    // Scrape (sequentially to be polite to servers)
    const scraperFns = [
      () => scrapeMommyPoppins(metro),    // covers all 5 metros
      () => scrapeMacaroniKid(metro),      // covers all 5 metros
      () => scrapeNYCFamily(metro),        // NYC only
      () => scrapeDFWChild(metro),         // Dallas only
      () => scrapeMyKidList(metro),        // Chicago only
      () => scrapeAtlantaParent(metro),    // Atlanta only
      () => scrapeOCParentGuide(metro),    // LA/OC only (Playwright)
    ];

    for (const scraperFn of scraperFns) {
      const scraped = await scraperFn().catch((err) => {
        log.error("pipeline", "Scraper failed", err);
        return [] as PipelineEvent[];
      });
      metroEvents.push(...scraped);
    }

    log.info(
      "pipeline",
      `${metro.name}: ${metroEvents.length} raw events collected`
    );
    allEvents.push(...metroEvents);
  }

  log.divider();
  log.info("pipeline", `Total raw events: ${allEvents.length}`);

  // Reassign LA events that belong to Orange County based on city names,
  // venue/address keywords, or geographic coordinates.
  // MommyPoppins treats LA + OC as a single region, so ALL SoCal events
  // arrive tagged "los-angeles". This step splits them correctly.
  const OC_CENTER = { lat: 33.7175, lon: -117.8311 };
  const LA_CENTER = { lat: 34.0522, lon: -118.2437 };
  const OC_CITIES = [
    // Major cities
    "anaheim", "irvine", "santa ana", "huntington beach", "costa mesa",
    "orange", "fullerton", "mission viejo", "lake forest", "laguna",
    "laguna beach", "laguna niguel", "laguna hills", "laguna woods",
    "newport beach", "newport coast", "tustin", "yorba linda", "brea",
    "placentia", "cypress", "garden grove", "westminster", "midway city",
    "fountain valley", "seal beach", "san clemente", "dana point",
    "san juan capistrano", "aliso viejo", "rancho santa margarita",
    "ladera ranch", "trabuco canyon", "coto de caza", "foothill ranch",
    "buena park", "la habra", "stanton", "los alamitos", "rossmoor",
    "silverado", "modjeska canyon", "villa park",
    // South county
    "capistrano beach", "monarch beach", "talega",
    // Landmarks and venues
    "discovery cube oc", "oc fair", "orange county", "south coast plaza",
    "spectrum center", "irvine spectrum", "the lab anti-mall",
    "bowers museum", "pretend city", "adventure playground",
    "great park", "tanaka farms", "knott's", "knotts",
    "medieval times buena park",
  ];
  let ocReassigned = 0;
  for (const event of allEvents) {
    if (event.metro !== "los-angeles") continue;

    // Check city, venue name, address, AND description for OC indicators
    const text = `${event.city} ${event.locationName || ""} ${event.address || ""} ${event.description || ""}`.toLowerCase();
    const matchesOC = OC_CITIES.some((c) => text.includes(c));

    if (matchesOC) {
      event.metro = "orange-county";
      ocReassigned++;
      continue;
    }

    // Coordinate-based: if event has lat/lon, check if closer to OC center
    if (event.latitude && event.longitude) {
      const dLA = Math.pow(event.latitude - LA_CENTER.lat, 2) + Math.pow(event.longitude - LA_CENTER.lon, 2);
      const dOC = Math.pow(event.latitude - OC_CENTER.lat, 2) + Math.pow(event.longitude - OC_CENTER.lon, 2);
      // Reassign if closer to OC and within the OC longitude band
      if (dOC < dLA && event.longitude > -118.1 && event.longitude < -117.3) {
        event.metro = "orange-county";
        ocReassigned++;
      }
    }
  }
  if (ocReassigned > 0) {
    log.info("pipeline", `Reassigned ${ocReassigned} events from los-angeles → orange-county`);
  }

  // Deduplicate
  const deduped = deduplicateEvents(allEvents);

  // Clean promotional language from descriptions
  const cleaned = cleanDescriptions(deduped);

  // Rewrite descriptions to be unique
  const rewritten = rewriteDescriptions(cleaned);

  // Filter out stale events (startDate before today)
  const todayMidnightUTC = new Date();
  todayMidnightUTC.setUTCHours(0, 0, 0, 0);
  const todayStr = todayMidnightUTC.toISOString();

  const upcoming = rewritten.filter((event) => event.startDate >= todayStr);
  const staleCount = rewritten.length - upcoming.length;
  if (staleCount > 0) {
    log.info(
      "pipeline",
      `Removed ${staleCount} stale events (before ${todayMidnightUTC.toISOString().slice(0, 10)})`
    );
  }
  log.info("pipeline", `Upcoming events: ${upcoming.length}`);

  // Fill missing images
  const withImages = await fillMissingImages(upcoming);

  // Upload to CloudKit (or write to output/)
  log.divider();
  await uploadToCloudKit(withImages);

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  log.divider();
  log.success("pipeline", `Done! ${withImages.length} events in ${elapsed}s`);
}

main().catch((err) => {
  log.error("pipeline", "Fatal error", err);
  process.exit(1);
});
