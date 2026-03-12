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

    // MARK: - Fetch helpers

    /// Fetch ALL events from CloudKit (no date predicate) and filter client-side.
    /// The pipeline stores startDate as Int64 milliseconds via the REST API,
    /// which causes type-mismatch issues with server-side NSDate/NSNumber predicates.
    /// With ~150 events in the database, fetching all and filtering locally is fast.
    private func fetchAllEvents() async throws -> [Event] {
        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.event,
            predicate: NSPredicate(value: true),
            sortDescriptors: [NSSortDescriptor(key: "startDate", ascending: true)],
            resultsLimit: 500
        )
        return records.compactMap { Event(record: $0) }
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
        let predicate = NSPredicate(
            format: "self contains %@",
            query
        )

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.event,
            predicate: predicate
        )

        return records.compactMap { Event(record: $0) }
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
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMeters = radiusMiles * 1609.34

        let predicate = NSPredicate(
            format: "distanceToLocation:fromLocation:(location, %@) < %f",
            location,
            radiusMeters
        )
        let sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.event,
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            resultsLimit: 200
        )

        return records.compactMap { Event(record: $0) }
    }

    func fetchFeaturedEvents() async throws -> [Event] {
        let predicate = NSPredicate(format: "isFeatured == 1")
        let sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.event,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )

        return records.compactMap { Event(record: $0) }
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
        // Fetch the existing record to preserve server metadata (changeTag, etc.)
        let recordID = CKRecord.ID(recordName: event.id)
        let existingRecord = try await cloudKit.fetchRecord(recordID: recordID)

        // Apply updated fields
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

enum EventServiceError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Failed to parse the saved event record."
        }
    }
}
