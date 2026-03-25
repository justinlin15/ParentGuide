import { type PipelineEvent, isAggregatorSource } from "./normalize.js";
import { log } from "./utils/logger.js";

/**
 * Rewrite event descriptions to make them unique and original.
 * Uses deterministic template-based paraphrasing seeded by sourceId.
 */
export function rewriteDescriptions(events: PipelineEvent[]): PipelineEvent[] {
  let rewritten = 0;

  const result = events.map((event) => {
    // Only rewrite aggregator content — direct sources keep original descriptions
    if (!isAggregatorSource(event.source)) {
      // Still generate a brief description if completely missing
      if (!event.description || event.description.length < 5) {
        return { ...event, description: generateBriefDescription(event) };
      }
      return event;
    }

    if (!event.description || event.description.length < 20) {
      // Too short to rewrite — generate a brief description from title
      return {
        ...event,
        description: generateBriefDescription(event),
      };
    }

    const seed = hashCode(event.sourceId);
    const newDesc = rewriteDescription(event.description, event, seed);

    if (newDesc !== event.description) rewritten++;
    return { ...event, description: newDesc };
  });

  log.info("rewrite", `Rewrote ${rewritten} descriptions`);
  return result;
}

// ─── Rewriting Engine ───────────────────────────────────────────────────────

function rewriteDescription(
  description: string,
  event: PipelineEvent,
  seed: number
): string {
  let text = description;

  // Step 1: Apply phrase swaps
  text = applyPhraseSwaps(text, seed);

  // Step 2: Vary sentence starters
  text = varySentenceStarters(text, seed);

  // Step 3: Add a contextual intro if the description is short
  if (text.length < 100) {
    text = addContextualIntro(text, event, seed);
  }

  // Step 4: Clean up
  text = text
    .replace(/\s{2,}/g, " ")
    .replace(/\.\s*\./g, ".")
    .trim();

  // Ensure it doesn't end abruptly
  if (text.length > 0 && !/[.!?]$/.test(text)) {
    text += ".";
  }

  return text;
}

// ─── Phrase Swaps ───────────────────────────────────────────────────────────

const PHRASE_SWAPS: Array<[RegExp, string[]]> = [
  [
    /\bjoin us for\b/gi,
    ["Come enjoy", "Bring the family to", "Don't miss", "Head out to", "Experience"],
  ],
  [
    /\bdon'?t miss\b/gi,
    ["Be sure to check out", "Come enjoy", "Mark your calendar for", "Plan to attend"],
  ],
  [
    /\bfree and open to the public\b/gi,
    ["no cost to attend", "free for all families", "open to everyone at no charge", "free admission for all"],
  ],
  [
    /\bfree admission\b/gi,
    ["no entry fee", "complimentary admission", "free to attend", "no cost to enter"],
  ],
  [
    /\bfree event\b/gi,
    ["no-cost event", "complimentary event", "free family outing", "no-charge gathering"],
  ],
  [
    /\bkids of all ages\b/gi,
    ["children of every age", "the whole family", "kids young and old", "families with children of all ages"],
  ],
  [
    /\bfun for the whole family\b/gi,
    ["a great time for everyone", "enjoyable for all ages", "perfect for families", "family-friendly fun"],
  ],
  [
    /\bgreat for families\b/gi,
    ["perfect for families", "ideal for families", "wonderful for the whole family", "a family favorite"],
  ],
  [
    /\bcome out and\b/gi,
    ["Head over and", "Stop by and", "Swing by to", "Plan to"],
  ],
  [
    /\bring the kids\b/gi,
    ["bring the little ones", "bring your children", "come with the family", "bring the whole crew"],
  ],
  [
    /\bfamily[- ]friendly\b/gi,
    ["great for families", "perfect for all ages", "welcoming to families", "kid-friendly"],
  ],
  [
    /\bactivities include\b/gi,
    ["you can look forward to", "highlights include", "the lineup features", "planned activities feature"],
  ],
  [
    /\bfor more information\b/gi,
    ["for full details", "to learn more", "for additional info", "for the complete scoop"],
  ],
  [
    /\bmark your calendars?\b/gi,
    ["save the date", "pencil this in", "plan ahead for", "put this on your schedule"],
  ],
  [
    /\bthis (?:exciting |special )?event\b/gi,
    ["this outing", "this gathering", "this activity", "this occasion"],
  ],
  [
    /\bplease (?:join|come|visit)\b/gi,
    ["we invite you to", "families are welcome to", "feel free to", "you're invited to"],
  ],
];

