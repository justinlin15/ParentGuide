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
        } else {
            favoriteIDs.insert(eventID)
        }
        persist()
    }

    func addFavorite(_ eventID: String) {
        favoriteIDs.insert(eventID)
        persist()
    }

    func removeFavorite(_ eventID: String) {
        favoriteIDs.remove(eventID)
        persist()
    }

    var count: Int { favoriteIDs.count }

    private func persist() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: Self.favoritesKey)
    }
}
