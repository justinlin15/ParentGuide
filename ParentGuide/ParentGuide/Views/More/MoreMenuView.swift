//
//  MoreMenuView.swift
//  ParentGuide
//

import SwiftUI

struct MoreMenuView: View {
    @State private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink(destination: ResourcesView()) {
                        Label("Resources", systemImage: "doc.fill")
                    }
                    NavigationLink(destination: PlansView()) {
                        Label("Plans & Pricing", systemImage: "creditcard")
                    }
                }

                Section("Account") {
                    if authService.isSignedIn {
                        NavigationLink(destination: ProfileView()) {
                            Label("Profile", systemImage: "person.circle")
                        }
                        NavigationLink(destination: AccountSettingsView()) {
                            Label("Account Settings", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            authService.signOut()
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        NavigationLink(destination: LoginView()) {
                            Label("Log In", systemImage: "person.circle")
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Parent Guide")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Built by parents, for parents")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreMenuView()
}
