import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { deduplicateEvents } from "../deduplicate.js";
import { categorizeEvent, cleanDescription } from "../normalize.js";
import { cleanDescriptions } from "../clean-descriptions.js";
import { type PipelineEvent } from "../normalize.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Create a minimal valid PipelineEvent with sensible defaults. */
function makeEvent(overrides: Partial<PipelineEvent> = {}): PipelineEvent {
  return {
    sourceId: "test:1",
    source: "test",
    title: "Untitled Event",
    description: "",
    startDate: "2026-06-15T10:00:00.000Z",
    isAllDay: false,
    category: "other",
    city: "Los Angeles",
    metro: "los-angeles",
    isFeatured: false,
    isRecurring: false,
    tags: [],
    ...overrides,
  };
}

// ===========================================================================
// 1. Deduplication tests
// ===========================================================================

describe("deduplicateEvents", () => {
  it("removes exact duplicates (same title + same date + same city)", () => {
    const events = [
      makeEvent({ sourceId: "a:1", title: "Family Storytime at the Library" }),
      makeEvent({ sourceId: "b:1", title: "Family Storytime at the Library" }),
    ];

    const result = deduplicateEvents(events);
    assert.equal(result.length, 1, "Should deduplicate to 1 event");
  });

  it("deduplicates via fuzzy match when titles are similar and on the same date", () => {
    // Both titles are > 20 chars and one is a substring of the other (after normalization).
    const events = [
      makeEvent({
        sourceId: "a:1",
        title: "Summer Family Music Festival in the Park",
      }),
      makeEvent({
        sourceId: "b:1",
        title: "Summer Family Music Festival in the Park (Free)",
      }),
    ];

    const result = deduplicateEvents(events);
    assert.equal(
      result.length,
      1,
      "Fuzzy match should detect these as the same event"
    );
  });

  it("does NOT deduplicate events on different dates", () => {
    const events = [
      makeEvent({
        sourceId: "a:1",
        title: "Family Storytime at the Library",
        startDate: "2026-06-15T10:00:00.000Z",
      }),
      makeEvent({
        sourceId: "b:1",
        title: "Family Storytime at the Library",
        startDate: "2026-06-16T10:00:00.000Z",
      }),
    ];

    const result = deduplicateEvents(events);
    assert.equal(result.length, 2, "Different dates should remain separate");
  });

  it("skips fuzzy matching for short titles (< 20 chars after normalization)", () => {
    // "Art Class" is < 20 chars, so fuzzy matching is skipped.
    // These have different exact keys (different sourceIds would normally differ,
    // but dedup keys are based on title+date+city, so "Art Class" and "Art Classes"
    // have different normalized titles and should NOT be merged).
    const events = [
      makeEvent({ sourceId: "a:1", title: "Art Class" }),
      makeEvent({ sourceId: "b:1", title: "Art Classes" }),
    ];

    const result = deduplicateEvents(events);
    assert.equal(
      result.length,
      2,
      "Short titles should not be fuzzy-matched, both should remain"
    );
  });

  it("prefers the event with higher completeness score (imageURL)", () => {
    const withoutImage = makeEvent({
      sourceId: "a:1",
      title: "Family Storytime at the Library",
      description: "A wonderful reading event for families.",
    });
    const withImage = makeEvent({
      sourceId: "b:1",
      title: "Family Storytime at the Library",
      description: "A wonderful reading event for families.",
      imageURL: "https://example.com/image.jpg",
    });

    // Regardless of order, the one with the image should win
    const result1 = deduplicateEvents([withoutImage, withImage]);
    assert.equal(result1.length, 1);
    assert.equal(
      result1[0].imageURL,
      "https://example.com/image.jpg",
      "Event with image should be preferred"
    );

    const result2 = deduplicateEvents([withImage, withoutImage]);
    assert.equal(result2.length, 1);
    assert.equal(
      result2[0].imageURL,
      "https://example.com/image.jpg",
      "Event with image should be preferred regardless of input order"
    );
  });

  it("prefers the event with more complete data overall", () => {
    const sparse = makeEvent({
      sourceId: "a:1",
      title: "Family Storytime at the Library",
    });
    const rich = makeEvent({
      sourceId: "b:1",
      title: "Family Storytime at the Library",
      description: "Join us for a wonderful storytime session with crafts.",
      imageURL: "https://example.com/img.jpg",
      latitude: 34.05,
      longitude: -118.25,
      address: "123 Main St",
      locationName: "Central Library",
      externalURL: "https://example.com/event",
    });

    const result = deduplicateEvents([sparse, rich]);
    assert.equal(result.length, 1);
    assert.equal(result[0].sourceId, "b:1", "Richer event should be kept");
  });

  it("does NOT deduplicate events in different cities", () => {
    const events = [
      makeEvent({
        sourceId: "a:1",
        title: "Family Storytime at the Library",
        city: "Los Angeles",
      }),
      makeEvent({
        sourceId: "b:1",
        title: "Family Storytime at the Library",
        city: "New York",
      }),
    ];

    const result = deduplicateEvents(events);
    assert.equal(result.length, 2, "Different cities should remain separate");
  });
});

