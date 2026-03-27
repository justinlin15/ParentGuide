import { readFileSync, readdirSync, existsSync } from "fs";
import { join } from "path";
import { type PipelineEvent } from "./normalize.js";
import { deduplicateEvents } from "./deduplicate.js";
import { log } from "./utils/logger.js";

const OUTPUT_DIR = join(process.cwd(), "output");

/**
 * Load all per-metro event files from the output directory and merge them.
 * Files are named `{metro-id}-events.json` (written by single-metro mode).
 */
export function loadPerMetroOutputs(): PipelineEvent[] {
  if (!existsSync(OUTPUT_DIR)) {
    log.warn("merge", `Output directory not found: ${OUTPUT_DIR}`);
    return [];
  }

  const files = readdirSync(OUTPUT_DIR).filter((f) => f.endsWith("-events.json"));
  if (files.length === 0) {
    log.warn("merge", "No per-metro event files found in output/");
    return [];
  }

  const allEvents: PipelineEvent[] = [];

  for (const file of files) {
    const filePath = join(OUTPUT_DIR, file);
    try {
      const events = JSON.parse(readFileSync(filePath, "utf8")) as PipelineEvent[];
      log.info("merge", `Loaded ${events.length} events from ${file}`);
      allEvents.push(...events);
    } catch (err) {
      log.warn("merge", `Failed to load ${file}: ${err}`);
    }
  }

  log.info("merge", `Total events from all metros: ${allEvents.length}`);
  return allEvents;
}

/**
 * Run cross-metro deduplication on merged events.
 * Events from different metros may overlap (e.g., Ticketmaster returns the same
 * event for both OC and LA). The dedup step resolves these using source priority.
 */
export function deduplicateMerged(events: PipelineEvent[]): PipelineEvent[] {
  const before = events.length;
  const deduped = deduplicateEvents(events);
  const removed = before - deduped.length;
  if (removed > 0) {
    log.info("merge", `Cross-metro dedup removed ${removed} duplicates`);
  }
  return deduped;
}
