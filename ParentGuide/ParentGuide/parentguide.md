# ParentGuide App

## Goal
The goal of the app is to function similar to https://www.orangecountyparentguide.com which is to help families explore the local areas by giving them curated recommendations for playgrounds, restaurants, library programs, travel destinations, and localized events.

## Data Pipeline Requirements

### Scraping Schedule
- Scrape kids activity sites similar to Orange County Parent Guide every 12 hours
- Update app with new activities once every 12 hours
- If events do not have images then search the internet using the event title and descriptions to find and image.  Events must have an image

### Content Filtering Rules
- Exclude events that mention the source site name
- Exclude community meetups specific to the source site
- Exclude site member-only promotions
- Maintain the same quantity of events as the scraped sites

### Deduplication Rules
- Do not import duplicate events with the same title, same date, etc.

## Source Site Credentials
- URL: https://www.orangecountyparentguide.com/
- Login and password are stored in GitHub Secrets (not in source code).

