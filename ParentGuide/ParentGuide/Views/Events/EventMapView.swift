//
//  EventMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: View {
    let events: [Event]
    let selectedDate: Date
    @State private var selectedEvent: Event?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showLocationPrompt = false
    @State private var showZipEntry = false
    @State private var zipCode = ""
    @State private var locationManager = LocationHelper()
    @State private var cityCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var isGeocodingCities = false
    var metroService = MetroService.shared

    // MARK: - Date-Filtered Events

    /// Events for the currently selected date only.
    private var eventsForSelectedDate: [Event] {
        let calendar = Calendar.current
        return events.filter { event in
            let eventEnd = event.endDate ?? event.startDate
            let dayStart = calendar.startOfDay(for: selectedDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            return event.startDate < dayEnd && eventEnd >= dayStart
        }
    }

    // MARK: - Computed Events

    /// Events that can be placed on the map (have valid coords or a geocoded city).
    /// Pre-computed once per render to avoid redundant work.
    private var mappableEvents: [(event: Event, coordinate: CLLocationCoordinate2D)] {
        var result: [(Event, CLLocationCoordinate2D)] = []
        for event in eventsForSelectedDate {
            if event.hasValidCoordinates, let lat = event.latitude, let lon = event.longitude {
                result.append((event, CLLocationCoordinate2D(latitude: lat, longitude: lon)))
            } else if let cityCoord = cityCoordinates[event.city] {
                result.append((event, cityCoord))
            }
        }
        return result
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        ZStack {
            Map(position: $mapPosition, selection: $selectedEvent) {
                ForEach(mappableEvents, id: \.event.id) { item in
                    Annotation(item.event.title, coordinate: item.coordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: item.event.category.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(item.event.category.color)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2.5)
                                )
                                .shadow(color: item.event.category.color.opacity(0.4), radius: 4, y: 2)

                            Image(systemName: "triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(item.event.category.color)
                                .rotationEffect(.degrees(180))
                                .offset(y: -3)
                        }
                        .onTapGesture {
                            selectedEvent = item.event
                        }
                    }
                    .tag(item.event)
                }
            }

            if !showLocationPrompt && !showZipEntry {
                VStack {
                    HStack {
                        // Today indicator + event count
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if isToday {
                                    Text("TODAY")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.brandBlue)
                                        .clipShape(Capsule())
                                }
                                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            Text("\(mappableEvents.count) event\(mappableEvents.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                    Spacer()

                    // My Location button
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
        .onChange(of: metroService.selectedMetro.id) {
            let metro = metroService.selectedMetro
            withAnimation {
                setInitialRegion(center: CLLocationCoordinate2D(latitude: metro.latitude, longitude: metro.longitude))
            }
        }
        .task {
            await geocodeMissingCities()
        }
    }

    // MARK: - Geocoding

    /// Geocode unique city names for events that lack valid coordinates.
    private func geocodeMissingCities() async {
        let citiesNeedingGeocode = Set(
            eventsForSelectedDate
                .filter { !$0.hasValidCoordinates && !$0.city.isEmpty }
                .map { $0.city }
        )

        guard !citiesNeedingGeocode.isEmpty else { return }

        let geocoder = CLGeocoder()
        var results: [String: CLLocationCoordinate2D] = [:]

        for city in citiesNeedingGeocode {
            // Skip if already geocoded
            if cityCoordinates[city] != nil { continue }

            do {
                let placemarks = try await geocoder.geocodeAddressString(city)
                if let location = placemarks.first?.location {
                    results[city] = location.coordinate
                }
            } catch {
                NSLog("[EventMapView] Geocode failed for '%@': %@", city, error.localizedDescription)
            }

            // Small delay to avoid hitting geocoder rate limits
            try? await Task.sleep(for: .milliseconds(200))
        }

        await MainActor.run {
            cityCoordinates.merge(results) { _, new in new }
        }
    }

    private func setInitialRegion(center: CLLocationCoordinate2D) {
        mapPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
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
    EventMapView(events: PreviewData.sampleEvents, selectedDate: Date())
}
