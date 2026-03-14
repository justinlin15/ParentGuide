//
//  MetroSwitcherView.swift
//  ParentGuide
//

import SwiftUI
import CoreLocation

/// A tappable location pill that shows the current metro and lets users quickly switch.
/// Similar to Yelp/DoorDash location picker in the header.
struct MetroSwitcherView: View {
    @State private var metroService = MetroService.shared
    @State private var showPicker = false
    @State private var isDetecting = false
    @State private var showLocationDenied = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(metroService.selectedMetro.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.brandBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.brandBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showPicker) {
            metroPickerSheet
                .presentationDetents([.medium])
                .alert("Location Access Denied", isPresented: $showLocationDenied) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Location access was previously denied. Please enable it in Settings to auto-detect your metro area.")
                }
        }
    }

    // MARK: - Picker Sheet

    private var metroPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // Check if location permission was denied
                        let status = CLLocationManager().authorizationStatus
                        if status == .denied || status == .restricted {
                            showLocationDenied = true
                            return
                        }

                        isDetecting = true
                        Task {
                            let detected = await metroService.autoDetect()
                            metroService.selectMetro(detected)
                            isDetecting = false
                            showPicker = false
                        }
                    } label: {
                        Label(
                            isDetecting ? "Detecting..." : "Use My Location",
                            systemImage: "location.fill"
                        )
                        .foregroundStyle(Color.brandBlue)
                    }
                    .disabled(isDetecting)
                }

                Section("Metro Areas") {
                    ForEach(AppConstants.metroAreas, id: \.id) { metro in
                        Button {
                            metroService.selectMetro(metro)
                            showPicker = false
                        } label: {
                            HStack {
                                Text(metro.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if metroService.selectedMetro.id == metro.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandBlue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPicker = false }
                }
            }
        }
    }
}

#Preview {
    MetroSwitcherView()
}
