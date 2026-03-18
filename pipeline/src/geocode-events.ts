import { type PipelineEvent } from "./normalize.js";
import { geocodeAddress, delay, RATE_LIMITED } from "./utils/geocoder.js";
import {
  searchForVenueLocation,
  extractAddressFromText,
} from "./utils/web-enricher.js";
import { log } from "./utils/logger.js";
import { config } from "./config.js";

/**
 * Post-scrape geocoding step.
 *
 * Identifies events that are missing valid latitude/longitude and attempts
 * to resolve coordinates using event metadata: address, locationName, title,
 * description, and city. Uses OpenStreetMap Nominatim (free, no API key).
 *
 * Run this AFTER deduplication so we don't geocode duplicates, and BEFORE
 * the CloudKit upload so events arrive with coordinates.
 */

const METRO_CITIES: Record<string, string> = {
  "los-angeles": "Los Angeles, CA",
  "orange-county": "Irvine, CA",
  "new-york": "New York, NY",
  dallas: "Dallas, TX",
  chicago: "Chicago, IL",
  atlanta: "Atlanta, GA",
};

/**
 * Generic/metro-level city names that are too broad for city-validated geocoding.
 * When an event has one of these as its city, we try to extract the real city
 * from the event title before geocoding.
 */
const GENERIC_CITY_NAMES = new Set([
  // Metro/county level — too broad
  "orange county", "los angeles", "la", "oc", "southern california", "socal",
  "greater los angeles", "greater orange county",
  // Venue names that scrapers accidentally store as the city
  "discovery cube oc", "discovery cube", "disneyland", "disney california adventure",
  "knott's berry farm", "knotts berry farm", "universal studios",
  "irvine spectrum", "south coast plaza", "the great park",
  "irvine park railroad", "tanaka farms",
]);

function isGenericCity(city: string): boolean {
  return GENERIC_CITY_NAMES.has(city.toLowerCase().trim());
}

/**
 * Known OC and LA city names ordered longest-first to prefer more specific matches
 * (e.g. "Laguna Niguel" before "Laguna").
 */
const EXTRACTABLE_CITIES = [
  "Corona del Mar", "Newport Coast", "Laguna Niguel", "Laguna Hills", "Laguna Woods",
  "Laguna Beach", "Huntington Beach", "Newport Beach", "Mission Viejo", "Lake Forest",
  "Rancho Santa Margarita", "San Juan Capistrano", "Aliso Viejo", "San Clemente",
  "Dana Point", "Fountain Valley", "Garden Grove", "Yorba Linda", "Buena Park",
  "Santa Ana", "Costa Mesa", "Fullerton", "Anaheim", "Placentia", "La Habra",
  "Stanton", "Cypress", "Westminster", "Los Alamitos", "Seal Beach", "Irvine",
  "Tustin", "Orange", "Brea", "Villa Park",
  // LA cities
  "Santa Monica", "Long Beach", "Pasadena", "Burbank", "Glendale", "Torrance",
  "El Segundo", "Culver City", "Inglewood", "Hawthorne", "Redondo Beach",
  "Hermosa Beach", "Manhattan Beach", "Malibu", "Calabasas", "Thousand Oaks",
  "Chatsworth", "Northridge", "Sherman Oaks", "Studio City", "Van Nuys",
  "North Hollywood", "Hollywood", "West Hollywood", "Koreatown",
];

/**
 * Try to extract a real city name from an event title.
 * E.g. "Corona Del Mar Songs and Stories" → "Corona del Mar"
 * Looks for known city names at the start of the title or after common prepositions.
 */
function extractCityFromTitle(title: string): string | null {
  const lower = title.toLowerCase();
  for (const city of EXTRACTABLE_CITIES) {
    const cityLower = city.toLowerCase();
    // City at the start of the title (e.g. "Corona Del Mar Songs and Stories")
    if (lower.startsWith(cityLower)) return city;
    // City after "at", "in", "-", "–"
    const prefixMatch = lower.match(
      new RegExp(`(?:^|\\bat\\b|\\bin\\b|\\s[-–]\\s)\\s*${cityLower.replace(/\s+/g, "\\s+")}`, "i")
    );
    if (prefixMatch) return city;
  }
  return null;
}

