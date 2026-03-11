//
//  HomeView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct HomeView: View {
    @State private var showNotifications = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HeroSectionView()

                    VStack(spacing: 24) {
                        FeatureHighlightView(
                            icon: "calendar.badge.plus",
                            title: "1,500+ events",
                            description: "An up-to-date, curated list of over 1,500 affordable, family-friendly events each month."
                        )

                        FeatureHighlightView(
                            icon: "person.3.fill",
                            title: "Subscriber meetups",
                            description: "Free and discounted subscriber meetups — Mom's Night Out, Escape Rooms, and more!"
                        )

                        FeatureHighlightView(
                            icon: "tag.fill",
                            title: "Partner perks",
                            description: "Exclusive discounts to family photographers, art classes, music classes, and play places."
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)

                    HomeMapView()
                        .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.2.and.child.holdinghands")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandBlue)
                            Text("Parent Guide")
                                .font(.headline)
                                .foregroundStyle(Color.brandBlue)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(Color.brandBlue)
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showProfile = false }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
