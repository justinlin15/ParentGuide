//
//  KidsEatFreeViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class KidsEatFreeViewModel {
    var restaurants: [KidsEatFreeRestaurant] = []
    var filteredRestaurants: [KidsEatFreeRestaurant] = []
    var selectedCities: Set<String> = []
    var selectedDays: Set<String> = []
    var searchText = ""
    var allCities: [String] = []
    var isLoading = false
    var errorMessage: String?
    var showFilter = false

    var usePreviewData = true

    static let allDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var activeFilterCount: Int {
        selectedCities.count + selectedDays.count
    }

    func loadRestaurants() async {
        isLoading = true

        if usePreviewData {
            restaurants = PreviewData.sampleRestaurants
            extractCities()
            applyFilter()
            isLoading = false
            return
        }

        do {
            restaurants = try await GuideService.shared.fetchKidsEatFreeRestaurants()
            extractCities()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleCity(_ city: String) {
        if selectedCities.contains(city) {
            selectedCities.remove(city)
        } else {
            selectedCities.insert(city)
        }
        applyFilter()
    }

    func toggleDay(_ day: String) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        applyFilter()
    }

    func clearFilter() {
        selectedCities.removeAll()
        selectedDays.removeAll()
        applyFilter()
    }

    func applyFilter() {
        var result = restaurants

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter by city
        if !selectedCities.isEmpty {
            result = result.filter { restaurant in
                restaurant.cities.contains { selectedCities.contains($0) }
            }
        }

        // Filter by day of week
        if !selectedDays.isEmpty {
            result = result.filter { restaurant in
                let details = restaurant.dealDetails.lowercased()
                if details.contains("every day") || details.contains("everyday") { return true }
                return selectedDays.contains { details.contains($0.lowercased()) }
            }
        }

        filteredRestaurants = result
    }

    private func extractCities() {
        let citySet = Set(restaurants.flatMap { $0.cities })
        allCities = citySet.sorted()
    }
}
