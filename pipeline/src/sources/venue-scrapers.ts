/**
 * venue-scrapers.ts — Direct venue/museum event scrapers
 *
 * Fetches events directly from venue websites instead of through aggregators
 * like MommyPoppins or OC Parent Guide. Each venue uses the simplest approach
 * available (REST API > iCal feed > __NEXT_DATA__ JSON > HTML parse).
 *
 * Venues covered:
 *  - Kidspace Children's Museum (WordPress REST API)
 *  - South Coast Plaza (iCal feed)
 *  - Academy Museum of Motion Pictures (__NEXT_DATA__ JSON)
 *  - Natural History Museum of LA (HTML parse)
 *  - Skirball Cultural Center (HTML parse)
 *  - Discovery Cube OC (HTML parse)
 *  - Underwood Family Farms (HTML parse)
 */

import { type MetroArea } from "../config.js";
import {
  type PipelineEvent,
  categorizeEvent,
  cleanDescription,
} from "../normalize.js";
import { log } from "../utils/logger.js";
import { delay } from "../utils/geocoder.js";
import { getRandomHeaders } from "../utils/user-agents.js";

// ─── Shared Helpers ───────────────────────────────────────────────────────────

function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function isFutureDate(dateStr: string): boolean {
  const d = new Date(dateStr);
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return d >= now;
}

function sixtyDaysFromNow(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 60);
  return d;
}

// ─── Main Entry Point ─────────────────────────────────────────────────────────

/**
 * Fetch events from all venue scrapers for the given metro.
 */
export async function fetchVenueEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const allEvents: PipelineEvent[] = [];

  // Define which scrapers run for which metro
  const scrapers: Array<{
    name: string;
    metros: string[];
    fn: () => Promise<PipelineEvent[]>;
  }> = [
    { name: "Kidspace Museum", metros: ["los-angeles"], fn: scrapeKidspace },
    { name: "South Coast Plaza", metros: ["orange-county"], fn: scrapeSouthCoastPlaza },
    { name: "Academy Museum", metros: ["los-angeles"], fn: scrapeAcademyMuseum },
    // NHM LA and Skirball are now in museum-scrapers.ts
    { name: "Discovery Cube OC", metros: ["orange-county"], fn: () => scrapeDiscoveryCube("oc") },
    { name: "Discovery Cube LA", metros: ["los-angeles"], fn: () => scrapeDiscoveryCube("la") },
    { name: "Underwood Farms", metros: ["los-angeles"], fn: scrapeUnderwoodFarms },
  ];

  const applicable = scrapers.filter((s) => s.metros.includes(metro.id));
  if (applicable.length === 0) return [];

  log.info("venues", `Running ${applicable.length} venue scrapers for ${metro.name}...`);

  for (const { name, fn } of applicable) {
    try {
      const events = await fn();
      if (events.length > 0) {
        log.info("venues", `  ${name}: ${events.length} events`);
        allEvents.push(...events);
      }
    } catch (err) {
      log.warn("venues", `  ${name} failed: ${err}`);
    }
    await delay(500);
  }

  log.success("venues", `Total: ${allEvents.length} venue events for ${metro.name}`);
  return allEvents;
}

// ─── Kidspace Children's Museum (WordPress REST API) ──────────────────────────
// https://kidspacemuseum.org/wp-json/tribe/events/v1/events

async function scrapeKidspace(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const today = new Date().toISOString().split("T")[0];
  const endDate = sixtyDaysFromNow().toISOString().split("T")[0];

  let page = 1;
  let totalPages = 1;

  while (page <= totalPages && page <= 5) {
    const url = `https://kidspacemuseum.org/wp-json/tribe/events/v1/events?start_date=${today}&end_date=${endDate}&per_page=50&page=${page}`;

    try {
      const res = await fetch(url, {
        headers: { ...getRandomHeaders(), Accept: "application/json" },
      });

      if (!res.ok) {
        if (page === 1) log.warn("venues", `Kidspace HTTP ${res.status}`);
        break;
      }

      const data = await res.json() as {
        events: Array<{
          id: number;
          title: string;
          description: string;
          url: string;
          start_date: string;
          end_date: string;
          all_day: boolean;
          cost: string;
          image?: { url: string };
          venue?: {
            venue: string;
            address: string;
            city: string;
            state: string;
            zip: string;
          };
          categories?: Array<{ name: string }>;
        }>;
        total_pages?: number;
      };

      if (!data.events || data.events.length === 0) break;

      totalPages = data.total_pages || 1;

      for (const raw of data.events) {
        const desc = cleanDescription(stripHtml(raw.description || ""));
        events.push({
          sourceId: `kidspace:${raw.id}`,
          source: "venue-kidspace",
          title: raw.title,
          description: desc,
          startDate: raw.start_date,
          endDate: raw.end_date || undefined,
          isAllDay: raw.all_day ?? false,
          category: categorizeEvent(raw.title, desc, []),
          city: raw.venue?.city || "Pasadena",
          locationName: raw.venue?.venue || "Kidspace Children's Museum",
          address: raw.venue ? `${raw.venue.address}, ${raw.venue.city}, ${raw.venue.state} ${raw.venue.zip}` : undefined,
          externalURL: raw.url,
          websiteURL: raw.url,
          imageURL: raw.image?.url,
          isFeatured: false,
          isRecurring: false,
          tags: [],
          metro: "los-angeles",
          price: raw.cost || undefined,
        });
      }

      page++;
      if (page <= totalPages) await delay(300);
    } catch (err) {
      log.warn("venues", `Kidspace page ${page} failed: ${err}`);
      break;
    }
  }

  return events;
}

