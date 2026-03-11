//
//  ColorDotView.swift
//  ParentGuide
//

import SwiftUI

struct ColorDotView: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        ColorDotView(color: .eventGreen)
        ColorDotView(color: .eventBlue)
        ColorDotView(color: .eventPink)
    }
}
