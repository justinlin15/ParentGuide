//
//  RecommendedCarouselSection.swift
//  ParentGuide
//

import SwiftUI

/// A horizontal carousel of recommended events, matching the Popular Near You tile style.
struct RecommendedCarouselSection: View {
    let events: [Event]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(Color.brandBlue)
                Text("Recommended For You")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(events) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            PopularEventHeroCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

#Preview {
    NavigationStack {
        RecommendedCarouselSection(events: PreviewData.sampleEvents)
    }
}
