//
//  NotificationsView.swift
//  ParentGuide
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var favoritesService = FavoritesService.shared
    @State private var favoriteEvents: [Event] = []
    @State private var selectedEvent: Event?

    var body: some View {
        NavigationStack {
            Group {
                if favoriteEvents.isEmpty && favoritesService.favoriteIDs.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadNotifications()
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetailView(event: event)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { selectedEvent = nil }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Notifications Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Favorite some events to get updates about changes and reminders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var notificationsList: some View {
        List {
            // Favorite event updates
            if !favoriteEvents.isEmpty {
                Section {
                    ForEach(favoriteEvents) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: event.category.iconName)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(event.category.color)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text("\(event.formattedDate) \(event.formattedTime)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if !event.city.isEmpty {
                                        Text(event.displayCity)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label("Favorited Events", systemImage: "heart.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }

            // Tip for users
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay Updated")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Favorite events to see them here and get notified about changes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Tips", systemImage: "info.circle")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func loadNotifications() async {
        if !favoritesService.favoriteIDs.isEmpty {
            do {
                favoriteEvents = try await EventService.shared.fetchFavoriteEvents(ids: favoritesService.favoriteIDs)
            } catch {
                // Silent fail
            }
        }
    }
}

#Preview {
    NotificationsView()
}
