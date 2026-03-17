# ParentGuide App

## Goal
The goal of the app is to function similar to https://www.orangecountyparentguide.com which is to help families explore the local areas by giving them curated recommendations for playgrounds, restaurants, library programs, travel destinations, and localized events.

## Launch Metros
- Phase 1: Orange County + Los Angeles only
- Other metros (NYC, Dallas, Chicago, Atlanta) are in code but disabled

## Data Pipeline

### Architecture
- **Location:** Runs on GitHub Actions (online), not locally
- **Schedule:** Twice daily at 5:17 AM and 6:17 PM UTC, plus random 0–30 min jitter
- **Manual trigger:** GitHub Actions tab → "Event Pipeline" → "Run workflow"
- **Dry run:** Pass `--dry-run` to skip CloudKit upload and write to `pipeline/output/`

### Pipeline Flow
1. **Scrape** — APIs (Ticketmaster, SeatGeek, Yelp) + scrapers (MommyPoppins, MacaroniKid, OC Parent Guide)
2. **Reassign metros** — Split LA/OC events based on city names and coordinates
3. **Deduplicate** — Remove duplicate events with same title, date, etc.
4. **Clean descriptions** — Strip promotional language
5. **Rewrite descriptions** — Make descriptions unique
6. **Enrich** — Sanitize URLs, extract prices, strip scraper tags
7. **Filter stale** — Remove events with startDate before today
8. **Geocode** — Fill missing coordinates via Nominatim
9. **Fill images** — og:image extraction, venue search, stock photo fallback (Unsplash/Pexels)
10. **Upload** — Push to CloudKit (production or development based on `CLOUDKIT_ENVIRONMENT` secret)

### Execution
- **Runs on:** GitHub Actions (cloud) — NOT on local machine
- **Trigger:** Automatic (twice daily cron) or manual (GitHub Actions → Run workflow)
- **Local dry run:** `cd pipeline && npx tsx src/index.ts --dry-run` (writes to `pipeline/output/`, skips CloudKit)
- **Workflow file:** `.github/workflows/event-pipeline.yml`
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

### Image Requirements
- Events must have an image
- Priority: scraper-provided image → og:image from event URL → venue/title search via Unsplash/Pexels → category-based stock photo

### Content Filtering Rules
- Exclude events that mention the source site name
- Exclude community meetups specific to the source site
- Exclude site member-only promotions
- Maintain the same quantity of events as the scraped sites

### Deduplication Rules
- Do not import duplicate events with the same title, same date, etc.

## Source Site Credentials
- URL: https://www.orangecountyparentguide.com/
- Login and password are stored in GitHub Secrets (not in source code)
- All API keys (Ticketmaster, SeatGeek, Yelp, Unsplash, Pexels) stored in GitHub Secrets
- CloudKit server-to-server auth key stored in GitHub Secrets

### CloudKit Schema (Event record type)
- Core fields: title, description, startDate, endDate, location, city, metro, category, latitude, longitude, imageURL, externalURL, source, tags
- Enriched fields (deployed to Production): price, ageRange, websiteURL, phone, contactEmail

### Pending Pipeline Improvements
- **Post-scraping enrichment** — Intelligent validation/enrichment of price, category, images after scraping. When data is missing, search online to fill gaps (e.g., find real venue photos, extract ticket prices from event websites).
- **Category validation** — Current category mapping uses simple keyword matching; needs AI/LLM-based classification for accuracy.
- **Image validation** — Detect generic/cartoon images and replace with real venue photos via web search.

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
- Event suggestion review queue

### Map
- Uses `Marker` (not `Annotation`) for smooth zoom/pan — natively rendered by MapKit GPU pipeline
- Capped at 50 pins on HomeMapView
- Lazy loads on appear with placeholder

### Pending iOS Tasks
- **Debug toggles in TestFlight** — Admin/premium toggles currently `#if DEBUG` only; need runtime flag for TestFlight builds
- **CloudKit EventSuggestion submission** — Requires user to be signed into iCloud (not just Sign in with Apple); shows clear error if not signed in
