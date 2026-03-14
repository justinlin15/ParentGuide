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

    // Enriched fields from detail pages
    var price: String? = nil
    var ageRange: String? = nil
    var websiteURL: String? = nil
    var phone: String? = nil
    var contactEmail: String? = nil

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

    // MARK: - Price Tier (Yelp-style $ to $$$$$)

    /// Whether this event is explicitly free
    var isFree: Bool {
        guard let price = price?.lowercased().trimmingCharacters(in: .whitespaces) else { return false }
        return price == "free" || price == "$0" || price == "0" || price.contains("free")
    }

    /// Yelp-style price tier: 1 ($) to 5 ($$$$$), or nil if unknown
    var priceTier: Int? {
        guard let priceStr = price?.trimmingCharacters(in: .whitespaces), !priceStr.isEmpty else {
            return nil
        }

        let lower = priceStr.lowercased()
        if lower == "free" || lower == "$0" || lower == "0" || lower.contains("free") {
            return 0 // Free
        }

        // Extract dollar amounts from the price string
        let amounts = extractDollarAmounts(from: priceStr)
        guard let maxAmount = amounts.max() else {
            // If no dollar amounts found but price exists, default to $
            return priceStr.isEmpty ? nil : 1
        }

        // Use the highest amount to determine tier
        switch maxAmount {
        case 0:           return 0 // Free
        case 1...10:      return 1 // $
        case 11...25:     return 2 // $$
        case 26...50:     return 3 // $$$
        case 51...100:    return 4 // $$$$
        default:          return 5 // $$$$$
        }
    }

    /// Display string for price tier: "FREE", "$", "$$", etc.
    var priceTierDisplay: String? {
        guard let tier = priceTier else { return nil }
        if tier == 0 { return "FREE" }
        return String(repeating: "$", count: tier)
    }

    /// Color for the price tier badge
    var priceTierColor: String {
        guard let tier = priceTier else { return "gray" }
        switch tier {
        case 0:  return "green"   // Free - green
        case 1:  return "green"   // $ - green
        case 2:  return "blue"    // $$ - blue
        case 3:  return "orange"  // $$$ - orange
        case 4:  return "red"     // $$$$ - red
        case 5:  return "red"     // $$$$$ - red
        default: return "gray"
        }
    }

    private func extractDollarAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        // Match patterns like $15, $25.50, $5
        let pattern = #"\$\s*(\d+(?:\.\d{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                if let amountRange = Range(match.range(at: 1), in: text),
                   let amount = Double(text[amountRange]) {
                    amounts.append(amount)
                }
            }
        }
        // Also try plain numbers
        if amounts.isEmpty {
            let numPattern = #"(\d+(?:\.\d{1,2})?)"#
            if let regex = try? NSRegularExpression(pattern: numPattern) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                for match in matches {
                    if let amountRange = Range(match.range(at: 1), in: text),
                       let amount = Double(text[amountRange]) {
                        amounts.append(amount)
                    }
                }
            }
        }
        return amounts
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

        // Enriched fields (may be empty strings from pipeline, treat as nil)
        let priceVal = record["price"] as? String
        self.price = (priceVal?.isEmpty == false) ? priceVal : nil
        let ageVal = record["ageRange"] as? String
        self.ageRange = (ageVal?.isEmpty == false) ? ageVal : nil
        let webVal = record["websiteURL"] as? String
        self.websiteURL = (webVal?.isEmpty == false) ? webVal : nil
        let phoneVal = record["phone"] as? String
        self.phone = (phoneVal?.isEmpty == false) ? phoneVal : nil
        let emailVal = record["contactEmail"] as? String
        self.contactEmail = (emailVal?.isEmpty == false) ? emailVal : nil
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
        record["price"] = (price ?? "") as CKRecordValue
        record["ageRange"] = (ageRange ?? "") as CKRecordValue
        record["websiteURL"] = (websiteURL ?? "") as CKRecordValue
        record["phone"] = (phone ?? "") as CKRecordValue
        record["contactEmail"] = (contactEmail ?? "") as CKRecordValue
    }
}
