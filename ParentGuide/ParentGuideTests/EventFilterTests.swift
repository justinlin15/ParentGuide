//
//  EventFilterTests.swift
//  ParentGuideTests
//

import Testing
import Foundation
import CoreLocation
@testable import ParentGuide

// MARK: - Test Helpers

private func makeEvent(
    id: String = UUID().uuidString,
    title: String = "Test Event",
    category: EventCategory = .other,
    startDate: Date = Date(),
    endDate: Date? = nil,
    isAllDay: Bool = false,
    price: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    city: String = "Irvine"
) -> Event {
    Event(
        id: id,
        title: title,
        eventDescription: "",
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        category: category,
        city: city,
        address: nil,
        latitude: latitude,
        longitude: longitude,
        locationName: nil,
        imageURL: nil,
        externalURL: nil,
        isFeatured: false,
        isRecurring: false,
        tags: [],
        metro: "OC",
        source: nil,
        createdAt: Date(),
        modifiedAt: Date(),
        price: price
    )
}

private let calendar = Calendar.current

/// Create a date relative to now with specified day offset and hour
private func date(daysFromNow days: Int, hour: Int = 10) -> Date {
    let start = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .hour, value: hour, to: calendar.date(byAdding: .day, value: days, to: start)!)!
}

/// Irvine, CA coordinates
private let irvineLocation = CLLocation(latitude: 33.6846, longitude: -117.8265)
/// Los Angeles coordinates (~40 miles from Irvine)
private let laLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
/// San Diego coordinates (~80 miles from Irvine)
private let sdLocation = CLLocation(latitude: 32.7157, longitude: -117.1611)

// MARK: - Category Filter Tests

@Suite("Category Filters")
struct CategoryFilterTests {
    @Test("No category filter returns all events")
    func noCategoryFilter() {
        let events = [
            makeEvent(category: .storytime),
            makeEvent(category: .music),
            makeEvent(category: .festival),
        ]
        var filter = EventFilter()
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 3)
    }

    @Test("Single category filter returns only matching events")
    func singleCategory() {
        let events = [
            makeEvent(category: .storytime),
            makeEvent(category: .music),
            makeEvent(category: .festival),
        ]
        var filter = EventFilter()
        filter.selectedCategories = [.storytime]
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].category == .storytime)
    }

    @Test("Multiple category filter returns all matching events")
    func multipleCategories() {
        let events = [
            makeEvent(category: .storytime),
            makeEvent(category: .music),
            makeEvent(category: .festival),
        ]
        var filter = EventFilter()
        filter.selectedCategories = [.storytime, .festival]
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 2)
    }

    @Test("Toggle category adds and removes")
    func toggleCategory() {
        var filter = EventFilter()
        filter.toggleCategory(.storytime)
        #expect(filter.selectedCategories.contains(.storytime))
        filter.toggleCategory(.storytime)
        #expect(!filter.selectedCategories.contains(.storytime))
    }
}

// MARK: - Price Filter Tests

@Suite("Price Filters")
struct PriceFilterTests {
    let events = [
        makeEvent(title: "Free Event", price: "Free"),
        makeEvent(title: "Paid Event", price: "$25"),
        makeEvent(title: "No Price", price: nil),
    ]

