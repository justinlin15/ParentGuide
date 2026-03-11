//
//  ParentsNightOutProvider.swift
//  ParentGuide
//

import Foundation
import CloudKit

struct ParentsNightOutProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let cities: [String]
    let providerDescription: String
    let ageRequirement: String?
    let pricing: String?
    let promoCode: String?
    let promoDetails: String?
    let imageURL: String?
    let externalURL: String?
    let isActive: Bool
    let sortOrder: Int
    let createdAt: Date
    let modifiedAt: Date
}

nonisolated extension ParentsNightOutProvider {
    init?(record: CKRecord) {
        guard let name = record["name"] as? String else { return nil }

        self.id = record.recordID.recordName
        self.name = name
        self.cities = record["cities"] as? [String] ?? []
        self.providerDescription = record["providerDescription"] as? String ?? ""
        self.ageRequirement = record["ageRequirement"] as? String
        self.pricing = record["pricing"] as? String
        self.promoCode = record["promoCode"] as? String
        self.promoDetails = record["promoDetails"] as? String
        self.imageURL = nil
        self.externalURL = record["externalURL"] as? String
        self.isActive = record["isActive"] as? Bool ?? true
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }
}
