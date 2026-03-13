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

    func loadEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let metroId = MetroService.shared.selectedMetro.id
            let fetched = try await EventService.shared.fetchUpcomingEvents(forMetro: metroId)
            events = fetched
            groupEventsByDate()
            NSLog("[EventCalendarVM] Loaded %d events for metro: %@", fetched.count, metroId)
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[EventCalendarVM] Error: %@", error.localizedDescription)
        }

        isLoading = false
    }

    func goToNextMonth() {
        currentMonth = currentMonth.adding(months: 1)
    }

    func goToPreviousMonth() {
        currentMonth = currentMonth.adding(months: -1)
    }

    /// Events for the currently displayed month.
    var eventsForCurrentMonth: [Event] {
        let startOfMonth = currentMonth.startOfMonth
        let endOfMonth = currentMonth.endOfMonth
        return events.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
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
