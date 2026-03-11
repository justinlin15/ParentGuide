//
//  EventService.swift
//  ParentGuide
//

import CloudKit
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
}
