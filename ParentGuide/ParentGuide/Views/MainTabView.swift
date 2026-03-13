//
//  MainTabView.swift
//  ParentGuide
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            EventCalendarContainerView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
                .tag(1)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(2)

            GuidesContainerView()
                .tabItem {
                    Label("Guides", systemImage: "book.fill")
                }
                .tag(3)

            MoreMenuView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(4)
        }
        .tint(Color.brandBlue)
    }
}

#Preview {
    MainTabView()
}
