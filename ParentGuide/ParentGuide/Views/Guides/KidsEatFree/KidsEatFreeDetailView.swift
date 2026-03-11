//
//  KidsEatFreeDetailView.swift
//  ParentGuide
//

import SwiftUI

struct KidsEatFreeDetailView: View {
    let restaurant: KidsEatFreeRestaurant
    @Environment(\.openURL) private var openURL

    private var avatarColor: Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .teal, .cyan]
        let index = abs(restaurant.name.hashValue) % colors.count
        return colors[index]
    }

    private var dealItems: [(location: String, detail: String)] {
        restaurant.dealDetails
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                if let colonRange = line.range(of: ":") {
                    let location = String(line[line.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let detail = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    return (location, detail)
                } else {
                    return ("", line.trimmingCharacters(in: .whitespaces))
                }
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                AsyncImage(url: URL(string: restaurant.imageURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                Text(restaurant.name)
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
                                Text(String(restaurant.name.prefix(1)))
                                    .font(.system(size: 60))
                                    .fontWeight(.bold)
                                    .foregroundStyle(avatarColor)
                                Text(restaurant.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(height: 220)
                    }
                }

                VStack(alignment: .leading, spacing: 24) {
                    // Quick Actions
                    quickActionsRow

                    // Address
                    if let address = restaurant.address {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Address", systemImage: "building.2.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.brandNavy)

                            Button {
                                openInMaps(query: "\(restaurant.name) \(address)")
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "map.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.brandBlue)
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    Divider()

                    // Locations
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Locations", systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandPink)

                        Text("Tap a location to open in Apple Maps")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        FlowLayout(spacing: 6) {
                            ForEach(restaurant.cities, id: \.self) { city in
                                Button {
                                    openInMaps(query: "\(restaurant.name) \(city), CA")
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

                    // Deal Details
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Deal Details", systemImage: "tag.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandBlue)

                        VStack(spacing: 10) {
                            ForEach(Array(dealItems.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.brandBlue)
                                        .padding(.top, 3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        if !item.location.isEmpty {
                                            Text(item.location)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text(item.detail.isEmpty ? item.location : item.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(14)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Website link
                    if let urlString = restaurant.websiteURL, let url = URL(string: urlString) {
                        Divider()

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

    // MARK: - Subviews

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            // Directions
            Button {
                openInMaps(query: "\(restaurant.name) \(restaurant.cities.first ?? "") CA")
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

            // Call
            if let phone = restaurant.phoneNumber {
                Button {
                    if let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                        openURL(url)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Call")
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

            // Website
            if let urlString = restaurant.websiteURL, let url = URL(string: urlString) {
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
    }

    // MARK: - Actions

    private func openInMaps(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            openURL(url)
        }
    }
}

#Preview {
    NavigationStack {
        KidsEatFreeDetailView(restaurant: PreviewData.sampleRestaurants[0])
    }
}
