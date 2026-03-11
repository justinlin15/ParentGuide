//
//  Event.swift
//  ParentGuide
//

import Foundation
import CloudKit

struct Event: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let eventDescription: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let category: EventCategory
    let city: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let imageURL: String?
    let externalURL: String?
    let isFeatured: Bool
    let isRecurring: Bool
    let tags: [String]
    let metro: String?
    let source: String?
    let createdAt: Date
    let modifiedAt: Date

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var formattedDate: String {
        if isAllDay {
            return startDate.formatted(date: .abbreviated, time: .omitted)
        }
        return startDate.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedTime: String {
        if isAllDay { return "All Day" }
        if let endDate {
            return "\(startDate.formatted(date: .omitted, time: .shortened)) - \(endDate.formatted(date: .omitted, time: .shortened))"
        }
        return startDate.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - CloudKit Conversion
nonisolated extension Event {
    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date else {
            return nil
        }

        self.id = record.recordID.recordName
        self.title = title
        self.eventDescription = record["eventDescription"] as? String ?? ""
        self.startDate = startDate
        self.endDate = record["endDate"] as? Date
        self.isAllDay = record["isAllDay"] as? Bool ?? false
        let categoryString = record["category"] as? String ?? "Other"
        self.category = EventCategory(rawValue: categoryString) ?? .other
        self.city = record["city"] as? String ?? ""
        self.address = record["address"] as? String
        self.latitude = record["latitude"] as? Double
        self.longitude = record["longitude"] as? Double
        self.locationName = record["locationName"] as? String
        self.imageURL = nil // Will be handled via CKAsset
        self.externalURL = record["externalURL"] as? String
        self.isFeatured = record["isFeatured"] as? Bool ?? false
        self.isRecurring = record["isRecurring"] as? Bool ?? false
        self.tags = record["tags"] as? [String] ?? []
        self.metro = record["metro"] as? String
        self.source = record["source"] as? String
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }
}