function applyPhraseSwaps(text: string, seed: number): string {
  let result = text;
  let swapSeed = seed;

  for (const [pattern, replacements] of PHRASE_SWAPS) {
    result = result.replace(pattern, (match) => {
      const idx = Math.abs(swapSeed++) % replacements.length;
      const replacement = replacements[idx];
      // Preserve original capitalization
      if (match[0] === match[0].toUpperCase()) {
        return replacement.charAt(0).toUpperCase() + replacement.slice(1);
      }
      return replacement;
    });
  }

  return result;
}

// ─── Sentence Starter Variation ─────────────────────────────────────────────

const SENTENCE_STARTERS: string[] = [
  "Families can enjoy",
  "This is a wonderful opportunity to",
  "Gather the family and",
  "Looking for something fun?",
  "Here's a great outing:",
  "Perfect for a family day out —",
  "A fantastic option for families:",
  "Treat the kids to",
];

function varySentenceStarters(text: string, seed: number): string {
  const sentences = text.split(/(?<=[.!?])\s+/);
  if (sentences.length < 2) return text;

  // Only modify the first sentence if it starts with a generic opener
  const genericOpeners = /^(?:This is|Come to|Welcome to|Visit|Check out|Enjoy)\b/i;
  if (genericOpeners.test(sentences[0])) {
    const idx = Math.abs(seed) % SENTENCE_STARTERS.length;
    const starter = SENTENCE_STARTERS[idx];
    // Replace just the opener portion
    sentences[0] = sentences[0].replace(genericOpeners, starter);
  }

  return sentences.join(" ");
}

// ─── Generate Brief Description ─────────────────────────────────────────────

const BRIEF_TEMPLATES = [
  (e: PipelineEvent) =>
    `Enjoy ${e.title} in ${e.city}. A wonderful ${getCategoryLabel(e.category)} event for the whole family.`,
  (e: PipelineEvent) =>
    `Head to ${e.city} for ${e.title}. This ${getCategoryLabel(e.category)} event is perfect for families looking for a fun outing.`,
  (e: PipelineEvent) =>
    `${e.title} is taking place in ${e.city}. Bring the kids for a memorable ${getCategoryLabel(e.category)} experience.`,
  (e: PipelineEvent) =>
    `Discover ${e.title} in ${e.city}. A great ${getCategoryLabel(e.category)} activity the whole family will love.`,
  (e: PipelineEvent) =>
    `Plan a family trip to ${e.title} in ${e.city}. This ${getCategoryLabel(e.category)} event offers something special for everyone.`,
  (e: PipelineEvent) =>
    `Looking for family fun in ${e.city}? Check out ${e.title}, a ${getCategoryLabel(e.category)} event the kids will enjoy.`,
];

function generateBriefDescription(event: PipelineEvent): string {
  const seed = hashCode(event.sourceId);
  const idx = Math.abs(seed) % BRIEF_TEMPLATES.length;
  return BRIEF_TEMPLATES[idx](event);
}

function addContextualIntro(
  text: string,
  event: PipelineEvent,
  seed: number
): string {
  const intros = [
    `Happening in ${event.city}: `,
    `In ${event.city}, families can look forward to this: `,
    `Here's what's coming up in ${event.city}: `,
    `A fun option for families in ${event.city}: `,
  ];
  const idx = Math.abs(seed) % intros.length;
  return intros[idx] + text;
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function getCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    storytime: "reading",
    farmersMarket: "farmers market",
    freeMovie: "movie",
    toddlerActivity: "toddler-friendly",
    craft: "arts and crafts",
    music: "music",
    fireStationTour: "fire station",
    museum: "museum",
    outdoorAdventure: "outdoor",
    food: "food",
    sports: "sports",
    education: "educational",
    festival: "festival",
    seasonal: "seasonal",
    other: "family",
  };
  return labels[category] || "family";
}

function hashCode(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0; // Convert to 32-bit integer
  }
  return hash;
}
