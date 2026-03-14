//
//  AccountSettingsView.swift
//  ParentGuide
//

import SwiftUI

struct AccountSettingsView: View {
    @State private var metroService = MetroService.shared

    var body: some View {
        List {
            Section("Location") {
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    HStack {
                        Text("Metro Area")
                        Spacer()
                        Text(metroService.selectedMetro.name)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section("Preferences") {
                Toggle("Push Notifications", isOn: .constant(true))
            }

            Section("Support") {
                Link("Privacy Policy", destination: URL(string: "https://www.orangecountyparentguide.com/privacy-policy")!)
                Link("Contact Us", destination: URL(string: "mailto:support@parentguide.com")!)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
}
