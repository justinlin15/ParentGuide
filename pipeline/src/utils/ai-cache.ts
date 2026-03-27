/**
 * Persistent cache for AI enrichment and honeypot verification results.
 *
 * Saves Claude API call results to disk between pipeline runs so that
 * unchanged events are served from cache instead of calling the API again.
 *
 * Cache file: pipeline/cache/ai-cache.json
 * GitHub Actions restores and saves this file between runs via actions/cache.
 *
 * Cache invalidation strategy:
 * - Enrichment entries expire after CACHE_TTL_DAYS days (default 30)
 * - The cache key includes a hash of the event's title + description + category,
 *   so if an event's content changes the old entry is ignored and reprocessed.
 * - Honeypot verdicts share the same TTL (once plausible, stays plausible unless
 *   the title changes or the entry expires).
 */

import { createHash } from "crypto";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { join } from "path";
import { log } from "./logger.js";

// ─── Config ───────────────────────────────────────────────────────────────────

const CACHE_DIR = join(process.cwd(), "cache");
const CACHE_FILE = join(CACHE_DIR, "ai-cache.json");
const CACHE_TTL_DAYS = 30;

// ─── Types ────────────────────────────────────────────────────────────────────

export interface CachedEnrichment {
  description: string;
  category: string;
  price: string | null;
  ageRange: string | null;
  locationName: string | null;
  address: string | null;
  cachedAt: string;
}

export interface CachedHoneypot {
  plausible: boolean;
  reason: string;
  cachedAt: string;
}

export interface CachedGuideEnrichment {
  description: string;
  address: string | null;
  phone: string | null;
  ageRange: string | null;
  priceLevel: string | null;
  kidsEatFreeVerified: boolean | null;
  dealDetails: string | null;
  cachedAt: string;
}

interface CacheData {
  enrichment: Record<string, CachedEnrichment>;
  honeypot: Record<string, CachedHoneypot>;
  guideEnrichment: Record<string, CachedGuideEnrichment>;
}

// ─── In-memory state ──────────────────────────────────────────────────────────

let cache: CacheData = { enrichment: {}, honeypot: {}, guideEnrichment: {} };
let isDirty = false;

// ─── Lifecycle ────────────────────────────────────────────────────────────────

function load(): void {
  try {
    if (existsSync(CACHE_FILE)) {
      const raw = readFileSync(CACHE_FILE, "utf-8");
      const parsed = JSON.parse(raw) as Partial<CacheData>;
      cache.enrichment = parsed.enrichment ?? {};
      cache.honeypot = parsed.honeypot ?? {};
      cache.guideEnrichment = parsed.guideEnrichment ?? {};
      prune();
      const e = Object.keys(cache.enrichment).length;
      const h = Object.keys(cache.honeypot).length;
      log.info("ai-cache", `Loaded cache: ${e} enrichment + ${h} honeypot entries`);
    } else {
      log.info("ai-cache", "No cache file found — starting fresh");
    }
  } catch (err) {
    log.warn("ai-cache", `Failed to load cache, starting fresh: ${err}`);
    cache = { enrichment: {}, honeypot: {}, guideEnrichment: {} };
  }
}

/** Remove entries older than CACHE_TTL_DAYS. Called on load. */
function prune(): void {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - CACHE_TTL_DAYS);
  const cutoffStr = cutoff.toISOString();

  let pruned = 0;
  for (const key of Object.keys(cache.enrichment)) {
    if ((cache.enrichment[key].cachedAt ?? "") < cutoffStr) {
      delete cache.enrichment[key];
      pruned++;
    }
  }
  for (const key of Object.keys(cache.honeypot)) {
    if ((cache.honeypot[key].cachedAt ?? "") < cutoffStr) {
      delete cache.honeypot[key];
      pruned++;
    }
  }
  for (const key of Object.keys(cache.guideEnrichment)) {
    if ((cache.guideEnrichment[key].cachedAt ?? "") < cutoffStr) {
      delete cache.guideEnrichment[key];
      pruned++;
    }
  }
  if (pruned > 0) {
    log.info("ai-cache", `Pruned ${pruned} expired entries (>${CACHE_TTL_DAYS} days old)`);
    isDirty = true;
  }
}

