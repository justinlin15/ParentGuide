//
//  HomeMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeMapView: View {
    private var metroService = MetroService.shared

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
                // Sample event markers
                ForEach(PreviewData.sampleEvents) { event in
                    if let lat = event.latitude, let lon = event.longitude {
                        Marker(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(Color.brandBlue)
                    }
                }
            }
            .frame(height: 250)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HomeMapView()
}