    @Test("Price filter 'all' returns all events")
    func priceAll() {
        var filter = EventFilter()
        filter.priceFilter = .all
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 3)
    }

    @Test("Price filter 'free' returns free events AND events with no price (nil = free)")
    func priceFree() {
        var filter = EventFilter()
        filter.priceFilter = .free
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "Free Event" })
        #expect(result.contains { $0.title == "No Price" })
    }

    @Test("Price filter 'paid' returns only events with explicit paid price")
    func pricePaid() {
        var filter = EventFilter()
        filter.priceFilter = .paid
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "Paid Event")
    }

    @Test("Free detection works with various price strings including nil")
    func freeDetection() {
        let freeVariations = [
            makeEvent(price: "Free"),
            makeEvent(price: "free"),
            makeEvent(price: "$0"),
            makeEvent(price: "0"),
            makeEvent(price: "Free admission"),
            makeEvent(price: nil),      // No price = free
            makeEvent(price: ""),       // Empty price = free
        ]
        for event in freeVariations {
            #expect(event.isFree, "Expected '\(event.price ?? "nil")' to be detected as free")
        }
    }

    @Test("Paid detection only matches explicit paid prices")
    func paidDetection() {
        #expect(makeEvent(price: "$25").hasPaidPrice)
        #expect(makeEvent(price: "$5").hasPaidPrice)
        #expect(!makeEvent(price: nil).hasPaidPrice)
        #expect(!makeEvent(price: "").hasPaidPrice)
        #expect(!makeEvent(price: "Free").hasPaidPrice)
    }

    @Test("Price tiers are calculated correctly")
    func priceTiers() {
        #expect(makeEvent(price: "Free").priceTier == 0)
        #expect(makeEvent(price: "$5").priceTier == 1)
        #expect(makeEvent(price: "$15").priceTier == 2)
        #expect(makeEvent(price: "$30").priceTier == 3)
        #expect(makeEvent(price: "$75").priceTier == 4)
        #expect(makeEvent(price: "$150").priceTier == 5)
        #expect(makeEvent(price: nil).priceTier == 0)  // No price = free tier
    }
}

// MARK: - Date Range Filter Tests

@Suite("Date Range Filters")
struct DateRangeFilterTests {
    @Test("'All Upcoming' returns all events")
    func allUpcoming() {
        let events = [
            makeEvent(startDate: date(daysFromNow: 0)),
            makeEvent(startDate: date(daysFromNow: 30)),
            makeEvent(startDate: date(daysFromNow: 90)),
        ]
        var filter = EventFilter()
        filter.dateRange = .allUpcoming
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 3)
    }

    @Test("'Today' returns only events starting today")
    func todayFilter() {
        let events = [
            makeEvent(title: "Today", startDate: date(daysFromNow: 0, hour: 14)),
            makeEvent(title: "Tomorrow", startDate: date(daysFromNow: 1)),
            makeEvent(title: "Yesterday", startDate: date(daysFromNow: -1)),
        ]
        var filter = EventFilter()
        filter.dateRange = .today
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "Today")
    }

    @Test("'Today' includes multi-day events that started before today but end today or later")
    func todayIncludesMultiDayEvents() {
        let events = [
            makeEvent(
                title: "Multi-day Festival",
                startDate: date(daysFromNow: -2, hour: 9),
                endDate: date(daysFromNow: 1, hour: 17)
            ),
            makeEvent(
                title: "Ended Yesterday",
                startDate: date(daysFromNow: -3, hour: 9),
                endDate: date(daysFromNow: -1, hour: 17)
            ),
            makeEvent(title: "Today Only", startDate: date(daysFromNow: 0, hour: 14)),
        ]
        var filter = EventFilter()
        filter.dateRange = .today
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "Multi-day Festival" })
        #expect(result.contains { $0.title == "Today Only" })
    }

    @Test("'This Week' returns events in current calendar week")
    func thisWeekFilter() {
        let events = [
            makeEvent(title: "This Week", startDate: date(daysFromNow: 0)),
            makeEvent(title: "Next Week", startDate: date(daysFromNow: 8)),
        ]
        var filter = EventFilter()
        filter.dateRange = .thisWeek
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.contains { $0.title == "This Week" })
        #expect(!result.contains { $0.title == "Next Week" })
    }

    @Test("'This Month' returns events in current month")
    func thisMonthFilter() {
        let events = [
            makeEvent(title: "This Month", startDate: date(daysFromNow: 0)),
            makeEvent(title: "Far Future", startDate: date(daysFromNow: 60)),
        ]
        var filter = EventFilter()
        filter.dateRange = .thisMonth
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.contains { $0.title == "This Month" })
        #expect(!result.contains { $0.title == "Far Future" })
    }

    @Test("'This Month' includes multi-day events overlapping the month")
    func thisMonthMultiDay() {
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)!
        let events = [
            makeEvent(
                title: "Started Last Month",
                startDate: calendar.date(byAdding: .day, value: -35, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 5, to: monthInterval.start)!
            ),
        ]
        var filter = EventFilter()
        filter.dateRange = .thisMonth
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
    }

    @Test("Custom date range works with start and end dates")
    func customDateRange() {
        let events = [
            makeEvent(title: "In Range", startDate: date(daysFromNow: 3)),
            makeEvent(title: "Before Range", startDate: date(daysFromNow: 0)),
            makeEvent(title: "After Range", startDate: date(daysFromNow: 10)),
        ]
        var filter = EventFilter()
        filter.dateRange = .custom
        filter.customStartDate = date(daysFromNow: 2)
        filter.customEndDate = date(daysFromNow: 5)
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "In Range")
    }

    @Test("Custom date range with only start date")
    func customStartOnly() {
        let events = [
            makeEvent(title: "Before", startDate: date(daysFromNow: 0)),
            makeEvent(title: "After", startDate: date(daysFromNow: 5)),
        ]
        var filter = EventFilter()
        filter.dateRange = .custom
        filter.customStartDate = date(daysFromNow: 3)
        filter.customEndDate = nil
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "After")
    }
}

