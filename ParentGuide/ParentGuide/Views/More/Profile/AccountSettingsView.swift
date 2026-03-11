//
//  AccountSettingsView.swift
//  ParentGuide
//

import SwiftUI

struct AccountSettingsView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var metroService = MetroService.shared

    private var planName: String {
        if subscriptionService.isSubscribed {
            if subscriptionService.activeProductID == SubscriptionService.annualID {
                return "Annual"
            } else {
                return "Monthly"
            }
        }
        return "Free"
    }

    var body: some View {
        List {
            Section("Subscription") {
                HStack {
                    Text("Current Plan")
                    Spacer()
                    Text(planName)
                        .foregroundStyle(.secondary)
                }

                if let expiry = subscriptionService.expirationDate {
                    HStack {
                        Text("Renews")
                        Spacer()
                        Text(expiry.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink("Manage Subscription") {
                    PlansView()
                }

                Button("Restore Purchases") {
                    Task { await subscriptionService.restorePurchases() }
                }
            }

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
