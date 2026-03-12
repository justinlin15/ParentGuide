//
//  ParentsNightOutViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class ParentsNightOutViewModel {
    var providers: [ParentsNightOutProvider] = []
    var filteredProviders: [ParentsNightOutProvider] = []
    var selectedCities: Set<String> = []
    var searchText = ""
    var onlyWithPromo = false
    var allCities: [String] = []
    var isLoading = false
    var errorMessage: String?
    var showFilter = false

    var usePreviewData = false

    var activeFilterCount: Int {
        selectedCities.count + (onlyWithPromo ? 1 : 0)
    }

    func loadProviders() async {
        isLoading = true

        if usePreviewData {
            providers = PreviewData.sampleProviders
            extractCities()
            applyFilter()
            isLoading = false
            return
        }

        do {
            let allProviders = try await GuideService.shared.fetchParentsNightOutProviders()
            let metroId = MetroService.shared.selectedMetro.id
            // Records with nil metro are legacy OC data — treat as "los-angeles"
            providers = allProviders.filter { ($0.metro ?? "los-angeles") == metroId }
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
        onlyWithPromo = false
        applyFilter()
    }

    func applyFilter() {
        var result = providers

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if !selectedCities.isEmpty {
            result = result.filter { provider in
                provider.cities.contains { selectedCities.contains($0) }
            }
        }

        if onlyWithPromo {
            result = result.filter { $0.promoCode != nil && !($0.promoCode?.isEmpty ?? true) }
        }

        filteredProviders = result
    }

    private func extractCities() {
        let citySet = Set(providers.flatMap { $0.cities })
        allCities = citySet.sorted()
    }
}
