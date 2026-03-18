//
//  HomeMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeMapView: View {
    /// Events passed from parent to avoid duplicate CloudKit fetch
    var events: [Event] = []

    @State private var metroService = MetroService.shared

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasAppeared = false

    /// Limit annotations to prevent map rendering lag
    private var mappableEvents: [Event] {
        Array(
            events
                .filter { $0.hasValidCoordinates }
                .prefix(50) // Cap at 50 pins for performance
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .foregroundStyle(Color.brandBlue)
                Text("Events Across \(metroService.selectedMetro.name)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 20)

            if hasAppeared {
                mapContent
            } else {
                // Lightweight placeholder until scrolled into view
                mapPlaceholder
                    .onAppear {
                        // Small delay so the rest of the feed renders first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeIn(duration: 0.2)) {
                                hasAppeared = true
                            }
                        }
                    }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Map Content (lazy loaded)

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $mapPosition) {
            ForEach(mappableEvents) { event in
                if let lat = event.latitude, let lon = event.longitude {
                    Marker(
                        event.title,
                        systemImage: event.category.iconName,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    )
                    .tint(event.category.color)
                }
            }
        }
        .frame(height: 250)
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .onAppear {
            centerOnMetro()
        }
        .onChange(of: metroService.selectedMetro.id) {
            centerOnMetro()
        }
    }

    // MARK: - Placeholder (shown before map loads)

    @ViewBuilder
    private var mapPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))

            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Loading map...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 250)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func centerOnMetro() {
        let metro = metroService.selectedMetro
        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: metro.latitude, longitude: metro.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    }
}

#Preview {
    HomeMapView()
}
