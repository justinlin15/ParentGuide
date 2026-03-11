//
//  View+Modifiers.swift
//  ParentGuide
//

import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.brandBlue.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    func sectionHeader() -> some View {
        self
            .font(.system(.title2, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
