//
//  MoreMenuView.swift
//  ParentGuide

import SwiftUI

struct MoreMenuView: View {
    @State private var authService = AuthService.shared
    @State private var adminService = AdminService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var draftCount: Int = 0

    var body: some View {
        NavigationStack {
            List {
                // Admin section (only visible to admins)
                if adminService.isAdmin {
                    Section("Admin") {
                        NavigationLink(destination: AdminDashboardView()) {
                            Label("Admin Dashboard", systemImage: "square.grid.2x2")
                                .foregroundStyle(Color.brandBlue)
                        }
                        NavigationLink(destination: AdminReviewQueueView()) {
                            Label("Review Queue", systemImage: "tray.full")
                                .foregroundStyle(Color.brandBlue)
                        }
                        NavigationLink(destination: DraftEventsView()) {
                            HStack {
                                Label("Draft Events", systemImage: "exclamationmark.shield")
                                    .foregroundStyle(draftCount > 0 ? .orange : Color.brandBlue)
                                Spacer()
                                if draftCount > 0 {
                                    Text("\(draftCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .task {
                        if let events = try? await EventService.shared.fetchDraftEvents() {
                            draftCount = events.count
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

                if AppConstants.betaTestingEnabled {
                    Section("🛠 Beta Testing (Disable Before Release)") {
                        Toggle(isOn: Binding(
                            get: { adminService.debugAdminOverride ?? adminService.isAdmin },
                            set: { newValue in
                                adminService.debugAdminOverride = newValue
                            }
                        )) {
                            Label("Admin Role", systemImage: "shield.lefthalf.filled")
                        }
                        .tint(.orange)

                        Toggle(isOn: Binding(
                            get: { subscriptionService.debugSubscriptionOverride ?? subscriptionService.isSubscribed },
                            set: { newValue in
                                subscriptionService.debugSubscriptionOverride = newValue
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Premium User", systemImage: "crown.fill")
                                Text("Calendar sync • >3 days • No ads")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.orange)
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoreMenuView()
}
