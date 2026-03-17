#!/usr/bin/env npx tsx
/**
 * Standalone script: fill missing event images via Pexels, then patch CloudKit.
 *
 * Usage (runs on GitHub Actions):
 *   npx tsx src/fill-images-only.ts
 *
 * Reads the last pipeline output (output/all-events.json or fetches from CloudKit),
 * finds events with no imageURL, searches Pexels for images, and uploads
 * only the patched records back to CloudKit.
 */

import "dotenv/config";
import { readFile, writeFile } from "fs/promises";
import { join } from "path";
import { config } from "./config.js";
import { log } from "./utils/logger.js";
import { delay } from "./utils/geocoder.js";

const PEXELS_BASE = "https://api.pexels.com/v1";

// Category → search keywords (matches images.ts)
const CATEGORY_SEARCH_TERMS: Record<string, string> = {
  Storytime: "children reading books library",
  "Farmers Market": "farmers market family outdoor",
  "Free Movie": "family movie night cinema",
  "Toddler Activity": "toddler playing activity",
  Craft: "kids arts crafts painting",
  Music: "family music concert kids",
  "Fire Station Tour": "fire station tour kids",
  Museum: "children museum exhibit",
  Outdoor: "family outdoor hiking nature",
  "Food & Dining": "family cooking kids food",
  Sports: "kids sports activity",
  Education: "children learning classroom stem",
  Festival: "family festival fair carnival",
  Seasonal: "family holiday celebration",
  Other: "family kids activity fun",
};

interface PexelsPhoto {
  src: { large: string; medium: string };
  alt?: string;
}

interface PexelsResult {
  photos: PexelsPhoto[];
  total_results: number;
}

