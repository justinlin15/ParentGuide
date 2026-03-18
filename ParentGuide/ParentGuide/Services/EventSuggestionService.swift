//
//  EventSuggestionService.swift
//  ParentGuide
//

import CloudKit
import Foundation

@Observable
class EventSuggestionService {
    static let shared = EventSuggestionService()

    var pendingCount = 0

    private let container = CloudKitConfig.container
    private let database = CloudKitConfig.publicDatabase

    private init() {}

    // MARK: - Diagnostics

    /// Check iCloud account status — needed for CREATE operations on public database
    func checkiCloudStatus() async -> (status: CKAccountStatus, errorMessage: String?) {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                NSLog("[EventSuggestionService] ✅ iCloud account available")
                return (status, nil)
            case .noAccount:
                NSLog("[EventSuggestionService] ❌ No iCloud account — go to Settings > Apple ID > iCloud")
                return (status, "You must be signed into iCloud to submit suggestions. Go to Settings > Apple ID > iCloud and sign in.")
            case .restricted:
                NSLog("[EventSuggestionService] ❌ iCloud account restricted")
                return (status, "iCloud access is restricted on this device.")
            case .couldNotDetermine:
                NSLog("[EventSuggestionService] ⚠️ Could not determine iCloud account status")
                return (status, "Could not check iCloud status. Please try again.")
            case .temporarilyUnavailable:
                NSLog("[EventSuggestionService] ⚠️ iCloud temporarily unavailable")
                return (status, "iCloud is temporarily unavailable. Please try again later.")
            @unknown default:
                NSLog("[EventSuggestionService] ⚠️ Unknown iCloud status: \(status.rawValue)")
                return (status, "Unknown iCloud status.")
            }
        } catch {
            NSLog("[EventSuggestionService] ❌ Failed to check iCloud status: %@", error.localizedDescription)
            return (.couldNotDetermine, "Failed to check iCloud: \(error.localizedDescription)")
        }
    }

    // MARK: - Submit (any signed-in user)

    func submitSuggestion(_ suggestion: EventSuggestion) async throws {
        // 1. Check iCloud account status first
        let (status, statusError) = await checkiCloudStatus()
        if status != .available {
            throw CloudKitPermissionError.notSignedIn(statusError ?? "iCloud not available")
        }

        // 2. Build the record
        let record = suggestion.toCKRecord()
        NSLog("[EventSuggestionService] Saving to record type: %@", record.recordType)
        NSLog("[EventSuggestionService] Record fields: title=%@, status=%@, city=%@",
              record["title"] as? String ?? "nil",
              record["status"] as? String ?? "nil",
              record["city"] as? String ?? "nil")

        // 3. Save using CKModifyRecordsOperation for better control
        do {
            let savedRecord = try await database.save(record)
            NSLog("[EventSuggestionService] ✅ Saved record ID: %@", savedRecord.recordID.recordName)
        } catch let ckError as CKError {
            NSLog("[EventSuggestionService] ❌ CKError code: %d, domain: %@", ckError.errorCode, ckError.localizedDescription)

            switch ckError.code {
            case .permissionFailure:
                NSLog("[EventSuggestionService] ❌ Permission failure — likely not signed into iCloud on this device")
                throw CloudKitPermissionError.permissionDenied(
                    "Permission denied. Please ensure you're signed into iCloud: Settings > Apple ID > iCloud."
                )
            case .notAuthenticated:
                throw CloudKitPermissionError.notSignedIn(
                    "You must be signed into iCloud to submit suggestions. Go to Settings > Apple ID > iCloud."
                )
            case .networkUnavailable, .networkFailure:
                throw CloudKitPermissionError.networkError("No internet connection. Please check your network and try again.")
            default:
                NSLog("[EventSuggestionService] ❌ Save FAILED: %@", ckError.localizedDescription)
                throw ckError
            }
        } catch {
            NSLog("[EventSuggestionService] ❌ Save FAILED: %@", error.localizedDescription)
            NSLog("[EventSuggestionService] Error details: %@", String(describing: error))
            throw error
        }
    }

    // MARK: - Admin: Fetch Pending

    func fetchPendingSuggestions() async throws -> [EventSuggestion] {
        NSLog("[EventSuggestionService] Fetching all suggestions...")

        // Fetch ALL suggestions (filter in code to avoid index issues)
        let allPredicate = NSPredicate(value: true)
        let allQuery = CKQuery(
            recordType: CloudKitConfig.RecordType.eventSuggestion,
            predicate: allPredicate
        )
        allQuery.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let (allResults, _) = try await database.records(matching: allQuery, resultsLimit: 100)
            NSLog("[EventSuggestionService] Total records returned: %d", allResults.count)

            var parseFailures = 0
            let allSuggestions = allResults.compactMap { _, result -> EventSuggestion? in
                switch result {
                case .success(let record):
                    let title = record["title"] as? String ?? "?"
                    let status = record["status"] as? String ?? "nil"
                    let desc = record["eventDescription"] as? String ?? "MISSING"
                    NSLog("[EventSuggestionService] Record: %@ — status: %@ — desc: %@ — id: %@",
                          title, status, desc, record.recordID.recordName)
                    if let suggestion = EventSuggestion(record: record) {
                        return suggestion
                    } else {
                        NSLog("[EventSuggestionService] ⚠️ Failed to parse record: %@", title)
                        parseFailures += 1
                        return nil
                    }
                case .failure(let error):
                    NSLog("[EventSuggestionService] ❌ Record fetch error: %@", error.localizedDescription)
                    return nil
                }
            }

            NSLog("[EventSuggestionService] Parsed: %d, Parse failures: %d", allSuggestions.count, parseFailures)

            // Filter to pending in code
            let suggestions = allSuggestions.filter { $0.status == .pending }
            NSLog("[EventSuggestionService] Pending: %d", suggestions.count)

            pendingCount = suggestions.count
            return suggestions
        } catch {
            NSLog("[EventSuggestionService] ❌ Fetch FAILED: %@", error.localizedDescription)
            NSLog("[EventSuggestionService] Error details: %@", String(describing: error))
            throw error
        }
    }

    // MARK: - Admin: Approve

    func approveSuggestion(_ suggestion: EventSuggestion) async throws {
        // 1. Create an Event from the suggestion
        let event = Event(
            id: UUID().uuidString,
            title: suggestion.title,
            eventDescription: suggestion.eventDescription,
            startDate: suggestion.startDate,
            endDate: suggestion.endDate,
            isAllDay: false,
            category: EventCategory(rawValue: suggestion.category) ?? .other,
            city: suggestion.city,
            address: suggestion.address,
            latitude: nil,
            longitude: nil,
            locationName: suggestion.locationName,
            imageURL: suggestion.imageURL,
            externalURL: suggestion.externalURL,
            isFeatured: false,
            isRecurring: false,
            tags: [],
            metro: suggestion.metro,
            source: "user-suggestion",
            manuallyEdited: false,
            createdAt: Date(),
            modifiedAt: Date(),
            price: nil,
            ageRange: nil,
            websiteURL: suggestion.externalURL,
            phone: nil,
            contactEmail: nil
        )

        _ = try await EventService.shared.createEvent(event)

        // 2. Update suggestion status to approved
        try await updateSuggestionStatus(suggestion, status: .approved)
        NSLog("[EventSuggestionService] Approved: %@", suggestion.title)
    }

    // MARK: - Admin: Reject

    func rejectSuggestion(_ suggestion: EventSuggestion, note: String? = nil) async throws {
        try await updateSuggestionStatus(suggestion, status: .rejected, note: note)
        NSLog("[EventSuggestionService] Rejected: %@", suggestion.title)
    }

    // MARK: - Private

    private func updateSuggestionStatus(
        _ suggestion: EventSuggestion,
        status: EventSuggestion.SuggestionStatus,
        note: String? = nil
    ) async throws {
        let recordID = CKRecord.ID(recordName: suggestion.id)
        let record = try await database.record(for: recordID)
        record["status"] = status.rawValue
        record["reviewedAt"] = Date()
        if let note { record["reviewNote"] = note }
        _ = try await database.save(record)
    }
}

// MARK: - Custom Errors

enum CloudKitPermissionError: LocalizedError {
    case notSignedIn(String)
    case permissionDenied(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn(let msg): return msg
        case .permissionDenied(let msg): return msg
        case .networkError(let msg): return msg
        }
    }
}
