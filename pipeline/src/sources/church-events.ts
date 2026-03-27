/**
 * church-events.ts — Direct church community event scrapers
 *
 * Fetches family-oriented community events from major OC/LA churches.
 * Only includes children-oriented, universally welcoming events (egg hunts,
 * fall festivals, VBS, kids camps, community outreach). Excludes worship
 * services, Bible studies, prayer groups, and other religion-focused events.
 *
 * Churches covered:
 *  - Mariners Church (Rock RMS JSON API)
 *  - Saddleback Church (Azure REST API)
 *  - Rock Harbor (Squarespace HTML)
 *  - Oceans Church (Squarespace HTML)
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

// ─── Church Family Event Filters ──────────────────────────────────────────────

/** Patterns that indicate a religious service/study (not a community event) */
const RELIGIOUS_EXCLUDE_PATS = [
  /\b(worship|church|sunday)\s+service/i,
  /\bbible\s+stud(y|ies)\b/i,
  /\bprayer\s+(group|meeting|call|chain|night|gathering)/i,
  /\bsermon\s+series\b/i,
  /\bbaptism\s+(class|prep)/i,
  /\b(men'?s|women'?s)\s+(ministry|fellowship|group|study|bible)/i,
  /\brecovery\s+(group|ministry|program|meeting)/i,
  /\bcelebrate\s+recovery\b/i,
  /\bmission\s+trip\b/i,
  /\b(adult|senior)\s+retreat\b/i,
  /\bcollege\s+(dinner|ministry|group|night)\b/i,
  /\byoung\s+adult\s+(group|night|service|ministry)\b/i,
  /\bdevotional\b/i,
  /\bconfirmation\s+class\b/i,
  /\bcommunion\b/i,
  /\bliturgy\b/i,
  /\bgriefshare\b/i,
  /\bgrief\s+support\b/i,
  /\bdivorcecare\b/i,
  /\bfinancial\s+peace\b/i,
  /\bmarriage\s+(counseling|ministry|enrichment)\b/i,
  /\bdoor\s+hanger\s+walk\b/i,
  /\bvolunteer\s+training\b/i,
  /\bleadership\s+(training|meeting|summit)\b/i,
  /\bstaff\s+meeting\b/i,
  /\bnewcomers?\s+(class|lunch|dinner)\b/i,
  /\bmembership\s+class\b/i,
  // Recurring weekly church programs (not special events)
  /\bsmall\s+group/i,
  /\blife\s+group/i,
  /\bvolunteer\s+orientation\b/i,
  /\bvolunteer\s+training\b/i,
  /\bopen\s+share\b/i,
  /\bdivorce\s+care\b/i,
  /\besl\b/i,
  /\benglish\s+as\s+a\s+second/i,
  /\bline\s+dancing\b/i,
  /\blongevity\s+fitness\b/i,
  /\bweekly\s+prayer\b/i,
  /\bfood\s+pantry\s+serve\b/i,
  /\bneighborhood\s+walk\b/i,
  // Worship and services
  /\bsaturday\s+nights?\s+at\b/i,
  /\bsunday\s+morning\b/i,
  // Newcomer/member events
  /\bwelcome\s+to\s+\w+\b/i,
  /\bchild\s+dedication\b/i,
  // Adult-focused
  /\b(women'?s|men'?s)\s+(retreat|tea|spring|fall|breakfast|bbq|luncheon)/i,
  /\bseniors?\s+(on.campus|community|luncheon|group)\b/i,
  /\bempowerment\s+study\b/i,
  /\bcouples'?\s+night\b/i,
  /\bseder\s+meal\b/i,
  /\bpassover\b/i,
  /\bhuddle\b/i,
  /\btownhall\s+meeting\b/i,
  /\bbaptism\s+at\b/i,
  /\bactivate\b/i,
  /\bsing.a.long\b/i,
  /\bnew\s+admins?\b/i,
  /\bcoaches?\s+information\b/i,
  /\bextensions?\s+experiment\b/i,
  /\bsaturday\s+nights?\s+with\b/i,
  /\bhome\s+build\s+faith\b/i,
  /\bfaith\s+adventure\b/i,
  /\bbackyard\s+bbq\b/i,
  /\bsaddleback\s+women\b/i,
  /\bwednesday\s+pm\b/i,
  /\bcelebrating\s+\d+\s+years\b/i,
  /\bspring\s+brunch\b/i,
  /\bactiva\b/i,
  /\brevival\b/i,
  /\bbaptize\b/i,
  /\bcollege\s+preview\b/i,
  /\bpreview\s+day\b/i,
  /\bworship\s+night\b/i,
  /\bgood\s+friday\b/i,
  /\beaster\s+sunday\b/i,
  /\bdiscipleship\b/i,
  /\bmosaic\s+houses\b/i,
  /\bmen'?s\s+\d+\s+hour\b/i,
  /\byouth\s+night\b/i,
  /\bcouple'?s\s+dinner\b/i,
  /\binternship\b/i,
  /\bfreedom\s+night\b/i,
  /\bvocational\s+group/i,
  /\bcommunity\s+group\s+leader/i,
  /\bregional\s+prayer\b/i,
  /\bnew\s+at\s+reality/i,
  /\beaster\s+baptism/i,
];