// ===========================================================================
// 2. Categorization tests
// ===========================================================================

describe("categorizeEvent", () => {
  it('categorizes "storytime" keyword correctly', () => {
    const result = categorizeEvent(
      "Weekly Storytime for Kids",
      "Join us for reading and fun",
    );
    assert.equal(result, "storytime");
  });

  it('categorizes "story time" (two words) correctly', () => {
    const result = categorizeEvent(
      "Story Time at the Library",
      "A fun reading session",
    );
    assert.equal(result, "storytime");
  });

  it('categorizes "farmers market" correctly', () => {
    const result = categorizeEvent(
      "Downtown Farmers Market",
      "Fresh produce and crafts",
    );
    assert.equal(result, "farmersMarket");
  });

  it('categorizes "museum" correctly', () => {
    const result = categorizeEvent(
      "Children\'s Museum Open Day",
      "Explore interactive exhibits",
    );
    assert.equal(result, "museum");
  });

  it('returns "other" for unrecognized content', () => {
    // Note: avoid accidental substring matches (e.g., "party" contains "art" which matches craft)
    const result = categorizeEvent(
      "Neighborhood Potluck Gathering",
      "Come join your neighbors for good times",
    );
    assert.equal(result, "other");
  });

  it("checks sourceCategories for keyword matches too", () => {
    const result = categorizeEvent(
      "Annual Open Event",
      "A fun event for families",
      ["museum admission"],
    );
    assert.equal(result, "museum");
  });

  it("matches keywords in the description, not just the title", () => {
    const result = categorizeEvent(
      "Weekend Fun",
      "Take a hike through the nature trails",
    );
    assert.equal(result, "outdoorAdventure");
  });
});

// ===========================================================================
// 3. Description cleaning tests
// ===========================================================================