/** Check if an event has valid (non-zero) coordinates. */
function hasValidCoords(event: PipelineEvent): boolean {
  if (event.latitude == null || event.longitude == null) return false;
  if (event.latitude === 0 && event.longitude === 0) return false;
  // Reject obviously wrong coordinates (outside continental US rough bounds)
  if (event.latitude < 24 || event.latitude > 50) return false;
  if (event.longitude < -130 || event.longitude > -65) return false;
  return true;
}

/**
 * Try multiple strategies to geocode an event, from most to least specific.
 * Returns { latitude, longitude } or null if all strategies fail.
 */
async function geocodeEvent(
  event: PipelineEvent
): Promise<{ latitude: number; longitude: number; address?: string } | null> {
  const metroCity = METRO_CITIES[event.metro] || event.city;

  // When the stored city is a generic metro/county name (e.g. "Orange County"),
  // try to extract the real neighbourhood/city from the event title so we can
  // do precise geocoding instead of falling back to the wrong metro default.
  // E.g. "Corona Del Mar Songs and Stories" → effectiveCity = "Corona del Mar"
  let effectiveCity = event.city;
  if (!effectiveCity || isGenericCity(effectiveCity)) {
    const extracted = extractCityFromTitle(event.title);
    if (extracted) {
      effectiveCity = extracted;
      log.info("geocode", `  Extracted city "${extracted}" from title "${event.title}"`);
    }
  }

  // Strategy 0: Google Places Text Search (most accurate — knows businesses by name)
  // Build the most specific query we can from available event data.
  // Prefer effectiveCity over metroCity so "Tustin Farmers Market" searches in
  // Tustin, not the metro default of Irvine. City is passed as expectedCity
  // so results from a different city are rejected even if within metro bounds.
  if (config.googlePlaces.apiKey) {
    const queries: string[] = [];
    const specificCity = effectiveCity ? `${effectiveCity}, CA` : metroCity;

    // Most specific: venue name + address + event city
    if (event.locationName && event.address) {
      queries.push(`${event.locationName}, ${event.address}, ${specificCity}`);
    }
    // Venue name + event city (primary lookup — most likely to find the right place)
    if (event.locationName) {
      queries.push(`${event.locationName}, ${specificCity}`);
    }
    // Title venue extraction + event city
    const titleVenue = extractVenueFromTitle(event.title);
    if (titleVenue && titleVenue !== event.locationName) {
      queries.push(`${titleVenue}, ${specificCity}`);
    }
    // Full event title + event city
    queries.push(`${event.title}, ${specificCity}`);
    // Fallback: venue name + metro city (in case event.city is mis-labelled)
    if (event.locationName && specificCity !== metroCity) {
      queries.push(`${event.locationName}, ${metroCity}`);
    }

    for (const query of queries) {
      // Pass effectiveCity as expectedCity so wrong-city results are rejected.
      // effectiveCity may be extracted from the title when event.city is generic
      // (e.g. "REDO Market in Costa Mesa" → effectiveCity = "Costa Mesa").
      // Skip city validation on the last fallback query (no constraint).
      const isMetroFallback = query.endsWith(metroCity) && specificCity !== metroCity;
      const result = await lookupGooglePlaces(
        query,
        event.metro,
        isMetroFallback ? undefined : (effectiveCity && !isGenericCity(effectiveCity) ? effectiveCity : undefined)
      );
      if (result) {
        log.info("geocode", `  ✓ [Google Places] "${event.title}" → ${result.address ?? query}`);
        await delay(200); // Respect rate limits (modest, Places API is generous)
        return result;
      }
    }
    await delay(200);
  }

  // Strategy 1: Full street address + city (most precise)
  if (event.address && event.address.length > 5) {
    const fullAddress = event.city
      ? `${event.address}, ${event.city}`
      : event.address;
    const result = await geocodeAddress(fullAddress);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info("geocode", `  ✓ [address] "${event.title}" → ${fullAddress}`);
      return result;
    }
    await delay(1500);
  }

  // Strategy 2: Location/venue name + city (e.g. "Tanaka Farms, Irvine, CA")
  if (event.locationName && event.locationName.length > 2) {
    const query = `${event.locationName}, ${metroCity}`;
    const result = await geocodeAddress(query);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info("geocode", `  ✓ [venue+city] "${event.title}" → ${query}`);
      return result;
    }
    await delay(1500);
  }

  // Strategy 3: Extract address from description text
  const extractedAddr = extractAddressFromText(event.description);
  if (extractedAddr) {
    const query = event.city
      ? `${extractedAddr}, ${event.city}`
      : extractedAddr;
    const result = await geocodeAddress(query);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info(
        "geocode",
        `  ✓ [desc address] "${event.title}" → ${extractedAddr}`
      );
      return { ...result, address: extractedAddr };
    }
    await delay(1500);
  }

  // Strategy 4: Event title + city (works for named venues/places in title)
  // e.g. "Storytime at Irvine Public Library" → "Irvine Public Library, Irvine, CA"
  const titleVenue = extractVenueFromTitle(event.title);
  if (titleVenue) {
    const query = `${titleVenue}, ${metroCity}`;
    const result = await geocodeAddress(query);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info("geocode", `  ✓ [title venue] "${event.title}" → ${titleVenue}`);
      return result;
    }
    await delay(1500);
  }

  // Strategy 5: "at Venue" pattern in description
  const atVenueMatch = event.description.match(
    /(?:at|@|held at|located at|venue:\s*)\s+([A-Z][A-Za-z'\-& ]{2,50}(?:Park|Museum|Center|Centre|Library|Hall|Arena|Stadium|Theater|Theatre|Zoo|Garden|Gallery|Church|School|Academy|Institute|Pavilion|Plaza|Square|Beach|Pool|Farm|Ranch|Brewery|Restaurant|Cafe|Studios?)?)/i
  );
  if (atVenueMatch) {
    const venueFromDesc = atVenueMatch[1].trim();
    const query = `${venueFromDesc}, ${metroCity}`;
    const result = await geocodeAddress(query);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info(
        "geocode",
        `  ✓ [desc venue] "${event.title}" → ${venueFromDesc}`
      );
      return result;
    }
    await delay(1500);
  }

  // Strategy 6: City-level fallback (least precise but better than nothing)
  // Only use if event has a specific city name (not just the metro)
  if (event.city && event.city.length > 2) {
    const stateAbbrev = getStateForMetro(event.metro);
    const query = stateAbbrev
      ? `${event.city}, ${stateAbbrev}`
      : event.city;
    const result = await geocodeAddress(query);
    if (result === RATE_LIMITED) { await delay(5000); return null; } // back off on persistent rate limit

    if (result && isReasonableLocation(result, event.metro)) {
      log.info("geocode", `  ✓ [city] "${event.title}" → ${event.city}`);
      return result;
    }
    await delay(1500);
  }

  return null;
}