/** Returns true if the event title/description looks like a religious service */
function isReligiousService(title: string, description: string): boolean {
  const text = `${title} ${description}`;
  return RELIGIOUS_EXCLUDE_PATS.some((p) => p.test(text));
}

/** Audience values that indicate kids/family events for Mariners API */
const FAMILY_AUDIENCES = new Set([
  "kids", "children", "elementary", "preschool", "families", "family",
  "students", "youth", "junior high", "high school", "nursery",
  "toddlers", "infants", "parents", "moms", "dads",
]);

/** Check if a Mariners event targets family audiences */
function hasFamilyAudience(audiences: Array<{ Value: string }>): boolean {
  return audiences.some((a) =>
    FAMILY_AUDIENCES.has(a.Value.toLowerCase())
  );
}

// Saddleback category IDs for family-relevant events (from API response)
const SADDLEBACK_FAMILY_CATEGORIES = new Set([
  7,  // Kids & Students
  6,  // Gatherings (community events)
  1,  // Activate (outreach)
]);

// ─── Main Entry Point ─────────────────────────────────────────────────────────

export async function fetchChurchEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  const allEvents: PipelineEvent[] = [];

  const scrapers: Array<{
    name: string;
    metros: string[];
    fn: () => Promise<PipelineEvent[]>;
  }> = [
    { name: "Mariners Church", metros: ["orange-county"], fn: scrapeMarinersChurch },
    { name: "Saddleback Church", metros: ["orange-county", "los-angeles"], fn: scrapeSaddlebackChurch },
    { name: "Rock Harbor", metros: ["orange-county"], fn: scrapeRockHarbor },
    { name: "Oceans Church", metros: ["orange-county"], fn: scrapeOceansChurch },
    { name: "Mosaic Church", metros: ["los-angeles"], fn: scrapeMosaicChurch },
    { name: "Reality LA", metros: ["los-angeles"], fn: scrapeRealityLA },
  ];

  const applicable = scrapers.filter((s) => s.metros.includes(metro.id));
  if (applicable.length === 0) return [];

  log.info("churches", `Running ${applicable.length} church scrapers for ${metro.name}...`);

  for (const { name, fn } of applicable) {
    try {
      const events = await fn();
      if (events.length > 0) {
        log.info("churches", `  ${name}: ${events.length} events`);
        allEvents.push(...events);
      } else {
        log.info("churches", `  ${name}: 0 events`);
      }
    } catch (err) {
      log.warn("churches", `  ${name} failed: ${err}`);
    }
    await delay(500);
  }

  log.success("churches", `Total: ${allEvents.length} church community events for ${metro.name}`);
  return allEvents;
}

// ─── Mariners Church (Rock RMS JSON API) ──────────────────────────────────────
// https://www.marinerschurch.org/wp-content/themes/mariners/rockcms/events/

interface MarinersEvent {
  EventItemOccurrenceId: number;
  EventItemId: number;
  Name: string;
  Campus: string;
  CampusId: number;
  Location: string;
  LocationDescription: string;
  Summary: string;
  Description: string;
  FriendlyScheduleText: string;
  Image: {
    Url: string;
    FileName?: string;
  } | null;
  EventDates: Array<{
    StartDateTime: string;
    EndDateTime: string;
  }>;
  Linkages: Array<{
    Message: string;
    RegistrationUrl: string;
    IsActive: boolean;
  }>;
  Audiences: Array<{ Value: string }>;
  Schedule?: {
    FriendlyScheduleText: string;
    EffectiveStartDate: string;
    EffectiveEndDate: string | null;
    IsActive: boolean;
  };
}

