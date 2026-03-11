//
//  ParentsNightOutCardView.swift
//  ParentGuide
//

import SwiftUI

struct ParentsNightOutCardView: View {
    let provider: ParentsNightOutProvider

    private var avatarColor: Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .teal, .cyan]
        let index = abs(provider.name.hashValue) % colors.count
        return colors[index]
    }

    private var providerLetterAvatar: some View {
        VStack(spacing: 2) {
            Text(String(provider.name.prefix(1)))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(avatarColor)
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.caption2)
                .foregroundStyle(avatarColor.opacity(0.5))
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                LinearGradient(
                    colors: [avatarColor.opacity(0.2), avatarColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let urlString = provider.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            providerLetterAvatar
                        }
                    }
                } else {
                    providerLetterAvatar
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(avatarColor.opacity(0.15), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(provider.name)
                        .font(.headline)
                        .lineLimit(1)

                    if provider.promoCode != nil {
                        Text("PROMO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.eventOrange.opacity(0.2))
                            .foregroundStyle(Color.eventOrange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                        .foregroundStyle(Color.brandPink)
                    Text(provider.cities.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(provider.providerDescription)
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
    ParentsNightOutCardView(provider: PreviewData.sampleProviders[0])
        .padding()
}