// MARK: - Distance Filter Tests

@Suite("Distance Filters")
struct DistanceFilterTests {
    @Test("Unlimited distance returns all events with and without coords")
    func unlimitedDistance() {
        let events = [
            makeEvent(latitude: 33.68, longitude: -117.82),
            makeEvent(latitude: nil, longitude: nil),
        ]
        var filter = EventFilter()
        filter.distanceOption = .unlimited
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.count == 2)
    }

    @Test("Distance filter excludes events without coordinates")
    func noCoordinates() {
        let events = [
            makeEvent(title: "Has Coords", latitude: 33.68, longitude: -117.82),
            makeEvent(title: "No Coords", latitude: nil, longitude: nil),
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.count == 1)
        #expect(result[0].title == "Has Coords")
    }

    @Test("Distance filter excludes events with 0,0 coordinates")
    func zeroCoordinates() {
        let events = [
            makeEvent(title: "Valid", latitude: 33.68, longitude: -117.82),
            makeEvent(title: "Zero", latitude: 0, longitude: 0),
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.count == 1)
        #expect(result[0].title == "Valid")
    }

    @Test("5 mile filter returns only nearby events")
    func fiveMileFilter() {
        let events = [
            makeEvent(title: "Nearby", latitude: 33.69, longitude: -117.83), // ~0.5mi
            makeEvent(title: "LA", latitude: 34.0522, longitude: -118.2437), // ~40mi
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.count == 1)
        #expect(result[0].title == "Nearby")
    }

    @Test("50 mile filter includes LA but excludes San Diego")
    func fiftyMileFilter() {
        let events = [
            makeEvent(title: "Irvine", latitude: 33.68, longitude: -117.82),
            makeEvent(title: "LA", latitude: 34.0522, longitude: -118.2437),
            makeEvent(title: "SD", latitude: 32.7157, longitude: -117.1611),
        ]
        var filter = EventFilter()
        filter.distanceOption = .fifty
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.contains { $0.title == "Irvine" })
        #expect(result.contains { $0.title == "LA" })
        #expect(!result.contains { $0.title == "SD" })
    }

    @Test("Distance filter without user location returns all events")
    func noUserLocation() {
        let events = [
            makeEvent(latitude: 33.68, longitude: -117.82),
            makeEvent(latitude: 34.05, longitude: -118.24),
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        let result = filter.apply(to: events, userLocation: nil)
        // Without user location, distance filter should not exclude events
        #expect(result.count == 2)
    }

    @Test("Distance from home uses home location instead of current location")
    func distanceFromHome() {
        // Home in LA, current location in Irvine
        let homeInLA = laLocation
        let events = [
            makeEvent(title: "Near LA", latitude: 34.06, longitude: -118.25),    // ~0.5mi from LA
            makeEvent(title: "Near Irvine", latitude: 33.69, longitude: -117.83), // ~40mi from LA, ~0.5mi from Irvine
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        filter.distanceFrom = .home
        let result = filter.apply(to: events, userLocation: irvineLocation, homeLocation: homeInLA)
        // Should filter from LA, not Irvine
        #expect(result.count == 1)
        #expect(result[0].title == "Near LA")
    }

    @Test("Distance from current location uses GPS location")
    func distanceFromCurrentLocation() {
        let homeInLA = laLocation
        let events = [
            makeEvent(title: "Near LA", latitude: 34.06, longitude: -118.25),
            makeEvent(title: "Near Irvine", latitude: 33.69, longitude: -117.83),
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        filter.distanceFrom = .currentLocation
        let result = filter.apply(to: events, userLocation: irvineLocation, homeLocation: homeInLA)
        // Should filter from Irvine (current location), not LA
        #expect(result.count == 1)
        #expect(result[0].title == "Near Irvine")
    }

    @Test("Distance from home falls back to current location when home not set")
    func distanceFromHomeFallback() {
        let events = [
            makeEvent(title: "Near Irvine", latitude: 33.69, longitude: -117.83),
            makeEvent(title: "Far", latitude: 34.05, longitude: -118.24),
        ]
        var filter = EventFilter()
        filter.distanceOption = .five
        filter.distanceFrom = .home
        // No home location, should fall back to current (Irvine)
        let result = filter.apply(to: events, userLocation: irvineLocation, homeLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "Near Irvine")
    }

    @Test("clearAll resets distanceFrom to currentLocation")
    func clearAllResetsDistanceFrom() {
        var filter = EventFilter()
        filter.distanceFrom = .home
        filter.clearAll()
        #expect(filter.distanceFrom == .currentLocation)
    }
}

// MARK: - Sort Tests

@Suite("Sort Options")
struct SortTests {
    @Test("Sort by date orders events chronologically")
    func sortByDate() {
        let events = [
            makeEvent(title: "Later", startDate: date(daysFromNow: 5)),
            makeEvent(title: "First", startDate: date(daysFromNow: 0)),
            makeEvent(title: "Middle", startDate: date(daysFromNow: 2)),
        ]
        var filter = EventFilter()
        filter.sortBy = .date
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result[0].title == "First")
        #expect(result[1].title == "Middle")
        #expect(result[2].title == "Later")
    }

    @Test("Sort by distance orders events by proximity")
    func sortByDistance() {
        let events = [
            makeEvent(title: "SD", latitude: 32.7157, longitude: -117.1611),
            makeEvent(title: "Irvine", latitude: 33.69, longitude: -117.83),
            makeEvent(title: "LA", latitude: 34.0522, longitude: -118.2437),
        ]
        var filter = EventFilter()
        filter.sortBy = .distance
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result[0].title == "Irvine")
        #expect(result[1].title == "LA")
        #expect(result[2].title == "SD")
    }

    @Test("Sort by distance without location falls back to date sort")
    func sortByDistanceNoLocation() {
        let events = [
            makeEvent(title: "Later", startDate: date(daysFromNow: 5), latitude: 32.71, longitude: -117.16),
            makeEvent(title: "First", startDate: date(daysFromNow: 0), latitude: 34.05, longitude: -118.24),
        ]
        var filter = EventFilter()
        filter.sortBy = .distance
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result[0].title == "First")
        #expect(result[1].title == "Later")
    }

    @Test("Sort by price orders free first (including nil), then by tier")
    func sortByPrice() {
        let events = [
            makeEvent(title: "Expensive", startDate: date(daysFromNow: 0), price: "$50"),
            makeEvent(title: "Free", startDate: date(daysFromNow: 1), price: "Free"),
            makeEvent(title: "Cheap", startDate: date(daysFromNow: 2), price: "$5"),
            makeEvent(title: "No Price", startDate: date(daysFromNow: 3), price: nil),
        ]
        var filter = EventFilter()
        filter.sortBy = .priceLowToHigh
        let result = filter.apply(to: events, userLocation: nil)
        // Free and No Price are both tier 0, sorted by date within tier
        #expect(result[0].title == "Free")
        #expect(result[1].title == "No Price")
        #expect(result[2].title == "Cheap")
        #expect(result[3].title == "Expensive")
    }
}

