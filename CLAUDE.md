# ParentGuide App

## Goal
The goal of the app is to function similar to https://www.orangecountyparentguide.com which is to help families explore the local areas by giving them curated recommendations for playgrounds, restaurants, library programs, travel destinations, and localized events.

## Launch Metros
- Phase 1: Orange County + Los Angeles only
- Other metros (NYC, Dallas, Chicago, Atlanta) are in code but disabled

## Data Pipeline

### Architecture
- **Location:** Runs on GitHub Actions (online), not locally
- **Schedule:** Twice daily at 5:17 AM and 6:17 PM UTC, plus random 0–5 min jitter (scheduled runs only)
- **Manual trigger:** GitHub Actions tab → "Event Pipeline" → "Run workflow"
- **Dry run:** Pass `--dry-run` to skip CloudKit upload and write to `pipeline/output/`

### Pipeline Flow
1. **Scrape** — APIs (Ticketmaster, SeatGeek, Yelp, Eventbrite) + scrapers (OC Parent Guide, Kidsguide, MommyPoppins, MacaroniKid)
2. **Reassign metros** — Split LA/OC events based on city names and coordinates
3. **Deduplicate** — Remove duplicate events with same title, date, etc.
4. **Clean descriptions** — Strip promotional language
5. **Rewrite descriptions** — Template-based paraphrasing (fast pre-pass before AI)
6. **Enrich** — Sanitize URLs, extract prices via regex, strip scraper tags
7. **AI Enrichment** — Claude rewrites all descriptions, validates categories, extracts missing price/ageRange/locationName/address
8. **Verify** — 3-layer honeypot detection (see below)
9. **Filter stale** — Remove events with startDate before today
10. **Geocode** — Fill missing coordinates via Nominatim
11. **Fill images** — og:image extraction, venue search, stock photo fallback (Unsplash/Pexels)
12. **Upload** — Push to CloudKit (production or development based on `CLOUDKIT_ENVIRONMENT` secret)

### Execution
- **Runs on:** GitHub Actions (cloud) — NOT on local machine
- **Trigger:** Automatic (twice daily cron) or manual (GitHub Actions → Run workflow)
- **Local dry run:** `cd pipeline && npx tsx src/index.ts --dry-run` (writes to `pipeline/output/`, skips CloudKit)
- **Timeout:** 150 minutes
- **Workflow file:** `.github/workflows/pipeline.yml`
- **Node version:** 20.x
- **CloudKit environment:** Controlled by `CLOUDKIT_ENVIRONMENT` GitHub Secret (`production` or `development`)

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
1. **OC Parent Guide** — Primary source for OC. Playwright-based (Boom Calendar iframe). Requires Wix login credentials. Goes through honeypot verification (Layer 2 + 3) like all scrapers.
2. **Kidsguide Magazine** — OC/LA family events. Uses The Events Calendar WordPress REST API (`/wp-json/tribe/events/v1/events`). Trusted API source (auto-published).
3. **MommyPoppins** — Secondary source. HTML scraper, 60 days ahead. LA region 115 covers both LA + OC.
4. **MacaroniKid** — Supplementary. HTML scraper, 60 days ahead (8 weekly page offsets).
5. **Ticketmaster / SeatGeek / Yelp / Eventbrite** — API-based, run in parallel per metro. All 60 days forward window. Trusted API sources (auto-published).

### Event Window
- All sources fetch **60 days forward** from current date
- Ticketmaster: `endDateTime` parameter
- SeatGeek: `datetime_local.lte` parameter
- Yelp: `end_date` unix timestamp
- Kidsguide: `end_date` query parameter
- MacaroniKid: 8 weekly page offsets (≈ 60 days)
- MommyPoppins: `DAYS_AHEAD = 60`
- OC Parent Guide: navigates current month + 2 additional months (≈ 60–90 days)

### Honeypot Detection & Event Verification
Scraper sites may embed fake "watermark" events to detect unauthorized scraping. The pipeline uses a 3-layer system to assign a `status` field to every event:

**Layer 1 — Trusted API sources** (auto-published, no check needed):
- Ticketmaster, SeatGeek, Yelp, Eventbrite, Kidsguide
- These are contractual data-sharing partners with no incentive to watermark

**Layer 2 — URL verification** (all scrapers, including OC Parent Guide):
- If the enricher found a real venue/event website (`websiteURL` or `externalURL` pointing to a non-aggregator, non-Google domain) → `published`
- OC Parent Guide events typically fail this layer (their `externalURL` points to the aggregator domain) and proceed to Layer 3

