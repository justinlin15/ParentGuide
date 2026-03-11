//
//  View+Modifiers.swift
//  ParentGuide
//

import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    func sectionHeader() -> some View {
        self
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
