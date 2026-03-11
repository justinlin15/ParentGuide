import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

// Source site names and their variations — sentences mentioning these get removed
const SOURCE_SITES = [
  "OC Parent Guide",
  "OC ParentGuide",
  "ocparentguide",
  "Orange County Parent Guide",
  "Macaroni KID",
  "Macaroni Kid",
  "MacaroniKid",
  "macaronikid",
  "MommyPoppins",
  "Mommy Poppins",
  "mommypoppins",
  "DFW Child",
  "dfwchild",
  "Atlanta Parent",
  "atlantaparent",
  "MyKidList",
  "mykidlist",
  "NYC Family",
  "New York Family",
  "newyorkfamily",
];

// Regex patterns that match promotional sentences/phrases
const PROMO_PATTERNS: RegExp[] = [
  // Site-specific membership/subscription promos
  /\b(?:free|get)\s+\d+[\s-]*month\s+membership[^.!?\n]*[.!?\n]?/gi,
  /\buse\s+code\s+\S+\s+for\s+[^.!?\n]*[.!?\n]?/gi,
  /\bpromo(?:tion(?:al)?)?\s+code[^.!?\n]*[.!?\n]?/gi,
  /\bcoupon\s+code[^.!?\n]*[.!?\n]?/gi,
  /\bdiscount\s+code[^.!?\n]*[.!?\n]?/gi,

  // Newsletter/signup CTAs
  /\bsign\s+up\s+for\s+(?:our|the)\s+(?:newsletter|mailing\s+list|email)[^.!?\n]*[.!?\n]?/gi,
  /\bjoin\s+(?:our|the)\s+(?:newsletter|mailing\s+list|email\s+list)[^.!?\n]*[.!?\n]?/gi,
  /\bsubscribe\s+(?:to|for)\s+(?:our|the|more)[^.!?\n]*[.!?\n]?/gi,
  /\bfollow\s+us\s+on\s+(?:social\s+media|instagram|facebook|twitter)[^.!?\n]*[.!?\n]?/gi,

  // Referral/affiliate language
  /\baffiliate\s+link[^.!?\n]*[.!?\n]?/gi,
  /\bsponsored\s+(?:post|content|by)[^.!?\n]*[.!?\n]?/gi,

  // "Members get..." / "Subscribers receive..."
  /\b(?:members?|subscribers?)\s+(?:get|receive|enjoy|can)[^.!?\n]*[.!?\n]?/gi,
];

// Build a regex that matches any sentence containing a source site name
function buildSourceSitePattern(): RegExp {
  const escaped = SOURCE_SITES.map((s) =>
    s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  );
  // Match a sentence (or clause) that contains any source site name
  return new RegExp(
    `[^.!?\\n]*\\b(?:${escaped.join("|")})\\b[^.!?\\n]*[.!?\\n]?`,
    "gi"
  );
}

const SOURCE_SITE_PATTERN = buildSourceSitePattern();

/**
 * Clean promotional and source-specific language from all event descriptions and titles.
 */
export function cleanDescriptions(events: PipelineEvent[]): PipelineEvent[] {
  let totalCleaned = 0;

  const cleaned = events.map((event) => {
    const originalDesc = event.description;
    const originalTitle = event.title;

    let desc = cleanText(event.description);
    let title = cleanTitle(event.title);

    if (desc !== originalDesc || title !== originalTitle) {
      totalCleaned++;
    }

    return { ...event, description: desc, title };
  });

  if (totalCleaned > 0) {
    log.info("clean", `Cleaned promotional language from ${totalCleaned} events`);
  }

  return cleaned;
}

function cleanText(text: string): string {
  if (!text) return text;

  let result = text;

  // Remove sentences that mention source sites
  result = result.replace(SOURCE_SITE_PATTERN, "");

  // Remove promotional patterns
  for (const pattern of PROMO_PATTERNS) {
    result = result.replace(pattern, "");
  }

  // Clean up whitespace artifacts
  result = result
    .replace(/\s{2,}/g, " ") // collapse multiple spaces
    .replace(/\.\s*\./g, ".") // fix double periods
    .replace(/^\s*[.!?]\s*/g, "") // remove leading punctuation
    .replace(/\s+([.!?,])/g, "$1") // fix space before punctuation
    .trim();

  return result;
}

function cleanTitle(title: string): string {
  if (!title) return title;

  let result = title;

  // Remove parenthetical promo text from titles
  // e.g., "(Free 1-Month Membership for OC Parent Guide Subscribers!)"
  result = result.replace(
    /\s*\([^)]*(?:membership|subscriber|coupon|code|discount|OC Parent Guide|Macaroni KID|MommyPoppins)[^)]*\)/gi,
    ""
  );

  // Remove trailing promo phrases after dash/hyphen
  result = result.replace(
    /\s*[-–—]\s*(?:free\s+(?:for|with)\s+)?(?:OC Parent Guide|Macaroni KID|MommyPoppins|subscribers?|members?)[^]*$/gi,
    ""
  );

  return result.trim();
}
