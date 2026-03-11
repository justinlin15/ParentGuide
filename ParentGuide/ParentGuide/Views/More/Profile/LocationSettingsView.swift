//
//  LocationSettingsView.swift
//  ParentGuide
//

import SwiftUI

struct LocationSettingsView: View {
    @State private var metroService = MetroService.shared
    @State private var isDetecting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button {
                    isDetecting = true
                    Task {
                        let detected = await metroService.autoDetect()
                        metroService.selectMetro(detected)
                        isDetecting = false
                    }
                } label: {
                    Label(
                        isDetecting ? "Detecting..." : "Use My Location",
                        systemImage: "location.fill"
                    )
                }
                .disabled(isDetecting)
            }

            Section("Metro Areas") {
                ForEach(AppConstants.metroAreas, id: \.id) { metro in
                    Button {
                        metroService.selectMetro(metro)
                    } label: {
                        HStack {
                            Text(metro.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if metroService.selectedMetro.id == metro.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandBlue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Location")
    }
}

#Preview {
    NavigationStack {
        LocationSettingsView()
    }
}
