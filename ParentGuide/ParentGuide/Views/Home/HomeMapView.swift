//
//  HomeMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeMapView: View {
    private var metroService = MetroService.shared
    @State private var events: [Event] = []

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: metroService.selectedMetro.latitude,
                longitude: metroService.selectedMetro.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Events across \(metroService.selectedMetro.name)")
                .font(.title3)
                .fontWeight(.semibold)

            Map(initialPosition: .region(region)) {
                ForEach(events.filter { $0.hasLocation }) { event in
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
            do {
                let metroId = metroService.selectedMetro.id
                events = try await EventService.shared.fetchUpcomingEvents(forMetro: metroId)
            } catch {
                // Fallback: leave empty
            }
        }
    }
}

#Preview {
    HomeMapView()
}
