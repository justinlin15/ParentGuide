//
//  UserProfile.swift
//  ParentGuide
//

import Foundation

struct UserProfile: Identifiable {
    let id: String
    var displayName: String
    var email: String
    var avatarURL: String?
    var favoriteEventIDs: [String]
    var favoriteCities: [String]
    var subscriptionTier: String?
    var subscriptionExpiresAt: Date?
    let createdAt: Date
    var modifiedAt: Date
}
