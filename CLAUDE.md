# ParentGuide App

## Goal
The goal of the app is to function similar to https://www.orangecountyparentguide.com which is to help families explore the local areas by giving them curated recommendations for playgrounds, restaurants, library programs, travel destinations, and localized events.

## Launch Metros
- Phase 1: Orange County + Los Angeles only
- Other metros (NYC, Dallas, Chicago, Atlanta) are in code but disabled

## Data Pipeline

### Architecture
- **Location:** Runs on GitHub Actions (online), not locally
- **Schedule:** Twice daily at 5:17 AM and 6:18 PM UTC, plus random 0–5 min jitter (scheduled runs only)
- **Manual trigger:** GitHub Actions tab → "Event Pipeline" → "Run workflow"
- **Dry run:** Pass `--dry-run` to skip CloudKit upload and write to `pipeline/output/`
- **Reprocess run:** Pass `--reprocess` (or check "reprocess" in the workflow_dispatch UI) to skip scraping, re-enrich/re-geocode/re-image existing events and upload — useful for testing pipeline improvements without hitting source sites

### Pipeline Flow
1. **Scrape** — APIs (Ticketmaster, SeatGeek, Yelp, Eventbrite) + scrapers (OC Parent Guide, Kidsguide, MommyPoppins, MacaroniKid)
2. **Reassign metros** — Split LA/OC events based on city names and coordinates
3. **Deduplicate** — Remove duplicate events with same title, date, etc.
4. **Clean descriptions** — Strip promotional language
5. **Rewrite descriptions** — Template-based paraphrasing (fast pre-pass before AI)
6. **Enrich** — Sanitize URLs, extract prices via regex, strip scraper tags
7. **Content filter** — Remove adult/21+/18+ events, known adult comedy venues (Irvine Improv, Brea Improv, Comedy Store, Laugh Factory, etc.), Yelp Elite community meetups (UYE prefix), and multi-location guide articles
8. **AI Enrichment** — Claude Sonnet rewrites descriptions, validates categories, corrects locationName/address using world knowledge, extracts missing price/ageRange. Results cached by `sourceId + content hash` to skip unchanged events on future runs.
9. **Post-AI sanity checks** — Rule-based fixes: "Free Movie" category requires free price; title price hints (e.g. `($29)`) override AI-extracted price; category corrected to "Other" if price contradicts
10. **Verify** — 3-layer honeypot detection (see below). AI verdicts cached by `sourceId + title hash`.
11. **Filter stale** — Remove events with startDate before today
12. **Geocode** — City extracted from event title when stored city is generic ("Orange County", "Los Angeles"). Google Places searched with `effectiveCity` for accurate results; wrong-city results rejected via city validation. Google Places Photos used as venue image when event has no `websiteURL`.
13. **Fill images** — Priority: og:image from event's own `websiteURL` (fetched once per unique URL, reused for all recurring instances) → venue/title search via Unsplash/Pexels → category-based stock photo. Google Places venue photos are **skipped** when the event has a specific event-page `websiteURL` (lets og:image fetch the real promo photo instead).
14. **Upload** — Push to CloudKit (production or development based on `CLOUDKIT_ENVIRONMENT` secret)
15. **Commit** — Pipeline commits updated `docs/api/events.json` AND `ParentGuide/ParentGuide/Resources/events.json` to the repo so both the remote feed and the bundled iOS fallback stay in sync
16. **Save AI cache** — Flush enrichment + honeypot cache to `pipeline/cache/ai-cache.json`

### Execution
- **Runs on:** GitHub Actions (cloud) — NOT on local machine
- **Trigger:** Automatic (twice daily cron) or manual (GitHub Actions → Run workflow)
- **Local dry run:** `cd pipeline && npx tsx src/index.ts --dry-run` (writes to `pipeline/output/`, skips CloudKit)
- **Local reprocess dry run:** `cd pipeline && npx tsx src/index.ts --reprocess --dry-run`
- **Timeout:** 150 minutes
- **Workflow file:** `.github/workflows/pipeline.yml`
- **Node version:** 20.x
- **CloudKit environment:** Controlled by `CLOUDKIT_ENVIRONMENT` GitHub Secret (`production` or `development`)

