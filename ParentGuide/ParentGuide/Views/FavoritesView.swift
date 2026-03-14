//
//  FavoritesView.swift
//  ParentGuide
//

import SwiftUI

struct FavoritesView: View {
    @State private var favoritesService = FavoritesService.shared
    @State private var favoriteEvents: [Event] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: "Loading favorites...")
                } else if favoriteEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Favorites")
            .task {
                await loadFavorites()
            }
            .onChange(of: favoritesService.favoriteIDs) {
                Task { await loadFavorites() }
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
                NavigationLink(destination: EventDetailView(event: event)) {
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
}

#Preview {
    FavoritesView()
}