// MARK: - Combined Filter Tests

@Suite("Combined Filters")
struct CombinedFilterTests {
    @Test("Category + Price filters combine correctly")
    func categoryAndPrice() {
        let events = [
            makeEvent(title: "Free Music", category: .music, price: "Free"),
            makeEvent(title: "Paid Music", category: .music, price: "$20"),
            makeEvent(title: "Free Craft", category: .craft, price: "Free"),
        ]
        var filter = EventFilter()
        filter.selectedCategories = [.music]
        filter.priceFilter = .free
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.count == 1)
        #expect(result[0].title == "Free Music")
    }

    @Test("All filters combined")
    func allFiltersCombined() {
        let events = [
            makeEvent(title: "Match", category: .music, startDate: date(daysFromNow: 0, hour: 14), price: "Free", latitude: 33.69, longitude: -117.83),
            makeEvent(title: "Wrong Category", category: .craft, startDate: date(daysFromNow: 0, hour: 14), price: "Free", latitude: 33.69, longitude: -117.83),
            makeEvent(title: "Wrong Price", category: .music, startDate: date(daysFromNow: 0, hour: 14), price: "$50", latitude: 33.69, longitude: -117.83),
            makeEvent(title: "Too Far", category: .music, startDate: date(daysFromNow: 0, hour: 14), price: "Free", latitude: 34.05, longitude: -118.24),
        ]
        var filter = EventFilter()
        filter.selectedCategories = [.music]
        filter.priceFilter = .free
        filter.dateRange = .today
        filter.distanceOption = .five
        let result = filter.apply(to: events, userLocation: irvineLocation)
        #expect(result.count == 1)
        #expect(result[0].title == "Match")
    }
}

