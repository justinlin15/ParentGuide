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
                    NavigationLink(destination: ProfileView()) {
                        Label("Profile & Settings", systemImage: "person.circle")
                    }
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink(destination: ResourcesView()) {
                        Label("Resources", systemImage: "doc.fill")
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