/** Flush cache to disk. Call once at the end of the pipeline run. */
export function saveAiCache(): void {
  if (!isDirty) {
    log.info("ai-cache", "No changes to save");
    return;
  }
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2), "utf-8");
    const e = Object.keys(cache.enrichment).length;
    const h = Object.keys(cache.honeypot).length;
    log.info("ai-cache", `Saved cache: ${e} enrichment + ${h} honeypot entries`);
  } catch (err) {
    log.warn("ai-cache", `Failed to save cache: ${err}`);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Short stable hash of a string (first 16 hex chars of SHA-256). */
function hash16(input: string): string {
  return createHash("sha256").update(input).digest("hex").slice(0, 16);
}

// ─── Enrichment cache ─────────────────────────────────────────────────────────

/**
 * Cache key for AI enrichment.
 * Includes a hash of the event content so the entry is invalidated
 * whenever the source changes the title, description, or category.
 */
export function enrichmentCacheKey(
  sourceId: string,
  title: string,
  description: string,
  category: string
): string {
  const contentFingerprint = hash16(
    `${title}|${description.slice(0, 300)}|${category}`
  );
  return `${sourceId}:${contentFingerprint}`;
}

export function getCachedEnrichment(key: string): CachedEnrichment | null {
  return cache.enrichment[key] ?? null;
}

export function setCachedEnrichment(
  key: string,
  entry: Omit<CachedEnrichment, "cachedAt">
): void {
  cache.enrichment[key] = { ...entry, cachedAt: new Date().toISOString() };
  isDirty = true;
}

// ─── Honeypot cache ───────────────────────────────────────────────────────────

/**
 * Cache key for honeypot verification.
 * Keyed on sourceId + title hash — if the event title changes the verdict
 * is re-evaluated.
 */
export function honeypotCacheKey(sourceId: string, title: string): string {
  return `${sourceId}:${hash16(title)}`;
}

export function getCachedHoneypot(key: string): CachedHoneypot | null {
  return cache.honeypot[key] ?? null;
}

export function setCachedHoneypot(
  key: string,
  entry: Omit<CachedHoneypot, "cachedAt">
): void {
  cache.honeypot[key] = { ...entry, cachedAt: new Date().toISOString() };
  isDirty = true;
}

// ─── Guide enrichment cache ──────────────────────────────────────────────────

export function guideEnrichmentCacheKey(
  guideId: string,
  name: string,
  city: string,
  category: string
): string {
  const contentFingerprint = hash16(`${name}|${city}|${category}`);
  return `guide:${guideId}:${contentFingerprint}`;
}

export function getCachedGuideEnrichment(
  key: string
): CachedGuideEnrichment | null {
  return cache.guideEnrichment[key] ?? null;
}

export function setCachedGuideEnrichment(
  key: string,
  entry: Omit<CachedGuideEnrichment, "cachedAt">
): void {
  cache.guideEnrichment[key] = {
    ...entry,
    cachedAt: new Date().toISOString(),
  };
  isDirty = true;
}

/**
 * Merge multiple AI cache files into the current in-memory cache.
 * For each key, keeps the entry with the newest cachedAt timestamp.
 * Used by the merge job to combine caches from parallel metro jobs.
 */
export function mergeAiCaches(cacheFiles: string[]): void {
  for (const file of cacheFiles) {
    try {
      if (!existsSync(file)) continue;
      const raw = JSON.parse(readFileSync(file, "utf-8")) as Partial<CacheData>;

      for (const [key, entry] of Object.entries(raw.enrichment ?? {})) {
        if (!cache.enrichment[key] || (cache.enrichment[key].cachedAt ?? "") < (entry.cachedAt ?? "")) {
          cache.enrichment[key] = entry;
        }
      }
      for (const [key, entry] of Object.entries(raw.honeypot ?? {})) {
        if (!cache.honeypot[key] || (cache.honeypot[key].cachedAt ?? "") < (entry.cachedAt ?? "")) {
          cache.honeypot[key] = entry;
        }
      }
      for (const [key, entry] of Object.entries(raw.guideEnrichment ?? {})) {
        if (!cache.guideEnrichment[key] || (cache.guideEnrichment[key].cachedAt ?? "") < (entry.cachedAt ?? "")) {
          cache.guideEnrichment[key] = entry;
        }
      }

      isDirty = true;
      log.info("ai-cache", `Merged cache from ${file}`);
    } catch (err) {
      log.warn("ai-cache", `Failed to merge cache from ${file}: ${err}`);
    }
  }
}

// Load cache immediately on module import
load();