// Simple Pexels search
async function searchPexels(query: string, perPage = 5): Promise<string[]> {
  if (!config.pexels.apiKey) {
    log.error("pexels", "PEXELS_API_KEY not set");
    process.exit(1);
  }

  const params = new URLSearchParams({
    query,
    per_page: String(perPage),
    orientation: "landscape",
  });

  const res = await fetch(`${PEXELS_BASE}/search?${params}`, {
    headers: { Authorization: config.pexels.apiKey },
    signal: AbortSignal.timeout(10000),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    log.warn("pexels", `HTTP ${res.status}: ${body.slice(0, 100)}`);
    return [];
  }

  const data = (await res.json()) as PexelsResult;
  return data.photos.map((p) => p.src.large);
}

// Cache for category images
const categoryCache = new Map<string, string[]>();

async function getCategoryImages(category: string): Promise<string[]> {
  const cached = categoryCache.get(category);
  if (cached) return cached;

  const term = CATEGORY_SEARCH_TERMS[category] || CATEGORY_SEARCH_TERMS["Other"];
  const images = await searchPexels(term, 10);
  await delay(1200);

  if (images.length > 0) categoryCache.set(category, images);
  return images;
}

// Build search query from title
function buildSearchQuery(title: string): string | null {
  const cleaned = title
    .replace(/presents?:?\s*/gi, "")
    .replace(/\b(the|a|an|at|in|on|for|and|of|with)\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned.length >= 5 ? cleaned : null;
}

// ─── CloudKit patch (only update imageURL) ───────────────────────────────────

import { createSign, createHash } from "crypto";

function signRequest(date: string, body: string, subpath: string, pem: string): string {
  const bodyHash = createHash("sha256").update(body, "utf-8").digest("base64");
  const message = `${date}:${bodyHash}:${subpath}`;
  const sign = createSign("SHA256");
  sign.update(message);
  return sign.sign(pem, "base64");
}

async function patchCloudKit(
  records: Array<{ recordName: string; imageURL: string }>,
  privateKeyPem: string
): Promise<{ saved: number; errors: number }> {
  const env = config.cloudkit.environment;
  const container = config.cloudkit.container;
  const subpath = `/database/1/${container}/${env}/public/records/modify`;

  const operations = records.map((r) => ({
    operationType: "forceUpdate" as const,
    record: {
      recordType: "Event",
      recordName: r.recordName,
      fields: {
        imageURL: { value: r.imageURL },
      },
    },
  }));

  const bodyStr = JSON.stringify({ operations });
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const signature = signRequest(date, bodyStr, subpath, privateKeyPem);

  const resp = await fetch(`https://api.apple-cloudkit.com${subpath}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Apple-CloudKit-Request-KeyID": config.cloudkit.keyId,
      "X-Apple-CloudKit-Request-ISO8601Date": date,
      "X-Apple-CloudKit-Request-SignatureV1": signature,
    },
    body: bodyStr,
    signal: AbortSignal.timeout(60000),
  });

  if (!resp.ok) {
    const text = await resp.text();
    log.error("cloudkit", `Patch failed ${resp.status}: ${text.slice(0, 200)}`);
    return { saved: 0, errors: records.length };
  }

  const result = await resp.json();
  let saved = 0, errors = 0;
  for (const rec of (result as any).records || []) {
    if (rec.serverErrorCode) errors++;
    else saved++;
  }
  return { saved, errors };
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  log.info("fill-images", "=== Fill Missing Images (Pexels only) ===");

  // Load events from last pipeline output
  const outputPath = join(process.cwd(), "output", "all-events.json");
  let events: any[];
  try {
    const raw = await readFile(outputPath, "utf-8");
    events = JSON.parse(raw);
  } catch {
    log.error("fill-images", `Cannot read ${outputPath} — run the pipeline first`);
    process.exit(1);
  }

  // Find events without images
  const needImages = events.filter((e: any) => !e.imageURL || e.imageURL === "");
  log.info("fill-images", `${needImages.length} events missing images out of ${events.length} total`);

  if (needImages.length === 0) {
    log.success("fill-images", "All events already have images!");
    return;
  }

  // Track what we fill
  const patches: Array<{ recordName: string; imageURL: string }> = [];
  const eventImageCache = new Map<string, string[]>();

  // Step 1: Event-specific search (venue name or title)
  let specificFilled = 0;
  for (const event of needImages) {
    const venueQuery = event.locationName
      ? `${event.locationName} ${event.city || ""}`
      : null;
    const titleQuery = buildSearchQuery(event.title);

    if (venueQuery) {
      const cacheKey = venueQuery.toLowerCase().slice(0, 50);
      let images = eventImageCache.get(cacheKey);
      if (!images) {
        images = await searchPexels(venueQuery + " family kids", 3);
        eventImageCache.set(cacheKey, images);
        await delay(1200);
      }
      if (images.length > 0) {
        event.imageURL = images[0];
        specificFilled++;
        continue;
      }
    }

    if (titleQuery) {
      const cacheKey = titleQuery.toLowerCase().slice(0, 50);
      let images = eventImageCache.get(cacheKey);
      if (!images) {
        images = await searchPexels(titleQuery + " family kids", 3);
        eventImageCache.set(cacheKey, images);
        await delay(1200);
      }
      if (images.length > 0) {
        event.imageURL = images[0];
        specificFilled++;
        continue;
      }
    }
  }
  log.info("fill-images", `Event-specific search filled ${specificFilled} images`);

  // Step 2: Category-based fallback
  const stillNeed = needImages.filter((e: any) => !e.imageURL);
  let catFilled = 0;

  const byCategory = new Map<string, any[]>();
  for (const event of stillNeed) {
    const cat = event.category || "Other";
    const list = byCategory.get(cat) || [];
    list.push(event);
    byCategory.set(cat, list);
  }

  for (const [category, catEvents] of byCategory) {
    const images = await getCategoryImages(category);
    if (images.length === 0) continue;
    for (let i = 0; i < catEvents.length; i++) {
      catEvents[i].imageURL = images[i % images.length];
      catFilled++;
    }
  }
  log.info("fill-images", `Category fallback filled ${catFilled} images`);

  // Collect all patches
  for (const event of needImages) {
    if (event.imageURL) {
      const recordName = (event.sourceId || "").replace(/[^a-zA-Z0-9_-]/g, "_");
      if (recordName) {
        patches.push({ recordName, imageURL: event.imageURL });
      }
    }
  }

  const totalFilled = specificFilled + catFilled;
  log.success("fill-images", `Total: ${totalFilled}/${needImages.length} images filled`);

  // Upload patches to CloudKit
  if (patches.length > 0 && !config.dryRun) {
    if (!config.cloudkit.container || !config.cloudkit.keyId) {
      log.warn("fill-images", "CloudKit not configured — skipping upload");
    } else {
      let privateKeyPem: string;
      try {
        privateKeyPem = config.cloudkit.privateKey ||
          (config.cloudkit.privateKeyPath
            ? await readFile(config.cloudkit.privateKeyPath, "utf-8")
            : "");
        if (!privateKeyPem) throw new Error("No private key");
      } catch {
        log.warn("fill-images", "CloudKit private key not available — skipping upload");
        return;
      }

      log.info("fill-images", `Uploading ${patches.length} image patches to CloudKit...`);
      const BATCH = 200;
      let totalSaved = 0, totalErrors = 0;

      for (let i = 0; i < patches.length; i += BATCH) {
        const batch = patches.slice(i, i + BATCH);
        const batchNum = Math.floor(i / BATCH) + 1;
        const totalBatches = Math.ceil(patches.length / BATCH);
        const { saved, errors } = await patchCloudKit(batch, privateKeyPem);
        totalSaved += saved;
        totalErrors += errors;
        log.info("fill-images", `  Batch ${batchNum}/${totalBatches}: ${saved} saved, ${errors} errors`);
        if (i + BATCH < patches.length) await delay(500);
      }

      log.success("fill-images", `CloudKit upload: ${totalSaved} patched, ${totalErrors} errors`);
    }
  } else if (config.dryRun) {
    log.info("fill-images", `[DRY RUN] Would patch ${patches.length} records`);
  }

  // Save updated events back to output
  await writeFile(outputPath, JSON.stringify(events, null, 2));
  log.info("fill-images", `Updated ${outputPath}`);
}

main().catch((err) => {
  log.error("fill-images", `Fatal: ${err}`);
  process.exit(1);
});
