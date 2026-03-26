import { METRO_AREAS, config } from "./config.js";
import { type PipelineEvent, decodeHtmlEntities } from "./normalize.js";
import { fetchTicketmasterEvents } from "./sources/ticketmaster.js";
import { fetchSeatGeekEvents } from "./sources/seatgeek.js";
import { fetchYelpEvents, type YelpRateLimitInfo } from "./sources/yelp.js";
import { fetchEventbriteEvents } from "./sources/eventbrite.js";
import { fetchLibCalEvents } from "./sources/libcal.js";
import { fetchVenueEvents } from "./sources/venue-scrapers.js";
import { fetchThemeParkEvents } from "./sources/theme-parks.js";
import { fetchPretendCityEvents } from "./sources/pretend-city.js";
import { fetchMuseumEvents } from "./sources/museum-scrapers.js";
import { fetchLAParentEvents } from "./sources/la-parent.js";
import { fetchChurchEvents } from "./sources/church-events.js";
import { scrapeMacaroniKid } from "./sources/scrapers/macaroni-kid.js";
import { scrapeMommyPoppins } from "./sources/scrapers/mommy-poppins.js";
import { scrapeNYCFamily } from "./sources/scrapers/nyc-family.js";
import { scrapeDFWChild } from "./sources/scrapers/dfw-child.js";
import { scrapeMyKidList } from "./sources/scrapers/mykidlist.js";
import { scrapeAtlantaParent } from "./sources/scrapers/atlanta-parent.js";
import { scrapeOCParentGuide } from "./sources/scrapers/oc-parent-guide.js";
import { scrapeKidsguide } from "./sources/scrapers/kidsguide.js";
import { deduplicateEvents } from "./deduplicate.js";
import { fillMissingImages } from "./images.js";
import { cleanDescriptions } from "./clean-descriptions.js";
import { rewriteDescriptions } from "./rewrite.js";
import { enrichEvents } from "./enrich.js";
import { aiEnrichEvents } from "./utils/ai-enricher.js";
import { verifyEvents } from "./verify-events.js";
import { saveAiCache } from "./utils/ai-cache.js";
import { uploadToCloudKit, uploadIncrementalToCloudKit } from "./cloudkit.js";
import { diffEvents } from "./diff-events.js";
import { loadPerMetroOutputs, deduplicateMerged } from "./merge.js";
import { geocodeEvents } from "./geocode-events.js";
import { log } from "./utils/logger.js";
import { readFileSync } from "fs";
import { resolve } from "path";

// ─── Reprocess helpers ────────────────────────────────────────────────────────

/** Sources whose coordinates come from their own API — accurate, don't re-geocode */
const TRUSTED_COORD_SOURCES = new Set(["ticketmaster", "seatgeek", "yelp", "eventbrite", "kidsguide"]);

/** Stock-photo CDN hostnames — these should be cleared so we get real venue photos */
function isStockOrAggregatorImage(url: string, source: string): boolean {
  try {
    const host = new URL(url).hostname;
    if (host.includes("unsplash.com") || host.includes("images.pexels.com")) return true;
    const aggregatorHosts = ["mommypoppins.com", "macaronikid.com", "orangecountyparentguide.com", "squarespace.com", "sqsp.net"];
    if (aggregatorHosts.some((h) => host.includes(h))) return true;
    // Aggregator-sourced events keep only non-CDN images
    if (["mommypoppins", "macaronikid", "oc-parent-guide"].includes(source)) {
      if (host.includes("squarespace") || host.includes("sqsp")) return true;
    }
    return false;
  } catch { return false; }
}

/**
 * Load the committed docs/api/events.json and convert each entry to PipelineEvent.
 * Clears stale geocoding (scraper events only) and stock/aggregator images so the
 * improved geocode + image steps re-run with fresh logic.
 */
