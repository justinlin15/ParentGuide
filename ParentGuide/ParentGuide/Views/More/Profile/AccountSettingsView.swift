//
//  AccountSettingsView.swift
//  ParentGuide
//

import SwiftUI

struct AccountSettingsView: View {
    @State private var metroService = MetroService.shared

    // MARK: - Persisted Preferences

    @AppStorage("defaultEventView") private var defaultEventView: String = "Week"
    @AppStorage("defaultSearchRadius") private var defaultSearchRadius: String = "Any"
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"
    @AppStorage("addToCalendarOnFavorite") private var addToCalendarOnFavorite = false
    @AppStorage("notify_pushEnabled") private var pushNotificationsEnabled = true

    var body: some View {
        List {
            // MARK: - Location
            Section("Location") {
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    HStack {
                        Label {
                            Text("Metro Area")
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(Color.brandBlue)
                        }
                        Spacer()
                        Text(metroService.selectedMetro.name)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // MARK: - Events
            Section {
                Picker(selection: $defaultEventView) {
                    Text("Week").tag("Week")
                    Text("Day").tag("Day")
                    Text("Month").tag("Month")
                    Text("Map").tag("Map")
                } label: {
                    Label {
                        Text("Default View")
                    } icon: {
                        Image(systemName: "rectangle.split.3x1")
                            .foregroundStyle(Color.brandBlue)
                    }
                }

                Picker(selection: $defaultSearchRadius) {
                    Text("5 mi").tag("5")
                    Text("10 mi").tag("10")
                    Text("25 mi").tag("25")
                    Text("50 mi").tag("50")
                    Text("Any").tag("Any")
                } label: {
                    Label {
                        Text("Default Radius")
                    } icon: {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
            } header: {
                Text("Events")
            } footer: {
                Text("These defaults are applied when you open the Events tab.")
            }

            // MARK: - Preferences
            Section("Preferences") {
                Toggle(isOn: $pushNotificationsEnabled) {
                    Label {
                        Text("Push Notifications")
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
                .tint(Color.brandBlue)

                Toggle(isOn: $addToCalendarOnFavorite) {
                    Label {
                        Text("Add to Calendar on Favorite")
                    } icon: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
                .tint(Color.brandBlue)

                Picker(selection: $appearanceMode) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                } label: {
                    Label {
                        Text("Appearance")
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
            }

            // MARK: - Support
            Section("Support") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label {
                        Text("Privacy Policy")
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.brandBlue)
                    }
                }

                Link(destination: URL(string: "mailto:support@parentguide.com")!) {
                    Label {
                        Text("Contact Us")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Color.brandBlue)
                    }
                }

                Link(destination: URL(string: "https://apps.apple.com/app/parent-guide/id0000000000")!) {
                    Label {
                        Text("Rate the App")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
            }

            // MARK: - About
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Parent Guide")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Version \(appVersion)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Built by parents, for parents")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
}
