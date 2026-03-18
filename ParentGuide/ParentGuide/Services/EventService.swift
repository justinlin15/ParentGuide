//
//  EventService.swift
//  ParentGuide
//

import CloudKit
import CoreLocation
import Foundation

actor EventService {
    static let shared = EventService()

    private let cloudKit = CloudKitService.shared

    /// GitHub-hosted JSON feed — updated every 12 hours by the pipeline.
    private static let eventsJSONURL = URL(
        string: "https://raw.githubusercontent.com/justinlin15/ParentGuide/main/docs/api/events.json"
    )!

    // Simple in-memory cache (lives for the app session)
    private var cachedEvents: [Event]?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Persistent disk cache

    /// Wrapper for persisting events + timestamp to disk as JSON.
    private struct CachedEvents: Codable {
        let events: [Event]
        let timestamp: Date
    }

    /// File URL for the on-disk event cache.
    private var diskCacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("events-cache.json")
    }

    /// Persist fetched events to a JSON file in the caches directory.
    private func saveToDiskCache(_ events: [Event]) {
        guard let url = diskCacheURL else { return }
        do {
            let cached = CachedEvents(events: events, timestamp: Date())
            let data = try JSONEncoder().encode(cached)
            try data.write(to: url, options: [.atomic])
            NSLog("[EventService] Saved %d events to disk cache", events.count)
        } catch {
            NSLog("[EventService] Failed to write disk cache: %@", error.localizedDescription)
        }
    }

    /// Load previously cached events from disk. Returns nil if no cache exists.
    private func loadFromDiskCache() -> [Event]? {
        guard let url = diskCacheURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let cached = try JSONDecoder().decode(CachedEvents.self, from: data)
            NSLog("[EventService] Loaded %d events from disk cache (saved %@)",
                  cached.events.count,
                  cached.timestamp.formatted())
            return cached.events
        } catch {
            NSLog("[EventService] Failed to read disk cache: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Fetch helpers

    /// Fetch ALL events. Tries CloudKit first; falls back to JSON feed.
    func fetchAllEvents() async throws -> [Event] {
        // Return cache if fresh
        if let cached = cachedEvents, let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheDuration {
            return cached
        }

        // Try CloudKit first — use fetchAllRecords (zone changes API) because
        // the pipeline auto-creates the schema via REST without queryable indexes.
        // CKQuery would fail with "field not queryable" errors.
        do {
            let records = try await cloudKit.fetchAllRecords(
                recordType: CloudKitConfig.RecordType.event
            )
            let events = records.compactMap { Event(record: $0) }
            if !events.isEmpty {
                NSLog("[EventService] CloudKit: %d events", events.count)
                cachedEvents = events
                cacheTimestamp = Date()
                saveToDiskCache(events)
                return events
            }
        } catch {
            NSLog("[EventService] CloudKit fetch failed: %@, falling back to JSON feed", error.localizedDescription)
        }

        // Fallback: fetch from JSON feed
        let events = try await fetchEventsFromJSON()
        if !events.isEmpty {
            cachedEvents = events
            cacheTimestamp = Date()
            saveToDiskCache(events)
            return events
        }

        // Last resort: load from persistent disk cache (offline support)
        if let diskCached = loadFromDiskCache() {
            NSLog("[EventService] All sources failed, using disk cache (%d events)", diskCached.count)
            cachedEvents = diskCached
            cacheTimestamp = Date()
            return diskCached
        }

        return events
    }

    /// Fetch events from remote JSON feed (primary) or bundled JSON (offline fallback).
    private func fetchEventsFromJSON() async throws -> [Event] {
        let decoder = JSONDecoder()

        // 1. Try remote JSON feed first (most up-to-date, updated every 12h by pipeline)
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.eventsJSONURL)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let pipelineEvents = try decoder.decode([PipelineEvent].self, from: data)
                let events = pipelineEvents.compactMap { $0.toEvent() }
                NSLog("[EventService] Remote JSON feed: %d events (from %d raw)", events.count, pipelineEvents.count)
                if !events.isEmpty { return events }
            } else {
                NSLog("[EventService] Remote JSON feed returned non-200 status")
            }
        } catch {
            NSLog("[EventService] Remote JSON feed failed: %@, trying bundled JSON", error.localizedDescription)
        }

        // 2. Fallback: bundled events.json (available offline, updated at build time)
        if let bundleURL = Bundle.main.url(forResource: "events", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let pipelineEvents = try decoder.decode([PipelineEvent].self, from: data)
                let events = pipelineEvents.compactMap { $0.toEvent() }
                NSLog("[EventService] Bundled JSON: %d events (from %d raw)", events.count, pipelineEvents.count)
                if !events.isEmpty { return events }
            } catch {
                NSLog("[EventService] Bundled JSON parse error: %@", error.localizedDescription)
            }
        }

        return []
    }

    // MARK: - Filtered queries

    /// Fetch events for a single calendar month.
    func fetchEvents(for month: Date) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth
        return allEvents.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
    }

    /// Fetch events for a specific day.
    func fetchEvents(forDay date: Date) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return allEvents.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
    }

    /// Fetch events for a metro area across 2 months from today.
    /// Excludes draft (pending review) and rejected events for regular users.
    func fetchUpcomingEvents(forMetro metro: String) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let now = Calendar.current.startOfDay(for: Date())
        let threeMonthsLater = Calendar.current.date(byAdding: .month, value: 2, to: now)!

        return allEvents.filter { event in
            let isUpcoming = event.startDate >= now && event.startDate <= threeMonthsLater
            let matchesMetro = (event.metro ?? "los-angeles") == metro
            let isVisible = !event.isDraft && !event.isRejected
            return isUpcoming && matchesMetro && isVisible
        }.sorted { $0.startDate < $1.startDate }
    }

    /// Fetch events for a metro area within a specific month.
    func fetchEvents(forMetro metro: String, month: Date) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth

        return allEvents.filter { event in
            let inMonth = event.startDate >= startOfMonth && event.startDate <= endOfMonth
            let matchesMetro = (event.metro ?? "los-angeles") == metro
            return inMonth && matchesMetro
        }
    }

    func searchEvents(query: String) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let lowerQuery = query.lowercased()
        return allEvents.filter {
            guard !$0.isDraft && !$0.isRejected else { return false }
            return $0.title.lowercased().contains(lowerQuery) ||
                   $0.eventDescription.lowercased().contains(lowerQuery) ||
                   $0.city.lowercased().contains(lowerQuery)
        }
    }

    func fetchNearbyEvents(latitude: Double, longitude: Double, radiusMiles: Double = 50) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMeters = radiusMiles * 1609.34

        return allEvents.filter { event in
            guard let lat = event.latitude, let lon = event.longitude,
                  lat != 0, lon != 0 else { return false }
            let eventLocation = CLLocation(latitude: lat, longitude: lon)
            return eventLocation.distance(from: userLocation) <= radiusMeters
        }
    }

    func fetchFeaturedEvents() async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        return allEvents.filter { $0.isFeatured }
    }

    /// Fetch events that the user has favorited (deduplicated by id).
    func fetchFavoriteEvents(ids: Set<String>) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        var seen = Set<String>()
        return allEvents
            .filter { ids.contains($0.id) }
            .sorted { $0.startDate < $1.startDate }
            .filter { event in
                guard !seen.contains(event.id) else { return false }
                seen.insert(event.id)
                return true
            }
    }

    /// Fetch popular/trending events (favorited → featured → has image → by date).
    func fetchPopularEvents(forMetro metro: String, limit: Int = 10) async throws -> [Event] {
        let upcoming = try await fetchUpcomingEvents(forMetro: metro)
        let favoriteIDs = FavoritesService.shared.favoriteIDs

        let sorted = upcoming.sorted { a, b in
            // Favorited events rank higher (popular = frequently favorited)
            let aFav = favoriteIDs.contains(a.id)
            let bFav = favoriteIDs.contains(b.id)
            if aFav != bFav { return aFav }
            // Featured events rank next
            if a.isFeatured != b.isFeatured { return a.isFeatured }
            // Events with images rank higher (better for carousel)
            let aHasImage = a.imageURL != nil && !(a.imageURL?.isEmpty ?? true)
            let bHasImage = b.imageURL != nil && !(b.imageURL?.isEmpty ?? true)
            if aHasImage != bHasImage { return aHasImage }
            return a.startDate < b.startDate
        }
        return Array(sorted.prefix(limit))
    }

    // MARK: - Draft / Moderation

    /// Fetch events pending admin review (status == "draft").
    /// Only used by the admin Draft Events review view.
    func fetchDraftEvents() async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        return allEvents
            .filter { $0.isDraft }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Publish a draft event (sets status to "published").
    func publishEvent(_ event: Event) async throws -> Event {
        var updated = event
        updated.status = "published"
        return try await updateEvent(updated)
    }

    /// Reject an event (sets status to "rejected" — hidden from all users).
    func rejectEvent(_ event: Event) async throws -> Event {
        var updated = event
        updated.status = "rejected"
        return try await updateEvent(updated)
    }

    // MARK: - Admin CRUD

    func createEvent(_ event: Event) async throws -> Event {
        let record = event.toCKRecord()
        let savedRecord = try await cloudKit.savePublicRecord(record)
        guard let newEvent = Event(record: savedRecord) else {
            throw EventServiceError.invalidRecord
        }
        return newEvent
    }

    func updateEvent(_ event: Event) async throws -> Event {
        let recordID = CKRecord.ID(recordName: event.id)

        // Try to fetch the existing CloudKit record first so we preserve
        // any server-side metadata (changeTag, etc.). If the record doesn't
        // exist yet (e.g. the event only lives in the JSON feed and the
        // pipeline hasn't uploaded it to CloudKit), fall back to creating it.
        let record: CKRecord
        do {
            let existing = try await cloudKit.fetchRecord(recordID: recordID)
            event.applyFields(to: existing)
            record = existing
        } catch {
            // Record not in CloudKit yet — create a fresh one with all fields.
            NSLog("[EventService] Record not found in CloudKit (%@), creating new record", event.id)
            record = event.toCKRecord()
        }

        let savedRecord = try await cloudKit.savePublicRecord(record)
        guard let updatedEvent = Event(record: savedRecord) else {
            throw EventServiceError.invalidRecord
        }
        return updatedEvent
    }

    func deleteEvent(id: String) async throws {
        let recordID = CKRecord.ID(recordName: id)
        try await cloudKit.deletePublicRecord(recordID: recordID)
    }
}

