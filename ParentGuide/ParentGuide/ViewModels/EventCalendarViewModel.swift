//
//  EventCalendarViewModel.swift
//  ParentGuide
//

import Foundation
import CoreLocation

enum CalendarViewMode: String, CaseIterable {
    case week = "Week"
    case list = "Day"
    case month = "Month"
    case map = "Map"
}

@Observable
class EventCalendarViewModel: NSObject, CLLocationManagerDelegate {
    var currentMonth: Date = Date()
    var events: [Event] = []
    var eventsByDate: [Date: [Event]] = [:]
    var selectedViewMode: CalendarViewMode = .week
    var selectedDate: Date?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Filter State
    var filter = EventFilter()
    var userLocation: CLLocation?
    private var locationManager: CLLocationManager?

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Location

    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager = manager

        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func requestLocationAccess() {
        locationManager?.requestWhenInUseAuthorization()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.userLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("[EventCalendarVM] Location error: %@", error.localizedDescription)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    var hasLocation: Bool {
        userLocation != nil
    }

    // MARK: - Filtered Events

    /// All events with current filters applied
    var filteredEvents: [Event] {
        filter.apply(to: events, userLocation: userLocation)
    }

    /// Filtered events for the currently displayed month
    var filteredEventsForCurrentMonth: [Event] {
        let startOfMonth = currentMonth.startOfMonth
        let endOfMonth = currentMonth.endOfMonth
        return filteredEvents.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
    }

    /// Filtered events grouped by date
    var filteredEventsByDate: [Date: [Event]] {
        var grouped: [Date: [Event]] = [:]
        for event in filteredEvents {
            let key = Calendar.current.startOfDay(for: event.startDate)
            grouped[key, default: []].append(event)
        }
        return grouped
    }

    func filteredEventsForDate(_ date: Date) -> [Event] {
        let key = Calendar.current.startOfDay(for: date)
        return filteredEventsByDate[key] ?? []
    }

    // MARK: - Data Loading

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

    /// Events for the currently displayed month (unfiltered).
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
