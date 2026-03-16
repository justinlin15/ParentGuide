//
//  HomeMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeMapView: View {
    private var metroService = MetroService.shared
    @State private var events: [Event] = []
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 12) {
            Text("Events across \(metroService.selectedMetro.name)")
                .font(.title3)
                .fontWeight(.semibold)

            Map(position: $mapPosition) {
                ForEach(events.filter { $0.hasValidCoordinates }) { event in
                    if let lat = event.latitude, let lon = event.longitude {
                        Annotation(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Image(systemName: event.category.iconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(event.category.color)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .shadow(color: event.category.color.opacity(0.3), radius: 3, y: 1)
                        }
                    }
                }
            }
            .frame(height: 250)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .task {
            await loadAndCenter()
        }
        .onChange(of: metroService.selectedMetro.id) {
            Task { await loadAndCenter() }
        }
    }

    private func loadAndCenter() async {
        let metro = metroService.selectedMetro
        // Center map on selected metro
        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: metro.latitude, longitude: metro.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
        // Load events
        do {
            events = try await EventService.shared.fetchUpcomingEvents(forMetro: metro.id)
        } catch {
            // Fallback: leave empty
        }
    }
}

#Preview {
    HomeMapView()
}
