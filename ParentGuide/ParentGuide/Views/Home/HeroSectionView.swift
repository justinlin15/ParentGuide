//
//  HeroSectionView.swift
//  ParentGuide
//

import SwiftUI

struct HeroSectionView: View {
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Access to over 1,500 monthly events, exclusive subscriber meet-ups, local partner discounts and free giveaways!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                NavigationLink(destination: PlansView()) {
                    Text("Start free trial")
                        .font(.headline)
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