function loadEventsForReprocess(): PipelineEvent[] {
  const jsonPath = resolve(process.cwd(), "../docs/api/events.json");
  const raw = JSON.parse(readFileSync(jsonPath, "utf8")) as Array<Record<string, unknown>>;

  log.info("pipeline", `Reprocess: loaded ${raw.length} events from docs/api/events.json`);

  return raw.map((e): PipelineEvent => {
    const source = String(e.source ?? "unknown");
    const imageURL = e.imageURL ? String(e.imageURL) : undefined;

    // Keep API-source coordinates; clear scraper coords so improved city-validated
    // geocoding runs fresh (fixes Tustin event → Irvine address mismatches)
    const keepCoords = TRUSTED_COORD_SOURCES.has(source);

    // Clear stock / aggregator images so Google Places Photos + improved
    // Unsplash queries run fresh. Keep real venue images from API sources.
    // Also clear Google Places venue photos for events that have a specific
    // event-page websiteURL — the og:image step will fetch a better promotional
    // image (e.g. Eggstravaganza eggs, Bluey show poster) instead of a random
    // user-uploaded venue photo from Google Maps.
    const websiteURL = e.websiteURL ? String(e.websiteURL) : undefined;
    const hasEventPageURL = websiteURL &&
      !websiteURL.includes("google.com/search") &&
      !websiteURL.includes("mommypoppins.com") &&
      !websiteURL.includes("macaronikid.com");
    const isGooglePlacesPhoto = imageURL?.includes("lh3.googleusercontent.com/place-photos") ||
      imageURL?.includes("lh3.googleusercontent.com/places");
    // Also clear scraped images from aggregator sources (mommypoppins, macaronikid,
    // oc-parent-guide) when the event has its own event-page websiteURL.
    // Scrapers often grab wrong/outdated images from venue media libraries
    // (e.g. Discovery Cube's WordPress uploads returning a Vietnamese museum photo).
    // The og:image step will fetch the real promotional image from the event page.
    const AGGREGATOR_IMAGE_SOURCES = new Set(["mommypoppins", "macaronikid", "oc-parent-guide"]);
    const isAggregatorSourceWithEventPage = AGGREGATOR_IMAGE_SOURCES.has(source) && !!hasEventPageURL;

    const keepImage = imageURL &&
      !isStockOrAggregatorImage(imageURL, source) &&
      !(isGooglePlacesPhoto && hasEventPageURL) &&
      !isAggregatorSourceWithEventPage
        ? imageURL : undefined;

    return {
      sourceId: String(e.id ?? e.sourceId ?? ""),
      title: String(e.title ?? ""),
      description: String(e.description ?? ""),
      startDate: String(e.startDate ?? ""),
      endDate: e.endDate ? String(e.endDate) : undefined,
      isAllDay: !!e.isAllDay,
      locationName: e.location ? String(e.location) : (e.locationName ? String(e.locationName) : undefined),
      city: String(e.city ?? ""),
      metro: String(e.metro ?? ""),
      category: String(e.category ?? "Other"),
      imageURL: keepImage,
      externalURL: e.externalURL ? String(e.externalURL) : undefined,
      websiteURL: e.websiteURL ? String(e.websiteURL) : undefined,
      latitude: keepCoords && e.latitude ? Number(e.latitude) : undefined,
      longitude: keepCoords && e.longitude ? Number(e.longitude) : undefined,
      address: e.address ? String(e.address) : undefined,
      source,
      isFeatured: !!e.isFeatured,
      isRecurring: !!e.isRecurring,
      tags: Array.isArray(e.tags) ? e.tags.map(String) : [],
      price: e.price ? String(e.price) : undefined,
      ageRange: e.ageRange ? String(e.ageRange) : undefined,
      status: e.status ? String(e.status) as PipelineEvent["status"] : undefined,
    };
  });
}

/**
 * Load baseline events from the previous run for incremental diff.
 * Unlike loadEventsForReprocess(), this preserves ALL fields (coords, images, etc.)
 * because unchanged events will be carried forward as-is.
 */
function loadBaseline(): PipelineEvent[] | null {
  const jsonPath = resolve(process.cwd(), "../docs/api/events.json");
  try {
    const raw = JSON.parse(readFileSync(jsonPath, "utf8")) as Array<Record<string, unknown>>;
    if (!raw.length) return null;

    log.info("pipeline", `Incremental: loaded ${raw.length} baseline events from docs/api/events.json`);

    return raw.map((e): PipelineEvent => ({
      sourceId: String(e.id ?? e.sourceId ?? ""),
      title: String(e.title ?? ""),
      description: String(e.description ?? ""),
      startDate: String(e.startDate ?? ""),
      endDate: e.endDate ? String(e.endDate) : undefined,
      isAllDay: !!e.isAllDay,
      locationName: e.location ? String(e.location) : (e.locationName ? String(e.locationName) : undefined),
      city: String(e.city ?? ""),
      metro: String(e.metro ?? ""),
      category: String(e.category ?? "Other"),
      imageURL: e.imageURL ? String(e.imageURL) : undefined,
      externalURL: e.externalURL ? String(e.externalURL) : undefined,
      websiteURL: e.websiteURL ? String(e.websiteURL) : undefined,
      latitude: e.latitude != null ? Number(e.latitude) : undefined,
      longitude: e.longitude != null ? Number(e.longitude) : undefined,
      address: e.address ? String(e.address) : undefined,
      source: String(e.source ?? "unknown"),
      tags: Array.isArray(e.tags) ? e.tags.map(String) : [],
      price: e.price ? String(e.price) : undefined,
      ageRange: e.ageRange ? String(e.ageRange) : undefined,
      status: e.status ? String(e.status) as PipelineEvent["status"] : undefined,
      isFeatured: !!e.isFeatured,
      isRecurring: !!e.isRecurring,
      phone: e.phone ? String(e.phone) : undefined,
      contactEmail: e.contactEmail ? String(e.contactEmail) : undefined,
    }));
  } catch {
    log.info("pipeline", "No baseline found — will run full processing (first run)");
    return null;
  }
}

// ─── Shared Child-Friendly Event Filter ──────────────────────────────────────
// Used by both the normal pipeline path and the --reprocess path.

