//
//  FavoritesService.swift
//  ParentGuide
//

import Foundation

@Observable
class FavoritesService {
    static let shared = FavoritesService()

    private static let favoritesKey = "favoriteEventIDs"

    /// Set of favorited event IDs
    var favoriteIDs: Set<String> = []

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? []
        favoriteIDs = Set(saved)
    }

    func isFavorite(_ eventID: String) -> Bool {
        favoriteIDs.contains(eventID)
    }

    func toggleFavorite(_ eventID: String) {
        if favoriteIDs.contains(eventID) {
            favoriteIDs.remove(eventID)
            NotificationService.shared.cancelReminder(for: eventID)
        } else {
            favoriteIDs.insert(eventID)
        }
        persist()
    }

    /// Toggle favorite for an event, scheduling a reminder notification if favorited.
    func toggleFavorite(for event: Event) {
        if favoriteIDs.contains(event.id) {
            favoriteIDs.remove(event.id)
            NotificationService.shared.cancelReminder(for: event.id)
        } else {
            favoriteIDs.insert(event.id)
            // Schedule a reminder notification
            Task {
                await NotificationService.shared.scheduleReminder(for: event)
            }
        }
        persist()
    }

    func addFavorite(_ eventID: String) {
        favoriteIDs.insert(eventID)
        persist()
    }

    func removeFavorite(_ eventID: String) {
        favoriteIDs.remove(eventID)
        NotificationService.shared.cancelReminder(for: eventID)
        persist()
    }

    var count: Int { favoriteIDs.count }

    private func persist() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: Self.favoritesKey)
    }
}
