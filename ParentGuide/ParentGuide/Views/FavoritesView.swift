//
//  FavoritesView.swift
//  ParentGuide
//

import SwiftUI

struct FavoritesView: View {
    @State private var favoritesService = FavoritesService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var calendarService = CalendarService.shared
    @State private var favoriteEvents: [Event] = []
    @State private var isLoading = false
    @State private var isAddingToCalendar = false
    @State private var showPaywall = false
    @State private var showCalendarResult = false
    @State private var showCalendarDenied = false
    @State private var calendarResultMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: "Loading favorites...")
                } else if favoriteEvents.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        eventsList

                        // Add Favorites to Calendar button
                        addToCalendarButton

                        // Banner ad pinned to bottom for non-subscribers
                        BannerAdView(adUnitID: AdService.AdUnitID.banner)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Favorites")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .task {
                await loadFavorites()
            }
            .onChange(of: favoritesService.favoriteIDs) {
                Task { await loadFavorites() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(lockedContentName: "calendar sync")
            }
            .alert("Added to Calendar", isPresented: $showCalendarResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(calendarResultMessage)
            }
            .alert("Calendar Access Required", isPresented: $showCalendarDenied) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please allow calendar access in Settings to add events to your calendar.")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        EmptyStateView(
            icon: "heart",
            title: "No Favorites Yet",
            message: "Tap the heart icon on any event to save it here for quick access."
        )
    }

    @ViewBuilder
    private var eventsList: some View {
        List {
            ForEach(favoriteEvents) { event in
                SubscriptionGatedLink(event: event) {
                    EventCardView(event: event)
                }
                .listRowInsets(EdgeInsets())
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            favoritesService.removeFavorite(event.id)
                            favoriteEvents.removeAll { $0.id == event.id }
                        }
                    } label: {
                        Label("Remove", systemImage: "heart.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var addToCalendarButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                if subscriptionService.hasFullAccess {
                    addAllToCalendar()
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 10) {
                    if isAddingToCalendar {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isAddingToCalendar ? "Adding..." : "Add Favorites to Calendar")
                        .font(.headline)

                    if !subscriptionService.hasFullAccess {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandBlue)
                .cornerRadius(14)
            }
            .disabled(isAddingToCalendar)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private func loadFavorites() async {
        guard !favoritesService.favoriteIDs.isEmpty else {
            favoriteEvents = []
            return
        }
        isLoading = true
        do {
            favoriteEvents = try await EventService.shared.fetchFavoriteEvents(ids: favoritesService.favoriteIDs)
        } catch {
            NSLog("[FavoritesView] Load error: %@", error.localizedDescription)
        }
        isLoading = false
    }

    private func addAllToCalendar() {
        isAddingToCalendar = true
        Task {
            let result = await calendarService.addBatchToCalendar(favoriteEvents)
            await MainActor.run {
                isAddingToCalendar = false
                if result.denied {
                    showCalendarDenied = true
                } else {
                    var parts: [String] = []
                    if result.added > 0 {
                        parts.append("\(result.added) event\(result.added == 1 ? "" : "s") added")
                    }
                    if result.skipped > 0 {
                        parts.append("\(result.skipped) already in your calendar")
                    }
                    if parts.isEmpty {
                        calendarResultMessage = "No new events to add."
                    } else {
                        calendarResultMessage = parts.joined(separator: ", ") + "."
                    }
                    showCalendarResult = true
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
}
