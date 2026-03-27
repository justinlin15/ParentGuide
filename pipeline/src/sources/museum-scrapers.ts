/**
 * museum-scrapers.ts — Direct museum event scrapers for LA
 *
 * Fetches events directly from museum websites:
 *  - Natural History Museum of LA (Drupal HTML parse)
 *  - Skirball Cultural Center (Drupal Views AJAX)
 *
 * These replace MommyPoppins as the source for museum events.
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

// ─── Main Entry Point ────────────────────────────────────────────────────────

export async function fetchMuseumEvents(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "los-angeles") return [];

  const allEvents: PipelineEvent[] = [];

  const scrapers = [
    { name: "NHM LA", fn: scrapeNHM },
    { name: "Skirball", fn: scrapeSkirball },
    { name: "Autry Museum", fn: scrapeAutry },
  ];

  log.info("museums", `Running ${scrapers.length} museum scrapers for ${metro.name}...`);

  for (const { name, fn } of scrapers) {
    try {
      const events = await fn();
      if (events.length > 0) {
        log.info("museums", `  ${name}: ${events.length} events`);
        allEvents.push(...events);
      }
    } catch (err) {
      log.warn("museums", `  ${name} failed: ${err}`);
    }
    await delay(500);
  }

  log.success("museums", `Total: ${allEvents.length} museum events for ${metro.name}`);
  return allEvents;
}

// ─── Natural History Museum of LA ────────────────────────────────────────────
// https://nhm.org/calendar
//
// Strategy: Fetch the calendar page, extract /calendar/{slug} links,
// then fetch each event detail page for title, dates, price, description.

async function scrapeNHM(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];
  const slugs = new Set<string>();

  // Step 1: Fetch multiple calendar listing pages to find all event slugs
  // NHM uses Drupal — fetch current month + next 2 months, with pager variations
  const now = new Date();
  const monthUrls: string[] = ["https://nhm.org/calendar"];
  for (let i = 1; i <= 2; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() + i, 1);
    const ym = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    monthUrls.push(`https://nhm.org/calendar?month=${ym}`);
  }

  // For each month URL, also try Drupal pager (?page=0,1,2)
  const allUrls: string[] = [];
  for (const base of monthUrls) {
    allUrls.push(base);
    const sep = base.includes("?") ? "&" : "?";
    allUrls.push(`${base}${sep}page=1`);
    allUrls.push(`${base}${sep}page=2`);
  }

  for (const url of allUrls) {
    try {
      const calRes = await fetch(url, { headers: getRandomHeaders() });
      if (!calRes.ok) continue;

      const calHtml = await calRes.text();

      // Extract unique /calendar/ slugs (case-insensitive, broader char set)
      const slugRegex = /href="(\/calendar\/[a-zA-Z0-9_-]+)"/gi;
      let m;
      while ((m = slugRegex.exec(calHtml)) !== null) {
        slugs.add(m[1]);
      }

      await delay(200);
    } catch {
      // Skip failed calendar pages
    }
  }

  if (slugs.size === 0) {
    log.warn("museums", "NHM: no event slugs found");
    return [];
  }

  log.info("museums", `NHM: found ${slugs.size} unique event slugs across ${allUrls.length} calendar pages`);

  // Step 2: Fetch each detail page (raised limit to 100 for comprehensive coverage)
  const slugArray = [...slugs].slice(0, 100);
  for (const slug of slugArray) {
    try {
      await delay(200);
      const detailRes = await fetch(`https://nhm.org${slug}`, {
        headers: getRandomHeaders(),
      });
      if (!detailRes.ok) continue;

      const html = await detailRes.text();
      const event = parseNHMDetailPage(html, slug);
      if (event) events.push(event);
    } catch {
      // Skip failed detail pages
    }
  }

  return events;
}

function parseNHMDetailPage(html: string, slug: string): PipelineEvent | null {
  // Extract title from <h1> or og:title
  const ogTitle = html.match(/property="og:title"\s+content="([^"]+)"/);
  const h1Match = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
  const title = ogTitle?.[1] || h1Match?.[1]?.trim() || "";
  if (!title || title === "Calendar") return null;

  // Extract date range — look for patterns like "March 25, 2026" or "December 14, 2025 – April 18, 2027"
  const datePatterns = [
    // "December 14, 2025 – April 18, 2027" or "March 25, 2026 - May 10, 2026"
    /(\w+ \d{1,2}, \d{4})\s*[–—-]\s*(\w+ \d{1,2}, \d{4})/,
    // Single date: "March 25, 2026"
    /(\w+ \d{1,2}, \d{4})/,
  ];

  let startDate: Date | null = null;
  let endDate: Date | null = null;

  for (const pattern of datePatterns) {
    const dateMatch = html.match(pattern);
    if (dateMatch) {
      startDate = new Date(dateMatch[1]);
      if (dateMatch[2]) endDate = new Date(dateMatch[2]);
      break;
    }
  }

  // If no date found or date is invalid, skip
  if (!startDate || isNaN(startDate.getTime())) return null;

  // For exhibits with far-future end dates, use today as the "event" date
  // so they show up in current listings
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const sixtyOut = new Date();
  sixtyOut.setDate(sixtyOut.getDate() + 60);

  // If this is an ongoing exhibit, use today as start
  if (startDate < now && endDate && endDate > now) {
    startDate = now;
  }

  // Skip if start is past our window
  if (startDate > sixtyOut) return null;

  // Extract price
  const priceMatch = html.match(/(?:Free|free|FREE|\$\d+[^<]*?)(?:\s*(?:with|per|for))?[^<]{0,30}(?:admission|member|person|ticket)/i);
  const price = priceMatch?.[0]?.trim().slice(0, 50);

  // Extract description from og:description or first paragraph
  const ogDesc = html.match(/property="og:description"\s+content="([^"]+)"/);
  const desc = ogDesc?.[1] || "";

  // Extract image
  const ogImage = html.match(/property="og:image"\s+content="([^"]+)"/);
  let imageURL = ogImage?.[1];
  if (imageURL && !imageURL.startsWith("http")) {
    imageURL = `https://nhm.org${imageURL}`;
  }

  const fullUrl = `https://nhm.org${slug}`;

  return {
    sourceId: `nhm:${slug.replace("/calendar/", "")}`,
    source: "venue-nhm",
    title: title.replace(/\s*\|.*$/, "").trim(), // Strip " | NHM" suffix
    description: cleanDescription(stripHtml(desc)),
    startDate: startDate.toISOString(),
    endDate: endDate ? endDate.toISOString() : undefined,
    isAllDay: true,
    category: categorizeEvent(title, desc, []),
    city: "Los Angeles",
    locationName: "Natural History Museum of Los Angeles",
    address: "900 W Exposition Blvd, Los Angeles, CA 90007",
    latitude: 34.0171,
    longitude: -118.2887,
    externalURL: fullUrl,
    websiteURL: fullUrl,
    imageURL,
    isFeatured: false,
    isRecurring: false,
    tags: [],
    metro: "los-angeles",
    price,
  };
}

// ─── Skirball Cultural Center ────────────────────────────────────────────────
// https://www.skirball.org/programs/kids-and-families
//
// Strategy: Fetch the kids & families page, parse the article cards,
// then optionally fetch detail pages for fuller descriptions.

async function scrapeSkirball(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  // Fetch multiple Skirball pages for broader coverage
  const pageUrls = [
    "https://www.skirball.org/programs/kids-and-families",
    "https://www.skirball.org/programs/festivals",
    "https://www.skirball.org/calendar",
    "https://www.skirball.org/exhibitions",
  ];

  const seenHrefs = new Set<string>();
  const programLinks: Array<{ href: string; title: string; schedule: string; desc: string; imageURL?: string }> = [];

  for (const pageUrl of pageUrls) {
    try {
      const res = await fetch(pageUrl, { headers: getRandomHeaders() });
      if (!res.ok) continue;
      const html = await res.text();

      // Strategy 1: Parse article cards — Skirball uses <article class="node-type--event">
      const articlePattern = /<article[^>]*class="[^"]*node[^"]*"[^>]*>([\s\S]*?)<\/article>/g;
      let match;

      while ((match = articlePattern.exec(html)) !== null) {
        const card = match[1];
        const titleMatch = card.match(/<h[23][^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>([^<]+)<\/a>/);
        if (!titleMatch) continue;

        const [, href, title] = titleMatch;
        if (!title.trim() || seenHrefs.has(href)) continue;
        seenHrefs.add(href);

        const scheduleMatch = card.match(/<p[^>]*class="[^"]*date[^"]*"[^>]*>([\s\S]*?)<\/p>/);
        const schedule = scheduleMatch ? stripHtml(scheduleMatch[1]) : "";
        const descMatch = card.match(/<p[^>]*class="[^"]*(?:body|desc|summary)[^"]*"[^>]*>([\s\S]*?)<\/p>/);
        const desc = descMatch ? stripHtml(descMatch[1]) : "";
        const imgMatch = card.match(/<img[^>]*src="([^"]+)"/);
        let imageURL = imgMatch?.[1];
        if (imageURL && !imageURL.startsWith("http")) imageURL = `https://www.skirball.org${imageURL}`;

        programLinks.push({ href, title: title.trim(), schedule, desc, imageURL });
      }

      // Strategy 2: Find program links if no articles matched
      const linkPattern = /<a[^>]*href="(\/(?:programs|calendar|exhibitions)\/[a-zA-Z0-9_-]+)"[^>]*>([^<]+)<\/a>/gi;
      let linkMatch;

      while ((linkMatch = linkPattern.exec(html)) !== null) {
        const [, href, text] = linkMatch;
        const title = text.trim();
        if (!title || /^(details|reservations|learn more|read more|view|see)$/i.test(title)) continue;
        if (seenHrefs.has(href)) continue;
        seenHrefs.add(href);

        programLinks.push({ href, title, schedule: "", desc: "" });
      }

      await delay(300);
    } catch {
      // Skip failed pages
    }
  }

  // Fetch detail pages for programs to get proper dates and descriptions
  for (const prog of programLinks.slice(0, 50)) {
    try {
      const fullUrl = prog.href.startsWith("http") ? prog.href : `https://www.skirball.org${prog.href}`;
      await delay(200);
      const detailRes = await fetch(fullUrl, { headers: getRandomHeaders() });
      if (!detailRes.ok) {
        // Use listing page data as fallback
        addSkirballEvent(events, prog, fullUrl);
        continue;
      }

      const detailHtml = await detailRes.text();

      // Extract date from detail page
      const ogDesc = detailHtml.match(/property="og:description"\s+content="([^"]+)"/);
      const desc = ogDesc?.[1] || prog.desc;
      const ogImage = detailHtml.match(/property="og:image"\s+content="([^"]+)"/);
      const imageURL = ogImage?.[1] || prog.imageURL;

      // Look for specific dates on the page
      const datePattern = /(\w+ \d{1,2}, \d{4})/g;
      const dates: Date[] = [];
      let dm;
      while ((dm = datePattern.exec(detailHtml)) !== null) {
        const d = new Date(dm[1]);
        if (!isNaN(d.getTime())) dates.push(d);
      }

      const now = new Date();
      now.setHours(0, 0, 0, 0);
      const sixtyOut = new Date();
      sixtyOut.setDate(sixtyOut.getDate() + 60);

      // Filter to future dates within 60-day window
      const futureDates = dates.filter((d) => d >= now && d <= sixtyOut);

      if (futureDates.length > 0) {
        // Create one event per date occurrence
        for (const eventDate of futureDates) {
          eventDate.setHours(10, 0, 0, 0);
          const dateStr = eventDate.toISOString().split("T")[0];
          events.push({
            sourceId: `skirball:${prog.href.replace(/[^a-z0-9]/gi, "-").slice(0, 40)}-${dateStr}`,
            source: "venue-skirball",
            title: prog.title,
            description: cleanDescription(stripHtml(desc) + (prog.schedule ? ` Schedule: ${prog.schedule}.` : "")),
            startDate: eventDate.toISOString(),
            isAllDay: false,
            category: categorizeEvent(prog.title, desc, []),
            city: "Los Angeles",
            locationName: "Skirball Cultural Center",
            address: "2701 N Sepulveda Blvd, Los Angeles, CA 90049",
            latitude: 34.0823,
            longitude: -118.4736,
            externalURL: fullUrl,
            websiteURL: fullUrl,
            imageURL,
            isFeatured: false,
            isRecurring: futureDates.length > 1,
            tags: ["family"],
            metro: "los-angeles",
            price: "Included with admission",
          });
        }
      } else {
        // No specific dates found — generate weekly recurring instances
        addSkirballEvent(events, { ...prog, desc, imageURL }, fullUrl);
      }
    } catch {
      const fullUrl = prog.href.startsWith("http") ? prog.href : `https://www.skirball.org${prog.href}`;
      addSkirballEvent(events, prog, fullUrl);
    }
  }

  return events;
}

/** Create a single representative event for a Skirball program (fallback) */
function addSkirballEvent(
  events: PipelineEvent[],
  prog: { href: string; title: string; schedule: string; desc: string; imageURL?: string },
  fullUrl: string
): void {
  const now = new Date();
  now.setHours(10, 0, 0, 0);

  events.push({
    sourceId: `skirball:${prog.href.replace(/[^a-z0-9]/gi, "-").slice(0, 50)}`,
    source: "venue-skirball",
    title: prog.title,
    description: cleanDescription(prog.desc + (prog.schedule ? ` Schedule: ${prog.schedule}.` : "") || "Family program at the Skirball Cultural Center."),
    startDate: now.toISOString(),
    isAllDay: false,
    category: categorizeEvent(prog.title, prog.desc, []),
    city: "Los Angeles",
    locationName: "Skirball Cultural Center",
    address: "2701 N Sepulveda Blvd, Los Angeles, CA 90049",
    latitude: 34.0823,
    longitude: -118.4736,
    externalURL: fullUrl,
    websiteURL: fullUrl,
    imageURL: prog.imageURL,
    isFeatured: false,
    isRecurring: true,
    tags: ["family"],
    metro: "los-angeles",
    price: "Included with admission",
  });
}