describe("cleanDescriptions", () => {
  it("removes promotional language (promo codes)", () => {
    const events = [
      makeEvent({
        description:
          "Great family event. Use code SAVE20 for a discount on tickets. Bring the whole family!",
      }),
    ];

    const result = cleanDescriptions(events);
    // The promo sentence should be removed
    assert.ok(
      !result[0].description.includes("Use code"),
      "Promo code sentence should be removed"
    );
    assert.ok(
      result[0].description.includes("Great family event"),
      "Non-promo content should remain"
    );
  });

  it("removes newsletter signup CTAs", () => {
    const events = [
      makeEvent({
        description:
          "Fun activities for all ages. Sign up for our newsletter to get updates. See you there!",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.ok(
      !result[0].description.includes("Sign up for our newsletter"),
      "Newsletter CTA should be removed"
    );
    assert.ok(
      result[0].description.includes("Fun activities"),
      "Non-promo content should remain"
    );
  });

  it("removes source site name mentions from descriptions", () => {
    const events = [
      makeEvent({
        description:
          "A wonderful event for families. Find more events on Macaroni KID today. Enjoy!",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.ok(
      !result[0].description.includes("Macaroni KID"),
      "Source site name should be removed"
    );
  });

  it("removes OC Parent Guide mentions from descriptions", () => {
    const events = [
      makeEvent({
        description:
          "Awesome craft activity. Visit OC Parent Guide for more events like this. Bring supplies!",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.ok(
      !result[0].description.includes("OC Parent Guide"),
      "OC Parent Guide mention should be removed"
    );
  });

  it("removes MommyPoppins mentions from descriptions", () => {
    const events = [
      makeEvent({
        description:
          "A great outdoor day. Check out MommyPoppins for more ideas. Have fun!",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.ok(
      !result[0].description.includes("MommyPoppins"),
      "MommyPoppins mention should be removed"
    );
  });

  it("removes parenthetical promo text from titles", () => {
    const events = [
      makeEvent({
        title:
          "Kids Art Workshop (Free 1-Month Membership for OC Parent Guide Subscribers!)",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.equal(
      result[0].title,
      "Kids Art Workshop",
      "Parenthetical promo should be removed from title"
    );
  });

  it("preserves clean descriptions unchanged", () => {
    const events = [
      makeEvent({
        description: "A wonderful family-friendly event at the park.",
      }),
    ];

    const result = cleanDescriptions(events);
    assert.equal(
      result[0].description,
      "A wonderful family-friendly event at the park.",
      "Clean description should not be modified"
    );
  });
});

// ===========================================================================
// 4. Description cleaning (normalize.ts cleanDescription)
// ===========================================================================

describe("cleanDescription (HTML + truncation)", () => {
  it("strips HTML tags", () => {
    const result = cleanDescription("<p>Hello <b>world</b></p>");
    assert.equal(result, "Hello world");
  });

  it("decodes HTML entities", () => {
    const result = cleanDescription("Tom &amp; Jerry &lt;3");
    assert.equal(result, "Tom & Jerry <3");
  });

  it("collapses whitespace", () => {
    const result = cleanDescription("Hello   \n\n  world");
    assert.equal(result, "Hello world");
  });

  it("truncates to maxLength", () => {
    const long = "A".repeat(600);
    const result = cleanDescription(long, 500);
    assert.equal(result.length, 500);
  });
});

// ===========================================================================
// 5. Stale event filtering tests
// ===========================================================================

describe("stale event filtering", () => {
  // Replicate the filtering logic from index.ts inline for unit testing
  function filterStaleEvents(events: PipelineEvent[], today: Date): PipelineEvent[] {
    const todayMidnightUTC = new Date(today);
    todayMidnightUTC.setUTCHours(0, 0, 0, 0);
    const todayStr = todayMidnightUTC.toISOString();
    return events.filter((event) => event.startDate >= todayStr);
  }

  const referenceDate = new Date("2026-06-15T12:00:00.000Z");

  it("filters out events that started before today", () => {
    const events = [
      makeEvent({
        sourceId: "past:1",
        title: "Past Event",
        startDate: "2026-06-14T10:00:00.000Z",
      }),
      makeEvent({
        sourceId: "past:2",
        title: "Way Past Event",
        startDate: "2025-01-01T10:00:00.000Z",
      }),
    ];

    const result = filterStaleEvents(events, referenceDate);
    assert.equal(result.length, 0, "All past events should be filtered out");
  });

  it("keeps events happening today", () => {
    const events = [
      makeEvent({
        sourceId: "today:1",
        title: "Today Event",
        startDate: "2026-06-15T10:00:00.000Z",
      }),
    ];

    const result = filterStaleEvents(events, referenceDate);
    assert.equal(result.length, 1, "Events happening today should be kept");
  });

  it("keeps future events", () => {
    const events = [
      makeEvent({
        sourceId: "future:1",
        title: "Future Event",
        startDate: "2026-07-01T10:00:00.000Z",
      }),
      makeEvent({
        sourceId: "future:2",
        title: "Far Future Event",
        startDate: "2027-01-01T10:00:00.000Z",
      }),
    ];

    const result = filterStaleEvents(events, referenceDate);
    assert.equal(result.length, 2, "All future events should be kept");
  });

  it("correctly separates past and future events in a mixed set", () => {
    const events = [
      makeEvent({
        sourceId: "past:1",
        title: "Past Event",
        startDate: "2026-06-14T23:59:59.000Z",
      }),
      makeEvent({
        sourceId: "today:1",
        title: "Today Event",
        startDate: "2026-06-15T00:00:00.000Z",
      }),
      makeEvent({
        sourceId: "future:1",
        title: "Future Event",
        startDate: "2026-06-16T10:00:00.000Z",
      }),
    ];

    const result = filterStaleEvents(events, referenceDate);
    assert.equal(result.length, 2, "Only the past event should be removed");
    assert.ok(
      result.every((e) => e.sourceId !== "past:1"),
      "Past event should not be in results"
    );
  });
});
