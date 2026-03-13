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
                CachedAsyncImagePhase(url: URL(string: provider.imageURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                Text(provider.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                                    .padding(16)
                            }
                    default:
                        ZStack {
                            Rectangle().fill(avatarColor.opacity(0.15))
                            VStack(spacing: 8) {
                                Text(String(provider.name.prefix(1)))
                                    .font(.system(size: 60))
                                    .fontWeight(.bold)
                                    .foregroundStyle(avatarColor)
                                Text(provider.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(height: 200)
                    }
                }

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

                    // Cities
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Locations", systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandPink)

                        Text("Tap a location to open in Apple Maps")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

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
                                    .background(Color.brandPink.opacity(0.1))
                                    .foregroundStyle(Color.brandPink)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandBlue)

                        Text(provider.providerDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Details grid
                    if provider.ageRequirement != nil || provider.pricing != nil {
                        Divider()

                        HStack(spacing: 16) {
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
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

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