// ─── South Coast Plaza (iCal Feed) ───────────────────────────────────────────
// https://www.southcoastplaza.com/?feed=eo-events

async function scrapeSouthCoastPlaza(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://www.southcoastplaza.com/?feed=eo-events", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("venues", `South Coast Plaza HTTP ${res.status}`);
    return [];
  }

  const icalText = await res.text();
  const parsed = parseICalSimple(icalText);

  // Non-family event keywords to skip
  const SKIP_KEYWORDS = [
    "trunk show", "ready to wear", "runway", "fashion show",
    "wine tasting", "wine dinner", "cocktail", "happy hour",
    "bridal", "wedding", "engagement ring",
    "private event", "corporate", "networking",
    "black tie", "gala", "fundraiser",
  ];

  for (const evt of parsed) {
    if (!evt.summary || !evt.dtstart) continue;
    if (!isFutureDate(evt.dtstart)) continue;

    // Skip non-family events
    const combined = `${evt.summary} ${evt.description || ""}`.toLowerCase();
    if (SKIP_KEYWORDS.some((kw) => combined.includes(kw))) continue;

    const desc = cleanDescription(stripHtml(evt.description || ""));
    events.push({
      sourceId: `scp:${evt.uid || evt.summary.slice(0, 30)}`,
      source: "venue-southcoastplaza",
      title: evt.summary,
      description: desc,
      startDate: evt.dtstart,
      endDate: evt.dtend || undefined,
      isAllDay: evt.dtstart.length === 10, // date-only = all day
      category: categorizeEvent(evt.summary, desc, []),
      city: "Costa Mesa",
      locationName: evt.location || "South Coast Plaza",
      externalURL: evt.url || "https://www.southcoastplaza.com/calendar/",
      websiteURL: evt.url || "https://www.southcoastplaza.com/calendar/",
      imageURL: evt.imageURL,
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: "orange-county",
    });
  }

  return events;
}

/** Minimal iCal parser — extracts VEVENT blocks */
function parseICalSimple(text: string): Array<{
  uid?: string;
  summary?: string;
  description?: string;
  dtstart?: string;
  dtend?: string;
  location?: string;
  url?: string;
  imageURL?: string;
}> {
  const events: Array<Record<string, string>> = [];
  // Unfold continuation lines (RFC 5545: CRLF + space/tab = continuation)
  const unfolded = text.replace(/\r?\n[ \t]/g, "");
  const lines = unfolded.split(/\r?\n/);
  let current: Record<string, string> | null = null;

  for (const line of lines) {
    if (line === "BEGIN:VEVENT") {
      current = {};
    } else if (line === "END:VEVENT" && current) {
      events.push(current);
      current = null;
    } else if (current) {
      const colonIdx = line.indexOf(":");
      if (colonIdx > 0) {
        let key = line.slice(0, colonIdx).toLowerCase();
        const value = line.slice(colonIdx + 1);
        // Strip parameters (e.g., DTSTART;VALUE=DATE:20260401 → dtstart)
        const semiIdx = key.indexOf(";");
        const params = semiIdx > 0 ? key.slice(semiIdx) : "";
        if (semiIdx > 0) key = key.slice(0, semiIdx);

        if (key === "summary") current.summary = value;
        else if (key === "description") current.description = value.replace(/\\n/g, "\n").replace(/\\,/g, ",");
        else if (key === "dtstart") current.dtstart = icalDateToISO(value);
        else if (key === "dtend") current.dtend = icalDateToISO(value);
        else if (key === "location") current.location = value.replace(/\\,/g, ",");
        else if (key === "url") current.url = value;
        else if (key === "uid") current.uid = value;
        // ATTACH;FMTTYPE=image/jpeg:/wp-content/uploads/... → imageURL
        else if (key === "attach" && params.includes("image")) {
          const imgPath = value.startsWith("http") ? value : `https://www.southcoastplaza.com${value}`;
          current.imageURL = imgPath;
        }
      }
    }
  }

  return events;
}

