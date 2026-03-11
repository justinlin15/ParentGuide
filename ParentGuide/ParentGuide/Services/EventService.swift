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

    func fetchEvents(for month: Date) async throws -> [Event] {
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth

        let predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
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

    func fetchEvents(forDay date: Date) async throws -> [Event] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSPredicate(
            format: "startDate >= %@ AND startDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        let sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.event,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )

        return records.compactMap { Event(record: $0) }
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
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth

        let predicate = NSPredicate(
            format: "metro == %@ AND startDate >= %@ AND startDate <= %@",
            metro,
            startOfMonth as NSDate,
            endOfMonth as NSDate
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
        record["manuallyEdited"] = Int64(1) as CKRecordValue
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
        existingRecord["manuallyEdited"] = Int64(1) as CKRecordValue

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
