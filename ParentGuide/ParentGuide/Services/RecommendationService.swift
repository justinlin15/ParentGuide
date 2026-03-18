//
//  RecommendationService.swift
//  ParentGuide
//

import Foundation
import SwiftUI

@Observable
class RecommendationService {
    static let shared = RecommendationService()

    private init() {}

    // MARK: - Interest Keys (must match ProfileView @AppStorage keys)

    private static let interestKeys: [(key: String, category: EventCategory)] = [
        ("interest_storytime", .storytime),
        ("interest_farmersMarket", .farmersMarket),
        ("interest_freeMovie", .freeMovie),
        ("interest_toddlerActivity", .toddlerActivity),
        ("interest_craft", .craft),
        ("interest_music", .music),
        ("interest_museum", .museum),
        ("interest_outdoorAdventure", .outdoorAdventure),
        ("interest_food", .food),
        ("interest_sports", .sports),
        ("interest_education", .education),
        ("interest_festival", .festival),
        ("interest_seasonal", .seasonal),
    ]

    // MARK: - Public API

    /// Whether the user has set any interest preferences.
    func userHasInterests() -> Bool {
        Self.interestKeys.contains { UserDefaults.standard.bool(forKey: $0.key) }
    }

    /// Returns recommended events scored by interest match, favorite patterns, and recency.
    func recommendedEvents(from events: [Event], favoriteIDs: Set<String> = [], limit: Int = 10) -> [Event] {
        let enabledCategories = enabledInterestCategories()

        // Derive categories the user tends to favorite
        let favoritedCategories = deriveFavoritedCategories(from: events, favoriteIDs: favoriteIDs)

        // Need at least one signal to make recommendations
        guard !enabledCategories.isEmpty || !favoritedCategories.isEmpty else { return [] }

        let now = Date()
        let sevenDaysOut = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        let scored: [(Event, Int)] = events.compactMap { event in
            // Skip past events
            guard event.startDate >= now else { return nil }

            var score = 0

            // +3 if event category matches an enabled interest
            if enabledCategories.contains(event.category) {
                score += 3
            }

            // +2 if event tags overlap with interest category names
            let interestNames = enabledCategories.map { $0.rawValue.lowercased() }
            let tagOverlap = event.tags.contains { tag in
                interestNames.contains { tag.lowercased().contains($0) }
            }
            if tagOverlap { score += 2 }

            // +1 if event category matches a previously favorited category
            if favoritedCategories.contains(event.category) {
                score += 1
            }

            // +1 if within next 7 days (recency boost)
            if event.startDate <= sevenDaysOut {
                score += 1
            }

            // +1 if event has an image (visual appeal)
            if event.imageURL != nil && !event.imageURL!.isEmpty {
                score += 1
            }

            // -1 if already favorited (user already knows about it)
            if favoriteIDs.contains(event.id) {
                score -= 1
            }

            // Only include if there's some relevance
            guard score > 0 else { return nil }

            return (event, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Private

    private func enabledInterestCategories() -> Set<EventCategory> {
        var categories = Set<EventCategory>()
        for (key, category) in Self.interestKeys {
            if UserDefaults.standard.bool(forKey: key) {
                categories.insert(category)
            }
        }
        return categories
    }

    private func deriveFavoritedCategories(from events: [Event], favoriteIDs: Set<String>) -> Set<EventCategory> {
        guard !favoriteIDs.isEmpty else { return [] }
        let favoritedEvents = events.filter { favoriteIDs.contains($0.id) }
        return Set(favoritedEvents.map(\.category))
    }
}
