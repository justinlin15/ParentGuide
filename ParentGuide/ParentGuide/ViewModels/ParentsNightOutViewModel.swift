//
//  ParentsNightOutViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class ParentsNightOutViewModel {
    var providers: [ParentsNightOutProvider] = []
    var isLoading = false
    var errorMessage: String?

    var usePreviewData = true

    func loadProviders() async {
        isLoading = true

        if usePreviewData {
            providers = PreviewData.sampleProviders
            isLoading = false
            return
        }

        do {
            providers = try await GuideService.shared.fetchParentsNightOutProviders()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