// ─── Autry Museum of the American West ──────────────────────────────────────
// https://theautry.org/events
//
// Strategy: Fetch the events listing page (Drupal 9+), extract event links,
// then fetch each detail page for title, dates, description, image.

async function scrapeAutry(): Promise<PipelineEvent[]> {
  const events: PipelineEvent[] = [];

  // Step 1: Fetch the events listing page
  const listingUrls = [
    "https://theautry.org/events",
    "https://theautry.org/calendar",
  ];

  const eventLinks = new Set<string>();

  for (const listUrl of listingUrls) {
    try {
      const res = await fetch(listUrl, { headers: getRandomHeaders() });
      if (!res.ok) continue;

      const html = await res.text();

      // Extract event/calendar links — Drupal typically uses /events/{slug} or /calendar/{slug}
      const linkPatterns = [
        /href="(\/events\/[a-zA-Z0-9_-]+[^"]*)"/gi,
        /href="(\/calendar\/[a-zA-Z0-9_-]+[^"]*)"/gi,
        /href="(https:\/\/theautry\.org\/events\/[a-zA-Z0-9_-]+[^"]*)"/gi,
      ];

      for (const pattern of linkPatterns) {
        let m;
        while ((m = pattern.exec(html)) !== null) {
          const link = m[1].split("?")[0].split("#")[0]; // Clean query params
          if (link && !link.includes("/events/page/") && link !== "/events" && link !== "/events/") {
            eventLinks.add(link);
          }
        }
      }

      await delay(300);
    } catch {
      // Skip failed listing pages
    }
  }

  if (eventLinks.size === 0) {
    log.warn("museums", "Autry: no event links found");
    return [];
  }

  log.info("museums", `Autry: found ${eventLinks.size} event links`);

  // Step 2: Fetch each detail page (limit to 50)
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const sixtyOut = new Date();
  sixtyOut.setDate(sixtyOut.getDate() + 60);

  for (const link of [...eventLinks].slice(0, 50)) {
    try {
      await delay(200);
      const fullUrl = link.startsWith("http") ? link : `https://theautry.org${link}`;
      const detailRes = await fetch(fullUrl, { headers: getRandomHeaders() });
      if (!detailRes.ok) continue;

      const html = await detailRes.text();

      // Extract title from og:title or <h1>
      const ogTitle = html.match(/property="og:title"\s+content="([^"]+)"/);
      const h1Match = html.match(/<h1[^>]*>([^<]+)<\/h1>/);
      const title = (ogTitle?.[1] || h1Match?.[1]?.trim() || "").replace(/\s*\|.*$/, "").trim();
      if (!title || title === "Events" || title === "Calendar") continue;

      // Extract date
      const datePatterns = [
        /(\w+ \d{1,2}, \d{4})\s*[–—-]\s*(\w+ \d{1,2}, \d{4})/,
        /(\w+ \d{1,2}, \d{4})/,
      ];

      let startDate: Date | null = null;
      let endDate: Date | null = null;

      for (const pattern of datePatterns) {
        const dateMatch = html.match(pattern);
        if (dateMatch) {
          startDate = new Date(dateMatch[1]);
          if (dateMatch[2]) endDate = new Date(dateMatch[2]);
          break;
        }
      }

      if (!startDate || isNaN(startDate.getTime())) continue;

      // Handle ongoing exhibits
      if (startDate < now && endDate && endDate > now) {
        startDate = now;
      }
      if (startDate > sixtyOut) continue;

      // Extract description
      const ogDesc = html.match(/property="og:description"\s+content="([^"]+)"/);
      const desc = ogDesc?.[1] || "";

      // Extract image
      const ogImage = html.match(/property="og:image"\s+content="([^"]+)"/);
      let imageURL = ogImage?.[1];
      if (imageURL && !imageURL.startsWith("http")) {
        imageURL = `https://theautry.org${imageURL}`;
      }

      // Extract price
      const priceMatch = html.match(/(?:Free|free|FREE|\$\d+[^<]*?)(?:\s*(?:with|per|for))?[^<]{0,30}(?:admission|member|person|ticket|general)/i);
      const price = priceMatch?.[0]?.trim().slice(0, 50);

      const slug = link.replace(/^.*\//, "").replace(/[^a-z0-9-]/gi, "-").slice(0, 50);

      events.push({
        sourceId: `autry:${slug}`,
        source: "venue-autry",
        title,
        description: cleanDescription(stripHtml(desc)),
        startDate: startDate.toISOString(),
        endDate: endDate ? endDate.toISOString() : undefined,
        isAllDay: true,
        category: categorizeEvent(title, desc, []),
        city: "Los Angeles",
        locationName: "Autry Museum of the American West",
        address: "4700 Western Heritage Way, Los Angeles, CA 90027",
        latitude: 34.1486,
        longitude: -118.2839,
        externalURL: fullUrl,
        websiteURL: fullUrl,
        imageURL,
        isFeatured: false,
        isRecurring: false,
        tags: [],
        metro: "los-angeles",
        price,
      });
    } catch {
      // Skip failed detail pages
    }
  }

  return events;
}