/** Convert iCal date (20260401 or 20260401T093000) to ISO string */
function icalDateToISO(value: string): string {
  const clean = value.replace("Z", "");
  if (clean.length === 8) {
    // Date only: 20260401
    return `${clean.slice(0, 4)}-${clean.slice(4, 6)}-${clean.slice(6, 8)}`;
  }
  if (clean.length >= 15) {
    // DateTime: 20260401T093000
    return `${clean.slice(0, 4)}-${clean.slice(4, 6)}-${clean.slice(6, 8)}T${clean.slice(9, 11)}:${clean.slice(11, 13)}:${clean.slice(13, 15)}`;
  }
  return value;
}

// ─── Academy Museum (__NEXT_DATA__ JSON) ─────────────────────────────────────
// https://www.academymuseum.org/en/programs

async function scrapeAcademyMuseum(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://www.academymuseum.org/en/programs", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("venues", `Academy Museum HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();

  // Extract __NEXT_DATA__ JSON blob
  const match = html.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
  if (!match) {
    log.warn("venues", "Academy Museum: __NEXT_DATA__ not found");
    return [];
  }

  let nextData: any;
  try {
    nextData = JSON.parse(match[1]);
  } catch {
    log.warn("venues", "Academy Museum: Failed to parse __NEXT_DATA__");
    return [];
  }

  // Navigate the Contentful data structure
  const pageProps = nextData?.props?.pageProps;
  if (!pageProps) return [];

  const programs = pageProps.cfProgramsKeyedByTkId || {};
  const programList = Object.values(programs) as any[];
  const maxDate = sixtyDaysFromNow();

  for (const raw of programList) {
    try {
      if (raw.hideFromCalendar) continue;

      // Extract plain text title from rich text HTML
      const titleHtml = raw.programTitle?.html || raw.title?.html || "";
      const title = titleHtml.replace(/<[^>]+>/g, "").trim();
      if (!title) continue;

      // Dates are in activeStartDate/activeEndDate (ISO format)
      const startDate = raw.activeStartDate;
      if (!startDate) continue;

      const start = new Date(startDate);
      if (isNaN(start.getTime())) continue;
      if (!isFutureDate(startDate) || start > maxDate) continue;

      // Extract description — fields may be strings, HTML, or Contentful rich text objects
      const descSource = typeof raw.programTagline === "string"
        ? raw.programTagline
        : typeof raw.filmDescription1 === "string"
          ? raw.filmDescription1
          : "";
      const desc = cleanDescription(stripHtml(descSource));
      const slug = raw.slug || raw.sys?.id || title.toLowerCase().replace(/\s+/g, "-").slice(0, 40);
      const eventUrl = `https://www.academymuseum.org/en/programs/${slug}`;

      events.push({
        sourceId: `academy:${raw.sys?.id || slug}`,
        source: "venue-academy",
        title,
        description: desc,
        startDate: start.toISOString(),
        endDate: raw.activeEndDate ? new Date(raw.activeEndDate).toISOString() : undefined,
        isAllDay: false,
        category: categorizeEvent(title, desc, []),
        city: "Los Angeles",
        locationName: "Academy Museum of Motion Pictures",
        address: "6067 Wilshire Blvd, Los Angeles, CA 90036",
        latitude: 34.0628,
        longitude: -118.3589,
        externalURL: eventUrl,
        websiteURL: eventUrl,
        imageURL: raw.image?.url,
        isFeatured: false,
        isRecurring: false,
        tags: [],
        metro: "los-angeles",
      });
    } catch {
      // Skip malformed entries
    }
  }

  return events;
}

// ─── Natural History Museum of LA ─────────────────────────────────────────────
// Skipped: NHM uses complex Drupal Views with non-standard HTML structure.
// MommyPoppins already provides NHM events with real websiteURLs (nhm.org).
// TODO: Revisit if NHM exposes a JSON API or simpler calendar feed.

