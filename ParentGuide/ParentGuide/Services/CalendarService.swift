//
//  CalendarService.swift
//  ParentGuide
//

import EventKit
import Foundation

@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Authorization

    /// Request access to the user's calendar. Returns true if granted.
    @MainActor
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            print("[CalendarService] Access request failed: \(error)")
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    var hasAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    // MARK: - Add Event

    /// Add a ParentGuide event to the user's default calendar.
    /// Returns true if successfully saved.
    @MainActor
    func addToCalendar(_ event: Event) async -> CalendarResult {
        // Ensure we have access
        if !hasAccess {
            let granted = await requestAccess()
            if !granted {
                return .denied
            }
        }

        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.title
        calendarEvent.startDate = event.startDate
        calendarEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600) // default 1 hour
        calendarEvent.isAllDay = event.isAllDay

        // Build notes from available info
        var notes: [String] = []
        if !event.eventDescription.isEmpty {
            notes.append(event.eventDescription)
        }
        if let price = event.price, !price.isEmpty {
            notes.append("Price: \(price)")
        }
        if let ageRange = event.ageRange, !ageRange.isEmpty {
            notes.append("Ages: \(ageRange)")
        }
        if let phone = event.phone, !phone.isEmpty {
            notes.append("Phone: \(phone)")
        }
        if !notes.isEmpty {
            calendarEvent.notes = notes.joined(separator: "\n\n")
        }

        // Location
        if let locationName = event.locationName {
            calendarEvent.location = event.address != nil
                ? "\(locationName), \(event.address!)"
                : locationName
        } else if let address = event.address {
            calendarEvent.location = address
        }

        // URL
        if let urlString = event.externalURL, let url = URL(string: urlString) {
            calendarEvent.url = url
        } else if let urlString = event.websiteURL, let url = URL(string: urlString) {
            calendarEvent.url = url
        }

        // Add a 1-hour reminder
        calendarEvent.addAlarm(EKAlarm(relativeOffset: -3600))

        calendarEvent.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(calendarEvent, span: .thisEvent)
            return .success
        } catch {
            print("[CalendarService] Save failed: \(error)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Duplicate Detection

    /// Check if an event with the same title and start date already exists in the user's calendar.
    func isAlreadyInCalendar(_ event: Event) -> Bool {
        guard hasAccess else { return false }
        let startOfDay = Calendar.current.startOfDay(for: event.startDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let existingEvents = store.events(matching: predicate)
        return existingEvents.contains { existing in
            existing.title == event.title &&
            abs(existing.startDate.timeIntervalSince(event.startDate)) < 60 // within 1 minute
        }
    }

    // MARK: - Batch Add

    /// Add multiple events to calendar, skipping duplicates.
    /// Returns (added, skipped, errors) counts.
    @MainActor
    func addBatchToCalendar(_ events: [Event]) async -> BatchCalendarResult {
        // Ensure we have access
        if !hasAccess {
            let granted = await requestAccess()
            if !granted {
                return BatchCalendarResult(added: 0, skipped: 0, denied: true, errorMessage: nil)
            }
        }

        var added = 0
        var skipped = 0

        for event in events {
            // Skip if already in calendar
            if isAlreadyInCalendar(event) {
                skipped += 1
                continue
            }

            let result = await addToCalendar(event)
            switch result {
            case .success:
                added += 1
            case .denied:
                return BatchCalendarResult(added: added, skipped: skipped, denied: true, errorMessage: nil)
            case .error(let msg):
                NSLog("[CalendarService] Batch add error for '%@': %@", event.title, msg)
                // Continue with remaining events
            }
        }

        return BatchCalendarResult(added: added, skipped: skipped, denied: false, errorMessage: nil)
    }

    struct BatchCalendarResult {
        let added: Int
        let skipped: Int
        let denied: Bool
        let errorMessage: String?
    }

    enum CalendarResult {
        case success
        case denied
        case error(String)
    }
}
