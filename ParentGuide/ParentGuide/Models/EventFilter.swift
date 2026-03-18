//
//  EventFilter.swift
//  ParentGuide
//

import Foundation
import CoreLocation

// MARK: - Filter Enums

enum PriceFilter: String, CaseIterable {
    case all = "All"
    case free = "Free"
    case paid = "Paid"
}

enum DateRangeOption: String, CaseIterable {
    case allUpcoming = "All Upcoming"
    case today = "Today"
    case thisWeek = "This Week"
    case thisWeekend = "This Weekend"
    case thisMonth = "This Month"
    case custom = "Custom"

    var displayName: String { rawValue }
}

enum EventSortOption: String, CaseIterable {
    case date = "Date"
    case distance = "Distance"
    case priceLowToHigh = "Price"

    var iconName: String {
        switch self {
        case .date: return "calendar"
        case .distance: return "location"
        case .priceLowToHigh: return "dollarsign.circle"
        }
    }
}

enum DistanceOption: Double, CaseIterable {
    case five = 5
    case ten = 10
    case twentyFive = 25
    case fifty = 50
    case unlimited = 0

    var displayName: String {
        switch self {
        case .five: return "5 mi"
        case .ten: return "10 mi"
        case .twentyFive: return "25 mi"
        case .fifty: return "50 mi"
        case .unlimited: return "Any"
        }
    }
}

enum DistanceFromOption: String, CaseIterable {
    case currentLocation = "Current Location"
    case home = "Home"
}

// MARK: - Event Filter

struct EventFilter {
    var selectedCategories: Set<EventCategory> = []
    var priceFilter: PriceFilter = .all
    var dateRange: DateRangeOption = .allUpcoming
    var customStartDate: Date? = nil
    var customEndDate: Date? = nil
    var distanceOption: DistanceOption = .unlimited
    var distanceFrom: DistanceFromOption = .currentLocation
    var sortBy: EventSortOption = .date

