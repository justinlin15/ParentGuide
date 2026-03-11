//
//  AboutView.swift
//  ParentGuide
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 16) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.brandBlue)

                    Text("Parent Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("By parents, for parents.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Mission
                VStack(alignment: .leading, spacing: 12) {
                    Label("Our Mission", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(Color.brandPink)

                    Text("We believe every family deserves access to meaningful experiences without breaking the bank. Parent Guide helps you discover free and affordable activities, events, and deals happening right in your neighborhood.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                // What we offer
                VStack(alignment: .leading, spacing: 16) {
                    Label("What We Offer", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Color.brandBlue)

                    featureRow(icon: "calendar.badge.plus", color: .eventBlue, title: "1,500+ Monthly Events", description: "Curated family-friendly events across Orange County updated daily.")

                    featureRow(icon: "fork.knife", color: .eventOrange, title: "Kids Eat Free Deals", description: "Save money with our comprehensive guide to restaurants where kids eat free.")

                    featureRow(icon: "figure.2.and.child.holdinghands", color: .eventPink, title: "Parents Night Out", description: "Find trusted providers so you can enjoy a well-deserved date night.")

                    featureRow(icon: "map.fill", color: .eventGreen, title: "Local Discovery", description: "Explore activities near you with GPS-powered search and interactive maps.")
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Built by parents
                VStack(spacing: 12) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.eventOrange)

                    Text("Built by Parents Who Get It")
                        .font(.headline)

                    Text("We know how hard it can be to find things to do with the kids that are fun, affordable, and actually worth the drive. That\u{2019}s why we built Parent Guide \u{2014} to make it easy for families like ours to create lasting memories together.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                // Version
                VStack(spacing: 4) {
                    Text("Parent Guide v1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Made with love in Orange County")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("About")
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
