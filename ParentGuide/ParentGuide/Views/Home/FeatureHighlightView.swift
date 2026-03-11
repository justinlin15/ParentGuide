//
//  FeatureHighlightView.swift
//  ParentGuide
//

import SwiftUI

struct FeatureHighlightView: View {
    let icon: String
    let title: String
    let description: String
    var imageOnLeft: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.brandBlue)
                .frame(width: 72, height: 72)
                .background(Color.brandBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(title)
                .font(.title3)
                .fontWeight(.bold)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    FeatureHighlightView(
        icon: "calendar.badge.plus",
        title: "1,500+ events",
        description: "Browse available events easily using filter and search features."
    )
    .padding()
}
