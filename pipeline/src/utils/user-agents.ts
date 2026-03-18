// Realistic browser User-Agent strings for scraping rotation.
// Updated to current browser versions to avoid detection.

const USER_AGENTS = [
  // Chrome 131/132 on Windows (most common desktop)
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
  // Chrome on macOS
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  // Firefox on Windows
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0",
  // Firefox on macOS
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:132.0) Gecko/20100101 Firefox/132.0",
  // Safari on macOS
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
  // Edge on Windows
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0.0",
];

// Matching sec-ch-ua hints for Chrome UAs (must correspond to Chrome version)
const CHROME_HINTS: Record<string, { ua: string; platform: string }> = {
  "130": {
    ua: `"Chromium";v="130", "Google Chrome";v="130", "Not?A_Brand";v="99"`,
    platform: '"Windows"',
  },
  "131": {
    ua: `"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"`,
    platform: '"Windows"',
  },
  "132": {
    ua: `"Google Chrome";v="132", "Chromium";v="132", "Not_A Brand";v="24"`,
    platform: '"Windows"',
  },
};

function extractChromeVersion(ua: string): string | null {
  const m = ua.match(/Chrome\/(\d+)/);
  return m ? m[1] : null;
}

/** Return a random User-Agent string from the pool. */
export function getRandomUserAgent(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

/**
 * Return a full set of realistic browser headers.
 *
 * For Chrome UAs, includes sec-ch-ua client hints and sec-fetch-* headers
 * that real browsers always send — their absence is a strong bot signal.
 */
export function getRandomHeaders(options?: {
  referer?: string; // e.g. "https://www.google.com/"
  isNavigation?: boolean; // true = loading a page (sec-fetch-dest: document)
}): Record<string, string> {
  const ua = getRandomUserAgent();
  const isChrome = ua.includes("Chrome/") && !ua.includes("Edg/");
  const isFirefox = ua.includes("Firefox/");
  const isSafari = ua.includes("Safari/") && !ua.includes("Chrome/");
  const chromeVersion = extractChromeVersion(ua);
  const hints = chromeVersion ? CHROME_HINTS[chromeVersion] : null;
  const isNavigation = options?.isNavigation ?? true;

  const headers: Record<string, string> = {
    "User-Agent": ua,
    Accept: isNavigation
      ? "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
      : "application/json,text/plain,*/*;q=0.9",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Cache-Control": "max-age=0",
    Connection: "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    DNT: "1",
  };

  // Referer — realistic browsing path
  if (options?.referer) {
    headers["Referer"] = options.referer;
  } else {
    // Randomly appear to arrive from Google search ~40% of the time
    if (Math.random() < 0.4) {
      headers["Referer"] = "https://www.google.com/";
    }
  }

  // Chrome-specific client hints (absent in Firefox/Safari)
  if (isChrome && hints) {
    headers["sec-ch-ua"] = hints.ua;
    headers["sec-ch-ua-mobile"] = "?0";
    headers["sec-ch-ua-platform"] = Math.random() < 0.6
      ? '"Windows"'
      : '"macOS"';
    headers["Sec-Fetch-Dest"] = isNavigation ? "document" : "empty";
    headers["Sec-Fetch-Mode"] = isNavigation ? "navigate" : "cors";
    headers["Sec-Fetch-Site"] = options?.referer ? "cross-site" : "none";
    if (isNavigation) {
      headers["Sec-Fetch-User"] = "?1";
    }
  }

  // Firefox — slightly different header order/values
  if (isFirefox) {
    headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8";
    headers["Sec-Fetch-Dest"] = isNavigation ? "document" : "empty";
    headers["Sec-Fetch-Mode"] = isNavigation ? "navigate" : "cors";
    headers["Sec-Fetch-Site"] = options?.referer ? "cross-site" : "none";
    if (isNavigation) headers["Sec-Fetch-User"] = "?1";
    headers["Priority"] = "u=0, i";
  }

  if (isSafari) {
    headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";
  }

  return headers;
}

/**
 * Headers for a JSON/API request (as opposed to a page navigation).
 * No Sec-Fetch-User, different Accept.
 */
export function getApiHeaders(options?: {
  referer?: string;
}): Record<string, string> {
  return getRandomHeaders({ ...options, isNavigation: false });
}

/** Wait a random amount of time between minMs and maxMs (inclusive). */
export async function randomDelay(
  minMs: number,
  maxMs: number
): Promise<void> {
  const ms = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Realistic Playwright browser context launch options.
 * Mimics a real user's browser environment to avoid bot fingerprinting.
 */
export function getPlaywrightContextOptions(): Parameters<
  import("playwright").Browser["newContext"]
>[0] {
  const ua = USER_AGENTS.filter((u) => u.includes("Chrome/") && !u.includes("Edg/"))[
    Math.floor(Math.random() * 6) // pick from first 6 Chrome UAs
  ];
  const chromeVersion = extractChromeVersion(ua) ?? "131";
  const hints = CHROME_HINTS[chromeVersion];

  // Realistic viewport sizes (common desktop resolutions)
  const viewports = [
    { width: 1920, height: 1080 },
    { width: 1440, height: 900 },
    { width: 1280, height: 800 },
    { width: 1366, height: 768 },
    { width: 1536, height: 864 },
  ];
  const viewport = viewports[Math.floor(Math.random() * viewports.length)];

  return {
    userAgent: ua,
    viewport,
    locale: "en-US",
    timezoneId: "America/Los_Angeles",
    colorScheme: "light",
    deviceScaleFactor: Math.random() < 0.3 ? 2 : 1, // ~30% have HiDPI
    extraHTTPHeaders: {
      "Accept-Language": "en-US,en;q=0.9",
      "sec-ch-ua": hints?.ua ?? "",
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": '"Windows"',
      DNT: "1",
    },
  };
}
