//
//  AccountSettingsView.swift
//  ParentGuide
//

import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        List {
            Section("Subscription") {
                HStack {
                    Text("Current Plan")
                    Spacer()
                    Text("Free")
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Manage Subscription") {
                    PlansView()
                }
            }

            Section("Preferences") {
                Toggle("Push Notifications", isOn: .constant(true))
                NavigationLink("Favorite Cities") {
                    Text("Coming soon")
                        .foregroundStyle(.secondary)
                }
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
