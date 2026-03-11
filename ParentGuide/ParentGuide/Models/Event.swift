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
    var manuallyEdited: Bool = false
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

    /// Read a Date field that may be stored as native Date (iOS SDK) or Int64 milliseconds (REST API pipeline)
    private static func readDate(from record: CKRecord, key: String) -> Date? {
        if let date = record[key] as? Date {
            return date
        }
        if let millis = record[key] as? Int64 {
            return Date(timeIntervalSince1970: Double(millis) / 1000.0)
        }
        if let number = record[key] as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue / 1000.0)
        }
        return nil
    }

    /// Read a Bool field that may be stored as Bool or Int64 (0/1)
    private static func readBool(from record: CKRecord, key: String) -> Bool {
        if let boolVal = record[key] as? Bool {
            return boolVal
        }
        if let intVal = record[key] as? Int64 {
            return intVal != 0
        }
        if let number = record[key] as? NSNumber {
            return number.boolValue
        }
        return false
    }

    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let startDate = Event.readDate(from: record, key: "startDate") else {
            return nil
        }

        self.id = record.recordID.recordName
        self.title = title

        // Pipeline writes "description"; handle both field names for robustness
        self.eventDescription = (record["description"] as? String)
            ?? (record["eventDescription"] as? String)
            ?? ""

        self.startDate = startDate
        self.endDate = Event.readDate(from: record, key: "endDate")
        self.isAllDay = Event.readBool(from: record, key: "isAllDay")

        let categoryString = record["category"] as? String ?? "Other"
        self.category = EventCategory(rawValue: categoryString) ?? .other

        self.city = record["city"] as? String ?? ""
        self.address = record["address"] as? String
        self.latitude = record["latitude"] as? Double
        self.longitude = record["longitude"] as? Double
        self.locationName = record["locationName"] as? String
        self.imageURL = record["imageURL"] as? String
        self.externalURL = record["externalURL"] as? String
        self.isFeatured = Event.readBool(from: record, key: "isFeatured")
        self.isRecurring = Event.readBool(from: record, key: "isRecurring")
        self.tags = record["tags"] as? [String] ?? []
        self.metro = record["metro"] as? String
        self.source = record["source"] as? String
        self.manuallyEdited = Event.readBool(from: record, key: "manuallyEdited")
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }

    /// Convert to a new CKRecord for creating an event
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: CloudKitConfig.RecordType.event, recordID: recordID)
        applyFields(to: record)
        return record
    }

    /// Apply this event's fields to an existing CKRecord (for updates)
    func applyFields(to record: CKRecord) {
        record["sourceId"] = id as CKRecordValue
        record["source"] = (source ?? "admin") as CKRecordValue
        record["title"] = title as CKRecordValue
        record["description"] = eventDescription as CKRecordValue
        record["startDate"] = Int64(startDate.timeIntervalSince1970 * 1000) as CKRecordValue
        if let endDate {
            record["endDate"] = Int64(endDate.timeIntervalSince1970 * 1000) as CKRecordValue
        }
        record["isAllDay"] = Int64(isAllDay ? 1 : 0) as CKRecordValue
        record["category"] = category.rawValue as CKRecordValue
        record["city"] = city as CKRecordValue
        record["address"] = (address ?? "") as CKRecordValue
        record["latitude"] = (latitude ?? 0) as CKRecordValue
        record["longitude"] = (longitude ?? 0) as CKRecordValue
        record["locationName"] = (locationName ?? "") as CKRecordValue
        record["imageURL"] = (imageURL ?? "") as CKRecordValue
        record["externalURL"] = (externalURL ?? "") as CKRecordValue
        record["isFeatured"] = Int64(isFeatured ? 1 : 0) as CKRecordValue
        record["isRecurring"] = Int64(isRecurring ? 1 : 0) as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["metro"] = (metro ?? "") as CKRecordValue
        record["manuallyEdited"] = Int64(manuallyEdited ? 1 : 0) as CKRecordValue
    }
}