// ─── Skirball Cultural Center ────────────────────────────────────────────────
// Skipped: Skirball uses Drupal with AJAX-rendered calendar.
// MommyPoppins already provides Skirball events with real websiteURLs.
// TODO: Revisit if Skirball exposes a JSON API or iCal feed.

// ─── Discovery Cube OC + LA ─────────────────────────────────────────────────
// https://www.discoverycube.org/events/ (OC)
// https://www.discoverycube.org/la/events/ (LA)

const DISCOVERY_CUBE_LOCATIONS = {
  oc: {
    city: "Santa Ana",
    locationName: "Discovery Cube Orange County",
    address: "2500 N Main St, Santa Ana, CA 92705",
    latitude: 33.7823,
    longitude: -117.8675,
    metro: "orange-county",
    eventsUrl: "https://www.discoverycube.org/events/",
  },
  la: {
    city: "Los Angeles",
    locationName: "Discovery Cube Los Angeles",
    address: "11800 Foothill Blvd, Los Angeles, CA 91342",
    latitude: 34.2986,
    longitude: -118.3914,
    metro: "los-angeles",
    eventsUrl: "https://www.discoverycube.org/la/events/",
  },
} as const;

async function scrapeDiscoveryCube(location: "oc" | "la"): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const loc = DISCOVERY_CUBE_LOCATIONS[location];

  // Strategy 1: Try WP REST API first (more reliable than HTML parsing)
  try {
    const apiEvents = await scrapeDiscoveryCubeApi(location);
    if (apiEvents.length > 0) return apiEvents;
  } catch {
    // Fall through to HTML parsing
  }

  // Strategy 2: HTML parse fallback
  const res = await fetch(loc.eventsUrl, { headers: getRandomHeaders() });

  if (!res.ok) {
    log.warn("venues", `Discovery Cube ${location.toUpperCase()} HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();

  // Discovery Cube uses WordPress with custom event markup
  const articlePattern = /<article[^>]*>([\s\S]*?)<\/article>/g;
  let match;

  while ((match = articlePattern.exec(html)) !== null) {
    const card = match[1];

    const titleMatch = card.match(/<(?:h[1-4]|a)[^>]*>(?:<a[^>]*href="([^"]*)"[^>]*>)?\s*([^<]+)/);
    if (!titleMatch) continue;

    const href = titleMatch[1] || "";
    const title = titleMatch[2]?.trim();
    if (!title) continue;

    const dateMatch = card.match(/datetime="([^"]+)"/);
    const dateStr = dateMatch?.[1] || "";

    let startDate: string;
    if (dateStr) {
      const start = new Date(dateStr);
      if (isNaN(start.getTime()) || !isFutureDate(dateStr)) continue;
      if (start > sixtyDaysFromNow()) continue;
      startDate = start.toISOString();
    } else {
      continue;
    }

    const imgMatch = card.match(/src="([^"]*(?:jpg|jpeg|png|webp)[^"]*)"/i);
    const desc = cleanDescription(stripHtml(card));
    const fullUrl = href.startsWith("http") ? href : (href ? `https://www.discoverycube.org${href}` : loc.eventsUrl);

    events.push({
      sourceId: `discoverycube-${location}:${(href || title).replace(/[^a-z0-9]/gi, "-").slice(0, 60)}`,
      source: "venue-discoverycube",
      title,
      description: desc.slice(0, 300),
      startDate,
      isAllDay: false,
      category: categorizeEvent(title, desc, []),
      city: loc.city,
      locationName: loc.locationName,
      address: loc.address,
      latitude: loc.latitude,
      longitude: loc.longitude,
      externalURL: fullUrl,
      websiteURL: fullUrl,
      imageURL: imgMatch?.[1],
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: loc.metro,
    });
  }

  return events;
}

