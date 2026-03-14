//
//  HeroSectionView.swift
//  ParentGuide
//

import SwiftUI

struct HeroSectionView: View {
    @State private var authService = AuthService.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandPink.opacity(0.3), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 16) {
                Spacer().frame(height: 8)

                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandBlue)

                Text("Your family fun calendar!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Discover 1,500+ family-friendly events each month. Create a free account to save favorites, RSVP, and get personalized recommendations!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                NavigationLink(destination: LoginView()) {
                    Text("Create Free Account")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.brandBlue)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 24)
        }
        .frame(minHeight: 280)
    }
}

#Preview {
    NavigationStack {
        HeroSectionView()
    }
}