**Layer 3 — Claude AI plausibility check** (events that failed Layer 2):
- Claude haiku evaluates title, source, city, category, and description
- Determines: genuine local family event vs. likely honeypot watermark
- Plausible → `published`; Suspicious → `draft` for admin review
- Falls back to `published` on API error or parse failure (never blocks real events)

**Status values:**
- `"published"` — Visible to all users in the app
- `"draft"` — Pending admin review (More → Admin → Draft Events); hidden from regular users
- `"rejected"` — Admin dismissed as honeypot or invalid; hidden from all users

**Source file:** `pipeline/src/verify-events.ts`

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
Single Claude pass (`claude-haiku-4-5`) over all events in batches of 15:
- Rewrites descriptions: fresh 2–3 sentence prose, family-focused, no promotional language
- Validates/corrects event categories (14 valid categories)
- Extracts missing structured fields from description text: price, ageRange, locationName, address
- Falls back gracefully when `ANTHROPIC_API_KEY` is not set
- Source file: `pipeline/src/utils/ai-enricher.ts`

### Category Classification
Score-based keyword matching in `pipeline/src/normalize.ts`:
- Title keyword match = 3 points; body/description match = 1 point
- Highest-scoring category wins
- 14 categories: Storytime, Farmers Market, Free Movie, Toddler Activity, Craft, Music, Fire Station Tour, Museum, Outdoor, Food & Dining, Sports, Education, Festival, Seasonal
- AI enrichment corrects any mismatch in a second pass

### Image Requirements
- Events must have an image
- Priority: scraper-provided image → og:image from event URL → venue/title search via Unsplash/Pexels → category-based stock photo
- Copyright: Do NOT use og:image from aggregator domains (MommyPoppins, MacaroniKid) — only from event's own website

### Content Filtering Rules
- Exclude events that mention the source site name
- Exclude community meetups specific to the source site
- Exclude site member-only promotions
- Maintain the same quantity of events as the scraped sites

### Deduplication Rules
- Do not import duplicate events with the same title, same date, etc.

## Source Site Credentials
- OC Parent Guide URL: https://www.orangecountyparentguide.com/ — login/password in GitHub Secrets
- All API keys (Ticketmaster, SeatGeek, Yelp, Eventbrite, Unsplash, Pexels) stored in GitHub Secrets
- Anthropic API key stored in GitHub Secrets (`ANTHROPIC_API_KEY`)
- CloudKit server-to-server auth key stored in GitHub Secrets
- Google Places API key stored in GitHub Secrets (geocoding)

### CloudKit Schema (Event record type)
- Core fields: title, description, startDate, endDate, location, city, metro, category, latitude, longitude, imageURL, externalURL, source, tags
- Enriched fields (deployed to Production): price, ageRange, websiteURL, phone, contactEmail, status

## iOS App

### Subscription Model
- **Free tier:** See all events, but tapping events >3 days out triggers paywall. Banner ads (AdMob).
- **Premium ($5/month, $48/year):** Calendar sync, extended event viewing, ad-free

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
- Admin Apple User IDs configured in AdminService
- Event CRUD: create, edit, delete events
- Event suggestion review queue (user-submitted events)
- **Draft Events review queue** — pipeline events pending honeypot verification (`More → Admin → Draft Events`)
  - Swipe right to publish, swipe left to reject
  - Multi-select mode with bulk approve/reject
  - Orange badge on menu item shows pending count

### Event Moderation (Status Field)
- `status` field on every Event: `"published"` | `"draft"` | `"rejected"` (nil = published for old records)
- Regular users only see published events (`isDraft == false && isRejected == false`)
- `EventService.fetchUpcomingEvents()` and `searchEvents()` automatically filter out drafts/rejected
- Admin-only: `EventService.fetchDraftEvents()`, `publishEvent()`, `rejectEvent()`
- Source file: `ParentGuide/Views/Admin/DraftEventsView.swift`

### Map
- Uses `Marker` (not `Annotation`) for smooth zoom/pan — natively rendered by MapKit GPU pipeline
- Capped at 50 pins on HomeMapView
- Lazy loads on appear with placeholder

### Pending iOS Tasks
- **Debug toggles in TestFlight** — Admin/premium toggles currently `#if DEBUG` only; need runtime flag for TestFlight builds
- **CloudKit EventSuggestion submission** — Requires user to be signed into iCloud (not just Sign in with Apple); shows clear error if not signed in
