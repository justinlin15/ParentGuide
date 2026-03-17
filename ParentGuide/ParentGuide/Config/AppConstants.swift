//
//  AppConstants.swift
//  ParentGuide
//

import Foundation

nonisolated enum AppConstants {
    static let cloudKitContainerID = "iCloud.com.parentguide.app"
    static let appName = "Parent Guide"
    static let tagline = "Your family fun calendar!"
    static let monthlyPrice = "$5"
    static let annualPrice = "$48"

    // MARK: - Subscription Gates
    /// Free users can only view events within this many days from today.
    /// Events beyond this window are visible but tapping them triggers the paywall.
    static let freeEventHorizonDays = 3
    static let eventCount = "1,500+"
    static let defaultRegionLatitude = 33.7175  // Orange County center
    static let defaultRegionLongitude = -117.8311
    static let defaultRegionSpanDelta = 0.5

    // MARK: - Metro Areas (must match pipeline/src/config.ts)
    struct Metro: Equatable {
        let id: String
        let name: String
        let latitude: Double
        let longitude: Double
    }

    static let metroAreas: [Metro] = [
        Metro(id: "los-angeles", name: "Los Angeles", latitude: 34.0522, longitude: -118.2437),
        Metro(id: "orange-county", name: "Orange County", latitude: 33.7175, longitude: -117.8311),
        Metro(id: "new-york", name: "New York City / Tri-State", latitude: 40.7128, longitude: -74.006),
        Metro(id: "dallas", name: "Dallas-Fort Worth", latitude: 32.7767, longitude: -96.797),
        Metro(id: "chicago", name: "Chicago", latitude: 41.8781, longitude: -87.6298),
        Metro(id: "atlanta", name: "Atlanta", latitude: 33.749, longitude: -84.388),
    ]

    // MARK: - Launch Configuration
    // Only these metros are active for Phase 1 launch.
    // To expand: add metro IDs here — the full definitions stay in metroAreas above.
    static let launchMetroIDs: Set<String> = ["los-angeles", "orange-county"]
    static var launchMetros: [Metro] {
        metroAreas.filter { launchMetroIDs.contains($0.id) }
    }

    // Find the nearest metro to a given coordinate (searches only launch metros)
    static func nearestMetro(latitude: Double, longitude: Double) -> Metro {
        launchMetros.min { a, b in
            let dA = pow(a.latitude - latitude, 2) + pow(a.longitude - longitude, 2)
            let dB = pow(b.latitude - latitude, 2) + pow(b.longitude - longitude, 2)
            return dA < dB
        } ?? launchMetros[0]
    }
}