const ADULT_TITLE_PATS = [
  /\b21\+/i, /\b18\+/i,
  /\b21\s*and\s*(over|up)\b/i, /\b18\s*and\s*(over|up)\b/i,
  /\b21\s*&\s*(over|up)\b/i,
  /\badults?\s*only\b/i, /\bmature\s*audiences?\b/i,
  /\bfor\s+adults\b/i,
  /\badult\s+(enrichment|craft|coloring|book\s*club|yoga|meditation|fitness|workshop|class|program|lecture|seminar)\b/i,
  /\b(makerspace|workshop|class|program|seminar|lecture)\s+for\s+adults\b/i,
  /\bsenior\s+(center|citizen|group|club|program|activity|fitness|yoga|exercise)\b/i,
  /\bseniors?\s+only\b/i,
  /\b(computer|tech|smartphone|iphone)\s+(basics?|help|class|101)\b/i,
  /\besl\s+(class|conversation|group)\b/i,
  /\b(resume|job\s+search|career)\s+(help|workshop|class)\b/i,
  /\btax\s+(prep|preparation|help|clinic)\b/i,
  /\b(medicare|social\s+security|aarp|notary|legal\s+clinic)\b/i,
  /\b(blood\s+pressure|health\s+screening|caregiver\s+support)\b/i,
  /\b(grief\s+support|bereavement|dementia|alzheimer)\b/i,
  /\bnaturalization\s+(ceremony|class|workshop)\b/i,
  /\bcitizenship\s+(class|prep|workshop)\b/i,
  /\bknitting\s+(circle|group|club)\b/i, /\bcrochet\s+(circle|group|club)\b/i,
  /\bbook\s+club\s+for\s+adults\b/i,
  /\bbingo\s+(night|for\s+seniors)\b/i,
  /\bwine\s+(tasting|pairing|dinner|night)\b/i,
  /\bbar\s+crawl\b/i, /\bhappy\s+hour\b/i,
  /\bcocktail\s+(class|making|hour|party)\b/i,
  /\bbrewing\s+(class|workshop)\b/i,
  /\bspeed\s+dating\b/i, /\bsingles\s+(mixer|event|night)\b/i,
  /\bnetworking\s+(event|mixer|happy\s+hour)\b/i,
  // Adult yoga/fitness/wellness (not "yoga for kids" or "family yoga")
  /\b(?:monthly\s+)?(?:corepower\s+)?(?:yoga|pilates|breathwork)\s+(?:on\s+the\s+green|class|session|break)\b/i,
  /\bself\s+care:\s*yoga\b/i, /\bwellness\s+break\b/i,
  // Beer/wine/spirits events
  /\bbeer\s+(?:tasting|festival|day|crawl)\b/i,
  /\bwhisk(?:e?y)\s+tasting\b/i, /\bspirits?\s+tasting\b/i,
  /\bblind\s+tasting\b/i, /\braise\s+a\s+glass\b/i,
  // Date night / tantra
  /\btantra\b/i, /\bdate\s+night\s*\(for\s+couples\)/i,
  // Board meetings, cancelled events, veteran/military, blood drives
  /\bboard\s+(?:meeting|of\s+trustees)\b/i,
  /\bcancell?ed\b/i,
  /\bblood\s+drive\b/i,
  /\bveterans?\s+(?:resource|day\s+event)\b/i,
  // Guide articles combining unrelated topics with "+"
  /\+\s*(?:family\s+)?hiking\s+recs?\b/i,
  /\brecs?\s+nearby\b/i,
  // "17+ Nature Centers" style roundup articles
  /\b\d+\+?\s+(?:nature\s+centers?|places?\s+to|things?\s+to|ways?\s+to)\b/i,
];
const ADULT_DESC_PATS = [
  /\b21\+\s*(?:event|show|only|venue|required|admission)/i,
  /\b18\+\s*(?:event|show|only|venue|required|admission)/i,
  /must\s+be\s+21/i, /must\s+be\s+18/i,
  /\bno\s+(?:one\s+)?under\s+(?:21|18)\b/i,
  /\bdesigned\s+for\s+adults\b/i, /\badult\s+program\b/i,
  /\bage[sd]?\s+18\s*\+/i, /\bages?\s+55\s*\+/i, /\bages?\s+60\s*\+/i,
  /\bfor\s+older\s+adults\b/i,
  /\badults?\s+only\b/i,
];
const ADULT_COMEDY_VENUE_NAMES = [
  "irvine improv", "brea improv", "ontario improv", "tempe improv",
  "the improv", "comedy store", "laugh factory", "ice house comedy",
  "cellar comedy", "comedy cellar",
];

function isChildFriendlyEvent(e: PipelineEvent): boolean {
  if (ADULT_TITLE_PATS.some((p) => p.test(e.title))) return false;
  if (ADULT_DESC_PATS.some((p) => p.test(e.description || ""))) return false;
  // Comedy clubs (API sources only)
  if (["seatgeek", "ticketmaster", "yelp", "eventbrite"].includes(e.source)) {
    const venueLower = (e.locationName || "").toLowerCase();
    if (ADULT_COMEDY_VENUE_NAMES.some((v) => venueLower.includes(v))) return false;
  }
  return true;
}

