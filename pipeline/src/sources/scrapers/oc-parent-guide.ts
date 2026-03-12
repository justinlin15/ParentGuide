import { chromium, type Browser, type Page, type Frame } from "playwright";
import { type PipelineEvent, categorizeEvent } from "../../normalize.js";
import { type MetroArea } from "../../config.js";
import { log } from "../../utils/logger.js";

const SITE_URL = "https://www.orangecountyparentguide.com";
const EVENTS_PATH = "/event-calendar";
const SOURCE = "oc-parent-guide";

// Credentials from environment (stored as GitHub Secrets)
const OC_EMAIL = process.env.OC_PARENT_GUIDE_EMAIL || "";
const OC_PASSWORD = process.env.OC_PARENT_GUIDE_PASSWORD || "";

export async function scrapeOCParentGuide(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "los-angeles") return [];

  if (!OC_EMAIL || !OC_PASSWORD) {
    log.warn(SOURCE, "OC Parent Guide credentials not configured — skipping");
    return [];
  }

  log.info(SOURCE, "Scraping orangecountyparentguide.com (with login)...");

  let browser: Browser | null = null;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      viewport: { width: 1920, height: 1080 },
    });
    const page = await context.newPage();

    // Step 1: Navigate and login
    await page.goto(`${SITE_URL}${EVENTS_PATH}`, {
      waitUntil: "domcontentloaded",
      timeout: 45000,
    });
    await page.waitForTimeout(3000);

    log.info(SOURCE, "  Logging in...");
    await page.fill('input[type="email"]', OC_EMAIL);
    await page.fill('input[type="password"]', OC_PASSWORD);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => null),
      page.click('button:has-text("Sign in")'),
    ]);
    await page.waitForTimeout(3000);

    // Step 2: Navigate to event calendar after login
    log.info(SOURCE, "  Loading event calendar...");
    await page.goto(`${SITE_URL}${EVENTS_PATH}`, {
      waitUntil: "domcontentloaded",
      timeout: 45000,
    });
    await page.waitForTimeout(8000);

    // Step 3: Find the boomte.ch calendar iframe
    const calendarFrame = page.frames().find((f) =>
      f.url().includes("boomte.ch/widget")
    );

    if (!calendarFrame) {
      log.warn(SOURCE, "  Calendar iframe not found");
      return [];
    }

    log.info(SOURCE, "  Found calendar iframe, switching to List view...");

    // Step 4: Switch to List view for easier scraping
    try {
      await calendarFrame.click('button:has-text("List")', { timeout: 5000 });
      await page.waitForTimeout(3000);
    } catch {
      log.info(SOURCE, "  List view button not found, using Month view");
    }

    // Step 5: Extract events from the current month
    const events = await extractEventsFromCalendar(calendarFrame);
    log.info(SOURCE, `  Current month: ${events.length} events`);

    // Step 6: Navigate to next month for 30+ day coverage
    try {
      const nextBtn = await calendarFrame.$('button.fc-next-button, button[aria-label*="next" i], .fc-button-next');
      if (nextBtn) {
        await nextBtn.click();
        await page.waitForTimeout(3000);
        const nextMonthEvents = await extractEventsFromCalendar(calendarFrame);
        log.info(SOURCE, `  Next month: ${nextMonthEvents.length} events`);
        events.push(...nextMonthEvents);
      }
    } catch {
      log.info(SOURCE, "  Could not navigate to next month");
    }

    log.success(SOURCE, `Found ${events.length} events total`);
    return events;
  } catch (err) {
    log.error(SOURCE, `Scraping failed: ${err}`);
    return [];
  } finally {
    if (browser) await browser.close();
  }
}

