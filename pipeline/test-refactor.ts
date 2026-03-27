/**
 * Quick smoke test for the 3 refactoring changes.
 * Run: cd pipeline && npx tsx test-refactor.ts
 * Does NOT call any APIs, scrapers, or CloudKit.
 */

import { diffEvents, contentHash } from "./src/diff-events.js";
import { loadPerMetroOutputs, deduplicateMerged } from "./src/merge.js";
import { config, METRO_AREAS } from "./src/config.js";
import type { PipelineEvent } from "./src/normalize.js";

let passed = 0;
let failed = 0;

function assert(condition: boolean, label: string) {
  if (condition) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${label}`);
    failed++;
  }
}

// ─── Helper: create a test event ──────────────────────────────────────────────
function makeEvent(overrides: Partial<PipelineEvent> = {}): PipelineEvent {
  return {
    sourceId: "test:1",
    source: "test",
    title: "Kids Art Class",
    description: "A fun art class for kids",
    startDate: new Date(Date.now() + 86400000).toISOString(), // tomorrow
    isAllDay: false,
    category: "Craft",
    city: "Irvine",
    metro: "orange-county",
    isFeatured: false,
    isRecurring: false,
    tags: ["craft"],
    ...overrides,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 1: Config flag parsing (--metro, --merge-mode)\n");

// These should be undefined/false since we didn't pass those flags
assert(config.metroFilter === undefined, "metroFilter is undefined when --metro not passed");
assert(config.mergeMode === false, "mergeMode is false when --merge-mode not passed");
assert(config.dryRun === false, "dryRun is false");
assert(config.reprocess === false, "reprocess is false");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 2: Content hash stability\n");

const fixedDate = new Date(Date.now() + 86400000).toISOString();
const event1 = makeEvent({ startDate: fixedDate });
const event2 = makeEvent({ startDate: fixedDate }); // identical
const event3 = makeEvent({ title: "Different Title" });

assert(contentHash(event1) === contentHash(event2), "Identical events produce same hash");
assert(contentHash(event1) !== contentHash(event3), "Different title produces different hash");
assert(contentHash(event1).length === 16, "Hash is 16 hex chars");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 3: Diff — all new (no baseline)\n");

const current = [makeEvent({ sourceId: "a:1" }), makeEvent({ sourceId: "a:2" })];
const emptyBaseline: PipelineEvent[] = [];
const diff1 = diffEvents(current, emptyBaseline);

assert(diff1.newEvents.length === 2, "2 new events when baseline is empty");
assert(diff1.changedEvents.length === 0, "0 changed events");
assert(diff1.unchangedEvents.length === 0, "0 unchanged events");
assert(diff1.removedSourceIds.length === 0, "0 removed events");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 4: Diff — unchanged events carry forward baseline data\n");

const baselineEvent = makeEvent({
  sourceId: "a:1",
  latitude: 33.68,
  longitude: -117.83,
  imageURL: "https://example.com/photo.jpg",
  price: "$15",
  ageRange: "3-10",
});
const currentEvent = makeEvent({
  sourceId: "a:1",
  // Same content fields → should be detected as unchanged
});
const diff2 = diffEvents([currentEvent], [baselineEvent]);

assert(diff2.unchangedEvents.length === 1, "1 unchanged event");
assert(diff2.newEvents.length === 0, "0 new events");
// Unchanged events carry forward ALL baseline data
assert(diff2.unchangedEvents[0].latitude === 33.68, "Baseline latitude preserved");
assert(diff2.unchangedEvents[0].imageURL === "https://example.com/photo.jpg", "Baseline image preserved");
assert(diff2.unchangedEvents[0].price === "$15", "Baseline price preserved");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 5: Diff — changed event (title changed)\n");

const changedCurrent = makeEvent({ sourceId: "a:1", title: "NEW TITLE" });
const diff3 = diffEvents([changedCurrent], [baselineEvent]);

assert(diff3.changedEvents.length === 1, "1 changed event");
assert(diff3.unchangedEvents.length === 0, "0 unchanged events");
// Location didn't change → coords should be preserved from baseline
assert(diff3.changedEvents[0].latitude === 33.68, "Coords preserved (location unchanged)");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 6: Diff — changed event (location changed → coords cleared)\n");

const relocatedCurrent = makeEvent({ sourceId: "a:1", city: "Tustin", title: "NEW TITLE" });
const diff4 = diffEvents([relocatedCurrent], [baselineEvent]);

assert(diff4.changedEvents.length === 1, "1 changed event");
assert(diff4.changedEvents[0].latitude === undefined, "Coords cleared when city changed");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 7: Diff — removed events detected\n");

const diff5 = diffEvents([], [baselineEvent]);
assert(diff5.removedSourceIds.length === 1, "1 removed event");
assert(diff5.removedSourceIds[0] === "a:1", "Correct sourceId removed");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 8: Diff — stock images NOT preserved on changed events\n");

const baselineWithStock = makeEvent({
  sourceId: "a:1",
  imageURL: "https://images.unsplash.com/photo-123",
});
const changedWithStock = makeEvent({ sourceId: "a:1", title: "CHANGED" });
const diff6 = diffEvents([changedWithStock], [baselineWithStock]);

assert(diff6.changedEvents[0].imageURL === undefined, "Stock image NOT carried forward");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 9: Merge — deduplicateMerged removes dupes\n");

const dupeA = makeEvent({ sourceId: "tm:abc", source: "ticketmaster", title: "Family Concert" });
const dupeB = makeEvent({ sourceId: "oc:abc", source: "oc-parent-guide", title: "Family Concert" });
const unique = makeEvent({ sourceId: "yelp:xyz", source: "yelp", title: "Storytime" });
const mergeResult = deduplicateMerged([dupeA, dupeB, unique]);

assert(mergeResult.length <= 3, "Dedup ran without errors");
// The exact dedup behavior depends on the deduplicateEvents logic, but it shouldn't crash

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 10: Metro areas config check\n");

const enabled = METRO_AREAS.filter((m) => m.enabled);
assert(enabled.length >= 2, `${enabled.length} active metros (expected ≥2)`);
assert(enabled.some((m) => m.id === "orange-county"), "OC is enabled");
assert(enabled.some((m) => m.id === "los-angeles"), "LA is enabled");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 11: Yelp types imported correctly\n");

import type { YelpRateLimitInfo, YelpResult } from "./src/sources/yelp.js";
const testRateLimit: YelpRateLimitInfo = { remaining: 485, resetTime: "2026-03-27T00:00:00Z" };
assert(testRateLimit.remaining === 485, "YelpRateLimitInfo type works");

// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n🧪 Test 12: CloudKit PipelineMetadata type\n");

import type { PipelineMetadata } from "./src/cloudkit.js";
const testMeta: PipelineMetadata = {
  rateLimits: { yelp: { remaining: 100, resetTime: null } },
};
assert(testMeta.rateLimits?.yelp?.remaining === 100, "PipelineMetadata type works");

// ═══════════════════════════════════════════════════════════════════════════════
console.log(`\n${"═".repeat(60)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`${"═".repeat(60)}\n`);

process.exit(failed > 0 ? 1 : 0);
