//
//  Event.swift
//  ParentGuide
//

import Foundation
import CloudKit

struct Event: Identifiable, Hashable, Codable {
    // Custom Hashable/Equatable — compare by ID + status so SwiftUI detects
    // moderation changes (publish/reject) and re-renders rows immediately.
    // We deliberately skip the other 20+ fields for performance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }

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

    // Moderation status: "published" | "draft" | "rejected"
    // nil is treated as "published" for backwards compatibility with older records
    var status: String? = nil

    /// True when this event is pending admin review (scraper event with no verified URL)
    var isDraft: Bool { status == "draft" }

    /// True when this event has been rejected by an admin
    var isRejected: Bool { status == "rejected" }

    /// True when the event has any location info (name, address, or valid coordinates).
    var hasLocation: Bool {
        locationName != nil || address != nil || hasValidCoordinates
    }

    /// True only when lat/lon are present and not the 0,0 default placeholder.
    var hasValidCoordinates: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return !(lat == 0 && lon == 0)
    }

    // MARK: - Venue Name Inference

    /// Best available location name: explicit locationName, or inferred from title/description.
    var effectiveLocationName: String? {
        if let name = locationName, !name.isEmpty { return name }
        return inferredLocationName
    }

    /// Try to extract a venue/place name from the event title and description
    /// when the locationName field is missing. Handles patterns like:
    /// - "Free Movie at Lido Theater Newport Beach"
    /// - "Storytime - Irvine Public Library"
    /// - "Music at the Park"
    private var inferredLocationName: String? {
        // Strategy 1: "at <Venue>" in title
        if let venue = extractVenue(from: title) {
            return venue
        }
        // Strategy 2: "at <Venue>" in description (first sentence only)
        let firstSentence = String(eventDescription.prefix(200))
        if let venue = extractVenue(from: firstSentence) {
            return venue
        }
        return nil
    }

    /// Extract a venue name following "at" in text.
    /// Captures: "at Lido Theater Newport Beach" → "Lido Theater Newport Beach"
    private func extractVenue(from text: String) -> String? {
        // Match "at <Venue Name>" — venue starts with a capital letter
        // and may contain words, apostrophes, hyphens, ampersands
        let patterns = [
            // "at The Park" / "at Lido Theater Newport Beach"
            #"(?:\bat|@)\s+(?:the\s+)?([A-Z][A-Za-z''\-&. ]{2,50}?)(?:\s+(?:on|from|every|this|starting|for|with)\b|[,\.\!\?]|$)"#,
            // Fallback: broader "at <Venue>" without stop-word boundary
            #"(?:\bat|@)\s+(?:the\s+)?([A-Z][A-Za-z''\-&. ]{2,50})"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let venueRange = Range(match.range(at: 1), in: text) {
                let venue = String(text[venueRange]).trimmingCharacters(in: .whitespaces)
                // Skip if the "venue" is just a common word
                let skipWords: Set<String> = ["Home", "No", "An", "Any", "This", "That", "Our", "Your", "All", "Each"]
                if skipWords.contains(venue) { continue }
                if venue.count >= 3 { return venue }
            }
        }

        // Strategy: "– Venue Name" or "- Venue Name" after dash in title
        let dashPattern = #"[–—\-]\s*([A-Z][A-Za-z''\-&. ]{2,50})"#
        if let regex = try? NSRegularExpression(pattern: dashPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let venueRange = Range(match.range(at: 1), in: text) {
            let venue = String(text[venueRange]).trimmingCharacters(in: .whitespaces)
            if venue.count >= 3 { return venue }
        }

        return nil
    }

    // MARK: - City Display

    /// Generic region/county names that should never be shown as the city label.
    private static let genericCityNames: Set<String> = [
        "orange county", "los angeles", "los angeles county",
        "la", "oc", "southern california", "socal",
        "greater los angeles", "los angeles metro"
    ]

    /// City suitable for display: the stored city, unless it is a generic region
    /// name (e.g. "Orange County"), in which case we extract the specific city
    /// from the address string (e.g. "Laguna Niguel" from "…, Laguna Niguel, CA 92677, USA").
    var displayCity: String {
        let lower = city.lowercased()
        guard Self.genericCityNames.contains(lower) else { return city }
        return cityFromAddress() ?? city
    }

    /// Extract the city segment from a US-format address string.
    /// Typical format: "1234 Main St, Anaheim, CA 92801, USA"
    private func cityFromAddress() -> String? {
        guard let address else { return nil }
        let parts = address.components(separatedBy: ", ")
        // Need at least: street, city, state+zip[, country]
        guard parts.count >= 3 else { return nil }
        let candidate = parts[1].trimmingCharacters(in: .whitespaces)
        // Reject state abbreviation + ZIP (e.g. "CA 92677") or country names
        let looksLikeStateZip = candidate.range(of: #"^[A-Z]{2}\s+\d{5}"#, options: .regularExpression) != nil
        guard !candidate.isEmpty,
              candidate != "USA",
              candidate != "United States",
              !looksLikeStateZip
        else { return nil }
        return candidate
    }

    /// Best query string for directions/geocoding when coordinates are missing.
    /// Combines venue name (or inferred) with city for better results.
    var directionsQuery: String {
        [effectiveLocationName, address, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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

    /// Ticketed sources where missing price does NOT mean free
    private static let ticketedSources: Set<String> = [
        "seatgeek", "ticketmaster", "eventbrite",
        // Direct venue scrapers — missing price means unknown, not free
        "venue-southcoastplaza", "venue-academy", "venue-kidspace",
        "venue-nhm", "venue-skirball", "venue-expopark",
        "themeparks", "pretend-city", "la-parent",
    ]

    /// Whether the price field is explicitly set to a free value
    private var hasExplicitFreePrice: Bool {
        guard let price = price?.lowercased().trimmingCharacters(in: .whitespaces),
              !price.isEmpty else { return false }
        return price == "free" || price == "$0" || price == "0" || price.contains("free")
    }

    /// Whether this event is free.
    /// Only returns true when the price is EXPLICITLY set to a free value.
    /// Missing/empty price = unknown, not free (avoids showing "FREE" on paid events like WonderCon).
    var isFree: Bool {
        return hasExplicitFreePrice
    }

    /// Whether this event has an explicit paid price
    var hasPaidPrice: Bool {
        guard let price = price?.trimmingCharacters(in: .whitespaces),
              !price.isEmpty else { return false }
        return !hasExplicitFreePrice
    }

    /// Yelp-style price tier: 0 (free) to 5 ($$$$$)
    /// nil = unknown price (no badge shown)
    var priceTier: Int? {
        guard let priceStr = price?.trimmingCharacters(in: .whitespaces), !priceStr.isEmpty else {
            return nil // No price data = unknown, don't show a badge
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

    /// Binary price display: "FREE" for free events, "$" for any paid event.
    var priceTierDisplay: String? {
        guard let tier = priceTier else { return nil }
        return tier == 0 ? "FREE" : "$"
    }

    /// Color for the price tier badge: green for FREE, blue for paid.
    var priceTierColor: String {
        guard let tier = priceTier else { return "gray" }
        return tier == 0 ? "green" : "blue"
    }

    // Cached regexes — avoid allocating on every call (called per-row in lists)
    private static let dollarRegex = try? NSRegularExpression(pattern: #"\$\s*(\d+(?:\.\d{1,2})?)"#)
    private static let numberRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d{1,2})?)"#)

    private func extractDollarAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        let range = NSRange(text.startIndex..., in: text)
        // Match patterns like $15, $25.50, $5
        if let matches = Self.dollarRegex?.matches(in: text, range: range) {
            for match in matches {
                if let amountRange = Range(match.range(at: 1), in: text),
                   let amount = Double(text[amountRange]) {
                    amounts.append(amount)
                }
            }
        }
        // Also try plain numbers
        if amounts.isEmpty, let matches = Self.numberRegex?.matches(in: text, range: range) {
            for match in matches {
                if let amountRange = Range(match.range(at: 1), in: text),
                   let amount = Double(text[amountRange]) {
                    amounts.append(amount)
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

        // Moderation status (nil / missing = treated as "published" for backwards compat)
        let statusVal = record["status"] as? String
        self.status = (statusVal?.isEmpty == false) ? statusVal : nil
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
        record["startDate"] = startDate as CKRecordValue
        if let endDate {
            record["endDate"] = endDate as CKRecordValue
        } else {
            record["endDate"] = nil
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
        record["status"] = (status ?? "published") as CKRecordValue
    }
}
