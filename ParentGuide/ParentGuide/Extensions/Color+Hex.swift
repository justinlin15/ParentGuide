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

    // Brand colors — warm palette
    static let brandBlue = Color(hex: "C48B7F")        // Dusty Rose (primary accent)
    static let brandPink = Color(hex: "E8D5D0")        // Blush Cream (soft backgrounds)
    static let brandNavy = Color(hex: "3D3232")         // Warm Charcoal (dark contrast)
    static let brandLavender = Color(hex: "C0B5CB")     // Soft Lavender
    static let warmSurface = Color(hex: "F5EFEB")       // Warm Surface (card bg)

    // Event category colors — muted pastels
    static let eventGreen = Color(hex: "8FAE8B")        // Sage Green
    static let eventBlue = Color(hex: "7FA8BA")          // Dusty Blue
    static let eventPink = Color(hex: "D4918F")          // Muted Rose
    static let eventGray = Color(hex: "B5ADA7")          // Warm Taupe
    static let eventOrange = Color(hex: "D4A574")        // Warm Caramel
}

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
