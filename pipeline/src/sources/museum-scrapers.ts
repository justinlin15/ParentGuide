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

  // Step 1: Fetch calendar listing page to find event slugs
  const calRes = await fetch("https://nhm.org/calendar", {
    headers: getRandomHeaders(),
  });

  if (!calRes.ok) {
    log.warn("museums", `NHM calendar HTTP ${calRes.status}`);
    return [];
  }

  const calHtml = await calRes.text();

  // Extract unique /calendar/ slugs
  const slugRegex = /href="(\/calendar\/[a-z0-9-]+)"/g;
  const slugs = new Set<string>();
  let m;
  while ((m = slugRegex.exec(calHtml)) !== null) {
    slugs.add(m[1]);
  }

  if (slugs.size === 0) {
    log.warn("museums", "NHM: no event slugs found");
    return [];
  }

  // Step 2: Fetch each detail page (limit to 30 to be polite)
  const slugArray = [...slugs].slice(0, 30);
  for (const slug of slugArray) {
    try {
      await delay(300);
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

  // Fetch the kids & families listing page
  const res = await fetch("https://www.skirball.org/programs/kids-and-families", {
    headers: getRandomHeaders(),
  });

  if (!res.ok) {
    log.warn("museums", `Skirball HTTP ${res.status}`);
    return [];
  }

  const html = await res.text();

  // Parse article cards — Skirball uses <article class="node-type--event">
  const articlePattern = /<article[^>]*class="[^"]*node-type--event[^"]*"[^>]*>([\s\S]*?)<\/article>/g;
  let match;

  while ((match = articlePattern.exec(html)) !== null) {
    const card = match[1];

    // Extract title and link from <h3><a href="...">Title</a></h3>
    const titleMatch = card.match(/<h3[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>([^<]+)<\/a>/);
    if (!titleMatch) continue;

    const [, href, title] = titleMatch;
    if (!title.trim()) continue;

    // Extract schedule from <p class="dates">
    const scheduleMatch = card.match(/<p[^>]*class="[^"]*dates[^"]*"[^>]*>([\s\S]*?)<\/p>/);
    const schedule = scheduleMatch ? stripHtml(scheduleMatch[1]) : "";

    // Extract description — the <p> after dates
    const descMatch = card.match(/<p[^>]*class="[^"]*dates[^"]*"[^>]*>[\s\S]*?<\/p>\s*<p[^>]*>([\s\S]*?)<\/p>/);
    const desc = descMatch ? stripHtml(descMatch[1]) : "";

    // Extract image
    const imgMatch = card.match(/<img[^>]*src="([^"]+)"/);
    let imageURL = imgMatch?.[1];
    if (imageURL && !imageURL.startsWith("http")) {
      imageURL = `https://www.skirball.org${imageURL}`;
    }

    const fullUrl = href.startsWith("http") ? href : `https://www.skirball.org${href}`;

    // These are recurring weekly programs — create one event for "today" as representative
    // The AI enrichment will rewrite the description with the schedule info
    const now = new Date();
    now.setHours(10, 0, 0, 0);

    events.push({
      sourceId: `skirball:${href.replace(/[^a-z0-9]/gi, "-").slice(0, 50)}`,
      source: "venue-skirball",
      title: title.trim(),
      description: cleanDescription(`${desc} ${schedule ? `Schedule: ${schedule}.` : ""}`),
      startDate: now.toISOString(),
      isAllDay: false,
      category: categorizeEvent(title, desc, []),
      city: "Los Angeles",
      locationName: "Skirball Cultural Center",
      address: "2701 N Sepulveda Blvd, Los Angeles, CA 90049",
      latitude: 34.0823,
      longitude: -118.4736,
      externalURL: fullUrl,
      websiteURL: fullUrl,
      imageURL,
      isFeatured: false,
      isRecurring: true,
      tags: ["family", "kids"],
      metro: "los-angeles",
      price: "Included with admission",
    });
  }

  // If no articles found with the pattern, try a simpler approach
  if (events.length === 0) {
    // Try to find program links on the page
    const linkPattern = /<a[^>]*href="(\/programs\/[a-z0-9-]+)"[^>]*>([^<]+)<\/a>/g;
    const seen = new Set<string>();
    let linkMatch;

    while ((linkMatch = linkPattern.exec(html)) !== null) {
      const [, href, text] = linkMatch;
      const title = text.trim();
      if (!title || title === "Details and reservations" || title === "Learn more") continue;
      if (seen.has(href)) continue;
      seen.add(href);

      const fullUrl = `https://www.skirball.org${href}`;
      const now = new Date();
      now.setHours(10, 0, 0, 0);

      events.push({
        sourceId: `skirball:${href.replace(/[^a-z0-9]/gi, "-").slice(0, 50)}`,
        source: "venue-skirball",
        title,
        description: `Family program at the Skirball Cultural Center.`,
        startDate: now.toISOString(),
        isAllDay: false,
        category: categorizeEvent(title, "", []),
        city: "Los Angeles",
        locationName: "Skirball Cultural Center",
        address: "2701 N Sepulveda Blvd, Los Angeles, CA 90049",
        latitude: 34.0823,
        longitude: -118.4736,
        externalURL: fullUrl,
        websiteURL: fullUrl,
        isFeatured: false,
        isRecurring: true,
        tags: ["family", "kids"],
        metro: "los-angeles",
        price: "Included with admission",
      });
    }
  }

  return events;
}
