//
//  EventMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: View {
    let events: [Event]
    @State private var selectedEvent: Event?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showLocationPrompt = false
    @State private var showZipEntry = false
    @State private var zipCode = ""
    @State private var locationManager = LocationHelper()
    var metroService = MetroService.shared

    private var eventsWithLocation: [Event] {
        events.filter { $0.hasLocation }
    }

    private var displayedEvents: [Event] {
        guard let region = visibleRegion else { return eventsWithLocation }
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2
        return eventsWithLocation.filter { event in
            guard let lat = event.latitude, let lon = event.longitude else { return false }
            return lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax
        }
    }

    var body: some View {
        ZStack {
            Map(position: $mapPosition, selection: $selectedEvent) {
                ForEach(displayedEvents) { event in
                    if let lat = event.latitude, let lon = event.longitude {
                        Annotation(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            VStack(spacing: 0) {
                                Image(systemName: event.category.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(event.category.color)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: 2.5)
                                    )
                                    .shadow(color: event.category.color.opacity(0.4), radius: 4, y: 2)

                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(event.category.color)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: -3)
                            }
                            .onTapGesture {
                                selectedEvent = event
                            }
                        }
                        .tag(event)
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }

            if !showLocationPrompt && !showZipEntry {
                VStack {
                    HStack {
                        Text("\(displayedEvents.count) event\(displayedEvents.count == 1 ? "" : "s") in this area")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                    }
                    Spacer()

                    // My Location button (like Google Maps)
                    HStack {
                        Spacer()
                        Button {
                            locationManager.requestLocation { coordinate in
                                if let coordinate {
                                    withAnimation {
                                        mapPosition = .region(MKCoordinateRegion(
                                            center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        ))
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.brandBlue)
                                .frame(width: 44, height: 44)
                                .background(.ultraThickMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }
                    }
                }
                .padding()
            }

            if showLocationPrompt {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandBlue)
                    Text("Find events near you")
                        .font(.title3).fontWeight(.bold)
                    Text("Allow location access to find nearby events, or enter a zip code.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        locationManager.requestLocation { coordinate in
                            if let coordinate { setInitialRegion(center: coordinate) }
                            else { showZipEntry = true }
                            showLocationPrompt = false
                        }
                    } label: {
                        Label("Use My Location", systemImage: "location.fill")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.brandBlue).clipShape(Capsule())
                    }
                    Button { showLocationPrompt = false; showZipEntry = true } label: {
                        Text("Enter Zip Code Instead").font(.subheadline).foregroundStyle(Color.brandBlue)
                    }
                }
                .padding(32).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(24)
            }

            if showZipEntry {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Enter Zip Code").font(.title3).fontWeight(.bold)
                    TextField("e.g. 92618", text: $zipCode)
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200).multilineTextAlignment(.center)
                    Button { geocodeZip(zipCode) } label: {
                        Text("Find Events").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.brandBlue).clipShape(Capsule())
                    }
                    Button("Cancel") { showZipEntry = false }.foregroundStyle(.secondary)
                }
                .padding(32).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(24)
            }
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(event: event)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedEvent = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            let metro = metroService.selectedMetro
            setInitialRegion(center: CLLocationCoordinate2D(latitude: metro.latitude, longitude: metro.longitude))
        }
    }

    private func setInitialRegion(center: CLLocationCoordinate2D) {
        mapPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        ))
    }

    private func geocodeZip(_ zip: String) {
        Task {
            do {
                guard let request = MKGeocodingRequest(addressString: zip) else { return }
                let mapItems = try await request.mapItems
                if let location = mapItems.first?.location {
                    setInitialRegion(center: location.coordinate)
                }
            } catch { print("[EventMapView] Geocoding failed: \(error)") }
            showZipEntry = false
        }
    }
}

@Observable
class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    /// Whether location permission has been denied or restricted
    var isDenied: Bool {
        let status = manager.authorizationStatus
        return status == .denied || status == .restricted
    }

    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        manager.delegate = self

        let status = manager.authorizationStatus
        switch status {
        case .denied, .restricted:
            // Permission denied — return nil immediately
            completion(nil)
            self.completion = nil
        case .notDetermined:
            // Will trigger system prompt; wait for auth change
            manager.requestWhenInUseAuthorization()
        default:
            // Already authorized — request location
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.first?.coordinate
        Task { @MainActor in completion?(coordinate); completion = nil }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in completion?(nil); completion = nil }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            } else if status == .denied || status == .restricted {
                completion?(nil)
                completion = nil
            }
        }
    }
}

#Preview {
    EventMapView(events: PreviewData.sampleEvents)
}
