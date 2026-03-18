//
//  EventMapView.swift
//  ParentGuide
//

import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: View {
    let events: [Event]
    @Binding var selectedDate: Date
    @State private var selectedEvent: Event?
    @State private var selectedCluster: [Event]?
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

    /// Cluster key: round to 4 decimal places (~11m precision) so nearby pins share a cluster.
    private func clusterKey(for coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 10000).rounded() / 10000
        let lon = (coord.longitude * 10000).rounded() / 10000
        return "\(lat),\(lon)"
    }

    /// Groups of events at the same rounded coordinate. Single events stand alone; 2+ become a cluster.
    private var clusteredGroups: [(key: String, events: [Event], coordinate: CLLocationCoordinate2D)] {
        var groups: [String: (events: [Event], coordinate: CLLocationCoordinate2D)] = [:]
        for item in mappableEvents {
            let key = clusterKey(for: item.coordinate)
            if groups[key] == nil {
                groups[key] = (events: [], coordinate: item.coordinate)
            }
            groups[key]!.events.append(item.event)
        }
        return groups.map { (key: $0.key, events: $0.value.events, coordinate: $0.value.coordinate) }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        ZStack {
            Map(position: $mapPosition, selection: $selectedEvent) {
                ForEach(clusteredGroups, id: \.key) { group in
                    if group.events.count == 1, let event = group.events.first {
                        // Single event — normal marker; selection binding handles the tap
                        Marker(
                            event.title,
                            systemImage: event.category.iconName,
                            coordinate: group.coordinate
                        )
                        .tint(event.category.color)
                        .tag(event)
                    } else {
                        // Cluster — show count badge
                        Annotation("", coordinate: group.coordinate) {
                            Button {
                                selectedCluster = group.events
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.brandBlue)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                                    Text("\(group.events.count)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            }

            if !showLocationPrompt && !showZipEntry {
                VStack {
                    HStack(spacing: 8) {
                        // Previous day
                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.brandBlue)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }

                        // Date + event count
                        VStack(spacing: 2) {
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
                            Text("\(eventsForSelectedDate.count) event\(eventsForSelectedDate.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            // Tap date label to jump back to today
                            if !isToday {
                                withAnimation {
                                    selectedDate = Calendar.current.startOfDay(for: Date())
                                }
                            }
                        }

                        // Next day
                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.brandBlue)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }

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
        .sheet(isPresented: Binding(get: { selectedCluster != nil }, set: { if !$0 { selectedCluster = nil } })) {
            if let cluster = selectedCluster {
                NavigationStack {
                    List(cluster) { event in
                        Button {
                            selectedCluster = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedEvent = event
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: event.category.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(event.category.color)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(event.formattedDate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("\(cluster.count) Events Here")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedCluster = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
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
    EventMapView(events: PreviewData.sampleEvents, selectedDate: .constant(Date()))
}
