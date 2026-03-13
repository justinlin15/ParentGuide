//
//  KidsEatFreeCardView.swift
//  ParentGuide
//

import SwiftUI

struct KidsEatFreeCardView: View {
    let restaurant: KidsEatFreeRestaurant

    /// Color based on first letter of restaurant name
    private var avatarColor: Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .teal, .cyan]
        let index = abs(restaurant.name.hashValue) % colors.count
        return colors[index]
    }

    private var restaurantLetterAvatar: some View {
        VStack(spacing: 2) {
            Text(String(restaurant.name.prefix(1)))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(avatarColor)
            Image(systemName: "fork.knife")
                .font(.caption2)
                .foregroundStyle(avatarColor.opacity(0.5))
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Restaurant image/avatar
            ZStack {
                LinearGradient(
                    colors: [avatarColor.opacity(0.2), avatarColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let urlString = restaurant.imageURL, let url = URL(string: urlString) {
                    CachedAsyncImagePhase(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            restaurantLetterAvatar
                        }
                    }
                } else {
                    restaurantLetterAvatar
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(.headline)
                    .lineLimit(1)

                // City tags
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                        .foregroundStyle(Color.brandPink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(restaurant.cities, id: \.self) { city in
                                Text(city)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Text(restaurant.dealDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("View details")
                    .font(.caption)
                    .foregroundStyle(Color.brandBlue)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 30)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview {
    KidsEatFreeCardView(restaurant: PreviewData.sampleRestaurants[0])
        .padding()
}