### AI Cost Management
The pipeline uses two Claude API steps (enrichment + honeypot verification). To control costs:
- **Incremental cache** — Results are cached in `pipeline/cache/ai-cache.json` between GitHub Actions runs via `actions/cache`. On each run, unchanged events are served from cache with zero API calls.
- **Cache key** — `sourceId + SHA-256 hash of (title + description + category)`. If event content changes, the cache entry is automatically invalidated and the event is reprocessed.
- **Cache TTL** — 30 days. Entries older than 30 days are pruned on load.
- **GitHub Actions cache** — Restored via `restore-keys: ai-cache-v1-` so every run gets the most recent cache even though each run saves under a unique key.
- **Error fallbacks are NOT cached** — If Claude returns an error for a batch, those events are retried on the next run.
- **Steady-state cost** — After the first (cold) run, only new/changed events call the API (~20–50/day vs ~1,500 total). Expected ~97% cache hit rate. ~$0.05–0.15/run, ~$3–9/month.
- **Cold run cost** — Enrichment with claude-sonnet-4-5 over all ~1,979 events ≈ $3.50 total (enrichment ~$3.40 + honeypot ~$0.10)
- **Cache source file:** `pipeline/src/utils/ai-cache.ts`

### URL Sanitization Rules
- `externalURL` must NEVER link back to scraper source sites (MommyPoppins, MacaroniKid, etc.)
- The enrichment step fetches scraper article pages to find outbound links to the actual event/venue website
- If no venue URL is found, falls back to a Google search URL for the event
- The iOS app prefers `websiteURL` over `externalURL` for the "More Information" button

### Enriched Fields (uploaded to CloudKit)
- `price` — Extracted from event pages, descriptions, and titles (e.g., "Free", "$15–$25")
- `ageRange` — Target age range from detail pages
- `websiteURL` — Direct link to venue/event official website
- `phone` — Venue phone number
- `contactEmail` — Event contact email
- `status` — Moderation status: `"published"` | `"draft"` | `"rejected"` (see Honeypot Detection)

### Scraper Sources & Priority (OC/LA)
Each scraper declares its supported metro(s) and is only invoked for those metros — no wasted calls.

| Source | Metro(s) called for | Notes |
|--------|-------------------|-------|
| **OC Parent Guide** | `orange-county` only | Playwright-based (Boom Calendar iframe). Wix login required. Layer 2+3 honeypot verification. |
| **Kidsguide Magazine** | `los-angeles` only | WordPress REST API. OC metro skipped internally; OC events reassigned from LA batch in post-processing. Trusted API source (auto-published). |
| **MommyPoppins** | `los-angeles` only | HTML scraper, 60 days. LA region 115 covers all SoCal. OC metro skipped internally; OC events reassigned in post-processing. |
| **MacaroniKid** | `los-angeles` only | National site scraped once. OC events split out via city/coordinate reassignment. 8 weekly offsets ≈ 60 days. |
| **Ticketmaster / SeatGeek / Yelp / Eventbrite** | Both OC + LA | API-based, run in parallel per metro. 60-day window. Auto-published. SeatGeek uses `datetime_local` (not `datetime_utc`) to avoid wrong timezone display. |
| **NYC / Dallas / Chicago / Atlanta scrapers** | Disabled (metros off) | Code present but never invoked in Phase 1. |

### Event Window
- All sources fetch **60 days forward** from current date
- Ticketmaster: `endDateTime` parameter
- SeatGeek: `datetime_local.lte` parameter
- Yelp: `end_date` unix timestamp
- Kidsguide: `end_date` query parameter
- MacaroniKid: 8 weekly page offsets (≈ 60 days)
- MommyPoppins: `DAYS_AHEAD = 60`
- OC Parent Guide: navigates current month + 2 additional months (≈ 60–90 days)

### Content Filtering Rules
- Exclude adult/21+/18+/adults-only/mature-audiences events (title + description check)
- Exclude known adult comedy venue events: Irvine Improv, Brea Improv, Ontario Improv, Comedy Store, Laugh Factory, Ice House Comedy, Comedy Cellar
- Exclude Yelp Elite community meetups (title starts with "UYE")
- Exclude multi-location guide articles (titles like "Ice Skating in Irvine, Anaheim, and Westminster" — guide articles, not single events)
- Exclude events that mention the source site name
- Exclude site member-only promotions
- Source file: `pipeline/src/index.ts` (both normal and `--reprocess` paths)

### Honeypot Detection & Event Verification
Scraper sites may embed fake "watermark" events to detect unauthorized scraping. The pipeline uses a 3-layer system to assign a `status` field to every event:

**Layer 1 — Trusted API sources** (auto-published, no check needed):
- Ticketmaster, SeatGeek, Yelp, Eventbrite, Kidsguide
- These are contractual data-sharing partners with no incentive to watermark
- Note: Yelp is trusted but Yelp Elite (UYE) community meetups are still filtered by content filter

**Layer 2 — URL verification** (all scrapers, including OC Parent Guide):
- If the enricher found a real venue/event website (`websiteURL` or `externalURL` pointing to a non-aggregator, non-Google domain) → `published`
- OC Parent Guide events typically fail this layer (their `externalURL` points to the aggregator domain) and proceed to Layer 3

