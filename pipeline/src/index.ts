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
import { deduplicateEvents } from "./deduplicate.js";
import { fillMissingImages } from "./images.js";
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

  // Deduplicate
  const deduped = deduplicateEvents(allEvents);

  // Fill missing images
  const withImages = await fillMissingImages(deduped);

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
