//
//  EmptyStateView.swift
//  ParentGuide
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(Color.brandBlue.opacity(0.35))

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(icon: "calendar", title: "No Events", message: "There are no events scheduled for this date.")
}
