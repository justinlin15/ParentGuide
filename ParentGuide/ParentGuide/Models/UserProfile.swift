//
//  UserProfile.swift
//  ParentGuide
//

import CloudKit
import CoreLocation
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
    // Home location — for "distance from home" filter
    var homeCity: String?
    var homeLatitude: Double?
    var homeLongitude: Double?
    let createdAt: Date
    var modifiedAt: Date

    var hasHomeLocation: Bool {
        homeLatitude != nil && homeLongitude != nil
    }

    var homeLocation: CLLocation? {
        guard let lat = homeLatitude, let lon = homeLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // MARK: - CloudKit Init

    init?(record: CKRecord) {
        self.id = record.recordID.recordName
        self.displayName = (record["displayName"] as? String) ?? "Parent"
        self.email = (record["email"] as? String) ?? ""
        self.avatarURL = record["avatarURL"] as? String
        self.favoriteEventIDs = (record["favoriteEventIDs"] as? [String]) ?? []
        self.favoriteCities = (record["favoriteCities"] as? [String]) ?? []
        self.subscriptionTier = record["subscriptionTier"] as? String
        self.subscriptionExpiresAt = record["subscriptionExpiresAt"] as? Date
        self.homeCity = record["homeCity"] as? String
        self.homeLatitude = record["homeLatitude"] as? Double
        self.homeLongitude = record["homeLongitude"] as? Double
        self.createdAt = (record["createdAt"] as? Date) ?? record.creationDate ?? Date()
        self.modifiedAt = (record["modifiedAt"] as? Date) ?? record.modificationDate ?? Date()
    }

    // MARK: - Local Init

    init(
        id: String,
        displayName: String,
        email: String,
        avatarURL: String? = nil,
        favoriteEventIDs: [String] = [],
        favoriteCities: [String] = [],
        subscriptionTier: String? = nil,
        subscriptionExpiresAt: Date? = nil,
        homeCity: String? = nil,
        homeLatitude: Double? = nil,
        homeLongitude: Double? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.favoriteEventIDs = favoriteEventIDs
        self.favoriteCities = favoriteCities
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.homeCity = homeCity
        self.homeLatitude = homeLatitude
        self.homeLongitude = homeLongitude
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - To CloudKit

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        applyFields(to: record)
        return record
    }

    func applyFields(to record: CKRecord) {
        record["displayName"] = displayName as CKRecordValue
        record["email"] = email as CKRecordValue
        if let avatarURL { record["avatarURL"] = avatarURL as CKRecordValue }
        if !favoriteEventIDs.isEmpty { record["favoriteEventIDs"] = favoriteEventIDs as CKRecordValue }
        if !favoriteCities.isEmpty { record["favoriteCities"] = favoriteCities as CKRecordValue }
        if let subscriptionTier { record["subscriptionTier"] = subscriptionTier as CKRecordValue }
        if let subscriptionExpiresAt { record["subscriptionExpiresAt"] = subscriptionExpiresAt as CKRecordValue }
        if let homeCity { record["homeCity"] = homeCity as CKRecordValue }
        if let homeLatitude { record["homeLatitude"] = homeLatitude as CKRecordValue }
        if let homeLongitude { record["homeLongitude"] = homeLongitude as CKRecordValue }
        record["createdAt"] = createdAt as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
    }
}