/**
 * Extract a venue name from an event title.
 * Matches patterns like "Storytime at Irvine Library" → "Irvine Library"
 * or "Music at the Park" → "the Park"
 */
function extractVenueFromTitle(title: string): string | null {
  // "at <Venue>" pattern
  const atMatch = title.match(
    /\bat\s+(?:the\s+)?([A-Z][A-Za-z'\-& ]{2,40}(?:Park|Museum|Center|Centre|Library|Hall|Arena|Stadium|Theater|Theatre|Zoo|Garden|Gallery|Church|School|Academy|Farm|Ranch|Beach|Pool|Pavilion|Plaza|Square)?)/i
  );
  if (atMatch) return atMatch[1].trim();

  // "Venue: <Name>" pattern
  const colonMatch = title.match(
    /(?:venue|location|place|where):\s*([A-Z][A-Za-z'\-& ]{2,40})/i
  );
  if (colonMatch) return colonMatch[1].trim();

  // "– Venue Name" or "- Venue Name" (after dash)
  const dashMatch = title.match(
    /[–—-]\s*([A-Z][A-Za-z'\-& ]{2,40}(?:Park|Museum|Center|Centre|Library|Hall|Arena|Stadium|Theater|Theatre|Zoo|Garden|Gallery|Church|School|Farm|Ranch))/
  );
  if (dashMatch) return dashMatch[1].trim();

  return null;
}

/** Metro area bounding boxes (rough, generous) for sanity-checking geocoded results. */
const METRO_BOUNDS: Record<
  string,
  { latMin: number; latMax: number; lonMin: number; lonMax: number }
> = {
  "los-angeles": { latMin: 33.5, latMax: 34.5, lonMin: -118.9, lonMax: -117.5 },
  "orange-county": { latMin: 33.3, latMax: 34.0, lonMin: -118.2, lonMax: -117.3 },
  "new-york": { latMin: 40.4, latMax: 41.2, lonMin: -74.5, lonMax: -73.5 },
  dallas: { latMin: 32.4, latMax: 33.4, lonMin: -97.5, lonMax: -96.3 },
  chicago: { latMin: 41.5, latMax: 42.2, lonMin: -88.2, lonMax: -87.3 },
  atlanta: { latMin: 33.4, latMax: 34.2, lonMin: -84.8, lonMax: -83.8 },
};

/** Verify a geocoded result is within a reasonable distance of the metro area. */
function isReasonableLocation(
  result: { latitude: number; longitude: number },
  metro: string
): boolean {
  const bounds = METRO_BOUNDS[metro];
  if (!bounds) return true; // Unknown metro — accept anything in the US

  // Allow some slack beyond the strict bounds (±0.5 degrees ≈ 35 miles)
  const SLACK = 0.5;
  return (
    result.latitude >= bounds.latMin - SLACK &&
    result.latitude <= bounds.latMax + SLACK &&
    result.longitude >= bounds.lonMin - SLACK &&
    result.longitude <= bounds.lonMax + SLACK
  );
}

function getStateForMetro(metro: string): string | null {
  switch (metro) {
    case "los-angeles":
    case "orange-county":
      return "CA";
    case "new-york":
      return "NY";
    case "dallas":
      return "TX";
    case "chicago":
      return "IL";
    case "atlanta":
      return "GA";
    default:
      return null;
  }
}

// ─── Google Places API (New) lookup ──────────────────────────────────────────

interface PlacesSearchResponse {
  places?: Array<{
    location?: { latitude: number; longitude: number };
    formattedAddress?: string;
    displayName?: { text: string };
    photos?: Array<{ name: string }>;
  }>;
}

/**
 * Look up a venue using Google Places API (New) Text Search.
 * Returns coordinates + formatted address + venue photo URL, or null if not found.
 *
 * More reliable than Nominatim for business/venue names because Google Maps
 * has comprehensive business data including hours, addresses, and photos.
 *
 * @param expectedCity - If provided, rejects results whose address doesn't contain
 *   this city name. Prevents "Tustin event → Irvine address" mismatches where
 *   Google returns a nearby city that passes the metro bounding-box check.
 */
async function lookupGooglePlaces(
  query: string,
  metro: string,
  expectedCity?: string
): Promise<{ latitude: number; longitude: number; address?: string; photoUrl?: string } | null> {
  if (!config.googlePlaces.apiKey) return null;

  try {
    const res = await fetch(`${config.googlePlaces.baseUrl}/places:searchText`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": config.googlePlaces.apiKey,
        "X-Goog-FieldMask": "places.location,places.formattedAddress,places.displayName,places.photos",
      },
      body: JSON.stringify({ textQuery: query }),
    });

    if (!res.ok) {
      if (res.status === 403) {
        log.warn("geocode", `Google Places API key unauthorized (403). Check key + API enabled.`);
      }
      return null;
    }

    const data = (await res.json()) as PlacesSearchResponse;
    const place = data.places?.[0];

    if (!place?.location) return null;

    // City validation: if we know which city the event is in, reject results
    // that map to a different city. Prevents e.g. "Tustin event → Irvine address"
    // which passes the metro bounding-box check but is geographically wrong.
    if (expectedCity && place.formattedAddress) {
      const normalizedAddr = place.formattedAddress.toLowerCase();
      const normalizedCity = expectedCity.toLowerCase();
      if (!normalizedAddr.includes(normalizedCity)) {
        return null; // Wrong city — let caller try next query variant
      }
    }

    const result = {
      latitude: place.location.latitude,
      longitude: place.location.longitude,
      address: place.formattedAddress,
    };

    // Validate the result is within the metro bounds
    if (!isReasonableLocation(result, metro)) return null;

    // Fetch Google Places venue photo (free, high quality, event/venue specific)
    // Uses Places Photos API — same key as text search, no extra quota cost.
    let photoUrl: string | undefined;
    if (place.photos?.[0]?.name) {
      try {
        const photoRes = await fetch(
          `https://places.googleapis.com/v1/${place.photos[0].name}/media?maxWidthPx=1200&skipHttpRedirect=true&key=${config.googlePlaces.apiKey}`
        );
        if (photoRes.ok) {
          const photoData = (await photoRes.json()) as { photoUri?: string };
          if (photoData.photoUri) photoUrl = photoData.photoUri;
        }
      } catch {
        // Photo is a nice-to-have — never fail geocoding because of it
      }
    }

    return { ...result, photoUrl };
  } catch {
    return null;
  }
}

// ─── Main export ─────────────────────────────────────────────────────────────

/**
 * Geocode events that are missing valid coordinates.
 *
 * Modifies events in place, adding latitude/longitude (and optionally address)
 * where the geocoder succeeds.
 *
 * @param events - All pipeline events (after deduplication)
 * @returns The same array with coordinates filled in where possible
 */
export async function geocodeEvents(
  events: PipelineEvent[]
): Promise<PipelineEvent[]> {
  // Find events that need geocoding
  const needsGeocode = events.filter((e) => !hasValidCoords(e));

  if (needsGeocode.length === 0) {
    log.info("geocode", "All events already have valid coordinates ✓");
    return events;
  }

  const totalEvents = events.length;
  const withCoords = totalEvents - needsGeocode.length;

  log.info(
    "geocode",
    `${needsGeocode.length}/${totalEvents} events need geocoding (${withCoords} already have coords)`
  );

  // Deduplicate by location key to avoid redundant geocode calls.
  // Many events share the same venue — geocode once, apply to all.
  type LocationKey = string;
  const locationGroups = new Map<LocationKey, PipelineEvent[]>();

  for (const event of needsGeocode) {
    // Group by venue+city or address+city for deduplication
    const key = [
      event.locationName || "",
      event.address || "",
      event.city || "",
      event.metro,
    ]
      .join("|")
      .toLowerCase();
    const group = locationGroups.get(key) || [];
    group.push(event);
    locationGroups.set(key, group);
  }

  const uniqueLocations = locationGroups.size;
  log.info(
    "geocode",
    `${uniqueLocations} unique locations to geocode (deduplicated from ${needsGeocode.length} events)`
  );

  let geocoded = 0;
  let failed = 0;
  let processed = 0;

  for (const [, group] of locationGroups) {
    const representative = group[0]; // Use first event as the geocode target
    processed++;

    if (processed % 25 === 0) {
      log.info(
        "geocode",
        `  Progress: ${processed}/${uniqueLocations} locations (${geocoded} resolved)`
      );
    }

    const result = await geocodeEvent(representative);

    if (result) {
      // Apply coordinates (and venue photo) to ALL events in this location group
      for (const event of group) {
        event.latitude = result.latitude;
        event.longitude = result.longitude;
        // Only fill address if event didn't have one and we found one
        if (!event.address && result.address) {
          event.address = result.address;
        }
        // Use Google Places venue photo only when:
        //  1. Event has no image yet, AND
        //  2. Event does NOT have a specific event-page websiteURL
        //     (if it does, the og:image step will fetch a better event-specific
        //     promotional image — e.g. Bluey show poster, Eggstravaganza eggs —
        //     instead of a random user-uploaded venue photo from Google Maps)
        const hasEventPageURL = event.websiteURL &&
          !event.websiteURL.includes("google.com/search") &&
          !event.websiteURL.includes("mommypoppins.com") &&
          !event.websiteURL.includes("macaronikid.com");
        if (result.photoUrl && !event.imageURL && !hasEventPageURL) {
          event.imageURL = result.photoUrl;
        }
      }
      geocoded++;
    } else {
      failed++;
    }
  }

  // Also fix events that have obviously wrong coordinates (0,0 or out-of-bounds)
  let corrected = 0;
  for (const event of events) {
    if (
      event.latitude != null &&
      event.longitude != null &&
      !hasValidCoords(event)
    ) {
      // Clear invalid coordinates so CloudKit doesn't store 0,0
      event.latitude = undefined;
      event.longitude = undefined;
      corrected++;
    }
  }

  const totalGeocoded = geocoded;
  const eventsFixed = needsGeocode.filter((e) => hasValidCoords(e)).length;

  log.divider();
  log.info("geocode", `Geocoding complete:`);
  log.info(
    "geocode",
    `  ${totalGeocoded}/${uniqueLocations} unique locations resolved`
  );
  log.info("geocode", `  ${eventsFixed} events now have coordinates`);
  if (corrected > 0) {
    log.info(
      "geocode",
      `  ${corrected} events had invalid coords cleared (0,0 or out-of-bounds)`
    );
  }
  log.info(
    "geocode",
    `  ${failed} locations could not be geocoded (will show at city level in app)`
  );

  const finalWithCoords = events.filter((e) => hasValidCoords(e)).length;
  log.success(
    "geocode",
    `Coverage: ${finalWithCoords}/${totalEvents} events (${Math.round((finalWithCoords / totalEvents) * 100)}%) have valid coordinates`
  );

  return events;
}
