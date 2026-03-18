//
//  HomeView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeView: View {
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var authService = AuthService.shared
    @State private var metroService = MetroService.shared
    @State private var favoritesService = FavoritesService.shared

    // Feed data
    @State private var popularEvents: [Event] = []
    @State private var featuredEvents: [Event] = []
    @State private var favoriteEvents: [Event] = []
    @State private var todayEvents: [Event] = []
    @State private var recommendedEvents: [Event] = []
    @State private var allMetroEvents: [Event] = []
    @State private var isLoading = false

    private var recommendationService: RecommendationService { RecommendationService.shared }

    private var isSignedIn: Bool {
        authService.currentUser != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if isSignedIn {
                            signedInFeed
                        } else {
                            guestView
                        }
                    }
                }

                // Banner ad pinned to bottom for non-subscribers
                BannerAdView(adUnitID: AdService.AdUnitID.banner)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProfile = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.2.and.child.holdinghands")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandBlue)
                            Text("FamPass")
                                .font(.headline)
                                .foregroundStyle(Color.brandBlue)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    MetroSwitcherView()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNotifications = true } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showProfile = false }
                            }
                        }
                }
            }
            .task {
                await loadFeedData()
            }
            .onChange(of: metroService.selectedMetro.id) {
                Task { await loadFeedData() }
            }
        }
    }

    // MARK: - Signed-in Feed

    /// Whether the user has interests set or favorites saved
    private var hasInterestsOrFavorites: Bool {
        recommendationService.userHasInterests() || !favoritesService.favoriteIDs.isEmpty
    }

    @ViewBuilder
    private var signedInFeed: some View {
        VStack(spacing: 24) {
            // Welcome header
            VStack(spacing: 8) {
                Text("Welcome back!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Here's what's happening in \(metroService.selectedMetro.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            // 1. Featured Events (curated by admin — always first if present)
            if !featuredEvents.isEmpty {
                feedSection(title: "✨ Featured", icon: "star.fill") {
                    ForEach(featuredEvents.prefix(5)) { event in
                        SubscriptionGatedLink(event: event) {
                            CompactEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 2. Popular Near You
            if !popularEvents.isEmpty {
                PopularCarouselSection(events: Array(popularEvents.prefix(5)))
            }

            if hasInterestsOrFavorites {
                // Order: Popular → Recommended → Happening Today → Events Across

                // 2. Recommended For You (carousel tiles like Popular Near You)
                if !recommendedEvents.isEmpty {
                    RecommendedCarouselSection(events: Array(recommendedEvents.prefix(5)))
                }

                // 2b. Your Favorites (right below Recommended)
                if !favoriteEvents.isEmpty {
                    feedSection(title: "Your Favorites", icon: "heart.fill") {
                        ForEach(favoriteEvents.prefix(5)) { event in
                            SubscriptionGatedLink(event: event) {
                                CompactEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 3. Happening Today
                if !todayEvents.isEmpty {
                    feedSection(title: "Happening Today", icon: "sparkles") {
                        ForEach(todayEvents.prefix(5)) { event in
                            SubscriptionGatedLink(event: event) {
                                CompactEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                // Order: Popular → Happening Today → Recommended CTA → Events Across

                // 2. Happening Today
                if !todayEvents.isEmpty {
                    feedSection(title: "Happening Today", icon: "sparkles") {
                        ForEach(todayEvents.prefix(5)) { event in
                            SubscriptionGatedLink(event: event) {
                                CompactEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 3. Recommended For You — CTA to set interests
                recommendedForYouCTA
            }

            // 4. Events Across [location] (always last, lazy loaded)
            HomeMapView(events: allMetroEvents)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Recommended For You CTA

    @ViewBuilder
    private var recommendedForYouCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(Color.brandBlue)
                Text("Recommended For You")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.brandBlue)

                Text("Personalized event picks, just for your family")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Tell us what your family loves and we'll surface the best events based on your interests and favorites.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    showProfile = true
                } label: {
                    Text("Set Your Interests")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.brandBlue)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.brandBlue.opacity(0.06), radius: 8, y: 3)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Guest View

    @ViewBuilder
    private var guestView: some View {
        HeroSectionView()

        VStack(spacing: 24) {
            FeatureHighlightView(
                icon: "calendar.badge.plus",
                title: "1,500+ events",
                description: "An up-to-date, curated list of over 1,500 affordable, family-friendly events each month."
            )
            FeatureHighlightView(
                icon: "heart.fill",
                title: "Save & RSVP",
                description: "Favorite events, RSVP to activities, and build your family's personalized calendar."
            )
            FeatureHighlightView(
                icon: "mappin.and.ellipse",
                title: "Events near you",
                description: "Discover what's happening in your area with our interactive map and location-based recommendations."
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)

        // Popular events preview (even for guests)
        if !popularEvents.isEmpty {
            PopularCarouselSection(events: Array(popularEvents.prefix(5)))
        }

        HomeMapView(events: allMetroEvents)
            .padding(.top, 24)
            .padding(.bottom, 32)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func feedSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brandBlue)
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.brandBlue.opacity(0.06), radius: 8, y: 3)
            .padding(.horizontal, 16)
        }
    }

    private func loadFeedData() async {
        isLoading = true
        let metroId = metroService.selectedMetro.id

        do {
            // Load all metro events ONCE — shared with map + recommendations
            allMetroEvents = try await EventService.shared.fetchUpcomingEvents(forMetro: metroId)

            // Load featured events (admin-curated)
            featuredEvents = (try? await EventService.shared.fetchFeaturedEvents()) ?? []

            // Derive popular events from all events (avoid extra fetch)
            popularEvents = try await EventService.shared.fetchPopularEvents(forMetro: metroId, limit: 10)

            // Filter today's events from already-loaded data
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            todayEvents = allMetroEvents.filter { event in
                let eventEnd = event.endDate ?? event.startDate
                return event.startDate < todayEnd && eventEnd >= todayStart
            }

            // Load favorites
            if !favoritesService.favoriteIDs.isEmpty {
                favoriteEvents = try await EventService.shared.fetchFavoriteEvents(ids: favoritesService.favoriteIDs)
            }

            // Build recommendations from already-loaded events
            recommendedEvents = recommendationService.recommendedEvents(
                from: allMetroEvents,
                favoriteIDs: favoritesService.favoriteIDs,
                limit: 10
            )
        } catch {
            NSLog("[HomeView] Feed load error: %@", error.localizedDescription)
        }

        isLoading = false
    }
}

// MARK: - Compact Event Card (for feed)

struct CompactEventCard: View {
    let event: Event
    @State private var favoritesService = FavoritesService.shared

    private var isFavorite: Bool {
        favoritesService.isFavorite(event.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon circle
            Image(systemName: event.category.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(event.category.color)
                .clipShape(Circle())

            // Event info
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(event.formattedDate)
                        .font(.caption)
                    if !event.city.isEmpty {
                        Text("  \(event.displayCity)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Heart
            Button {
                withAnimation(.spring(response: 0.3)) {
                    favoritesService.toggleFavorite(event.id)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isFavorite ? Color.brandBlue : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    HomeView()
}
