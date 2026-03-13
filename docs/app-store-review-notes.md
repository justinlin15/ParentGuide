# App Store Review Notes - ParentGuide

## Demo Account / Sign-In Instructions

ParentGuide uses **Sign in with Apple** as the sole authentication method. No test credentials are needed.

- Tap "Sign in with Apple" on the launch screen.
- The reviewer may use any Apple ID to sign in. Apple's sandbox environment supports Sign in with Apple during review.
- No additional onboarding or verification steps are required beyond Apple Sign-In.

## Subscription Testing (Sandbox Environment)

ParentGuide offers two in-app subscription tiers managed via StoreKit 2:

| Plan     | Price         | Product ID                        |
|----------|---------------|-----------------------------------|
| Monthly  | $4.00/month   | com.parentguide.app.monthly       |
| Annual   | $45.00/year   | com.parentguide.app.annual        |

**How to test:**

1. Sign in with a Sandbox Apple ID (configured in App Store Connect under Users and Access > Sandbox > Test Accounts).
2. Navigate to the "Subscribe" or "Upgrade" prompt within the app.
3. Select either the Monthly or Annual plan.
4. Confirm the purchase using the sandbox account. Sandbox subscriptions renew at an accelerated rate (monthly renews every 5 minutes, annual renews every 1 hour).
5. Subscription status is reflected immediately in the app. Premium features unlock upon successful purchase.

**Note:** All subscription billing is handled entirely through Apple's App Store. We do not process payments directly.

## Key Features to Review

1. **Event Discovery Feed** - The home screen displays a curated feed of upcoming family-friendly events based on the user's selected metro area. Events can be filtered by category (outdoor, arts, sports, seasonal, etc.) and date.

2. **Metro Area Selection** - On first launch, the app requests location permission (one-time) to auto-detect the nearest supported metro area. Users can also manually select from: Los Angeles/Orange County, New York City, Dallas, Chicago, and Atlanta. This can be changed at any time in Settings.

3. **Event Detail View** - Tapping an event shows full details including date/time, location, description, and a map view. Users can get directions via Apple Maps integration.

4. **Favorites** - Authenticated users can save events to a Favorites list for quick access. Favorites sync across devices via CloudKit.

5. **Event Map View** - A map-based view shows events plotted by location within the selected metro area, allowing spatial browsing.

6. **Notifications** - Users can opt in to receive notifications about upcoming favorited events or new events in their area.

7. **Subscription Management** - Users can view and manage their subscription status within the app. Cancellation is handled through the App Store.

## Location Usage

- The app requests location permission (`When In Use`) solely to auto-detect the user's nearest supported metro area during initial setup.
- Location is **not** continuously tracked. After metro area detection, the app relies on the user's saved metro area preference.
- The `NSLocationWhenInUseUsageDescription` string explains this usage clearly.

## Event Data Sources

Event listings are aggregated from publicly available sources including community event calendars, family activity websites, and public ticketing platforms. Events are curated and categorized to ensure relevance to families with children.

All event data is sourced from publicly accessible information. We do not have exclusive partnerships or licensing agreements with event organizers. Event details (dates, times, venues, descriptions) are provided as-is and users are encouraged to verify details with the event organizer directly.

## Data Privacy

- Authentication: Sign in with Apple only
- Data storage: Apple CloudKit (iCloud container: iCloud.com.parentguide.app)
- No third-party analytics SDKs
- No advertising SDKs or ad tracking
- No data shared with third parties
- Users can delete their account and all associated data from within the app
- Full privacy policy available at: https://parentguide.app/privacy-policy

## Technical Details

- Minimum iOS version: iOS 17.0
- Frameworks: SwiftUI, MapKit, CoreLocation, CloudKit, StoreKit 2
- No third-party dependencies or external SDKs
- Universal app (iPhone and iPad)

## Contact

For any questions during the review process:
- Email: support@parentguide.app
