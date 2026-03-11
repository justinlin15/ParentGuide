//
//  EventCalendarViewModel.swift
//  ParentGuide
//

import Foundation

enum CalendarViewMode: String, CaseIterable {
    case week = "Week"
    case list = "Day"
    case month = "Month"
    case map = "Map"
}

@Observable
class EventCalendarViewModel {
    var currentMonth: Date = Date()
    var events: [Event] = []
    var eventsByDate: [Date: [Event]] = [:]
    var selectedViewMode: CalendarViewMode = .week
    var selectedDate: Date?
    var isLoading = false
    var errorMessage: String?

    // Use preview data for now; switch to CloudKit later
    var usePreviewData = true

    func loadEvents() async {
        isLoading = true
        errorMessage = nil

        if usePreviewData {
            let generated = PreviewData.generateMonthEvents(for: currentMonth)
            events = generated
            groupEventsByDate()
            isLoading = false
            return
        }

        do {
            let metroId = MetroService.shared.selectedMetro.id
            let fetched = try await EventService.shared.fetchEvents(forMetro: metroId, month: currentMonth)
            events = fetched
            groupEventsByDate()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func goToNextMonth() {
        currentMonth = currentMonth.adding(months: 1)
        Task { await loadEvents() }
    }

    func goToPreviousMonth() {
        currentMonth = currentMonth.adding(months: -1)
        Task { await loadEvents() }
    }

    func eventsForDate(_ date: Date) -> [Event] {
        let key = Calendar.current.startOfDay(for: date)
        return eventsByDate[key] ?? []
    }

    // MARK: - Admin CRUD helpers

    func removeEvent(id: String) {
        events.removeAll { $0.id == id }
        groupEventsByDate()
    }

    func upsertEvent(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
        groupEventsByDate()
    }

    private func groupEventsByDate() {
        eventsByDate = [:]
        for event in events {
            let key = Calendar.current.startOfDay(for: event.startDate)
            eventsByDate[key, default: []].append(event)
        }
    }
}