/** Try fetching Discovery Cube events via WordPress REST API */
async function scrapeDiscoveryCubeApi(location: "oc" | "la"): Promise<PipelineEvent[]> {
  const loc = DISCOVERY_CUBE_LOCATIONS[location];
  const events: PipelineEvent[] = [];

  let page = 1;
  let totalPages = 1;

  while (page <= totalPages && page <= 5) {
    const url = `https://www.discoverycube.org/wp-json/wp/v2/posts?per_page=50&page=${page}&_embed`;
    const res = await fetch(url, {
      headers: { ...getRandomHeaders(), Accept: "application/json" },
    });

    if (!res.ok) throw new Error(`WP REST API HTTP ${res.status}`);

    totalPages = parseInt(res.headers.get("X-WP-TotalPages") || "1", 10);

    const posts = (await res.json()) as Array<{
      id: number;
      date: string;
      title: { rendered: string };
      excerpt?: { rendered: string };
      link: string;
      _embedded?: {
        "wp:featuredmedia"?: Array<{ source_url: string }>;
      };
    }>;

    if (posts.length === 0) break;

    for (const post of posts) {
      const title = stripHtml(post.title.rendered || "");
      if (!title) continue;

      const postDate = new Date(post.date);
      if (isNaN(postDate.getTime()) || !isFutureDate(post.date)) continue;
      if (postDate > sixtyDaysFromNow()) continue;

      // Check if this post is related to the correct location
      const combinedText = `${title} ${post.excerpt?.rendered || ""}`.toLowerCase();
      if (location === "la" && !combinedText.includes("la") && !combinedText.includes("los angeles") && !combinedText.includes("sylmar")) continue;
      if (location === "oc" && (combinedText.includes("la location") || combinedText.includes("los angeles location"))) continue;

      const desc = cleanDescription(stripHtml(post.excerpt?.rendered || ""));
      const imageURL = post._embedded?.["wp:featuredmedia"]?.[0]?.source_url;

      events.push({
        sourceId: `discoverycube-${location}:${post.id}`,
        source: "venue-discoverycube",
        title,
        description: desc,
        startDate: postDate.toISOString(),
        isAllDay: false,
        category: categorizeEvent(title, desc, []),
        city: loc.city,
        locationName: loc.locationName,
        address: loc.address,
        latitude: loc.latitude,
        longitude: loc.longitude,
        externalURL: post.link,
        websiteURL: post.link,
        imageURL,
        isFeatured: false,
        isRecurring: false,
        tags: [],
        metro: loc.metro,
      });
    }

    page++;
    if (page <= totalPages) await delay(300);
  }

  return events;
}

// ─── Underwood Family Farms (HTML Parse) ─────────────────────────────────────
// https://www.underwoodfamilyfarms.com/events/

async function scrapeUnderwoodFarms(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://www.underwoodfamilyfarms.com/events/", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("venues", `Underwood Farms HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();

  // Underwood uses WordPress with Beaver Builder. Event cards are in the page.
  // Look for section/article/div patterns with event info
  const sectionPattern = /<(?:section|div)[^>]*class="[^"]*(?:event|fl-module)[^"]*"[^>]*>([\s\S]*?)(?=<(?:section|div)[^>]*class="[^"]*(?:event|fl-module)[^"]*"|$)/g;
  let match;

  // Also try a simpler approach: look for heading + date patterns
  const headingPattern = /<h[1-4][^>]*>\s*(?:<a[^>]*href="([^"]*)"[^>]*>)?\s*([^<]+?)(?:<\/a>)?\s*<\/h[1-4]>/g;
  let headMatch;
  const foundTitles = new Set<string>();

  while ((headMatch = headingPattern.exec(html)) !== null) {
    const href = headMatch[1] || "";
    const title = headMatch[2]?.trim();
    if (!title || title.length < 5) continue;
    if (foundTitles.has(title)) continue;

    // Check if it looks like an event (contains date-like info nearby)
    const context = html.slice(
      Math.max(0, headMatch.index - 100),
      headMatch.index + headMatch[0].length + 500
    );

    // Look for farm/event keywords
    if (!/farm|festival|harvest|easter|christmas|pumpkin|pick|berry|tomato|corn/i.test(context)) continue;

    foundTitles.add(title);

    const fullUrl = href.startsWith("http")
      ? href
      : href
        ? `https://www.underwoodfamilyfarms.com${href}`
        : "https://www.underwoodfamilyfarms.com/events/";

    const imgMatch = context.match(/src="([^"]*(?:jpg|jpeg|png|webp)[^"]*)"/i);
    const desc = cleanDescription(stripHtml(context));

    // Use today's date as placeholder — these are seasonal events
    events.push({
      sourceId: `underwood:${title.toLowerCase().replace(/[^a-z0-9]/g, "-").slice(0, 40)}`,
      source: "venue-underwood",
      title,
      description: desc.slice(0, 300),
      startDate: new Date().toISOString(),
      isAllDay: true,
      category: categorizeEvent(title, desc, []),
      city: "Moorpark",
      locationName: "Underwood Family Farms",
      address: "3370 Sunset Valley Rd, Moorpark, CA 93021",
      latitude: 34.2689,
      longitude: -118.8654,
      externalURL: fullUrl,
      websiteURL: fullUrl,
      imageURL: imgMatch?.[1],
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: "los-angeles",
    });
  }

  return events;
}
