//
//  CityTagView.swift
//  ParentGuide
//

import SwiftUI

struct CityTagView: View {
    let city: String
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Text(city)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.brandBlue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(12)
            .onTapGesture {
                onTap?()
            }
    }
}

#Preview {
    HStack {
        CityTagView(city: "Irvine")
        CityTagView(city: "Costa Mesa", isSelected: true)
    }
}
