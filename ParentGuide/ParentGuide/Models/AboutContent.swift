//
//  AboutContent.swift
//  ParentGuide
//

import Foundation

struct AboutSection: Identifiable {
    let id: String
    let text: String
    let imageURL: String?
    let imagePosition: ImagePosition
    let sortOrder: Int

    enum ImagePosition: String {
        case leading, trailing
    }
}
