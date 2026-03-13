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
    /// Used as primary data source while CloudKit schema indexes are being set up.
    private static let eventsJSONURL = URL(
        string: "https://raw.githubusercontent.com/justinlin15/ParentGuide/main/docs/api/events.json"
    )!

    // Simple in-memory cache (lives for the app session)
    private var cachedEvents: [Event]?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Fetch helpers

    /// Fetch ALL events. Tries CloudKit first; falls back to JSON feed.
    private func fetchAllEvents() async throws -> [Event] {
        // Return cache if fresh
        if let cached = cachedEvents, let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheDuration {
            return cached
        }

        // Try CloudKit first
        do {
            let records = try await cloudKit.fetchRecords(
                recordType: CloudKitConfig.RecordType.event,
                predicate: NSPredicate(value: true),
                sortDescriptors: [],
                resultsLimit: 500
            )
            let events = records.compactMap { Event(record: $0) }
            if !events.isEmpty {
                NSLog("[EventService] CloudKit: %d events", events.count)
                cachedEvents = events
                cacheTimestamp = Date()
                return events
            }
        } catch {
            NSLog("[EventService] CloudKit query failed: %@, falling back to JSON feed", error.localizedDescription)
        }

        // Fallback: fetch from JSON feed
        let events = try await fetchEventsFromJSON()
        cachedEvents = events
        cacheTimestamp = Date()
        return events
    }

    /// Fetch events from the pipeline's GitHub-hosted JSON feed.
    private func fetchEventsFromJSON() async throws -> [Event] {
        let (data, response) = try await URLSession.shared.data(from: Self.eventsJSONURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            NSLog("[EventService] JSON feed returned non-200 status")
            return []
        }

        let decoder = JSONDecoder()
        let pipelineEvents = try decoder.decode([PipelineEvent].self, from: data)
        let events = pipelineEvents.compactMap { $0.toEvent() }
        NSLog("[EventService] JSON feed: %d events (from %d raw)", events.count, pipelineEvents.count)
        return events
    }

    func fetchEvents(for month: Date) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth
        return allEvents.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
    }

    func fetchEvents(forDay date: Date) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return allEvents.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
    }

    func searchEvents(query: String) async throws -> [Event] {
        let allEvents = try await fetchAllEvents()
        let lowerQuery = query.lowercased()
        return allEvents.filter {
            $0.title.lowercased().contains(lowerQuery) ||
            $0.eventDescription.lowercased().contains(lowerQuery) ||
            $0.city.lowercased().contains(lowerQuery)
        }
    }

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
        let existingRecord = try await cloudKit.fetchRecord(recordID: recordID)
        event.applyFields(to: existingRecord)
        let savedRecord = try await cloudKit.savePublicRecord(existingRecord)
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

    func toEvent() -> Event? {
        // Parse the startDate string (ISO 8601 or date-only)
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
            title: title,
            eventDescription: description,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay ?? false,
            category: categoryEnum,
            city: city ?? "",
            address: address,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            imageURL: imageURL,
            externalURL: externalURL,
            isFeatured: isFeatured,
            isRecurring: isRecurring,
            tags: tags ?? [],
            metro: metro,
            source: source,
            manuallyEdited: false,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    private static func parseDate(_ str: String) -> Date? {
        // Try ISO 8601 with time
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        // Try ISO 8601 without timezone
        iso.formatOptions = [.withFullDate, .withFullTime]
        if let d = iso.date(from: str) { return d }

        // Try "yyyy-MM-dd'T'HH:mm:ss"
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = fmt.date(from: str) { return d }

        // Try date only "yyyy-MM-dd"
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: str) { return d }

        return nil
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