async function main() {
  const startTime = Date.now();

  log.divider();
  log.info("pipeline", "ParentGuide Event Pipeline starting...");
  const modeLabel = config.reprocess ? "REPROCESS (skip scraping)" : config.dryRun ? "DRY RUN" : "LIVE";
  log.info("pipeline", `Mode: ${modeLabel}`);

  // ── REPROCESS MODE: skip all scraping, load existing events ─────────────────
  // Use --reprocess to re-run enrichment/geocoding/images/upload on the current
  // docs/api/events.json without hitting any source sites.
  if (config.reprocess) {
    const rawReprocess = loadEventsForReprocess();

    // Strip adult/non-family events from the existing dataset (same filter as normal path)
    const events = rawReprocess.filter((e) => isChildFriendlyEvent(e));
    const removedAdult = rawReprocess.length - events.length;
    if (removedAdult > 0) log.info("pipeline", `Removed ${removedAdult} adult/non-family events during reprocess`);

    log.divider();
    log.info("pipeline", "Running AI enrichment (descriptions, categories, fields)...");
    const aiEnriched = await aiEnrichEvents(events);

    // Post-AI sanity: fix "Free Movie" with a price, and "($N)" titles marked Free
    let reprocessSanitized = 0;
    for (const event of aiEnriched) {
      if (event.category === "Free Movie") {
        const hasCost = event.price && !/^free$/i.test(event.price) && event.price !== "Included with admission";
        const titleHasPrice = /^\$\d/.test(event.title.trim());
        if (hasCost || titleHasPrice) { event.category = "Other"; reprocessSanitized++; }
      }
      if (event.price?.toLowerCase() === "free") {
        const m1 = event.title.match(/\(\$(\d+(?:\.\d{2})?)\)/);
        const m2 = event.title.match(/^\$(\d+)/);
        if (m1) { event.price = `$${m1[1]}`; reprocessSanitized++; }
        else if (m2) { event.price = `$${m2[1]}`; reprocessSanitized++; }
      }
    }
    if (reprocessSanitized > 0) log.info("pipeline", `Post-AI sanity: fixed ${reprocessSanitized} contradictions`);

    log.divider();
    log.info("pipeline", "Verifying events (honeypot detection, URL validation)...");
    const verified = await verifyEvents(aiEnriched);

    const todayMidnightUTC = new Date();
    todayMidnightUTC.setUTCHours(0, 0, 0, 0);
    const todayStr = todayMidnightUTC.toISOString();
    const upcoming = verified.filter((e) => e.startDate >= todayStr);
    log.info("pipeline", `Upcoming events after stale filter: ${upcoming.length}`);

    log.divider();
    log.info("pipeline", "Geocoding events with missing coordinates...");
    const geocoded = await geocodeEvents(upcoming);

    const withImages = await fillMissingImages(geocoded);

    log.divider();
    await uploadToCloudKit(withImages);

    saveAiCache();
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    log.divider();
    log.success("pipeline", `Reprocess done! ${withImages.length} events in ${elapsed}s`);
    return;
  }

  // ── MERGE MODE: combine per-metro outputs from parallel matrix jobs ─────────
  if (config.mergeMode) {
    log.info("pipeline", "Running in MERGE mode — combining per-metro outputs...");
    const merged = loadPerMetroOutputs();
    if (merged.length === 0) {
      log.error("pipeline", "No per-metro events found — nothing to merge");
      process.exit(1);
    }

    // Metro reassignment (some LA events belong to OC and vice versa)
    log.divider();
    log.info("pipeline", "Running metro reassignment on merged events...");
    // Note: reassignment logic is in the main loop below — for merge mode,
    // we skip it because each metro job already tagged events with their metro.
    // Cross-metro reassignment will be added when we have specific city lists.

    // Content filter
    const familyFiltered = merged.filter((e) => isChildFriendlyEvent(e));
    const adultRemoved = merged.length - familyFiltered.length;
    if (adultRemoved > 0) log.info("pipeline", `Removed ${adultRemoved} non-family events`);

    // Cross-metro dedup
    const deduped = deduplicateMerged(familyFiltered);

    // Stale filter
    const todayMidnightUTC = new Date();
    todayMidnightUTC.setUTCHours(0, 0, 0, 0);
    const todayStr = todayMidnightUTC.toISOString();
    const upcoming = deduped.filter((e) => e.startDate >= todayStr);
    const staleCount = deduped.length - upcoming.length;
    if (staleCount > 0) log.info("pipeline", `Removed ${staleCount} stale events`);

    // Incremental diff + upload
    const baseline = loadBaseline();
    if (baseline && baseline.length > 0) {
      const diff = diffEvents(upcoming, baseline);
      const newIds = new Set(diff.newEvents.map((e) => e.sourceId));
      const changedIds = new Set(diff.changedEvents.map((e) => e.sourceId));

      // For merge mode, the per-metro jobs already did AI/geocode/images.
      // We just need to upload the delta and carry forward unchanged events.
      // Merge processed events with unchanged baseline events.
      const mergedMap = new Map<string, PipelineEvent>();
      for (const e of diff.unchangedEvents) mergedMap.set(e.sourceId, e);
      for (const e of upcoming) {
        if (newIds.has(e.sourceId) || changedIds.has(e.sourceId)) {
          mergedMap.set(e.sourceId, e);
        }
      }
      const allFinal = Array.from(mergedMap.values());

      log.info("pipeline", `Merge upload: ${newIds.size} new, ${changedIds.size} changed, ${diff.unchangedEvents.length} unchanged, ${diff.removedSourceIds.length} removed`);

      await uploadIncrementalToCloudKit(allFinal, newIds, changedIds, diff.removedSourceIds);
    } else {
      await uploadToCloudKit(upcoming);
    }

    saveAiCache();
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    log.divider();
    log.success("pipeline", `Merge done! ${upcoming.length} events in ${elapsed}s`);
    return;
  }

  // Only process enabled metros (Phase 1: OC + LA)
  let activeMetros = METRO_AREAS.filter((m) => m.enabled);

  // Single-metro mode: filter to just the specified metro
  if (config.metroFilter) {
    activeMetros = activeMetros.filter((m) => m.id === config.metroFilter);
    if (activeMetros.length === 0) {
      log.error("pipeline", `Metro "${config.metroFilter}" not found or not enabled`);
      process.exit(1);
    }
    log.info("pipeline", `Single-metro mode: ${activeMetros[0].name}`);
  } else {
    log.info("pipeline", `Active metros: ${activeMetros.map((m) => m.name).join(", ")}`);
  }
  log.info("pipeline", `Skipped metros: ${METRO_AREAS.filter((m) => !m.enabled).map((m) => m.name).join(", ") || "none"}`);
  log.divider();

  const allEvents: PipelineEvent[] = [];
  let yelpRateLimit: YelpRateLimitInfo = { remaining: null, resetTime: null };

  for (const metro of activeMetros) {
    log.divider();
    log.info("pipeline", `Processing ${metro.name}...`);

    const metroEvents: PipelineEvent[] = [];

    if (!config.scrapersOnly) {
      // Fetch from APIs (run in parallel per metro)
      const [ticketmaster, seatgeek, yelpResult, eventbrite, libcal, venues, themeparks, pretendcity, museums, laparent, churches] = await Promise.all([
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
          return { events: [] as PipelineEvent[], rateLimit: { remaining: null, resetTime: null } };
        }),
                fetchEventbriteEvents(metro).catch((err) => {
                            log.error("pipeline", "Eventbrite failed", err);
                            return [] as PipelineEvent[];
                }),
        fetchLibCalEvents(metro).catch((err) => {
          log.error("pipeline", "LibCal failed", err);
          return [] as PipelineEvent[];
        }),
        fetchVenueEvents(metro).catch((err) => {
          log.error("pipeline", "Venue scrapers failed", err);
          return [] as PipelineEvent[];
        }),
        fetchThemeParkEvents(metro).catch((err) => {
          log.error("pipeline", "Theme parks failed", err);
          return [] as PipelineEvent[];
        }),
        fetchPretendCityEvents(metro).catch((err) => {
          log.error("pipeline", "Pretend City failed", err);
          return [] as PipelineEvent[];
        }),
        fetchMuseumEvents(metro).catch((err) => {
          log.error("pipeline", "Museum scrapers failed", err);
          return [] as PipelineEvent[];
        }),
        fetchLAParentEvents(metro).catch((err) => {
          log.error("pipeline", "LA Parent failed", err);
          return [] as PipelineEvent[];
        }),
        fetchChurchEvents(metro).catch((err) => {
          log.error("pipeline", "Church events failed", err);
          return [] as PipelineEvent[];
        }),
      ]);

      // Track Yelp rate limit (keep lowest remaining across metros)
      if (yelpResult.rateLimit.remaining !== null) {
        if (yelpRateLimit.remaining === null || yelpResult.rateLimit.remaining < yelpRateLimit.remaining) {
          yelpRateLimit = yelpResult.rateLimit;
        }
      }

      metroEvents.push(
        ...ticketmaster, ...seatgeek, ...yelpResult.events, ...eventbrite,
        ...libcal, ...venues, ...themeparks, ...pretendcity,
        ...museums, ...laparent, ...churches
      );
    }

    // Scrape (sequentially to be polite to servers).
    // Each entry declares which metro IDs it supports so scrapers are never
    // called for irrelevant regions — avoids wasted HTTP requests.
    //
    // OC Parent Guide:  OC only — internal guard returns [] for any other metro.
    // Kidsguide:        LA only — internal guard skips OC; OC events reassigned
    //                   from LA batch in post-processing.
    // MommyPoppins:     LA only — OC shares LA region 115; OC events reassigned.
    // MacaroniKid:      LA only — national site, run once; reassignment splits OC.
    // NYC/Dallas/Chicago/Atlanta: disabled in Phase 1 (metros not enabled).
    const scraperDefs: Array<{ metros: string[]; fn: () => Promise<PipelineEvent[]> }> = [
      { metros: ["orange-county"],  fn: () => scrapeOCParentGuide(metro) },
      { metros: ["los-angeles"],    fn: () => scrapeKidsguide(metro) },
      { metros: ["los-angeles"],    fn: () => scrapeMommyPoppins(metro) },
      { metros: ["los-angeles"],    fn: () => scrapeMacaroniKid(metro) },
      { metros: ["new-york"],       fn: () => scrapeNYCFamily(metro) },
      { metros: ["dallas"],         fn: () => scrapeDFWChild(metro) },
      { metros: ["chicago"],        fn: () => scrapeMyKidList(metro) },
      { metros: ["atlanta"],        fn: () => scrapeAtlantaParent(metro) },
    ];

    const applicableScrapers = scraperDefs.filter((s) => s.metros.includes(metro.id));
    log.info("pipeline", `  Running ${applicableScrapers.length} scrapers for ${metro.name}`);

    for (const { fn } of applicableScrapers) {
      const scraped = await fn().catch((err) => {
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

  // ── Adult Content Filter ─────────────────────────────────────────────────────
  // Reject events that are explicitly 21+/18+/adults-only OR at known adult
  // comedy club venues (Improv, Comedy Store, Laugh Factory, etc. are 21+).
  // These slip through from SeatGeek "comedy" taxonomy and have no place in
  // a family events app.
  // Platform-specific community meetup patterns — these are adult social events
  // tied to a specific app/platform (Yelp Elite, Nextdoor, etc.), not family events.
  // "UYE" = Yelp Elite event abbreviation used in Yelp's API event titles.
  const PLATFORM_MEETUP_PATTERNS = [
    /\bUYE\b/,                            // Yelp Elite event prefix
    /\byelp\s+(elite|community|event)\b/i,
    /\byelp\s+\w+\s+(lunch|dinner|brunch|meetup|mixer|party)\b/i,
    /\blunch\s+with\s+\w+\b/i,            // "Lunch with Joel" type Yelp events
    /\bdinner\s+with\s+\w+\b/i,
    /\bnextdoor\s+(event|meetup)\b/i,
    /\bcommunity\s+meetup\b/i,            // Generic adult networking
  ];

  // Multi-location guide/roundup article titles — these are blog articles
  // ("Ice Skating in Irvine, Anaheim, Westminster, and Yorba Linda") not single events.
  // Detect: title names 3+ cities OR has "in [City1], [City2]..., and [City3]" pattern.
  function isGuideArticleTitle(title: string): boolean {
    // Pattern: "in [Word], [Word], [Word], and [Word]" — 3+ comma-separated locations
    const multiLocationMatch = title.match(/\bin\s+[\w\s]+(?:,\s+[\w\s]+){2,},?\s+and\s+[\w\s]+/i);
    if (multiLocationMatch) return true;
    // Count known OC/LA city names in the title — 3+ = roundup article
    const citiesInTitle = OC_CITIES.filter((c) => new RegExp(`\\b${c}\\b`, "i").test(title));
    if (citiesInTitle.length >= 3) return true;
    return false;
  }

  const beforeAdultFilter = allEvents.length;
  const familyFiltered = allEvents.filter((e) => {
    // Shared child-friendly filter (adult events, age restrictions, comedy clubs)
    if (!isChildFriendlyEvent(e)) return false;

    // Platform-specific adult community meetups (Yelp Elite, etc.)
    if (PLATFORM_MEETUP_PATTERNS.some((p) => p.test(e.title))) return false;

    // Guide/roundup articles masquerading as single events
    if (isGuideArticleTitle(e.title)) return false;

    return true;
  });
  const adultRemoved = beforeAdultFilter - familyFiltered.length;
  if (adultRemoved > 0) {
    log.info("pipeline", `Removed ${adultRemoved} non-family events (adult/21+, platform meetups, guide articles)`);
  }

  // Decode HTML entities in titles (e.g. &#039; → ', &amp; → &)
  for (const e of familyFiltered) {
    e.title = decodeHtmlEntities(e.title);
    if (e.description) e.description = decodeHtmlEntities(e.description);
  }

  // Deduplicate
  const deduped = deduplicateEvents(familyFiltered);

  // Clean promotional language and scraper mentions from descriptions
  const cleaned = cleanDescriptions(deduped);

  // Template-based description rewrite (fast fallback — AI step below improves further)
  const rewritten = rewriteDescriptions(cleaned);

  // Enrich: sanitize URLs (replace scraper source links), extract prices via regex
  log.divider();
  log.info("pipeline", "Enriching events (URL sanitization, price extraction)...");
  const enriched = await enrichEvents(rewritten);

  // ── Single-Metro Mode: skip incremental diff, run full processing ────────────
  // In matrix strategy, each metro job processes its events fully and writes
  // a per-metro file. The merge job handles incremental diff and CloudKit upload.
  if (config.metroFilter) {
    log.divider();
    log.info("pipeline", `Single-metro mode: full processing for ${config.metroFilter}...`);

    const aiEnriched = await aiEnrichEvents(enriched);

    // Post-AI sanity
    let sanitized = 0;
    for (const event of aiEnriched) {
      if (event.category === "Free Movie") {
        const hasCost = event.price && !/^free$/i.test(event.price) && event.price !== "Included with admission";
        const titleHasPrice = /^\$\d/.test(event.title.trim());
        if (hasCost || titleHasPrice) { event.category = "Other"; sanitized++; }
      }
      if (event.price?.toLowerCase() === "free") {
        const m1 = event.title.match(/\(\$(\d+(?:\.\d{2})?)\)/);
        const m2 = event.title.match(/^\$(\d+)/);
        if (m1) { event.price = `$${m1[1]}`; sanitized++; }
        else if (m2) { event.price = `$${m2[1]}`; sanitized++; }
      }
    }
    if (sanitized > 0) log.info("pipeline", `Post-AI sanity: fixed ${sanitized} contradictions`);

    const verified = await verifyEvents(aiEnriched);

    const todayMidnightUTC = new Date();
    todayMidnightUTC.setUTCHours(0, 0, 0, 0);
    const todayStr = todayMidnightUTC.toISOString();
    const upcoming = verified.filter((e) => e.startDate >= todayStr);

    const geocoded = await geocodeEvents(upcoming);
    const withImages = await fillMissingImages(geocoded);

    // Write per-metro output file (merge job will combine these)
    const { writeFile, mkdir } = await import("fs/promises");
    const { join } = await import("path");
    const outputDir = join(process.cwd(), "output");
    await mkdir(outputDir, { recursive: true });
    const outputPath = join(outputDir, `${config.metroFilter}-events.json`);
    await writeFile(outputPath, JSON.stringify(withImages, null, 2));
    log.success("pipeline", `Wrote ${withImages.length} events to ${outputPath}`);

    saveAiCache();
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    log.divider();
    log.success("pipeline", `Done (single-metro)! ${withImages.length} events in ${elapsed}s`);
    return;
  }

  // ── Incremental Diff ──────────────────────────────────────────────────────────
  // Compare against previous run's output to only process new/changed events
  // through the slow steps (AI enrichment, geocoding, images).
  let finalEventCount = 0;
  const baseline = config.reprocess ? null : loadBaseline();

  const todayMidnightUTC = new Date();
  todayMidnightUTC.setUTCHours(0, 0, 0, 0);
  const todayStr = todayMidnightUTC.toISOString();

  if (baseline && baseline.length > 0) {
    log.divider();
    log.info("pipeline", "Running incremental diff against baseline...");
    const diff = diffEvents(enriched, baseline);

    // The "delta" = new + changed events — these need full processing
    const delta = [...diff.newEvents, ...diff.changedEvents];

    if (delta.length === 0) {
      log.info("pipeline", "No new or changed events — skipping AI/geocode/images");
      // Still filter stale from unchanged
      const upcomingUnchanged = diff.unchangedEvents.filter((e) => e.startDate >= todayStr);
      const staleCount = diff.unchangedEvents.length - upcomingUnchanged.length;
      if (staleCount > 0) {
        log.info("pipeline", `Removed ${staleCount} stale unchanged events`);
      }

      // Combine removed sourceIds: explicit removals + stale baseline events
      const staleRemovedIds = diff.unchangedEvents
        .filter((e) => e.startDate < todayStr)
        .map((e) => e.sourceId);
      const allRemovedIds = [...diff.removedSourceIds, ...staleRemovedIds];

      finalEventCount = upcomingUnchanged.length;
      log.divider();
      await uploadIncrementalToCloudKit(
        upcomingUnchanged,
        new Set<string>(),
        new Set<string>(),
        allRemovedIds,
        { rateLimits: yelpRateLimit.remaining !== null ? { yelp: yelpRateLimit } : undefined }
      );
    } else {
      log.info("pipeline", `Processing ${delta.length} new/changed events through full pipeline...`);

      // ── AI Enrichment (delta only) ──────────────────────────────────────────
      log.divider();
      log.info("pipeline", `Running AI enrichment on ${delta.length} events...`);
      const aiEnriched = await aiEnrichEvents(delta);

      // ── Post-AI Sanity Checks ──────────────────────────────────────────────
      let sanitized = 0;
      for (const event of aiEnriched) {
        if (event.category === "Free Movie") {
          const hasCost = event.price && !/^free$/i.test(event.price) && event.price !== "Included with admission";
          const titleHasPrice = /^\$\d/.test(event.title.trim());
          if (hasCost || titleHasPrice) { event.category = "Other"; sanitized++; }
        }
        if (event.price?.toLowerCase() === "free") {
          const m1 = event.title.match(/\(\$(\d+(?:\.\d{2})?)\)/);
          const m2 = event.title.match(/^\$(\d+)/);
          if (m1) { event.price = `$${m1[1]}`; sanitized++; }
          else if (m2) { event.price = `$${m2[1]}`; sanitized++; }
        }
      }
      if (sanitized > 0) log.info("pipeline", `Post-AI sanity: fixed ${sanitized} contradictions`);

      // ── Honeypot Verification (delta only) ──────────────────────────────────
      log.divider();
      log.info("pipeline", "Verifying events (honeypot detection, URL validation)...");
      const verified = await verifyEvents(aiEnriched);

      // Stale filter on delta
      const upcomingDelta = verified.filter((e) => e.startDate >= todayStr);

      // ── Geocode (delta only, events missing coordinates) ──────────────────
      log.divider();
      log.info("pipeline", `Geocoding ${upcomingDelta.filter((e) => !e.latitude).length} events with missing coordinates...`);
      const geocoded = await geocodeEvents(upcomingDelta);

      // ── Images (delta only) ───────────────────────────────────────────────
      const withImages = await fillMissingImages(geocoded);

      // Filter stale from unchanged baseline events
      const upcomingUnchanged = diff.unchangedEvents.filter((e) => e.startDate >= todayStr);
      const staleUnchanged = diff.unchangedEvents.length - upcomingUnchanged.length;
      if (staleUnchanged > 0) {
        log.info("pipeline", `Removed ${staleUnchanged} stale unchanged events`);
      }

      // Merge: processed delta + unchanged = full event set
      const mergedMap = new Map<string, PipelineEvent>();
      for (const e of upcomingUnchanged) mergedMap.set(e.sourceId, e);
      for (const e of withImages) mergedMap.set(e.sourceId, e);
      const allFinal = Array.from(mergedMap.values());

      log.info("pipeline", `Merged: ${withImages.length} processed + ${upcomingUnchanged.length} unchanged = ${allFinal.length} total`);

      // Combine removed sourceIds: explicit removals + stale events from both pools
      const staleRemovedIds = [
        ...diff.unchangedEvents.filter((e) => e.startDate < todayStr).map((e) => e.sourceId),
        ...verified.filter((e) => e.startDate < todayStr).map((e) => e.sourceId),
      ];
      const allRemovedIds = [...diff.removedSourceIds, ...staleRemovedIds];

      const newSourceIds = new Set(diff.newEvents.map((e) => e.sourceId));
      const changedSourceIds = new Set(diff.changedEvents.map((e) => e.sourceId));

      finalEventCount = allFinal.length;
      log.divider();
      await uploadIncrementalToCloudKit(
        allFinal,
        newSourceIds,
        changedSourceIds,
        allRemovedIds,
        { rateLimits: yelpRateLimit.remaining !== null ? { yelp: yelpRateLimit } : undefined }
      );
    }
  } else {
    // No baseline — full processing (first run or --reprocess)
    log.info("pipeline", "No baseline available — running full processing pipeline...");

    // ── AI Enrichment ───────────────────────────────────────────────────────────
    log.divider();
    log.info("pipeline", "Running AI enrichment (descriptions, categories, fields)...");
    const aiEnriched = await aiEnrichEvents(enriched);

    // ── Post-AI Sanity Checks ─────────────────────────────────────────────────────
    let sanitized = 0;
    for (const event of aiEnriched) {
      if (event.category === "Free Movie") {
        const hasCost = event.price && !/^free$/i.test(event.price) && event.price !== "Included with admission";
        const titleHasPrice = /^\$\d/.test(event.title.trim());
        if (hasCost || titleHasPrice) { event.category = "Other"; sanitized++; }
      }
      if (event.price?.toLowerCase() === "free") {
        const m1 = event.title.match(/\(\$(\d+(?:\.\d{2})?)\)/);
        const m2 = event.title.match(/^\$(\d+)/);
        if (m1) { event.price = `$${m1[1]}`; sanitized++; }
        else if (m2) { event.price = `$${m2[1]}`; sanitized++; }
      }
    }
    if (sanitized > 0) log.info("pipeline", `Post-AI sanity: fixed ${sanitized} contradictions`);

    // ── Honeypot / Watermark Verification ───────────────────────────────────────
    log.divider();
    log.info("pipeline", "Verifying events (honeypot detection, URL validation)...");
    const verified = await verifyEvents(aiEnriched);

    // Filter out stale events
    const upcoming = verified.filter((event) => event.startDate >= todayStr);
    const staleCount = verified.length - upcoming.length;
    if (staleCount > 0) {
      log.info("pipeline", `Removed ${staleCount} stale events (before ${todayMidnightUTC.toISOString().slice(0, 10)})`);
    }
    log.info("pipeline", `Upcoming events: ${upcoming.length}`);

    // Geocode events missing coordinates
    log.divider();
    log.info("pipeline", "Geocoding events with missing coordinates...");
    const geocoded = await geocodeEvents(upcoming);

    // Fill missing images
    const withImages = await fillMissingImages(geocoded);

    // Upload to CloudKit (full upload — no baseline to diff against)
    finalEventCount = withImages.length;
    log.divider();
    await uploadToCloudKit(withImages, {
      rateLimits: yelpRateLimit.remaining !== null ? { yelp: yelpRateLimit } : undefined,
    });
  }

  // Flush AI cache to disk so the next run benefits from today's results
  log.divider();
  saveAiCache();

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  log.divider();
  log.success("pipeline", `Done! ${finalEventCount} events in ${elapsed}s`);
}

main().catch((err) => {
  log.error("pipeline", "Fatal error", err);
  process.exit(1);
});
