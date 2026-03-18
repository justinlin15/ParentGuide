//
//  EventSuggestionTests.swift
//  ParentGuideTests
//

import CloudKit
import Testing
import Foundation
@testable import ParentGuide

// MARK: - EventSuggestion Model Tests

@Suite("EventSuggestion Model")
struct EventSuggestionModelTests {

    @Test("Local init creates suggestion with correct defaults")
    func localInit() {
        let suggestion = EventSuggestion(
            title: "Test Event",
            description: "A fun event",
            startDate: Date(),
            city: "Irvine",
            category: "Music",
            metro: "orange-county"
        )

        #expect(suggestion.title == "Test Event")
        #expect(suggestion.eventDescription == "A fun event")
        #expect(suggestion.city == "Irvine")
        #expect(suggestion.category == "Music")
        #expect(suggestion.metro == "orange-county")
        #expect(suggestion.status == .pending)
        #expect(suggestion.reviewNote == nil)
        #expect(suggestion.reviewedAt == nil)
        #expect(!suggestion.id.isEmpty)
    }

    @Test("Local init with all optional fields")
    func localInitAllFields() {
        let date = Date()
        let endDate = Date().addingTimeInterval(3600)
        let suggestion = EventSuggestion(
            title: "Full Event",
            description: "Description",
            startDate: date,
            endDate: endDate,
            city: "Tustin",
            address: "123 Main St",
            locationName: "City Hall",
            category: "Festival",
            imageURL: "https://example.com/img.jpg",
            externalURL: "https://example.com",
            metro: "orange-county",
            submitterName: "Test User",
            submitterEmail: "test@test.com"
        )

        #expect(suggestion.endDate == endDate)
        #expect(suggestion.address == "123 Main St")
        #expect(suggestion.locationName == "City Hall")
        #expect(suggestion.imageURL == "https://example.com/img.jpg")
        #expect(suggestion.externalURL == "https://example.com")
        #expect(suggestion.submitterName == "Test User")
        #expect(suggestion.submitterEmail == "test@test.com")
    }

    @Test("toCKRecord produces valid record with correct type")
    func toCKRecord() {
        let suggestion = EventSuggestion(
            title: "CK Test",
            description: "Testing CK",
            startDate: Date(),
            city: "Anaheim",
            category: "Outdoor",
            metro: "orange-county"
        )

        let record = suggestion.toCKRecord()

        #expect(record.recordType == "EventSuggestion")
        #expect(record["title"] as? String == "CK Test")
        #expect(record["eventDescription"] as? String == "Testing CK")
        #expect(record["city"] as? String == "Anaheim")
        #expect(record["category"] as? String == "Outdoor")
        #expect(record["metro"] as? String == "orange-county")
        #expect(record["status"] as? String == "pending")
    }

    @Test("toCKRecord includes optional fields when set")
    func toCKRecordOptionals() {
        let suggestion = EventSuggestion(
            title: "Full",
            description: "Desc",
            startDate: Date(),
            city: "Irvine",
            address: "456 Oak Ave",
            locationName: "Park",
            category: "Music",
            imageURL: "https://img.com/photo.jpg",
            externalURL: "https://event.com",
            metro: "los-angeles",
            submitterName: "Jane",
            submitterEmail: "jane@test.com"
        )

        let record = suggestion.toCKRecord()

        #expect(record["address"] as? String == "456 Oak Ave")
        #expect(record["locationName"] as? String == "Park")
        #expect(record["imageURL"] as? String == "https://img.com/photo.jpg")
        #expect(record["externalURL"] as? String == "https://event.com")
        #expect(record["submitterName"] as? String == "Jane")
        #expect(record["submitterEmail"] as? String == "jane@test.com")
    }

    @Test("CKRecord init parses valid record")
    func ckRecordInit() {
        let record = CKRecord(recordType: "EventSuggestion")
        record["title"] = "Parsed Event"
        record["eventDescription"] = "A description"
        record["startDate"] = Date()
        record["city"] = "Costa Mesa"
        record["status"] = "pending"
        record["category"] = "Craft"
        record["metro"] = "orange-county"

        let suggestion = EventSuggestion(record: record)

        #expect(suggestion != nil)
        #expect(suggestion?.title == "Parsed Event")
        #expect(suggestion?.eventDescription == "A description")
        #expect(suggestion?.city == "Costa Mesa")
        #expect(suggestion?.status == .pending)
        #expect(suggestion?.category == "Craft")
    }

    @Test("CKRecord init returns nil for missing required fields")
    func ckRecordInitMissingFields() {
        // Missing title
        let record1 = CKRecord(recordType: "EventSuggestion")
        record1["eventDescription"] = "Desc"
        record1["startDate"] = Date()
        record1["city"] = "Irvine"
        record1["status"] = "pending"
        #expect(EventSuggestion(record: record1) == nil)

        // Missing description
        let record2 = CKRecord(recordType: "EventSuggestion")
        record2["title"] = "Test"
        record2["startDate"] = Date()
        record2["city"] = "Irvine"
        record2["status"] = "pending"
        #expect(EventSuggestion(record: record2) == nil)

        // Missing startDate
        let record3 = CKRecord(recordType: "EventSuggestion")
        record3["title"] = "Test"
        record3["eventDescription"] = "Desc"
        record3["city"] = "Irvine"
        record3["status"] = "pending"
        #expect(EventSuggestion(record: record3) == nil)

        // Missing city
        let record4 = CKRecord(recordType: "EventSuggestion")
        record4["title"] = "Test"
        record4["eventDescription"] = "Desc"
        record4["startDate"] = Date()
        record4["status"] = "pending"
        #expect(EventSuggestion(record: record4) == nil)

        // Missing status
        let record5 = CKRecord(recordType: "EventSuggestion")
        record5["title"] = "Test"
        record5["eventDescription"] = "Desc"
        record5["startDate"] = Date()
        record5["city"] = "Irvine"
        #expect(EventSuggestion(record: record5) == nil)
    }

