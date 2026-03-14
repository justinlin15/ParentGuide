//
//  EventCardView.swift
//  ParentGuide
//

import SwiftUI

struct EventCardView: View {
    let event: Event
    @State private var favoritesService = FavoritesService.shared

    private var isFavorite: Bool {
        favoritesService.isFavorite(event.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.color)
                .frame(width: 4)

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Price tier label
                    if let tierDisplay = event.priceTierDisplay {
                        Text(tierDisplay)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(event.isFree ? .green : .orange)
                    }

                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(event.formattedTime)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(event.city)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Favorite heart button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    favoritesService.toggleFavorite(for: event)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isFavorite ? Color.brandBlue : .secondary)
            }
            .buttonStyle(.plain)

            // Category icon
            Image(systemName: event.category.iconName)
                .font(.caption)
                .foregroundStyle(event.category.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    EventCardView(event: PreviewData.sampleEvents[0])
}
