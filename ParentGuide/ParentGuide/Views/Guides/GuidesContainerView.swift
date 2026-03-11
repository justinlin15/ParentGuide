//
//  GuidesContainerView.swift
//  ParentGuide
//

import SwiftUI

enum GuideTab: String, CaseIterable {
    case kidsEatFree = "Kids Eat Free"
    case parentsNightOut = "Parents Night Out"
}

struct GuidesContainerView: View {
    @State private var selectedGuide: GuideTab = .kidsEatFree
    @State private var subscriptionService = SubscriptionService.shared
    @State private var adminService = AdminService.shared

    /// Whether the user has access (subscribed or admin).
    private var hasAccess: Bool {
        subscriptionService.isSubscribed || adminService.isAdmin
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasAccess {
                    guidesContent
                } else {
                    PaywallView(lockedContentName: "Guides")
                }
            }
            .navigationTitle("Guides")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var guidesContent: some View {
        VStack(spacing: 0) {
            Picker("Guide", selection: $selectedGuide) {
                ForEach(GuideTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            switch selectedGuide {
            case .kidsEatFree:
                KidsEatFreeListView()
            case .parentsNightOut:
                ParentsNightOutListView()
            }
        }
    }
}

#Preview {
    GuidesContainerView()
}
