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

    // Brand colors — soft feminine palette for moms
    static let brandBlue = Color(hex: "D4727E")         // Soft Coral Rose (primary accent)
    static let brandPink = Color(hex: "F8E8EC")         // Light Rose Mist (soft backgrounds)
    static let brandNavy = Color(hex: "3D3232")          // Warm Charcoal (dark contrast)
    static let brandLavender = Color(hex: "B8A9C9")     // Soft Lavender
    static let warmSurface = Color(hex: "FBF4F6")       // Warm Rose Surface (card bg)

    // Event category colors — soft pastels
    static let eventGreen = Color(hex: "7CB69A")         // Soft Sage
    static let eventBlue = Color(hex: "7BA7C2")          // Dusty Sky Blue
    static let eventPink = Color(hex: "D88B99")          // Rose Pink
    static let eventGray = Color(hex: "A8A3B3")          // Soft Mauve Gray
    static let eventOrange = Color(hex: "E0A96D")        // Warm Honey
    static let eventPurple = Color(hex: "9B8EC4")        // Soft Purple
}

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
