//
//  EventSuggestion.swift
//  ParentGuide
//

import CloudKit
import Foundation

struct EventSuggestion: Identifiable {
    let id: String
    var title: String
    var eventDescription: String
    var startDate: Date
    var endDate: Date?
    var city: String
    var address: String?
    var locationName: String?
    var category: String
    var imageURL: String?
    var externalURL: String?
    var metro: String
    var submitterName: String?
    var submitterEmail: String?
    var status: SuggestionStatus
    var reviewNote: String?
    let createdAt: Date
    var reviewedAt: Date?

    enum SuggestionStatus: String, CaseIterable {
        case pending
        case approved
        case rejected
    }

    // MARK: - CloudKit Init

    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let description = record["eventDescription"] as? String,
              let startDate = record["startDate"] as? Date,
              let city = record["city"] as? String,
              let status = record["status"] as? String
        else { return nil }

        self.id = record.recordID.recordName
        self.title = title
        self.eventDescription = description
        self.startDate = startDate
        self.endDate = record["endDate"] as? Date
        self.city = city
        self.address = record["address"] as? String
        self.locationName = record["locationName"] as? String
        self.category = record["category"] as? String ?? "Other"
        self.imageURL = record["imageURL"] as? String
        self.externalURL = record["externalURL"] as? String
        self.metro = record["metro"] as? String ?? ""
        self.submitterName = record["submitterName"] as? String
        self.submitterEmail = record["submitterEmail"] as? String
        self.status = SuggestionStatus(rawValue: status) ?? .pending
        self.reviewNote = record["reviewNote"] as? String
        self.createdAt = record.creationDate ?? Date()
        self.reviewedAt = record["reviewedAt"] as? Date
    }

    // Local init for creating new suggestions
    init(title: String, description: String, startDate: Date, endDate: Date? = nil,
         city: String, address: String? = nil, locationName: String? = nil,
         category: String, imageURL: String? = nil, externalURL: String? = nil,
         metro: String, submitterName: String? = nil, submitterEmail: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.eventDescription = description
        self.startDate = startDate
        self.endDate = endDate
        self.city = city
        self.address = address
        self.locationName = locationName
        self.category = category
        self.imageURL = imageURL
        self.externalURL = externalURL
        self.metro = metro
        self.submitterName = submitterName
        self.submitterEmail = submitterEmail
        self.status = .pending
        self.reviewNote = nil
        self.createdAt = Date()
        self.reviewedAt = nil
    }

    // MARK: - To CKRecord

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.RecordType.eventSuggestion)
        record["title"] = title
        record["eventDescription"] = eventDescription
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["city"] = city
        record["address"] = address
        record["locationName"] = locationName
        record["category"] = category
        record["imageURL"] = imageURL
        record["externalURL"] = externalURL
        record["metro"] = metro
        record["submitterName"] = submitterName
        record["submitterEmail"] = submitterEmail
        record["status"] = status.rawValue
        record["reviewNote"] = reviewNote
        record["reviewedAt"] = reviewedAt
        return record
    }
}
