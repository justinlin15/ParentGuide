//
//  HomeLocationSetupView.swift
//  ParentGuide
//

import MapKit
import SwiftUI

struct HomeLocationSetupView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedDisplayName: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @State private var isSaving = false
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var completer = LocationCompleterHelper()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Label("Set Home Location", systemImage: "house.fill")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Enter your city, neighborhood, or exact street address. This is used for the \"Distance from Home\" filter. Your location is stored privately and never shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Address, city, or neighborhood", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) {
                        completer.search(searchText)
                        // Clear selection when user types something new
                        if selectedDisplayName != nil && searchText != selectedDisplayName {
                            selectedDisplayName = nil
                            selectedLatitude = nil
                            selectedLongitude = nil
                        }
                    }
                    .onSubmit {
                        // Allow manual address entry by pressing return
                        if selectedDisplayName == nil && !searchText.isEmpty {
                            geocodeManualEntry(searchText)
                        }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedDisplayName = nil
                        selectedLatitude = nil
                        selectedLongitude = nil
                        completer.search("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if isResolving {
                HStack {
                    Spacer()
                    ProgressView("Looking up location…")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            // Results
            List {
                if let current = authService.currentUser, current.hasHomeLocation {
                    Section("Current") {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundStyle(Color.brandBlue)
                            Text(current.homeCity ?? "Home")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.brandBlue)
                                .font(.caption)
                        }
                    }
                }

                if !completer.results.isEmpty {
                    Section("Suggestions") {
                        ForEach(completer.results, id: \.self) { completion in
                            Button {
                                selectCompletion(completion)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if isResolving {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }

                // Manual entry option
                if !searchText.isEmpty && selectedDisplayName == nil && !completer.results.isEmpty {
                    Section {
                        Button {
                            geocodeManualEntry(searchText)
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(Color.brandBlue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use exact address")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("\"\(searchText)\"")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Selected location + Save
            if let displayName = selectedDisplayName {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color.brandBlue)
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    Button {
                        saveHomeLocation()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            }
                            Text(isSaving ? "Saving..." : "Save Home Location")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Home Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        errorMessage = nil

        Task { @MainActor in
            defer { isResolving = false }

            do {
                let request = MKLocalSearch.Request(completion: completion)
                request.resultTypes = [.address, .pointOfInterest]
                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                guard let item = response.mapItems.first else {
                    errorMessage = "Could not find that location. Try a different search."
                    return
                }

                let placemark = item.placemark

                // Build a meaningful display name — prefer full address for exact locations
                let displayName: String
                if let name = item.name, let locality = placemark.locality,
                   let state = placemark.administrativeArea {
                    if name == locality {
                        // City-level result: "Tustin, CA"
                        displayName = "\(locality), \(state)"
                    } else {
                        // Specific place: "123 Main St, Tustin, CA"
                        displayName = "\(name), \(locality), \(state)"
                    }
                } else if let locality = placemark.locality,
                          let state = placemark.administrativeArea {
                    displayName = "\(locality), \(state)"
                } else {
                    displayName = completion.title
                }

                selectedDisplayName = displayName
                selectedLatitude = placemark.coordinate.latitude
                selectedLongitude = placemark.coordinate.longitude
                searchText = displayName
            } catch {
                NSLog("[HomeLocation] Search failed: %@", error.localizedDescription)
                errorMessage = "Location lookup failed. Please try again."
            }
        }
    }

    /// Geocode a manually typed address string
    private func geocodeManualEntry(_ address: String) {
        isResolving = true
        errorMessage = nil

        Task { @MainActor in
            defer { isResolving = false }

            do {
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.geocodeAddressString(address)

                guard let placemark = placemarks.first, let location = placemark.location else {
                    errorMessage = "Could not find that address. Try adding more detail."
                    return
                }

                // Build display name from geocoded result
                let displayName: String
                if let name = placemark.name, let locality = placemark.locality,
                   let state = placemark.administrativeArea {
                    displayName = name == locality ? "\(locality), \(state)" : "\(name), \(locality), \(state)"
                } else if let locality = placemark.locality,
                          let state = placemark.administrativeArea {
                    displayName = "\(locality), \(state)"
                } else {
                    displayName = address
                }

                selectedDisplayName = displayName
                selectedLatitude = location.coordinate.latitude
                selectedLongitude = location.coordinate.longitude
                searchText = displayName
            } catch {
                NSLog("[HomeLocation] Geocode failed: %@", error.localizedDescription)
                errorMessage = "Could not look up that address. Check your connection and try again."
            }
        }
    }

    private func saveHomeLocation() {
        guard let displayName = selectedDisplayName, let lat = selectedLatitude, let lon = selectedLongitude else { return }
        isSaving = true

        Task { @MainActor in
            if var user = authService.currentUser {
                user.homeCity = displayName
                user.homeLatitude = lat
                user.homeLongitude = lon
                await authService.updateProfile(user)
            }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Location Completer Helper

@Observable
class LocationCompleterHelper: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(_ query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = Array(completer.results.prefix(8))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently fail
    }
}

#Preview {
    NavigationStack {
        HomeLocationSetupView()
    }
}
