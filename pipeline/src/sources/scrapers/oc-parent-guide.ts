import { chromium, type Browser, type Page, type Frame } from "playwright";
import { type PipelineEvent, categorizeEvent } from "../../normalize.js";
import { type MetroArea } from "../../config.js";
import { log } from "../../utils/logger.js";
import { getRandomUserAgent } from "../../utils/user-agents.js";

const SITE_URL = "https://www.orangecountyparentguide.com";
const EVENTS_PATH = "/event-calendar";
const SOURCE = "oc-parent-guide";

// Credentials from environment (stored as GitHub Secrets)
const OC_EMAIL = process.env.OC_PARENT_GUIDE_EMAIL || "";
const OC_PASSWORD = process.env.OC_PARENT_GUIDE_PASSWORD || "";

export async function scrapeOCParentGuide(
  metro: MetroArea
): Promise<PipelineEvent[]> {
  if (metro.id !== "orange-county") return [];

  if (!OC_EMAIL || !OC_PASSWORD) {
    log.warn(SOURCE, "OC Parent Guide credentials not configured — skipping");
    return [];
  }

  log.info(SOURCE, "Scraping orangecountyparentguide.com (with login)...");

  let browser: Browser | null = null;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      userAgent: getRandomUserAgent(),
      viewport: { width: 1920, height: 1080 },
    });
    const page = await context.newPage();

    // Step 1: Navigate to the event calendar page
    log.info(SOURCE, "  Loading event calendar page...");
    await page.goto(`${SITE_URL}${EVENTS_PATH}`, {
      waitUntil: "domcontentloaded",
      timeout: 60000,
    });
    await page.waitForTimeout(5000);

    // Step 2: Attempt Wix member login
    // Wix member login is typically triggered by clicking a login button in the
    // site header, which opens a lightbox/modal with email + password fields.
    log.info(SOURCE, "  Attempting login...");
    const loggedIn = await attemptWixLogin(page);
    if (loggedIn) {
      log.info(SOURCE, "  Login successful, reloading calendar page...");
      await page.goto(`${SITE_URL}${EVENTS_PATH}`, {
        waitUntil: "domcontentloaded",
        timeout: 60000,
      });
    } else {
      log.info(SOURCE, "  Login may have failed or was not needed, continuing...");
    }

    // Step 3: Wait for the boomte.ch calendar iframe to load
    // Wix sites are JavaScript-heavy and the calendar component loads last
    log.info(SOURCE, "  Waiting for calendar to load...");
    await page.waitForTimeout(10000);

    // Scroll down to trigger lazy-loaded content
    await page.evaluate(() => window.scrollBy(0, 500));
    await page.waitForTimeout(5000);

    // Step 4: Find the boomte.ch calendar iframe
    let calendarFrame = findCalendarFrame(page);

    if (!calendarFrame) {
      // Try scrolling more and waiting
      log.info(SOURCE, "  Calendar iframe not found yet, scrolling and waiting...");
      await page.evaluate(() => window.scrollBy(0, 800));
      await page.waitForTimeout(8000);
      calendarFrame = findCalendarFrame(page);
    }

    if (!calendarFrame) {
      // Log all frame URLs for debugging
      const frameUrls = page.frames().map((f) => f.url());
      log.warn(SOURCE, `  Calendar iframe not found. Frames: ${frameUrls.join(", ")}`);
      return [];
    }

    log.info(SOURCE, "  Found calendar iframe");

    // Step 5: Wait for FullCalendar to render inside the iframe
    try {
      await calendarFrame.waitForSelector(
        ".fc-daygrid-day, .fc-event, .fc-list-event",
        { timeout: 15000 }
      );
    } catch {
      log.warn(SOURCE, "  FullCalendar events did not render in time");
      // Continue anyway - might still find some elements
    }

    // Step 6: Try switching to List view for easier scraping
    try {
      // Boom Calendar has view buttons labeled "List" or "Agenda"
      const listBtn = await calendarFrame.$(
        'button:has-text("List"), button:has-text("Agenda"), ' +
        '[class*="list-btn"], [class*="agenda-btn"], ' +
        '.fc-listWeek-button, .fc-listMonth-button, .fc-list-button'
      );
      if (listBtn) {
        await listBtn.click();
        await page.waitForTimeout(4000);
        log.info(SOURCE, "  Switched to List/Agenda view");
      } else {
        log.info(SOURCE, "  No List view button found, using current view");
      }
    } catch {
      log.info(SOURCE, "  Could not switch to List view, using current view");
    }

    // Step 7: Extract events from the current month/view
    const events = await extractEventsFromCalendar(calendarFrame);
    log.info(SOURCE, `  Current view: ${events.length} events`);

    // Step 8: Navigate to next month for broader coverage
    try {
      const nextBtn = await calendarFrame.$(
        'button.fc-next-button, button[aria-label*="next" i], ' +
        '.fc-button-next, [class*="next-btn"], [class*="nav-next"]'
      );
      if (nextBtn) {
        await nextBtn.click();
        await page.waitForTimeout(4000);
        const nextMonthEvents = await extractEventsFromCalendar(calendarFrame);
        log.info(SOURCE, `  Next month: ${nextMonthEvents.length} events`);
        events.push(...nextMonthEvents);
      }
    } catch {
      log.info(SOURCE, "  Could not navigate to next month");
    }

    // Deduplicate by title + date
    const seen = new Set<string>();
    const unique = events.filter((e) => {
      const key = `${e.title}|${e.startDate}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    log.success(SOURCE, `Found ${unique.length} events total`);
    return unique;
  } catch (err) {
    log.error(SOURCE, `Scraping failed: ${err}`);
    return [];
  } finally {
    if (browser) await browser.close();
  }
}

function findCalendarFrame(page: Page): Frame | null {
  // Look for boomte.ch calendar iframe
  return (
    page.frames().find((f) => f.url().includes("boomte.ch/widget")) ||
    page.frames().find((f) => f.url().includes("boomte.ch")) ||
    page.frames().find((f) => f.url().includes("calendar")) ||
    null
  );
}

async function attemptWixLogin(page: Page): Promise<boolean> {
  try {
    // Wix sites have a member area dropdown or login button in the header.
    // Try several common selectors for the Wix login trigger.
    const loginTriggerSelectors = [
      '[data-testid="loginButton"]',
      '[data-hook="login-button"]',
      'button:has-text("Log In")',
      'button:has-text("Sign In")',
      'a:has-text("Log In")',
      'a:has-text("Sign In")',
      // OC Parent Guide uses a member area dropdown with username display
      '[data-hook="member-login-button"]',
      '[aria-label="Log in"]',
    ];

    let loginClicked = false;
    for (const selector of loginTriggerSelectors) {
      try {
        const el = await page.$(selector);
        if (el && await el.isVisible()) {
          await el.click();
          loginClicked = true;
          await page.waitForTimeout(2000);
          break;
        }
      } catch {
        continue;
      }
    }

    if (!loginClicked) {
      // Check if already logged in (member name visible)
      const memberArea = await page.$('[data-hook="member-name"], [class*="member-name"]');
      if (memberArea) {
        log.info(SOURCE, "  Already logged in");
        return true;
      }
      log.info(SOURCE, "  No login trigger found");
      return false;
    }

    // Wait for the login modal/lightbox to appear
    await page.waitForTimeout(2000);

    // Wix login modal uses specific data-testid attributes or iframe
    // Try filling the email field
    const emailSelectors = [
      '[data-testid="emailAuth.loginEmailInput"] input',
      'input[data-testid="emailInput"]',
      'input[type="email"]',
      'input[name="email"]',
      'input[placeholder*="email" i]',
      'input[placeholder*="Email" i]',
    ];

    let emailFilled = false;
    for (const selector of emailSelectors) {
      try {
        const el = await page.$(selector);
        if (el && await el.isVisible()) {
          await el.fill(OC_EMAIL);
          emailFilled = true;
          break;
        }
      } catch {
        continue;
      }
    }

    // Also check inside any iframes (Wix sometimes uses an auth iframe)
    if (!emailFilled) {
      for (const frame of page.frames()) {
        if (frame === page.mainFrame()) continue;
        try {
          for (const selector of emailSelectors) {
            const el = await frame.$(selector);
            if (el) {
              await el.fill(OC_EMAIL);
              emailFilled = true;
              break;
            }
          }
          if (emailFilled) break;
        } catch {
          continue;
        }
      }
    }

    if (!emailFilled) {
      log.warn(SOURCE, "  Could not find email input field");
      return false;
    }

    // Fill password
    const passwordSelectors = [
      '[data-testid="emailAuth.loginPasswordInput"] input',
      'input[data-testid="passwordInput"]',
      'input[type="password"]',
      'input[name="password"]',
    ];

    let passwordFilled = false;
    for (const selector of passwordSelectors) {
      try {
        const el = await page.$(selector);
        if (el && await el.isVisible()) {
          await el.fill(OC_PASSWORD);
          passwordFilled = true;
          break;
        }
      } catch {
        continue;
      }
    }

    // Check iframes for password too
    if (!passwordFilled) {
      for (const frame of page.frames()) {
        if (frame === page.mainFrame()) continue;
        try {
          for (const selector of passwordSelectors) {
            const el = await frame.$(selector);
            if (el) {
              await el.fill(OC_PASSWORD);
              passwordFilled = true;
              break;
            }
          }
          if (passwordFilled) break;
        } catch {
          continue;
        }
      }
    }

    if (!passwordFilled) {
      log.warn(SOURCE, "  Could not find password input field");
      return false;
    }

    // Click the submit/login button
    const submitSelectors = [
      '[data-testid="emailAuth.loginSubmitButton"]',
      '[data-testid="submit"]',
      'button:has-text("Log In")',
      'button:has-text("Sign In")',
      'button:has-text("Submit")',
      'button[type="submit"]',
    ];

    for (const selector of submitSelectors) {
      try {
        const el = await page.$(selector);
        if (el && await el.isVisible()) {
          await Promise.all([
            page
              .waitForNavigation({
                waitUntil: "domcontentloaded",
                timeout: 15000,
              })
              .catch(() => null),
            el.click(),
          ]);
          await page.waitForTimeout(3000);
          return true;
        }
      } catch {
        continue;
      }
    }

    // Also check iframes for the submit button
    for (const frame of page.frames()) {
      if (frame === page.mainFrame()) continue;
      try {
        for (const selector of submitSelectors) {
          const el = await frame.$(selector);
          if (el) {
            await el.click();
            await page.waitForTimeout(5000);
            return true;
          }
        }
      } catch {
        continue;
      }
    }

    log.warn(SOURCE, "  Could not find login submit button");
    return false;
  } catch (err) {
    log.warn(SOURCE, `  Login attempt error: ${err}`);
    return false;
  }
}

async function extractEventsFromCalendar(
  frame: Frame
): Promise<PipelineEvent[]> {
  const rawEvents = await frame.evaluate(() => {
    const results: Array<{
      title: string;
      dateText: string;
      timeText: string;
      endTimeText: string;
    }> = [];
    const seen = new Set<string>();

    // Strategy 1: FullCalendar month grid view - each day cell has data-date
    const dayCells = document.querySelectorAll(".fc-daygrid-day");
    if (dayCells.length > 0) {
      dayCells.forEach((cell) => {
        const dateAttr = cell.getAttribute("data-date") || "";

        // Events can be in various FullCalendar elements
        const eventEls = cell.querySelectorAll(
          ".fc-event, .fc-daygrid-event, [class*='event']"
        );
        eventEls.forEach((el) => {
          const titleEl =
            el.querySelector(".fc-event-title, .fc-event-title-container") ||
            el;
          const title = (titleEl as HTMLElement).textContent?.trim() || "";
          const timeEl = el.querySelector(
            ".fc-event-time, .fc-daygrid-event-time"
          );
          const timeText = timeEl
            ? (timeEl as HTMLElement).textContent?.trim() || ""
            : "";

          if (
            title &&
            title.length > 3 &&
            !title.startsWith("+") &&
            !seen.has(`${dateAttr}-${title}`)
          ) {
            seen.add(`${dateAttr}-${title}`);
            results.push({ title, dateText: dateAttr, timeText, endTimeText: "" });
          }
        });
      });
    }

    // Strategy 2: FullCalendar list view
    if (results.length === 0) {
      const listDays = document.querySelectorAll(
        ".fc-list-day, [class*='list-day']"
      );
      listDays.forEach((dayRow) => {
        // Prefer data-date attribute (YYYY-MM-DD) over text content
        const dataDate = dayRow.getAttribute("data-date") || "";
        const dateEl = dayRow.querySelector(
          ".fc-list-day-text, .fc-list-day-cushion, [class*='day-text']"
        );
        const dateText = dataDate || (dateEl
          ? (dateEl as HTMLElement).textContent?.trim() || ""
          : "");

        // Events follow each day header as sibling rows
        let sibling = dayRow.nextElementSibling;
        while (
          sibling &&
          !sibling.classList.contains("fc-list-day") &&
          !sibling.matches("[class*='list-day']")
        ) {
          const titleEl = sibling.querySelector(
            ".fc-list-event-title, .fc-event-title"
          ) as HTMLElement;
          const timeEl = sibling.querySelector(
            ".fc-list-event-time, .fc-event-time"
          ) as HTMLElement;
          const title = titleEl?.textContent?.trim() || "";
          const timeText = timeEl?.textContent?.trim() || "";

          // Dedup by date+title so multi-day events keep each occurrence
          const dedupKey = `${dateText}-${title}`;
          if (title && title.length > 3 && !seen.has(dedupKey)) {
            seen.add(dedupKey);
            results.push({ title, dateText, timeText, endTimeText: "" });
          }
          sibling = sibling.nextElementSibling;
        }
      });
    }

    // Strategy 3: Boom Calendar custom elements (non-FullCalendar)
    if (results.length === 0) {
      const allEvents = document.querySelectorAll(
        "[class*='event-item'], [class*='event-title'], [class*='agenda-item']"
      );
      allEvents.forEach((el) => {
        const title = (el as HTMLElement).textContent?.trim() || "";
        if (
          title &&
          title.length > 3 &&
          title.length < 200 &&
          !title.startsWith("+") &&
          !seen.has(title)
        ) {
          seen.add(title);
          results.push({ title, dateText: "", timeText: "", endTimeText: "" });
        }
      });
    }

    // Strategy 4: Generic fallback - any .fc-event elements anywhere
    if (results.length === 0) {
      document
        .querySelectorAll(".fc-event, [class*='fc-event']")
        .forEach((el) => {
          const title = (el as HTMLElement).textContent?.trim() || "";
          if (
            title &&
            title.length > 3 &&
            !title.startsWith("+") &&
            !seen.has(title)
          ) {
            seen.add(title);
            results.push({ title, dateText: "", timeText: "", endTimeText: "" });
          }
        });
    }

    return results;
  });

  // Get the current month/year from the calendar header
  const monthYear = await frame
    .evaluate(() => {
      const header = document.querySelector(
        ".fc-toolbar-title, .fc-header-toolbar h2, " +
          "[class*='toolbar-title'], [class*='calendar-title']"
      );
      return header?.textContent?.trim() || "";
    })
    .catch(() => "");

  log.info(
    SOURCE,
    `  Calendar showing: "${monthYear}" (${rawEvents.length} raw events)`
  );

  // Convert to PipelineEvent format
  return rawEvents
    .filter((e) => e.title.length > 3 && !e.title.startsWith("+"))
    .map((e) => {
      // Parse time range from timeText (e.g., "10:00am - 5:00pm" or "9:30a - 11:00a")
      const { startTime, endTime } = parseTimeRange(e.timeText);
      const startDate = parseEventDate(e.dateText, startTime, monthYear);
      let endDate: string | undefined;
      if (endTime && startDate) {
        const datePart = startDate.split("T")[0];
        endDate = `${datePart}T${endTime}`;
      }

      return {
        sourceId: `${SOURCE}-${slugify(e.title)}-${e.dateText || "nodate"}`,
        source: SOURCE,
        title: e.title,
        description: "",
        startDate: startDate || new Date().toISOString(),
        endDate,
        isAllDay: !startTime,
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
        metro: "orange-county",
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

/**
 * Resolve a time string to HH:MM:SS format.
 * Accepts either HH:MM:SS directly or am/pm text (e.g. "10:00am").
 */
function resolveTime(timeStr: string): string | null {
  if (!timeStr) return null;
  // Already in HH:MM:SS format (from parseTimeText)
  if (/^\d{2}:\d{2}:\d{2}$/.test(timeStr)) return timeStr;
  // Otherwise parse am/pm format
  return parseTimeText(timeStr);
}

function parseEventDate(
  dateAttr: string,
  timeText: string,
  monthYear: string
): string | null {
  // data-date is in YYYY-MM-DD format (from FullCalendar)
  if (dateAttr && /^\d{4}-\d{2}-\d{2}$/.test(dateAttr)) {
    if (timeText) {
      const time = resolveTime(timeText);
      if (time) return `${dateAttr}T${time}`;
    }
    return `${dateAttr}T00:00:00`;
  }

  // Try parsing dateText as a human-readable date
  // Handles: "Saturday, March 15", "March 15, 2026", "Thu Mar 15", etc.
  if (dateAttr) {
    // Strip day-of-week prefix like "Saturday, " or "Mon "
    const cleaned = dateAttr.replace(/^[A-Za-z]+,?\s+/, "").trim();
    try {
      const d = new Date(cleaned);
      if (!isNaN(d.getTime())) {
        const iso = d.toISOString().split("T")[0];
        if (timeText) {
          const time = resolveTime(timeText);
          if (time) return `${iso}T${time}`;
        }
        return `${iso}T00:00:00`;
      }
    } catch {}
    // Also try the original string
    try {
      const d = new Date(dateAttr);
      if (!isNaN(d.getTime())) {
        const iso = d.toISOString().split("T")[0];
        if (timeText) {
          const time = resolveTime(timeText);
          if (time) return `${iso}T${time}`;
        }
        return `${iso}T00:00:00`;
      }
    } catch {}
  }

  // Fallback: extract year from monthYear header (e.g., "March 8 – 14, 2026")
  // and combine with any day number in dateAttr
  if (monthYear && dateAttr) {
    const yearMatch = monthYear.match(/(\d{4})/);
    const monthMatch = monthYear.match(
      /(January|February|March|April|May|June|July|August|September|October|November|December)/i
    );
    const dayMatch = dateAttr.match(/(\d{1,2})/);
    if (yearMatch && monthMatch && dayMatch) {
      try {
        const d = new Date(`${monthMatch[1]} ${dayMatch[1]}, ${yearMatch[1]}`);
        if (!isNaN(d.getTime())) {
          const iso = d.toISOString().split("T")[0];
          if (timeText) {
            const time = resolveTime(timeText);
            if (time) return `${iso}T${time}`;
          }
          return `${iso}T00:00:00`;
        }
      } catch {}
    }
  }

  return null;
}

function parseTimeText(timeStr: string): string | null {
  const match = timeStr.match(/(\d{1,2}):?(\d{2})?\s*(am|pm|a|p)/i);
  if (!match) return null;

  let hours = parseInt(match[1]);
  const minutes = match[2] || "00";
  const period = match[3].toLowerCase();

  if ((period === "pm" || period === "p") && hours !== 12) hours += 12;
  if ((period === "am" || period === "a") && hours === 12) hours = 0;

  return `${hours.toString().padStart(2, "0")}:${minutes}:00`;
}

/**
 * Parse a time range string into separate start and end time strings (HH:MM:SS format).
 * Handles various formats:
 *   "10:00am - 5:00pm"  (dash separator)
 *   "9:30a – 11a"       (en-dash separator)
 *   "10:00 AM / 5:00 PM"  (slash separator, used by Boom Calendar)
 *   "10:00am\n5:00pm"   (newline separator)
 *   "10:00am"           (single time, no end)
 */
function parseTimeRange(timeStr: string): { startTime: string; endTime: string } {
  if (!timeStr) return { startTime: "", endTime: "" };

  // Normalize whitespace and newlines to single spaces for matching
  const normalized = timeStr.replace(/\s+/g, " ").trim();

  // Match patterns with various separators: -, –, /, or whitespace-only between two times
  const rangeMatch = normalized.match(
    /(\d{1,2}:?\d{0,2}\s*(?:am|pm|a|p))\s*[-–/]\s*(\d{1,2}:?\d{0,2}\s*(?:am|pm|a|p))/i
  );
  if (rangeMatch) {
    const start = parseTimeText(rangeMatch[1]);
    const end = parseTimeText(rangeMatch[2]);
    return { startTime: start || "", endTime: end || "" };
  }

  // Two am/pm times separated only by whitespace (e.g., "10:00 am 5:00 pm")
  const spacedMatch = normalized.match(
    /(\d{1,2}:\d{2}\s*(?:am|pm))\s+(\d{1,2}:\d{2}\s*(?:am|pm))/i
  );
  if (spacedMatch) {
    const start = parseTimeText(spacedMatch[1]);
    const end = parseTimeText(spacedMatch[2]);
    return { startTime: start || "", endTime: end || "" };
  }

  // Single time like "10:00am"
  const singleTime = parseTimeText(normalized);
  return { startTime: singleTime || "", endTime: "" };
}

function extractCity(title: string): string {
  // Try to extract city from event title (many include "in CityName" or "at Location, City")
  const match = title.match(/\bin\s+([\w\s]+?)(?:\s*\(|\s*$|\s*-)/i);
  if (match) {
    const city = match[1].trim();
    // Common OC cities
    const ocCities = [
      "Irvine",
      "Anaheim",
      "Huntington Beach",
      "Newport Beach",
      "Costa Mesa",
      "Tustin",
      "Orange",
      "Santa Ana",
      "Buena Park",
      "Dana Point",
      "San Clemente",
      "San Juan Capistrano",
      "Lake Forest",
      "Laguna Beach",
      "Laguna Niguel",
      "Mission Viejo",
      "Rancho Mission Viejo",
      "Yorba Linda",
      "Fullerton",
      "Westminster",
      "Long Beach",
      "Aliso Viejo",
      "Foothill Ranch",
    ];
    for (const oc of ocCities) {
      if (city.toLowerCase().includes(oc.toLowerCase())) return oc;
    }
    return city;
  }

  // Also check for city names appearing anywhere in the title
  const titleLower = title.toLowerCase();
  const cityChecks = [
    "Irvine",
    "Anaheim",
    "Huntington Beach",
    "Newport Beach",
    "Costa Mesa",
    "Tustin",
    "Santa Ana",
    "Laguna Beach",
    "Mission Viejo",
    "Fullerton",
    "Long Beach",
    "San Clemente",
    "Dana Point",
  ];
  for (const city of cityChecks) {
    if (titleLower.includes(city.toLowerCase())) return city;
  }

  return "Orange County";
}