**Layer 3 — Claude AI plausibility check** (events that failed Layer 2):
- Claude haiku evaluates title, source, city, category, and description
- Determines: genuine local family event vs. likely honeypot watermark
- Plausible → `published`; Suspicious → `draft` for admin review
- Falls back to `published` on API error or parse failure (never blocks real events)
- Verdicts are cached — once an event is verified its result is reused on future runs until TTL expires

**Status values:**
- `"published"` — Visible to all users in the app
- `"draft"` — Pending admin review (More → Admin → Draft Events); hidden from regular users
- `"rejected"` — Admin dismissed as honeypot or invalid; hidden from all users

**Source file:** `pipeline/src/verify-events.ts`

### Geocoding Details
- **City extraction from title** — When `event.city` is a generic metro name ("Orange County", "Los Angeles"), `extractCityFromTitle()` parses the actual city from the title (e.g., "Songs and Stories in Corona Del Mar" → "Corona del Mar"). The extracted city is used as `effectiveCity` for geocoding queries.
- **City validation** — Google Places results are rejected if `formattedAddress` doesn't contain `effectiveCity`, preventing wrong-city matches (e.g., Tustin event won't get an Irvine result)
- **Venue-as-city detection** — Venue names stored as city (e.g., "Discovery Cube OC", "Irvine Park Railroad") are treated as generic and corrected via title extraction or metro fallback
- **Google Places Photos** — Fetched during geocoding as venue image fallback. Skipped when event already has a `websiteURL` (event-page og:image is preferred over generic venue photos)
- **Source file:** `pipeline/src/geocode-events.ts`

### Image Priority (in order)
1. **og:image from `websiteURL`** — Fetched for all events that have their own event page. URLs are deduplicated so recurring events (e.g. 30 instances of "Eggstravaganza") fetch the image once and share it. No batch size limit.
2. **og:image from `externalURL`** — For non-aggregator sources only
3. **Google Places Photo** — Venue photo from Google Maps; only used when no `websiteURL` exists
4. **Unsplash/Pexels venue search** — Venue name or event title query
5. **Category stock photo** — Last resort fallback
- **Copyright:** Never use og:image from aggregator domains (MommyPoppins, MacaroniKid)
- **Source file:** `pipeline/src/images.ts`

### Scraping Masking
All scrapers use randomized browser fingerprinting to avoid bot detection:
- Rotating User-Agent strings (Chrome 130–132, Firefox 133, Safari 18, Edge 132)
- Chrome `sec-ch-ua` client hints matching the UA version
- `sec-fetch-dest/mode/site/user` headers for realistic browser behavior
- Random Google referer header (~40% of requests)
- Randomized viewport sizes (5 common desktop resolutions)
- `navigator.webdriver` hidden via `addInitScript` (Playwright)
- `--disable-blink-features=AutomationControlled` Chromium flag
- Non-round cron times (5:17 AM, 6:18 PM UTC) + random 0–5 min jitter on scheduled runs
- Source file: `pipeline/src/utils/user-agents.ts`

### AI Enrichment
Single Claude pass (`claude-sonnet-4-5`) over all events in batches of 15:
- Rewrites descriptions: fresh 2–3 sentence prose, family-focused, no promotional language
- Validates/corrects event categories (14 valid categories)
- **Corrects** locationName and address using world knowledge — not just fills empty fields (e.g. fixes wrong-city venue names)
- Extracts missing structured fields from description text: price, ageRange, locationName, address
- `IMPORTANT: The "city" field tells you exactly where this event takes place. locationName and address MUST be in that city.`
- Falls back gracefully when `ANTHROPIC_API_KEY` is not set
- Results cached per event — only new/changed events hit the API on repeat runs
- Source file: `pipeline/src/utils/ai-enricher.ts`

### Category Classification
Score-based keyword matching in `pipeline/src/normalize.ts`:
- Title keyword match = 3 points; body/description match = 1 point
- Highest-scoring category wins
- 14 categories: Storytime, Farmers Market, Free Movie, Toddler Activity, Craft, Music, Fire Station Tour, Museum, Outdoor, Food & Dining, Sports, Education, Festival, Seasonal
- AI enrichment corrects any mismatch in a second pass
- Post-AI rule: "Free Movie" category is corrected to "Other" if price field shows a cost

### Deduplication Rules
- Do not import duplicate events with the same title, same date, etc.

## Source Site Credentials
- OC Parent Guide URL: https://www.orangecountyparentguide.com/ — login/password in GitHub Secrets
- All API keys (Ticketmaster, SeatGeek, Yelp, Eventbrite, Unsplash, Pexels) stored in GitHub Secrets
- Anthropic API key stored in GitHub Secrets (`ANTHROPIC_API_KEY`)
- CloudKit server-to-server auth key stored in GitHub Secrets
- Google Places API key stored in GitHub Secrets (geocoding + venue photos)

