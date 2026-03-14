//
//  KidsEatFreeRestaurant.swift
//  ParentGuide
//

import Foundation
import CloudKit

struct KidsEatFreeRestaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let cities: [String]
    let dealDetails: String
    let imageURL: String?
    let websiteURL: String?
    let phoneNumber: String?
    let address: String?
    let isActive: Bool
    let sortOrder: Int
    let metro: String?
    let source: String?
    let createdAt: Date
    let modifiedAt: Date
}

extension KidsEatFreeRestaurant {
    /// Return a copy with a different imageURL (used to merge bundled images into CloudKit records).
    func withImageURL(_ url: String) -> KidsEatFreeRestaurant {
        KidsEatFreeRestaurant(
            id: id, name: name, cities: cities, dealDetails: dealDetails,
            imageURL: url, websiteURL: websiteURL, phoneNumber: phoneNumber,
            address: address, isActive: isActive, sortOrder: sortOrder,
            metro: metro, source: source, createdAt: createdAt, modifiedAt: modifiedAt
        )
    }
}

nonisolated extension KidsEatFreeRestaurant {
    init?(record: CKRecord) {
        guard let name = record["name"] as? String else { return nil }

        self.id = record.recordID.recordName
        self.name = name
        self.cities = record["cities"] as? [String] ?? []
        self.dealDetails = record["dealDetails"] as? String ?? ""
        self.imageURL = record["imageURL"] as? String
        self.websiteURL = record["websiteURL"] as? String
        self.phoneNumber = record["phoneNumber"] as? String
        self.address = record["address"] as? String
        self.isActive = record["isActive"] as? Bool ?? true
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        self.metro = record["metro"] as? String
        self.source = record["source"] as? String
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }
}
