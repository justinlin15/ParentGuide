import { createHash } from "crypto";
import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

export interface DiffResult {
  /** Events with a sourceId not present in the baseline */
  newEvents: PipelineEvent[];
  /** Events whose content hash changed — carries current scrape data */
  changedEvents: PipelineEvent[];
  /** Events unchanged from baseline — carries baseline data (already enriched) */
  unchangedEvents: PipelineEvent[];
  /** sourceIds present in baseline but absent from current scrape */
  removedSourceIds: string[];
}

/**
 * Compute a content hash for change detection.
 * Includes only "input" fields that would require reprocessing if changed.
 * Excludes "output" fields (imageURL, lat/lon, enriched price, etc.)
 * that are the RESULT of pipeline processing.
 */
export function contentHash(event: PipelineEvent): string {
  const payload = [
    event.title,
    event.description,
    event.startDate,
    event.endDate ?? "",
    event.category,
    event.locationName ?? "",
    event.city,
  ].join("|");
  return createHash("sha256").update(payload).digest("hex").slice(0, 16);
}

/**
 * Hash only location-related fields to detect whether geocoding needs to re-run.
 */
function locationHash(event: PipelineEvent): string {
  return [event.locationName ?? "", event.city, event.address ?? ""].join("|");
}

/**
 * Stock-photo CDN hostnames — images from these should not be preserved
 * as "existing" during incremental runs (they'd block fetching real venue photos).
 */
function isStockImage(url: string): boolean {
  try {
    const host = new URL(url).hostname;
    return host.includes("unsplash.com") || host.includes("images.pexels.com");
  } catch {
    return false;
  }
}

/**
 * Diff current scraped events against a baseline from the previous run.
 *
 * For changed events, selectively preserves expensive-to-compute fields
 * from the baseline when those fields' inputs haven't changed:
 * - Coordinates: preserved if locationName+city+address unchanged
 * - Images: preserved if not a stock photo
 */
export function diffEvents(
  currentEvents: PipelineEvent[],
  baselineEvents: PipelineEvent[]
): DiffResult {
  const baselineMap = new Map<string, PipelineEvent>();
  const baselineHashes = new Map<string, string>();

  for (const event of baselineEvents) {
    baselineMap.set(event.sourceId, event);
    baselineHashes.set(event.sourceId, contentHash(event));
  }

  const newEvents: PipelineEvent[] = [];
  const changedEvents: PipelineEvent[] = [];
  const unchangedEvents: PipelineEvent[] = [];
  const seenSourceIds = new Set<string>();

  for (const current of currentEvents) {
    seenSourceIds.add(current.sourceId);
    const baseline = baselineMap.get(current.sourceId);

    if (!baseline) {
      newEvents.push(current);
      continue;
    }

    const currentHash = contentHash(current);
    const prevHash = baselineHashes.get(current.sourceId)!;

    if (currentHash === prevHash) {
      // Unchanged — carry forward the fully-processed baseline version
      unchangedEvents.push(baseline);
    } else {
      // Changed — selectively preserve expensive fields from baseline
      const locUnchanged = locationHash(current) === locationHash(baseline);

      if (locUnchanged && baseline.latitude && baseline.longitude) {
        current.latitude = baseline.latitude;
        current.longitude = baseline.longitude;
      }

      if (baseline.imageURL && !isStockImage(baseline.imageURL)) {
        current.imageURL = baseline.imageURL;
      }

      changedEvents.push(current);
    }
  }

  // Removed = in baseline but not in current scrape
  const removedSourceIds = baselineEvents
    .filter((e) => !seenSourceIds.has(e.sourceId))
    .map((e) => e.sourceId);

  log.info("diff", `New: ${newEvents.length}, Changed: ${changedEvents.length}, Unchanged: ${unchangedEvents.length}, Removed: ${removedSourceIds.length}`);

  return { newEvents, changedEvents, unchangedEvents, removedSourceIds };
}