async function extractEventsFromCalendar(
  frame: Frame
): Promise<PipelineEvent[]> {
  const rawEvents = await frame.evaluate(() => {
    const results: Array<{
      title: string;
      dateText: string;
      dayNumber: string;
    }> = [];
    const seen = new Set<string>();

    // FullCalendar renders events as .fc-event elements inside day cells
    // Each day cell has a date attribute or day number
    const dayCells = document.querySelectorAll(".fc-daygrid-day, .fc-list-day");

    if (dayCells.length > 0) {
      // Month/Day grid view
      dayCells.forEach((cell) => {
        const dateAttr =
          cell.getAttribute("data-date") || "";
        const dayNum =
          cell.querySelector(".fc-daygrid-day-number")?.textContent?.trim() || "";

        const eventEls = cell.querySelectorAll(".fc-event-title");
        eventEls.forEach((el) => {
          const title = (el as HTMLElement).textContent?.trim() || "";
          if (title && !seen.has(`${dateAttr}-${title}`)) {
            seen.add(`${dateAttr}-${title}`);
            results.push({ title, dateText: dateAttr, dayNumber: dayNum });
          }
        });
      });
    }

    // Also check for list view events
    if (results.length === 0) {
      const listEvents = document.querySelectorAll(
        ".fc-list-event, .fc-event"
      );
      listEvents.forEach((el) => {
        const titleEl = el.querySelector(
          ".fc-event-title, .fc-list-event-title"
        ) as HTMLElement;
        const dateEl = el.closest(".fc-list-day")?.querySelector(
          ".fc-list-day-text"
        ) as HTMLElement;

        const title = titleEl?.textContent?.trim() || "";
        if (title && !seen.has(title)) {
          seen.add(title);
          results.push({
            title,
            dateText: dateEl?.textContent?.trim() || "",
            dayNumber: "",
          });
        }
      });
    }

    // Fallback: get "+N more" items by looking at all fc-event elements
    if (results.length === 0) {
      document.querySelectorAll(".fc-event").forEach((el) => {
        const title = (el as HTMLElement).textContent?.trim() || "";
        if (title && title.length > 3 && !title.startsWith("+") && !seen.has(title)) {
          seen.add(title);
          results.push({ title, dateText: "", dayNumber: "" });
        }
      });
    }

    return results;
  });

  // Get the current month/year from the calendar header
  const monthYear = await frame
    .evaluate(() => {
      const header = document.querySelector(
        ".fc-toolbar-title, .fc-header-toolbar h2"
      );
      return header?.textContent?.trim() || "";
    })
    .catch(() => "");

  log.info(SOURCE, `  Calendar showing: ${monthYear} (${rawEvents.length} events)`);

  // Convert to PipelineEvent format
  return rawEvents
    .filter((e) => e.title.length > 3 && !e.title.startsWith("+"))
    .map((e) => {
      const startDate = parseEventDate(e.dateText, monthYear);

      return {
        sourceId: `${SOURCE}-${slugify(e.title)}-${e.dateText || "nodate"}`,
        source: SOURCE,
        title: e.title,
        description: "",
        startDate: startDate || new Date().toISOString(),
        endDate: undefined,
        isAllDay: true,
        category: categorizeEvent(e.title, ""),
        city: extractCity(e.title) || "Orange County",
        address: "",
        latitude: 0,
        longitude: 0,
        locationName: "",
        imageURL: "",
        externalURL: `${SITE_URL}${EVENTS_PATH}`,
        isFeatured: false,
        isRecurring: false,
        tags: ["family", "orange county"],
        metro: "los-angeles",
      };
    });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60);
}

function parseEventDate(
  dateAttr: string,
  monthYear: string
): string | null {
  // data-date is in YYYY-MM-DD format
  if (dateAttr && /^\d{4}-\d{2}-\d{2}$/.test(dateAttr)) {
    return new Date(dateAttr + "T00:00:00").toISOString();
  }

  // Fallback: parse from month/year header + day number
  if (monthYear) {
    try {
      const d = new Date(monthYear + " 1");
      if (!isNaN(d.getTime())) {
        return d.toISOString();
      }
    } catch {}
  }

  return null;
}

function extractCity(title: string): string {
  // Try to extract city from event title (many include "in CityName")
  const match = title.match(
    /\bin\s+([\w\s]+?)(?:\s*\(|\s*$|\s*-)/i
  );
  if (match) {
    const city = match[1].trim();
    // Common OC cities
    const ocCities = [
      "Irvine", "Anaheim", "Huntington Beach", "Newport Beach",
      "Costa Mesa", "Tustin", "Orange", "Santa Ana", "Buena Park",
      "Dana Point", "San Clemente", "San Juan Capistrano", "Lake Forest",
      "Laguna Beach", "Laguna Niguel", "Mission Viejo", "Rancho Mission Viejo",
      "Yorba Linda", "Fullerton", "Westminster", "Long Beach",
      "Aliso Viejo", "Foothill Ranch",
    ];
    for (const oc of ocCities) {
      if (city.toLowerCase().includes(oc.toLowerCase())) return oc;
    }
    return city;
  }
  return "Orange County";
}
