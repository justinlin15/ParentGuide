//
//  PopularCarouselSection.swift
//  ParentGuide
//

import SwiftUI

/// A horizontal carousel of popular events with hero image cards and text overlay.
struct PopularCarouselSection: View {
    let events: [Event]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Popular Near You")
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

// MARK: - Hero Card

struct PopularEventHeroCard: View {
    let event: Event
    @State private var favoritesService = FavoritesService.shared

    private var isFavorite: Bool {
        favoritesService.isFavorite(event.id)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or gradient
            Group {
                if let imageURL = event.imageURL,
                   !imageURL.isEmpty,
                   let url = URL(string: imageURL) {
                    CachedAsyncImagePhase(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            categoryGradient
                        default:
                            categoryGradient
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        }
                    }
                } else {
                    categoryGradient
                }
            }
            .frame(width: 280, height: 200)
            .clipped()

            // Dark gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Text overlay
            VStack(alignment: .leading, spacing: 4) {
                // Category pill
                Text(event.category.displayName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(event.category.color.opacity(0.9))
                    .clipShape(Capsule())

                Text(event.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label(event.formattedDate, systemImage: "calendar")
                    if !event.city.isEmpty {
                        Label(event.city, systemImage: "mappin")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)

            // Favorite button (top right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            favoritesService.toggleFavorite(event.id)
                        }
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isFavorite ? .red : .white)
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(width: 280, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .opacity(phase.isIdentity ? 1 : 0.8)
        }
    }

    private var categoryGradient: some View {
        LinearGradient(
            colors: [event.category.color, event.category.color.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: event.category.iconName)
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
        }
    }
}

#Preview {
    NavigationStack {
        PopularCarouselSection(events: PreviewData.sampleEvents)
    }
}