    // MARK: - Active Filter Tracking

    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty ||
        priceFilter != .all ||
        dateRange != .allUpcoming ||
        distanceOption != .unlimited ||
        sortBy != .date
    }

    var activeFilterCount: Int {
        var count = 0
        if !selectedCategories.isEmpty { count += 1 }
        if priceFilter != .all { count += 1 }
        if dateRange != .allUpcoming { count += 1 }
        if distanceOption != .unlimited { count += 1 }
        if sortBy != .date { count += 1 }
        return count
    }

    /// Human-readable descriptions of active filters for chip display
    var activeFilterDescriptions: [(id: String, label: String)] {
        var descriptions: [(String, String)] = []

        if !selectedCategories.isEmpty {
            if selectedCategories.count == 1 {
                descriptions.append(("category", selectedCategories.first!.displayName))
            } else {
                descriptions.append(("category", "\(selectedCategories.count) categories"))
            }
        }

        if priceFilter != .all {
            descriptions.append(("price", priceFilter.rawValue))
        }

        if dateRange != .allUpcoming {
            descriptions.append(("date", dateRange.displayName))
        }

        if distanceOption != .unlimited {
            descriptions.append(("distance", "Within \(distanceOption.displayName)"))
        }

        if sortBy != .date {
            descriptions.append(("sort", "Sort: \(sortBy.rawValue)"))
        }

        return descriptions
    }

    // MARK: - Apply Filters

    func apply(to events: [Event], userLocation: CLLocation?, homeLocation: CLLocation? = nil) -> [Event] {
        var result = events

        // 1. Category filter
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.category) }
        }

        // 2. Price filter
        switch priceFilter {
        case .all:
            break
        case .free:
            result = result.filter { $0.isFree }
        case .paid:
            result = result.filter { $0.hasPaidPrice }
        }

        // 3. Date range filter
        // For multi-day events, check overlap: event starts before range ends AND event ends after range starts.
        // This ensures ongoing multi-day events appear in date filters even if their startDate was earlier.
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .allUpcoming:
            break // already filtered to upcoming in service layer
        case .today:
            let rangeStart = calendar.startOfDay(for: now)
            let rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart)!
            result = result.filter { eventOverlaps($0, rangeStart: rangeStart, rangeEnd: rangeEnd) }
        case .thisWeek:
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) {
                result = result.filter { eventOverlaps($0, rangeStart: weekInterval.start, rangeEnd: weekInterval.end) }
            }
        case .thisWeekend:
            // Find the next Saturday and Sunday
            let weekday = calendar.component(.weekday, from: now)
            let daysToSaturday = (7 - weekday) % 7
            if let saturday = calendar.date(byAdding: .day, value: daysToSaturday == 0 && weekday != 7 ? 7 : daysToSaturday, to: calendar.startOfDay(for: now)),
               let monday = calendar.date(byAdding: .day, value: 2, to: saturday) {
                // If today is Saturday or Sunday, use this weekend
                let actualStart: Date
                if weekday == 7 { // Saturday
                    actualStart = calendar.startOfDay(for: now)
                } else if weekday == 1 { // Sunday
                    actualStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
                } else {
                    actualStart = saturday
                }
                let actualEnd = weekday == 1
                    ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
                    : monday
                result = result.filter { eventOverlaps($0, rangeStart: actualStart, rangeEnd: actualEnd) }
            }
        case .thisMonth:
            if let monthInterval = calendar.dateInterval(of: .month, for: now) {
                result = result.filter { eventOverlaps($0, rangeStart: monthInterval.start, rangeEnd: monthInterval.end) }
            }
        case .custom:
            if let start = customStartDate {
                let rangeStart = calendar.startOfDay(for: start)
                if let end = customEndDate {
                    let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
                    result = result.filter { eventOverlaps($0, rangeStart: rangeStart, rangeEnd: rangeEnd) }
                } else {
                    result = result.filter { ($0.endDate ?? $0.startDate) >= rangeStart }
                }
            } else if let end = customEndDate {
                let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
                result = result.filter { $0.startDate < rangeEnd }
            }
        }

        // 4. Distance filter — use the appropriate reference location
        let referenceLocation: CLLocation? = distanceFrom == .home ? (homeLocation ?? userLocation) : userLocation
        if distanceOption != .unlimited, let location = referenceLocation {
            let maxMeters = distanceOption.rawValue * 1609.34 // miles to meters
            result = result.filter { event in
                guard event.hasValidCoordinates,
                      let lat = event.latitude, let lon = event.longitude else { return false }
                let eventLocation = CLLocation(latitude: lat, longitude: lon)
                return location.distance(from: eventLocation) <= maxMeters
            }
        }

        // 5. Sort
        let sortLocation: CLLocation? = distanceFrom == .home ? (homeLocation ?? userLocation) : userLocation
        switch sortBy {
        case .date:
            result.sort { $0.startDate < $1.startDate }
        case .distance:
            if let location = sortLocation {
                result.sort { a, b in
                    let distA = distanceInMiles(from: location, to: a)
                    let distB = distanceInMiles(from: location, to: b)
                    return distA < distB
                }
            } else {
                result.sort { $0.startDate < $1.startDate }
            }
        case .priceLowToHigh:
            result.sort { a, b in
                let tierA = a.priceTier ?? 99
                let tierB = b.priceTier ?? 99
                if tierA != tierB { return tierA < tierB }
                return a.startDate < b.startDate
            }
        }

        return result
    }

    // MARK: - Mutations

    mutating func clearAll() {
        selectedCategories = []
        priceFilter = .all
        dateRange = .allUpcoming
        customStartDate = nil
        customEndDate = nil
        distanceOption = .unlimited
        distanceFrom = .currentLocation
        sortBy = .date
    }

    mutating func removeFilter(id: String) {
        switch id {
        case "category": selectedCategories = []
        case "price": priceFilter = .all
        case "date":
            dateRange = .allUpcoming
            customStartDate = nil
            customEndDate = nil
        case "distance": distanceOption = .unlimited
        case "sort": sortBy = .date
        default: break
        }
    }

    mutating func toggleCategory(_ category: EventCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    // MARK: - Helpers

    /// Check if an event overlaps with a date range.
    /// An event overlaps if it starts before the range ends AND ends at or after the range starts.
    /// For single-day events (no endDate), falls back to checking if startDate is within range.
    private func eventOverlaps(_ event: Event, rangeStart: Date, rangeEnd: Date) -> Bool {
        let eventEnd = event.endDate ?? event.startDate
        return event.startDate < rangeEnd && eventEnd >= rangeStart
    }

    private func distanceInMiles(from location: CLLocation, to event: Event) -> Double {
        guard let lat = event.latitude, let lon = event.longitude else { return .greatestFiniteMagnitude }
        let eventLocation = CLLocation(latitude: lat, longitude: lon)
        return location.distance(from: eventLocation) / 1609.34
    }
}