// MARK: - Filter State Tests

@Suite("Filter State Management")
struct FilterStateTests {
    @Test("Default filter has no active filters")
    func defaultState() {
        let filter = EventFilter()
        #expect(!filter.hasActiveFilters)
        #expect(filter.activeFilterCount == 0)
        #expect(filter.activeFilterDescriptions.isEmpty)
    }

    @Test("hasActiveFilters detects each filter type")
    func hasActiveFilters() {
        var filter = EventFilter()

        filter.selectedCategories = [.music]
        #expect(filter.hasActiveFilters)
        filter.clearAll()

        filter.priceFilter = .free
        #expect(filter.hasActiveFilters)
        filter.clearAll()

        filter.dateRange = .today
        #expect(filter.hasActiveFilters)
        filter.clearAll()

        filter.distanceOption = .ten
        #expect(filter.hasActiveFilters)
        filter.clearAll()

        filter.sortBy = .distance
        #expect(filter.hasActiveFilters)
        filter.clearAll()

        #expect(!filter.hasActiveFilters)
    }

    @Test("activeFilterCount counts correctly")
    func activeFilterCount() {
        var filter = EventFilter()
        filter.selectedCategories = [.music]
        filter.priceFilter = .free
        filter.dateRange = .today
        #expect(filter.activeFilterCount == 3)
    }

