//
//  RestaurantHeroView.swift
//  ParentGuide
//
//  Reusable hero image for restaurant/provider detail views.
//  Chains multiple image sources: imageURL → logoURL → letter avatar.

import SwiftUI

struct RestaurantHeroView: View {
    let imageURL: String?
    let logoURL: String?
    let name: String
    let avatarColor: Color

    var body: some View {
        if let urlString = imageURL, let url = URL(string: urlString) {
            // Try primary image first
            CachedAsyncImagePhase(url: url) { phase in
                switch phase {
                case .success(let image):
                    heroImage(image)
                case .failure:
                    // Primary failed — try logo
                    logoOrAvatar
                default:
                    ProgressView()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .background(avatarColor.opacity(0.1))
                }
            }
        } else {
            logoOrAvatar
        }
    }

    @ViewBuilder
    private var logoOrAvatar: some View {
        if let logoStr = logoURL, let logoUrl = URL(string: logoStr) {
            CachedAsyncImagePhase(url: logoUrl) { phase in
                switch phase {
                case .success(let image):
                    // Logo loaded — show centered on colored background
                    ZStack {
                        Rectangle().fill(avatarColor.opacity(0.12))
                        VStack(spacing: 10) {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            Text(name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(height: 220)
                default:
                    letterAvatar
                }
            }
        } else {
            letterAvatar
        }
    }

    private var letterAvatar: some View {
        ZStack {
            Rectangle().fill(avatarColor.opacity(0.15))
            VStack(spacing: 8) {
                Text(String(name.prefix(1)))
                    .font(.system(size: 60))
                    .fontWeight(.bold)
                    .foregroundStyle(avatarColor)
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .frame(height: 220)
    }

    private func heroImage(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 220)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Text(name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(16)
            }
    }
}
