//
//  AdminDashboardViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class AdminDashboardViewModel {
    var allEvents: [Event] = []
    var searchText = ""
    var selectedMetroFilter: String? // nil = all metros
    var selectedSourceFilter: String? // nil = all sources
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed Filters

    var filteredEvents: [Event] {
        var events = allEvents

        if let metro = selectedMetroFilter {
            events = events.filter { $0.metro == metro }
        }

        if let source = selectedSourceFilter {
            events = events.filter { $0.source == source }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            events = events.filter {
                $0.title.lowercased().contains(query) ||
                $0.city.lowercased().contains(query) ||
                $0.eventDescription.lowercased().contains(query)
            }
        }

        return events.sorted { $0.startDate > $1.startDate }
    }

    var eventCount: Int { filteredEvents.count }

    var availableMetros: [String] {
        Array(Set(allEvents.compactMap(\.metro))).sorted()
    }

    var availableSources: [String] {
        Array(Set(allEvents.compactMap(\.source))).sorted()
    }

    // MARK: - Stats

    var totalEvents: Int { allEvents.count }

    var activeEvents: Int {
        let now = Date()
        return allEvents.filter { $0.startDate >= Calendar.current.startOfDay(for: now) || ($0.endDate ?? $0.startDate) >= now }.count
    }

    var expiredEvents: Int {
        let now = Date()
        return allEvents.filter {
            let end = $0.endDate ?? $0.startDate
            return end < Calendar.current.startOfDay(for: now)
        }.count
    }

    var eventsBySource: [(source: String, count: Int)] {
        let grouped = Dictionary(grouping: allEvents) { $0.source ?? "unknown" }
        return grouped.map { (source: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var eventsAddedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allEvents.filter { $0.createdAt >= weekAgo }.count
    }

    var featuredCount: Int {
        allEvents.filter(\.isFeatured).count
    }

    // MARK: - Flagged Events

    var eventsMissingImages: [Event] {
        allEvents.filter { $0.imageURL == nil || $0.imageURL?.isEmpty == true }
            .sorted { $0.startDate < $1.startDate }
    }

    var eventsMissingCoordinates: [Event] {
        allEvents.filter { $0.latitude == nil || $0.longitude == nil }
            .filter { $0.startDate >= Calendar.current.startOfDay(for: Date()) } // only active
            .sorted { $0.startDate < $1.startDate }
    }

    var staleEvents: [Event] {
        let now = Calendar.current.startOfDay(for: Date())
        return allEvents.filter {
            let end = $0.endDate ?? $0.startDate
            return end < now
        }
        .sorted { $0.startDate > $1.startDate }
    }

    var duplicateEvents: [(Event, Event)] {
        var dupes: [(Event, Event)] = []
        let sorted = allEvents.sorted { $0.title < $1.title }
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                let a = sorted[i], b = sorted[j]
                if a.title.lowercased() == b.title.lowercased() &&
                   Calendar.current.isDate(a.startDate, inSameDayAs: b.startDate) {
                    dupes.append((a, b))
                }
            }
            if dupes.count >= 20 { break } // cap for performance
        }
        return dupes
    }

    var totalFlaggedCount: Int {
        eventsMissingCoordinates.count + staleEvents.count + duplicateEvents.count
    }

    // MARK: - Actions

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            allEvents = try await EventService.shared.fetchAllEvents()
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
            NSLog("[AdminDashboard] Load error: %@", error.localizedDescription)
        }
        isLoading = false
    }

    func deleteEvent(_ event: Event) async {
        do {
            try await EventService.shared.deleteEvent(id: event.id)
            allEvents.removeAll { $0.id == event.id }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            NSLog("[AdminDashboard] Delete error: %@", error.localizedDescription)
        }
    }

    func bulkDeleteExpired() async {
        let expired = staleEvents
        for event in expired {
            await deleteEvent(event)
        }
    }
}
