//
//  MoreMenuView.swift
//  ParentGuide
//

import SwiftUI

struct MoreMenuView: View {
    @State private var authService = AuthService.shared
    @State private var adminService = AdminService.shared

    var body: some View {
        NavigationStack {
            List {
                // Admin section (only visible to admins)
                if adminService.isAdmin {
                    Section("Admin") {
                        NavigationLink(destination: AdminDashboardView()) {
                            Label("Event Dashboard", systemImage: "square.grid.2x2")
                                .foregroundStyle(Color.brandBlue)
                        }
                        NavigationLink(destination: AdminReviewQueueView()) {
                            Label("Review Queue", systemImage: "tray.full")
                                .foregroundStyle(Color.brandBlue)
                        }
                    }
                }

                Section {
                    NavigationLink(destination: ProfileView()) {
                        Label("Profile & Settings", systemImage: "person.circle")
                    }
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink(destination: ResourcesView()) {
                        Label("Resources", systemImage: "doc.fill")
                    }
                    if authService.isSignedIn {
                        NavigationLink(destination: SuggestEventView()) {
                            Label("Suggest an Event", systemImage: "plus.bubble")
                        }
                    }
                }

                if !authService.isSignedIn {
                    Section {
                        NavigationLink(destination: LoginView()) {
                            Label("Sign In", systemImage: "person.badge.plus")
                                .foregroundStyle(Color.brandBlue)
                        }
                    }
                }

                #if DEBUG
                Section("🛠 Debug (Remove Before Release)") {
                    Toggle(isOn: Binding(
                        get: { adminService.debugAdminOverride ?? adminService.isAdmin },
                        set: { newValue in
                            adminService.debugAdminOverride = newValue
                        }
                    )) {
                        Label("Admin Role", systemImage: "shield.lefthalf.filled")
                    }
                    .tint(.orange)
                }
                #endif

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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoreMenuView()
}