// Map Mariners campus names to cities
const MARINERS_CAMPUS_CITIES: Record<string, string> = {
  "Irvine": "Irvine",
  "Huntington Beach": "Huntington Beach",
  "Oceanside": "Oceanside",
  "San Juan Capistrano": "San Juan Capistrano",
  "Santa Ana": "Santa Ana",
  "Online": "",
};

async function scrapeMarinersChurch(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const maxDate = sixtyDaysFromNow();

  const res = await fetch(
    "https://www.marinerschurch.org/wp-content/themes/mariners/rockcms/events/",
    { headers: { ...getRandomHeaders(), Accept: "application/json" } }
  );

  if (!res.ok) {
    log.warn("churches", `Mariners HTTP ${res.status}`);
    return [];
  }

  const data = (await res.json()) as MarinersEvent[];
  if (!Array.isArray(data)) return [];

  for (const raw of data) {
    // Skip events without dates
    if (!raw.EventDates || raw.EventDates.length === 0) continue;

    // Skip online-only events
    if (raw.Campus === "Online" || raw.LocationDescription?.toLowerCase().includes("zoom")) continue;

    // Filter: must have family audience OR pass community event heuristic
    const hasAudience = raw.Audiences && raw.Audiences.length > 0;
    if (hasAudience && !hasFamilyAudience(raw.Audiences)) continue;

    // Filter out religious services
    const desc = stripHtml(raw.Description || raw.Summary || "");
    if (isReligiousService(raw.Name, desc)) continue;

    // Create an event for each occurrence date within our window
    for (const dateEntry of raw.EventDates) {
      if (!isFutureDate(dateEntry.StartDateTime)) continue;
      if (new Date(dateEntry.StartDateTime) > maxDate) continue;

      const city = MARINERS_CAMPUS_CITIES[raw.Campus] || raw.Campus || "Irvine";
      if (!city) continue; // skip online

      const cleanDesc = cleanDescription(desc);
      const registrationUrl = raw.Linkages?.find((l) => l.IsActive && l.RegistrationUrl)
        ?.RegistrationUrl;
      const websiteURL = registrationUrl
        ? `https://www.marinerschurch.org/events/?EventOccurrenceID=${raw.EventItemOccurrenceId}`
        : `https://www.marinerschurch.org/events/`;

      events.push({
        sourceId: `church-mariners:${raw.EventItemOccurrenceId}-${dateEntry.StartDateTime.split("T")[0]}`,
        source: "church-mariners",
        title: raw.Name,
        description: cleanDesc,
        startDate: dateEntry.StartDateTime,
        endDate: dateEntry.EndDateTime || undefined,
        isAllDay: false,
        category: categorizeEvent(raw.Name, cleanDesc, []),
        city,
        locationName: raw.LocationDescription
          ? `Mariners Church ${raw.Campus} - ${raw.LocationDescription}`
          : `Mariners Church ${raw.Campus}`,
        externalURL: websiteURL,
        websiteURL,
        imageURL: raw.Image?.Url || undefined,
        isFeatured: false,
        isRecurring: raw.EventDates.length > 1 || raw.FriendlyScheduleText?.startsWith("Weekly"),
        tags: [],
        metro: "orange-county",
      });
    }
  }

  return events;
}

// ─── Saddleback Church (Azure REST API) ───────────────────────────────────────
// https://hc.saddleback.com/api/v4/events

interface SaddlebackEvent {
  id: number;
  eventItemOccurrenceId?: number;
  name: string;
  publicName?: string;
  summary?: string;
  description?: string;
  categoryId: number;
  categoryName?: string;
  campusId?: number;
  campusName?: string;
  location?: string;
  locationDetail?: {
    latitude?: number;
    longitude?: number;
    address1?: string;
    city?: string;
    region?: string;
    postalCode?: string;
  };
  photoUrl?: string;
  childCareAvailable?: boolean;
  isPaid?: boolean;
  cost?: number;
  registrationUrl?: string;
  occurrence?: {
    date?: string;
    localStartDateTime?: string;
    localEndDateTime?: string;
  };
  contactInfo?: {
    contactName?: string;
    contactEmail?: string;
    contactPhone?: string;
  };
  slug?: string;
}

