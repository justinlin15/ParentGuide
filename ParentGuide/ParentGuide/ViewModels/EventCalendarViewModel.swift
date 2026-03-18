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
    /// The date the user is currently browsing in the week/agenda view. Persists across navigation.
    var browsedDate: Date = Calendar.current.startOfDay(for: Date())
    var isLoading = false
    var errorMessage: String?

    // MARK: - Filter State
    var filter = EventFilter()
    var userLocation: CLLocation?
    private var locationManager: CLLocationManager?
    /// Tracks the metro ID that events were last loaded for, so we can detect stale data on tab re-appearance.
    private(set) var loadedMetroId: String?

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

    /// All events with current filters applied.
    var filteredEvents: [Event] {
        filter.apply(to: events, userLocation: userLocation, homeLocation: homeLocation)
    }

    /// Home location from user profile for "distance from home" filter
    var homeLocation: CLLocation? {
        AuthService.shared.currentUser?.homeLocation
    }

    var hasHomeLocation: Bool {
        AuthService.shared.currentUser?.hasHomeLocation ?? false
    }

    /// The cutoff date beyond which free users cannot view event details.
    var freeHorizonDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: AppConstants.freeEventHorizonDays,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
    }

    /// Whether a given date is beyond the free viewing horizon for non-subscribers.
    func isDateLocked(_ date: Date) -> Bool {
        guard !SubscriptionService.shared.isSubscribed else { return false }
        return Calendar.current.startOfDay(for: date) > freeHorizonDate
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
            loadedMetroId = metroId
            groupEventsByDate()
            NSLog("[EventCalendarVM] Loaded %d events for metro: %@", fetched.count, metroId)
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[EventCalendarVM] Error: %@", error.localizedDescription)
        }

        isLoading = false
    }

    /// Reload events if the selected metro has changed since the last load.
    func reloadIfMetroChanged() async {
        let currentMetroId = MetroService.shared.selectedMetro.id
        if currentMetroId != loadedMetroId {
            NSLog("[EventCalendarVM] Metro changed from %@ to %@ — reloading", loadedMetroId ?? "nil", currentMetroId)
            await loadEvents()
        }
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
