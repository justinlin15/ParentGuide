//
//  ParentsNightOutDetailView.swift
//  ParentGuide
//

import SwiftUI

struct ParentsNightOutDetailView: View {
    let provider: ParentsNightOutProvider
    @Environment(\.openURL) private var openURL

    private var avatarColor: Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .teal, .cyan]
        let index = abs(provider.name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                heroImage

                VStack(alignment: .leading, spacing: 20) {
                    // Promo
                    if let promoCode = provider.promoCode, let promoDetails = provider.promoDetails {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(Color.eventOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(promoDetails)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Use code: \(promoCode)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.eventOrange)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.eventOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Quick Actions
                    HStack(spacing: 12) {
                        Button {
                            openInMaps(query: "\(provider.name) \(provider.cities.first ?? "") CA")
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.brandBlue)
                                Text("Directions")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let urlString = provider.externalURL, let url = URL(string: urlString) {
                            Link(destination: url) {
                                VStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .font(.title3)
                                        .foregroundStyle(Color.eventOrange)
                                    Text("Website")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Divider()

                    // Schedule
                    if let schedule = provider.schedule {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.brandBlue)

                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandBlue)
                                    .padding(.top, 3)

                                Text(schedule)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Divider()
                    }

                    // Locations
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Locations", systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandPink)

                        Text("Tap a location to open in Apple Maps")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 6) {
                            ForEach(provider.cities, id: \.self) { city in
                                Button {
                                    openInMaps(query: "\(provider.name) \(city), CA")
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin")
                                            .font(.system(size: 9))
                                        Text(city)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .foregroundStyle(Color.brandPink)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Divider()

                    // About
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandBlue)

                        Text(provider.providerDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    // Details grid
                    if provider.ageRequirement != nil || provider.pricing != nil {
                        Divider()

                        HStack(spacing: 12) {
                            if let age = provider.ageRequirement {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.brandBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ages")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(age)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let pricing = provider.pricing {
                                HStack(spacing: 10) {
                                    Image(systemName: "dollarsign.circle")
                                        .font(.title3)
                                        .foregroundStyle(Color.eventGreen)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pricing")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(pricing)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // External link
                    if let urlString = provider.externalURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Visit Website", systemImage: "safari")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.brandBlue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Image

    @ViewBuilder
    private var heroImage: some View {
        CachedAsyncImagePhase(url: URL(string: provider.imageURL ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(provider.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
            default:
                ZStack {
                    LinearGradient(
                        colors: [avatarColor.opacity(0.3), avatarColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 10) {
                        Image(systemName: "figure.and.child.holdinghands")
                            .font(.system(size: 44))
                            .foregroundStyle(avatarColor.opacity(0.6))
                        Text(provider.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Helpers

    private func openInMaps(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            openURL(url)
        }
    }
}

#Preview {
    NavigationStack {
        ParentsNightOutDetailView(provider: PreviewData.sampleProviders[1])
    }
}