interface SaddlebackDayGroup {
  date: string;
  events: SaddlebackEvent[];
}

// OC campus IDs for Saddleback
const SADDLEBACK_OC_CAMPUSES = new Set([
  2,  // Anaheim
  9,  // Irvine North
  10, // Irvine South
  12, // Lake Forest
  14, // San Clemente
  21, // Rancho Capistrano
]);

// LA-area campus IDs for Saddleback
const SADDLEBACK_LA_CAMPUSES = new Set([
  13, // Los Angeles
  22, // Whittier
]);

async function scrapeSaddlebackChurch(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const now = new Date();
  const endDate = sixtyDaysFromNow();

  const startStr = now.toISOString().split("T")[0] + "T00:00:00-07:00";
  const endStr = endDate.toISOString().split("T")[0] + "T23:59:59-07:00";

  try {
    // Fetch all events (API ignores categoryId filter — we filter client-side)
    const url = `https://hc.saddleback.com/api/v4/events?pageNumber=0&pageSize=500&startDate=${encodeURIComponent(startStr)}&endDate=${encodeURIComponent(endStr)}&groupByDay=true`;

    const res = await fetch(url, {
      headers: { ...getRandomHeaders(), Accept: "application/json" },
    });

    if (!res.ok) {
      log.warn("churches", `Saddleback HTTP ${res.status}`);
      return [];
    }

    // Response is an array of { date, events[] } objects
    const data = (await res.json()) as SaddlebackDayGroup[];
    if (!Array.isArray(data)) return [];

    for (const dayGroup of data) {
      if (!dayGroup.events || !Array.isArray(dayGroup.events)) continue;

      for (const raw of dayGroup.events) {
        // Filter to family-relevant categories
        if (raw.categoryId !== null && !SADDLEBACK_FAMILY_CATEGORIES.has(raw.categoryId)) continue;

        const title = raw.publicName || raw.name;
        if (!title) continue;

        const desc = stripHtml(raw.description || raw.summary || "");

        // Filter out religious services
        if (isReligiousService(title, desc)) continue;

        // Skip online/virtual events
        if (raw.isVirtual) continue;
        if (raw.location?.toLowerCase().includes("online") ||
            raw.location?.toLowerCase().includes("zoom")) continue;

        // Skip non-SoCal campuses
        const campus = raw.campusName?.toLowerCase() || "";
        if (campus.includes("hong kong") || campus.includes("berlin") ||
            campus.includes("buenos aires") || campus.includes("manila") ||
            campus.includes("santa rosa")) continue;

        const startDateTime = raw.occurrence?.localStartDateTime || raw.occurrence?.date || dayGroup.date;
        if (!startDateTime || !isFutureDate(startDateTime)) continue;

        const city = raw.locationDetail?.city || raw.campusName || "Lake Forest";
        const cleanDesc = cleanDescription(desc);

        const websiteURL = raw.slug
          ? `https://www.saddleback.com/events/${raw.slug}`
          : raw.registrationUrl || "https://www.saddleback.com/events";

        events.push({
          sourceId: `church-saddleback:${raw.id}-${startDateTime.split("T")[0]}`,
          source: "church-saddleback",
          title,
          description: cleanDesc,
          startDate: startDateTime,
          endDate: raw.occurrence?.localEndDateTime || undefined,
          isAllDay: false,
          category: categorizeEvent(title, cleanDesc, []),
          city,
          locationName: raw.location || `Saddleback Church ${raw.campusName || ""}`.trim(),
          address: raw.locationDetail
            ? `${raw.locationDetail.address1 || ""}, ${raw.locationDetail.city || ""}, ${raw.locationDetail.region || ""} ${raw.locationDetail.postalCode || ""}`.replace(/^,\s*/, "").trim()
            : undefined,
          latitude: raw.locationDetail?.latitude,
          longitude: raw.locationDetail?.longitude,
          externalURL: websiteURL,
          websiteURL,
          imageURL: raw.photoUrl || undefined,
          isFeatured: false,
          isRecurring: false,
          tags: [],
          metro: "orange-county", // metro assignment handled by reassign step
          price: raw.isPaid ? (raw.cost ? `$${raw.cost}` : undefined) : "Free",
          phone: raw.contactInfo?.contactPhone,
          contactEmail: raw.contactInfo?.contactEmail,
        });
      }
    }
  } catch (err) {
    log.warn("churches", `Saddleback failed: ${err}`);
  }

  // Dedup by sourceId (same event can appear in multiple day groups)
  const seen = new Set<string>();
  return events.filter((e) => {
    if (seen.has(e.sourceId)) return false;
    seen.add(e.sourceId);
    return true;
  });
}