    @Test("clearAll resets all filters")
    func clearAll() {
        var filter = EventFilter()
        filter.selectedCategories = [.music, .craft]
        filter.priceFilter = .free
        filter.dateRange = .thisWeek
        filter.distanceOption = .ten
        filter.sortBy = .distance
        filter.customStartDate = Date()
        filter.customEndDate = Date()

        filter.clearAll()

        #expect(filter.selectedCategories.isEmpty)
        #expect(filter.priceFilter == .all)
        #expect(filter.dateRange == .allUpcoming)
        #expect(filter.distanceOption == .unlimited)
        #expect(filter.sortBy == .date)
        #expect(filter.customStartDate == nil)
        #expect(filter.customEndDate == nil)
    }

    @Test("removeFilter removes individual filters by ID")
    func removeFilter() {
        var filter = EventFilter()
        filter.selectedCategories = [.music]
        filter.priceFilter = .free
        filter.dateRange = .today
        filter.distanceOption = .ten
        filter.sortBy = .distance

        filter.removeFilter(id: "category")
        #expect(filter.selectedCategories.isEmpty)
        #expect(filter.priceFilter == .free)

        filter.removeFilter(id: "price")
        #expect(filter.priceFilter == .all)

        filter.removeFilter(id: "date")
        #expect(filter.dateRange == .allUpcoming)

        filter.removeFilter(id: "distance")
        #expect(filter.distanceOption == .unlimited)

        filter.removeFilter(id: "sort")
        #expect(filter.sortBy == .date)
    }

    @Test("activeFilterDescriptions generates correct labels")
    func filterDescriptions() {
        var filter = EventFilter()
        filter.selectedCategories = [.music]
        filter.priceFilter = .free
        filter.distanceOption = .twentyFive
        filter.sortBy = .priceLowToHigh

        let descriptions = filter.activeFilterDescriptions
        #expect(descriptions.contains { $0.id == "category" && $0.label == "Music" })
        #expect(descriptions.contains { $0.id == "price" && $0.label == "Free" })
        #expect(descriptions.contains { $0.id == "distance" && $0.label == "Within 25 mi" })
        #expect(descriptions.contains { $0.id == "sort" && $0.label == "Sort: Price" })
    }

    @Test("Multiple categories shows count in description")
    func multipleCategoryDescription() {
        var filter = EventFilter()
        filter.selectedCategories = [.music, .craft, .festival]
        let descriptions = filter.activeFilterDescriptions
        #expect(descriptions.contains { $0.id == "category" && $0.label == "3 categories" })
    }
}

// MARK: - Weekend Filter Edge Cases

@Suite("Weekend Filter Edge Cases")
struct WeekendFilterTests {
    @Test("Weekend filter includes Saturday and Sunday events")
    func weekendIncludesBothDays() {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        // Calculate the Saturday of "this weekend" as the filter sees it:
        // On Saturday (7): this Saturday
        // On Sunday (1): yesterday (Saturday)
        // On weekdays: next Saturday
        let saturday: Date
        if weekday == 7 {
            saturday = calendar.startOfDay(for: now)
        } else if weekday == 1 {
            saturday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        } else {
            let daysToSat = 7 - weekday
            saturday = calendar.date(byAdding: .day, value: daysToSat, to: calendar.startOfDay(for: now))!
        }

        let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
        let monday = calendar.date(byAdding: .day, value: 2, to: saturday)!

        let events = [
            makeEvent(title: "Saturday Event", startDate: calendar.date(byAdding: .hour, value: 10, to: saturday)!),
            makeEvent(title: "Sunday Event", startDate: calendar.date(byAdding: .hour, value: 10, to: sunday)!),
            makeEvent(title: "Monday Event", startDate: calendar.date(byAdding: .hour, value: 10, to: monday)!),
        ]
        var filter = EventFilter()
        filter.dateRange = .thisWeekend
        let result = filter.apply(to: events, userLocation: nil)
        #expect(result.contains { $0.title == "Saturday Event" })
        #expect(result.contains { $0.title == "Sunday Event" })
        #expect(!result.contains { $0.title == "Monday Event" })
    }
}
