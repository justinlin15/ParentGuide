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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Guides")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    GuidesContainerView()
}