// MARK: - Pipeline JSON Model

/// Matches the JSON format output by the pipeline (all-events.json)
private struct PipelineEvent: Codable {
    let sourceId: String
    let source: String
    let title: String
    let description: String
    let startDate: String
    let endDate: String?
    let isAllDay: Bool?
    let category: String
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let imageURL: String?
    let externalURL: String?
    let isFeatured: Bool
    let isRecurring: Bool
    let tags: [String]?
    let metro: String

    // Enriched fields
    let price: String?
    let ageRange: String?
    let websiteURL: String?
    let phone: String?
    let contactEmail: String?
    let status: String?

    func toEvent() -> Event? {
        guard let start = Self.parseDate(startDate) else { return nil }
        let end = endDate.flatMap { Self.parseDate($0) }

        let recordName = sourceId.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "_",
            options: .regularExpression
        )

        let categoryEnum = EventCategory(rawValue: category) ?? .other

        return Event(
            id: recordName,
            title: Self.decodeHTMLEntities(title),
            eventDescription: Self.decodeHTMLEntities(description),
            startDate: start,
            endDate: end,
            isAllDay: isAllDay ?? false,
            category: categoryEnum,
            city: Self.decodeHTMLEntities(city ?? ""),
            address: address.map { Self.decodeHTMLEntities($0) },
            latitude: latitude,
            longitude: longitude,
            locationName: locationName.map { Self.decodeHTMLEntities($0) },
            imageURL: imageURL,
            externalURL: externalURL,
            isFeatured: isFeatured,
            isRecurring: isRecurring,
            tags: tags ?? [],
            metro: metro,
            source: source,
            manuallyEdited: false,
            createdAt: Date(),
            modifiedAt: Date(),
            price: price,
            ageRange: ageRange,
            websiteURL: websiteURL,
            phone: phone,
            contactEmail: contactEmail,
            status: status
        )
    }

    private static func parseDate(_ str: String) -> Date? {
        // 1. Try ISO 8601 with explicit timezone (e.g. "2026-03-12T10:00:00-07:00")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        // 2. Try ISO 8601 with fractional seconds (e.g. "2026-03-12T00:00:00.000Z")
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        // 3. For dates WITHOUT timezone, interpret as LOCAL time
        //    (so "2026-03-12T00:00:00" means midnight in the user's timezone)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current  // Local timezone

        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = fmt.date(from: str) { return d }

        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let d = fmt.date(from: str) { return d }

        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: str) { return d }

        return nil
    }

    /// Decode common HTML entities (&#039; &amp; &lt; &gt; &quot;)
    private static func decodeHTMLEntities(_ str: String) -> String {
        var result = str
        let entities: [(String, String)] = [
            ("&#039;", "'"), ("&#39;", "'"), ("&apos;", "'"),
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#x27;", "'"), ("&nbsp;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}

enum EventServiceError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Failed to parse the saved event record."
        }
    }
}
