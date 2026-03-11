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
    var allCities: [String] = []
    var isLoading = false
    var errorMessage: String?
    var showFilter = false

    var usePreviewData = true

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

    func clearFilter() {
        selectedCities.removeAll()
        applyFilter()
    }

    func applyFilter() {
        if selectedCities.isEmpty {
            filteredRestaurants = restaurants
        } else {
            filteredRestaurants = restaurants.filter { restaurant in
                !restaurant.cities.filter { selectedCities.contains($0) }.isEmpty
            }
        }
    }

    private func extractCities() {
        let citySet = Set(restaurants.flatMap { $0.cities })
        allCities = citySet.sorted()
    }
}