// ─── Rock Harbor (Squarespace HTML) ───────────────────────────────────────────
// https://www.rockharbor.org/events/
// Uses .user-items-list-item-container with .list-item-content__title

async function scrapeRockHarbor(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://www.rockharbor.org/events/", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("churches", `Rock Harbor HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();
  const maxDate = sixtyDaysFromNow();

  // Rock Harbor embeds event data as JSON in data-current-context userItems attribute
  const contextMatches = html.matchAll(/data-current-context="([^"]*)"/gi);
  for (const cm of contextMatches) {
    try {
      const jsonStr = cm[1].replace(/&quot;/g, '"').replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
      const ctx = JSON.parse(jsonStr);
      if (!ctx.userItems || !Array.isArray(ctx.userItems)) continue;

      for (const item of ctx.userItems) {
        const title = stripHtml(item.title || "");
        if (!title || title.length < 5) continue;

        const desc = stripHtml(item.description || "");
        if (isReligiousService(title, desc)) continue;

        // Extract date from description text
        let startDate = "";
        const dateInDesc = desc.match(
          /(?:Date:\s*)?(\d{1,2}\/\d{1,2}(?:[-–]\d{1,2}\/\d{1,2})?(?:\/\d{2,4})?)/
        );
        if (dateInDesc) {
          const parsed = parseDateText(dateInDesc[1]);
          if (parsed) startDate = parsed;
        }
        if (!startDate) {
          const monthDate = desc.match(
            /\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:\s*[-–]\s*\d{1,2})?,?\s*(\d{4})?/i
          );
          if (monthDate) {
            const parsed = parseDateText(monthDate[0]);
            if (parsed) startDate = parsed;
          }
        }

        if (startDate && !isFutureDate(startDate)) continue;
        if (startDate && new Date(startDate) > maxDate) continue;

        const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").slice(0, 50);
        const eventUrl = item.buttonLink?.url
          ? (item.buttonLink.url.startsWith("http") ? item.buttonLink.url : `https://www.rockharbor.org${item.buttonLink.url}`)
          : "https://www.rockharbor.org/events/";

        events.push({
          sourceId: `church-rockharbor:${slug}`,
          source: "church-rockharbor",
          title,
          description: cleanDescription(desc),
          startDate: startDate || new Date().toISOString(),
          isAllDay: false,
          category: categorizeEvent(title, desc, []),
          city: "Costa Mesa",
          locationName: "Rock Harbor Church",
          externalURL: eventUrl,
          websiteURL: eventUrl,
          imageURL: item.image?.assetUrl || undefined,
          isFeatured: false,
          isRecurring: false,
          tags: [],
          metro: "orange-county",
        });
      }
    } catch {
      // Not a valid JSON context, skip
    }
  }

  return events;
}

// ─── Oceans Church (Squarespace HTML) ─────────────────────────────────────────
// https://oceanschurch.com/events
// Uses blog-basic-grid with h1 titles, .blog-excerpt descriptions