### CloudKit Schema (Event record type)
- Core fields: title, description, startDate, endDate, location, city, metro, category, latitude, longitude, imageURL, externalURL, source, tags
- Enriched fields (deployed to Production): price, ageRange, websiteURL, phone, contactEmail, status

## iOS App

### Subscription Model
- **Free tier:** See all events, but tapping events >1 day out triggers paywall. Banner ads (AdMob).
- **Premium ($5/month, $48/year):** Calendar sync, extended event viewing, ad-free
- **Admins** automatically receive full premium access (`SubscriptionService.hasFullAccess` returns true for admins)

### Premium Gate Implementation
- All premium checks use `subscriptionService.hasFullAccess` (not `isSubscribed` directly)
- `hasFullAccess` = `isSubscribed || AdminService.shared.isAdmin`
- Gates: event date lock (>1 day), Add to Calendar, Add Favorites to Calendar, banner ads
- `AppConstants.freeEventHorizonDays = 1` controls the free viewing window

### Filters
- **Sort:** Date, Distance, Price
- **When:** All Upcoming, Today, This Week, This Weekend, This Month, Custom
- **Distance:** From Current Location (GPS) or From Home (user-set in profile)
- **Price:** All, Free, Paid
- **Category:** 14 categories (Storytime, Farmers Market, Free Movie, Toddler Activity, Craft, Music, Fire Station Tour, Museum, Outdoor, Food & Dining, Sports, Education, Festival, Seasonal)

### Home Location
- Users can set a home city or address in Profile → Home Location
- Uses Apple Maps autocomplete (MKLocalSearchCompleter)
- Stored in CloudKit UserProfile (homeCity, homeLatitude, homeLongitude)
- Used for "Distance from Home" filter

### Admin Features
- Admin dashboard accessible from More menu (admin users only)
- Admin Apple User IDs configured in `AdminService.adminAppleUserIDs`
- Admins automatically get full premium access (no subscription required)
- Event CRUD: create, edit, delete events
- `EventService.updateEvent()` handles both CloudKit records (fetch + update) and JSON-only events (creates new CloudKit record if not found)
- Event suggestion review queue (user-submitted events)
- **Draft Events review queue** — pipeline events pending honeypot verification (`More → Admin → Draft Events`)
  - Swipe right to publish, swipe left to reject
  - Multi-select mode with bulk approve/reject
  - Orange badge on menu item shows pending count
  - Uses `fetchAllEvents()` + filter for `.isDraft` (NOT raw CloudKit query — public DB doesn't support `recordZoneChanges`)

### Event Moderation (Status Field)
- `status` field on every Event: `"published"` | `"draft"` | `"rejected"` (nil = published for old records)
- Regular users only see published events (`isDraft == false && isRejected == false`)
- `EventService.fetchUpcomingEvents()` and `searchEvents()` automatically filter out drafts/rejected
- Admin-only: `EventService.fetchDraftEvents()`, `publishEvent()`, `rejectEvent()`
- Source file: `ParentGuide/Views/Admin/DraftEventsView.swift`

### Event Data Loading (Simulator vs Device)
- **Primary:** Remote JSON feed at `https://raw.githubusercontent.com/justinlin15/ParentGuide/main/docs/api/events.json`
- **Fallback:** Bundled `ParentGuide/ParentGuide/Resources/events.json` (updated automatically by every pipeline run)
- **Simulator note:** GitHub raw frequently returns non-200 in the simulator → app falls back to bundled JSON. To get latest data in the simulator: `git pull` then rebuild in Xcode.
- Check Xcode console for: `[EventService] Remote JSON feed: X events` (remote) vs `[EventService] Loaded X events from disk cache` (bundled/cached)

### Map
- Uses `Marker` (not `Annotation`) for smooth zoom/pan — natively rendered by MapKit GPU pipeline
- Cluster pins: events at the same coordinate grouped with a count badge; tap to see list
- Date navigation bar centered over map with `< [date] >` controls + calendar icon
- Tapping the date pill opens a graphical `DatePicker` sheet (`.medium` detent) with "Jump to Today" shortcut
- "My Location" button (bottom-right) centers map on device GPS
- Capped at 50 pins on HomeMapView
- Lazy loads on appear with placeholder

### Pending iOS Tasks
- **Debug toggles in TestFlight** — Admin/premium toggles visible at runtime via `AppConstants.betaTestingEnabled`; set to `false` before App Store submission
- **CloudKit EventSuggestion submission** — Requires user to be signed into iCloud (not just Sign in with Apple); shows clear error if not signed in
- **App Store URL** — Update `AppConstants.appStoreURL` with real App Store ID once published
- **iOS 26 deprecations** — `MKPlacemark`, `CLGeocoder` deprecated in iOS 26; update to `MKMapItem` APIs before iOS 26 ships
