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
    @State private var favoriteEvents: [Event] = []
    @State private var todayEvents: [Event] = []
    @State private var isLoading = false

    private var isSignedIn: Bool {
        authService.currentUser != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isSignedIn {
                        signedInFeed
                    } else {
                        guestView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProfile = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.2.and.child.holdinghands")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandBlue)
                            Text("Parent Guide")
                                .font(.headline)
                                .foregroundStyle(Color.brandBlue)
                        }
                    }
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
        }
    }

    // MARK: - Signed-in Feed

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

            // Today's Events
            if !todayEvents.isEmpty {
                feedSection(title: "Happening Today", icon: "sparkles") {
                    ForEach(todayEvents.prefix(5)) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            CompactEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Favorites section
            if !favoriteEvents.isEmpty {
                feedSection(title: "Your Favorites", icon: "heart.fill") {
                    ForEach(favoriteEvents.prefix(5)) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            CompactEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Popular events
            if !popularEvents.isEmpty {
                feedSection(title: "Popular Near You", icon: "flame.fill") {
                    ForEach(popularEvents.prefix(8)) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            CompactEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Map
            HomeMapView()
                .padding(.bottom, 32)
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
                icon: "person.3.fill",
                title: "Subscriber meetups",
                description: "Free and discounted subscriber meetups — Mom's Night Out, Escape Rooms, and more!"
            )
            FeatureHighlightView(
                icon: "tag.fill",
                title: "Partner perks",
                description: "Exclusive discounts to family photographers, art classes, music classes, and play places."
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)

        // Popular events preview (even for guests)
        if !popularEvents.isEmpty {
            feedSection(title: "Popular Events", icon: "flame.fill") {
                ForEach(popularEvents.prefix(5)) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        CompactEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        HomeMapView()
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
            // Load popular events
            popularEvents = try await EventService.shared.fetchPopularEvents(forMetro: metroId, limit: 10)

            // Load today's events
            todayEvents = try await EventService.shared.fetchEvents(forDay: Date())
            todayEvents = todayEvents.filter { ($0.metro ?? "los-angeles") == metroId }

            // Load favorites
            if !favoritesService.favoriteIDs.isEmpty {
                favoriteEvents = try await EventService.shared.fetchFavoriteEvents(ids: favoritesService.favoriteIDs)
            }
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
                        Text("  \(event.city)")
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