async function scrapeOceansChurch(): Promise<PipelineEvent[]> {
  const res = await fetch("https://oceanschurch.com/events", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("churches", `Oceans Church HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();
  return parseSquarespaceEvents(html, {
    source: "church-oceans",
    baseUrl: "https://oceanschurch.com",
    city: "Irvine",
    locationName: "Oceans Church",
    metro: "orange-county",
  });
}

// ─── Mosaic Church (Squarespace Event List) ──────────────────────────────────
// https://www.mosaic.org/events
// Uses Squarespace native .eventlist-event items with structured title/date/desc

async function scrapeMosaicChurch(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://www.mosaic.org/events", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("churches", `Mosaic Church HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();
  const maxDate = sixtyDaysFromNow();

  // Squarespace event list uses .eventlist-event with structured content
  const eventPattern = /<article[^>]*class="[^"]*eventlist-event[^"]*"[^>]*>([\s\S]*?)<\/article>/gi;
  let match;

  while ((match = eventPattern.exec(html)) !== null) {
    const block = match[1];

    // Title from .eventlist-title or h1/h2
    const titleMatch = block.match(/class="[^"]*eventlist-title[^"]*"[^>]*>\s*(?:<a[^>]*>)?\s*([^<]+)/)
      || block.match(/<h[1-3][^>]*>\s*(?:<a[^>]*>)?\s*([^<]+)/);
    if (!titleMatch) continue;
    const title = stripHtml(titleMatch[1].trim());
    if (!title || title.length < 5) continue;

    // Date from <time datetime="..."> or .eventlist-meta-date
    const dateAttrMatch = block.match(/<time[^>]*datetime="([^"]*)"/);
    const dateTextMatch = block.match(/class="[^"]*eventlist-meta-date[^"]*"[^>]*>([^<]*)/);
    let startDate = dateAttrMatch?.[1] || "";
    if (!startDate && dateTextMatch) {
      const parsed = parseDateText(dateTextMatch[1].trim());
      if (parsed) startDate = parsed;
    }

    if (startDate && !isFutureDate(startDate)) continue;
    if (startDate && new Date(startDate) > maxDate) continue;

    // Link
    const linkMatch = block.match(/href="(\/events\/[^"]*)"/);
    const eventUrl = linkMatch
      ? `https://www.mosaic.org${linkMatch[1]}`
      : "https://www.mosaic.org/events";

    // Image
    const imgMatch = block.match(/(?:src|data-src)="([^"]*(?:squarespace-cdn|jpg|jpeg|png|webp)[^"]*)"/i);

    // Description
    const descMatch = block.match(/class="[^"]*eventlist-description[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
    const desc = descMatch ? cleanDescription(stripHtml(descMatch[1])) : "";

    // Filter out religious services
    if (isReligiousService(title, desc)) continue;

    const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").slice(0, 50);

    events.push({
      sourceId: `church-mosaic:${slug}`,
      source: "church-mosaic",
      title,
      description: desc,
      startDate: startDate || new Date().toISOString(),
      isAllDay: false,
      category: categorizeEvent(title, desc, []),
      city: "Los Angeles",
      locationName: "Mosaic Church",
      externalURL: eventUrl,
      websiteURL: eventUrl,
      imageURL: imgMatch?.[1] || undefined,
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: "los-angeles",
    });
  }

  return events;
}

// ─── Reality LA (WordPress HTML) ──────────────────────────────────────────────
// https://realityla.com/upcoming/
// Events listed as structured blocks with date headers and descriptions

async function scrapeRealityLA(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  const res = await fetch("https://realityla.com/upcoming/", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("churches", `Reality LA HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();
  const maxDate = sixtyDaysFromNow();

  // Reality LA uses WordPress blocks with date headers followed by event titles
  // Pattern: date line (e.g., "SUN, APR 5, 9AM, 12PM, & 5PM") then h3/h4 title then description
  // Extract all heading + paragraph blocks

  // Find event blocks: look for date pattern followed by title
  const datePattern = /(?:SUN|MON|TUE|WED|THU|FRI|SAT),?\s+(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+\d{1,2}[^<]*/gi;

  // Parse the full HTML for structured event blocks
  // Reality LA pattern: Date line → Venue (ALL CAPS) → Event Title → (duplicate block) → Description
  const fullText = html.replace(/<[^>]+>/g, "\n").replace(/\n{2,}/g, "\n");
  const lines = fullText.split("\n").map((l) => l.trim()).filter(Boolean);

  // Track which date+title combos we've already processed (content is duplicated)
  const processed = new Set<string>();

  for (let i = 0; i < lines.length; i++) {
    // Look for date lines
    const dateMatch = lines[i].match(
      /^((?:SUN|MON|TUE|WED|THU|FRI|SAT),?\s+(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+\d{1,2})/i
    );
    if (!dateMatch) continue;

    // Pattern: +1 = venue (ALL CAPS), +2 = title (mixed case)
    if (i + 2 >= lines.length) continue;
    const venueLine = lines[i + 1];
    const titleLine = lines[i + 2];

    // Venue line should be ALL CAPS (location name)
    if (venueLine !== venueLine.toUpperCase()) continue;

    // Title should not be ALL CAPS (that would be another venue)
    const title = titleLine;
    if (!title || title.length < 5 || title.length > 100) continue;
    // Skip if title looks like a date, time, or "Learn More"
    if (/^(SUN|MON|TUE|WED|THU|FRI|SAT|BEGINNING|EVERY|LEARN)/i.test(title)) continue;
    // Skip if title is all caps (another venue name) or starts with a number (address)
    if (title === title.toUpperCase() && title.length < 40) continue;

    // Skip duplicates (each event appears twice in the HTML)
    const key = `${dateMatch[1]}:${title}`;
    if (processed.has(key)) continue;
    processed.add(key);

    // Get description — look for the next line after the duplicate block
    // Pattern: date → venue → title → date → venue → description → "Learn" → "More"
    let desc = "";
    for (let j = i + 3; j < Math.min(i + 8, lines.length); j++) {
      if (lines[j].length > 50 && lines[j] !== lines[j].toUpperCase() && !/^(SUN|MON|TUE|WED|THU|FRI|SAT)/i.test(lines[j])) {
        desc = lines[j];
        break;
      }
    }

    // Filter out religious services
    if (isReligiousService(title, desc)) continue;

    // Parse the date
    const parsed = parseDateText(dateMatch[1]);
    if (!parsed) continue;
    if (!isFutureDate(parsed)) continue;
    if (new Date(parsed) > maxDate) continue;

    const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").slice(0, 50);

    // Try to find a link for this event in the HTML
    const titleEscaped = title.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const linkMatch = html.match(new RegExp(`href="([^"]*)"[^>]*>[^<]*${titleEscaped}`, "i"))
      || html.match(new RegExp(`${titleEscaped}[^<]*<\\/a>[\\s\\S]*?href="([^"]*)"`, "i"));

    const eventUrl = linkMatch
      ? (linkMatch[1].startsWith("http") ? linkMatch[1] : `https://realityla.com${linkMatch[1]}`)
      : "https://realityla.com/upcoming/";

    events.push({
      sourceId: `church-realityla:${slug}`,
      source: "church-realityla",
      title,
      description: cleanDescription(desc),
      startDate: parsed,
      isAllDay: false,
      category: categorizeEvent(title, desc, []),
      city: "Los Angeles",
      locationName: "Reality LA",
      externalURL: eventUrl,
      websiteURL: eventUrl,
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: "los-angeles",
    });
  }

  // Dedup by title slug (same event can appear with multiple dates)
  const seen = new Set<string>();
  return events.filter((e) => {
    const key = e.sourceId;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// ─── Shared Squarespace Event Parser ──────────────────────────────────────────

interface SquarespaceOpts {
  source: string;
  baseUrl: string;
  city: string;
  locationName: string;
  metro: string;
}

function parseSquarespaceEvents(html: string, opts: SquarespaceOpts): PipelineEvent[] {
  const events: PipelineEvent[] = [];
  const maxDate = sixtyDaysFromNow();

  // Try multiple Squarespace patterns:
  // 1. user-items-list (Rock Harbor style)
  // 2. blog-basic-grid (Oceans Church style)
  // 3. article containers

  const blockPatterns = [
    /<li[^>]*class="[^"]*user-items-list-item-container[^"]*"[^>]*>([\s\S]*?)<\/li>/gi,
    // Squarespace blog grid (Oceans Church style)
    /<div[^>]*class="[^"]*blog-basic-grid--container[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>\s*<\/div>/gi,
    /<article[^>]*>([\s\S]*?)<\/article>/gi,
  ];

  const blocks: string[] = [];
  for (const pattern of blockPatterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) blocks.push(match[1]);
    if (blocks.length > 0) break;
  }

  for (const block of blocks) {
    // Extract title from h1-h4 or .list-item-content__title
    const titleMatch = block.match(/<h[1-4][^>]*>\s*(?:<a[^>]*>)?\s*([^<]+)/)
      || block.match(/class="[^"]*(?:list-item-content__title|blog-title)[^"]*"[^>]*>([^<]+)/);
    if (!titleMatch) continue;
    const title = stripHtml(titleMatch[1].trim());
    if (!title || title.length < 5) continue;

    // Skip generic navigation text or addresses
    if (/^(events?|home|about|contact|menu)$/i.test(title)) continue;
    if (/^\d+\s+\w+\s+(blvd|st|ave|dr|rd|ln|way|ct)\b/i.test(title)) continue;

    // Extract link
    const linkMatch = block.match(/href="(\/events\/[^"]*)"/);
    const eventUrl = linkMatch
      ? `${opts.baseUrl}${linkMatch[1]}`
      : `${opts.baseUrl}/events/`;

    // Extract date from datetime attr, text, or excerpt
    let startDate = "";
    const dateAttrMatch = block.match(/datetime="([^"]*)"/);
    if (dateAttrMatch) startDate = dateAttrMatch[1];

    // Try parsing date from excerpt text (e.g., "Date: 4/3-4/5" or "June 23-25")
    if (!startDate) {
      const excerptText = stripHtml(block);
      const dateInText = excerptText.match(
        /(?:Date:\s*)?(\d{1,2}\/\d{1,2}(?:[-–]\d{1,2}\/\d{1,2})?(?:\/\d{2,4})?)/
      );
      if (dateInText) {
        const parsed = parseDateText(dateInText[1]);
        if (parsed) startDate = parsed;
      }
      // Try month name format
      if (!startDate) {
        const monthDate = excerptText.match(
          /\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:\s*[-–]\s*\d{1,2})?,?\s*(\d{4})?/i
        );
        if (monthDate) {
          const parsed = parseDateText(monthDate[0]);
          if (parsed) startDate = parsed;
        }
      }
    }

    if (startDate && !isFutureDate(startDate)) continue;
    if (startDate && new Date(startDate) > maxDate) continue;

    // Extract image
    const imgMatch = block.match(/(?:src|data-src)="([^"]*(?:jpg|jpeg|png|webp)[^"]*)"/i);

    // Extract description from excerpt or description class
    const descMatch = block.match(
      /class="[^"]*(?:list-item-content__description|blog-excerpt|description|excerpt)[^"]*"[^>]*>([\s\S]*?)<\/(?:p|div|span)>/i
    );
    const desc = descMatch ? cleanDescription(stripHtml(descMatch[1])) : "";

    // Filter out religious services
    if (isReligiousService(title, desc)) continue;

    const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").slice(0, 50);

    events.push({
      sourceId: `${opts.source}:${slug}`,
      source: opts.source,
      title,
      description: desc,
      startDate: startDate || new Date().toISOString(),
      isAllDay: false,
      category: categorizeEvent(title, desc, []),
      city: opts.city,
      locationName: opts.locationName,
      externalURL: eventUrl,
      websiteURL: eventUrl,
      imageURL: imgMatch?.[1] || undefined,
      isFeatured: false,
      isRecurring: false,
      tags: [],
      metro: opts.metro,
    });
  }

  return events;
}

// ─── Date Parsing Helper ──────────────────────────────────────────────────────

/** Parse human-readable date text like "Apr 3-5, 2026" or "March 28, 2026" */
function parseDateText(text: string): string | null {
  const cleaned = text.trim();

  // "Month Day, Year" or "Month Day-Day, Year"
  const mdyMatch = cleaned.match(
    /(\w+)\s+(\d{1,2})(?:\s*[-–]\s*\d{1,2})?,?\s*(\d{4})/
  );
  if (mdyMatch) {
    const [, month, day, year] = mdyMatch;
    const d = new Date(`${month} ${day}, ${year}`);
    if (!isNaN(d.getTime())) return d.toISOString();
  }

  // "Month Day" (no year — assume current or next year)
  const mdMatch = cleaned.match(/(\w+)\s+(\d{1,2})/);
  if (mdMatch) {
    const [, month, day] = mdMatch;
    const now = new Date();
    let d = new Date(`${month} ${day}, ${now.getFullYear()}`);
    if (d < now) d = new Date(`${month} ${day}, ${now.getFullYear() + 1}`);
    if (!isNaN(d.getTime())) return d.toISOString();
  }

  return null;
}