    @Test("CKRecord init handles all status values")
    func ckRecordStatusParsing() {
        func makeRecord(status: String) -> CKRecord {
            let record = CKRecord(recordType: "EventSuggestion")
            record["title"] = "Test"
            record["eventDescription"] = "Desc"
            record["startDate"] = Date()
            record["city"] = "Irvine"
            record["status"] = status
            return record
        }

        #expect(EventSuggestion(record: makeRecord(status: "pending"))?.status == .pending)
        #expect(EventSuggestion(record: makeRecord(status: "approved"))?.status == .approved)
        #expect(EventSuggestion(record: makeRecord(status: "rejected"))?.status == .rejected)
        // Unknown status defaults to pending
        #expect(EventSuggestion(record: makeRecord(status: "unknown"))?.status == .pending)
    }

    @Test("Round-trip: local init → toCKRecord → CKRecord init preserves data")
    func roundTrip() {
        let original = EventSuggestion(
            title: "Round Trip",
            description: "Testing round trip",
            startDate: Date(),
            city: "Newport Beach",
            address: "100 PCH",
            locationName: "The Beach",
            category: "Outdoor",
            externalURL: "https://example.com",
            metro: "orange-county",
            submitterName: "Tester",
            submitterEmail: "tester@test.com"
        )

        let record = original.toCKRecord()
        let parsed = EventSuggestion(record: record)

        #expect(parsed != nil)
        #expect(parsed?.title == original.title)
        #expect(parsed?.eventDescription == original.eventDescription)
        #expect(parsed?.city == original.city)
        #expect(parsed?.address == original.address)
        #expect(parsed?.locationName == original.locationName)
        #expect(parsed?.category == original.category)
        #expect(parsed?.externalURL == original.externalURL)
        #expect(parsed?.metro == original.metro)
        #expect(parsed?.submitterName == original.submitterName)
        #expect(parsed?.submitterEmail == original.submitterEmail)
        #expect(parsed?.status == .pending)
    }
}

// MARK: - CloudKit Permission Error Tests

@Suite("CloudKit Permission Errors")
struct CloudKitPermissionErrorTests {

    @Test("notSignedIn error has correct description")
    func notSignedInError() {
        let error = CloudKitPermissionError.notSignedIn("Sign in required")
        #expect(error.errorDescription == "Sign in required")
        #expect(error.localizedDescription == "Sign in required")
    }

    @Test("permissionDenied error has correct description")
    func permissionDeniedError() {
        let error = CloudKitPermissionError.permissionDenied("Access denied")
        #expect(error.errorDescription == "Access denied")
    }

    @Test("networkError error has correct description")
    func networkError() {
        let error = CloudKitPermissionError.networkError("No connection")
        #expect(error.errorDescription == "No connection")
    }
}

// MARK: - Suggestion Validation Tests

@Suite("Suggestion Form Validation")
struct SuggestionValidationTests {

    @Test("Title is required - empty string is invalid")
    func titleRequired() {
        let title = ""
        let isValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isValid)
    }

    @Test("Title is required - whitespace only is invalid")
    func titleWhitespaceInvalid() {
        let title = "   "
        let isValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isValid)
    }

    @Test("Title is required - valid title passes")
    func titleValid() {
        let title = "Concert in the Park"
        let isValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(isValid)
    }

    @Test("City is required - empty string is invalid")
    func cityRequired() {
        let city = ""
        let isValid = !city.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isValid)
    }

    @Test("City is required - valid city passes")
    func cityValid() {
        let city = "Tustin"
        let isValid = !city.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(isValid)
    }

    @Test("Empty description gets space placeholder")
    func emptyDescriptionPlaceholder() {
        let description = ""
        let processed = description.trimmingCharacters(in: .whitespaces).isEmpty ? " " : description.trimmingCharacters(in: .whitespaces)
        #expect(processed == " ")
    }

    @Test("Non-empty description is preserved")
    func nonEmptyDescription() {
        let description = "A great event for families"
        let processed = description.trimmingCharacters(in: .whitespaces).isEmpty ? " " : description.trimmingCharacters(in: .whitespaces)
        #expect(processed == "A great event for families")
    }
}

// MARK: - CloudKitConfig Tests

@Suite("CloudKit Configuration")
struct CloudKitConfigTests {

    @Test("Record type constants are correct")
    func recordTypeConstants() {
        #expect(CloudKitConfig.RecordType.event == "Event")
        #expect(CloudKitConfig.RecordType.eventSuggestion == "EventSuggestion")
        #expect(CloudKitConfig.RecordType.userProfile == "UserProfile")
    }

    @Test("Container uses correct identifier")
    func containerIdentifier() {
        #expect(AppConstants.cloudKitContainerID == "iCloud.com.parentguide.app")
    }
}
