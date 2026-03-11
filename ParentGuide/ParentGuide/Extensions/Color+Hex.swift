//
//  Color+Hex.swift
//  ParentGuide
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Brand colors
    static let brandBlue = Color(hex: "4FC3F7")
    static let brandPink = Color(hex: "F8BBD0")
    static let brandNavy = Color(hex: "1A237E")
    static let eventGreen = Color(hex: "4CAF50")
    static let eventBlue = Color(hex: "42A5F5")
    static let eventPink = Color(hex: "E91E8A")
    static let eventGray = Color(hex: "9E9E9E")
    static let eventOrange = Color(hex: "FF9800")
}
