//
//  MetroService.swift
//  ParentGuide
//

import CoreLocation
import Foundation

@Observable
class MetroService {
    static let shared = MetroService()

    // MARK: - State

    /// The currently selected metro area. Persisted in UserDefaults.
    var selectedMetro: AppConstants.Metro {
        didSet { persist() }
    }

    /// Whether the user has completed the onboarding flow (picked a metro).
    /// Stored property so @Observable can track changes and SwiftUI re-renders.
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    // MARK: - Keys

    private static let selectedMetroKey = "selectedMetroId"
    private static let onboardingKey = "hasCompletedOnboarding"

    // MARK: - Init

    private init() {
        // Restore saved metro from UserDefaults, or fall back to first metro (LA/OC)
        let savedId = UserDefaults.standard.string(forKey: Self.selectedMetroKey)
        selectedMetro = AppConstants.metroAreas.first { $0.id == savedId }
            ?? AppConstants.metroAreas[0]
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    // MARK: - Actions

    func selectMetro(_ metro: AppConstants.Metro) {
        selectedMetro = metro
        print("[MetroService] Selected metro: \(metro.name) (\(metro.id))")
    }

    /// Called when the user completes onboarding — persists metro and marks onboarding done.
    func completeOnboarding(with metro: AppConstants.Metro) {
        selectMetro(metro)
        hasCompletedOnboarding = true
        print("[MetroService] Onboarding complete with metro: \(metro.name)")
    }

    /// Auto-detect the nearest metro from the device's current location.
    func autoDetect() async -> AppConstants.Metro {
        await withCheckedContinuation { continuation in
            let helper = LocationHelper()
            helper.requestLocation { coordinate in
                if let coordinate {
                    let nearest = AppConstants.nearestMetro(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    print("[MetroService] Auto-detected metro: \(nearest.name) from (\(coordinate.latitude), \(coordinate.longitude))")
                    continuation.resume(returning: nearest)
                } else {
                    print("[MetroService] Auto-detect failed — falling back to default")
                    continuation.resume(returning: AppConstants.metroAreas[0])
                }
            }
        }
    }

    /// Restore the metro from a signed-in user's CloudKit profile (if they have one saved).
    func restoreFromProfile(_ profile: UserProfile) {
        if let savedMetroId = profile.favoriteCities.first,
           let metro = AppConstants.metroAreas.first(where: { $0.id == savedMetroId }) {
            selectedMetro = metro
            print("[MetroService] Restored metro from profile: \(metro.name)")
        }
    }

    // MARK: - Private

    private func persist() {
        UserDefaults.standard.set(selectedMetro.id, forKey: Self.selectedMetroKey)
    }
}
