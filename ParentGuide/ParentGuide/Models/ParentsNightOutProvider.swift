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
    let schedule: String?
    let promoCode: String?
    let promoDetails: String?
    let imageURL: String?
    let externalURL: String?
    let isActive: Bool
    let sortOrder: Int
    let metro: String?
    let source: String?
    let createdAt: Date
    let modifiedAt: Date
}

extension ParentsNightOutProvider {
    /// Return a copy with a different imageURL (used to merge bundled images into CloudKit records).
    func withImageURL(_ url: String) -> ParentsNightOutProvider {
        ParentsNightOutProvider(
            id: id, name: name, cities: cities, providerDescription: providerDescription,
            ageRequirement: ageRequirement, pricing: pricing, schedule: schedule,
            promoCode: promoCode, promoDetails: promoDetails,
            imageURL: url, externalURL: externalURL, isActive: isActive,
            sortOrder: sortOrder, metro: metro, source: source,
            createdAt: createdAt, modifiedAt: modifiedAt
        )
    }
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
        self.schedule = record["schedule"] as? String
        self.promoCode = record["promoCode"] as? String
        self.promoDetails = record["promoDetails"] as? String
        self.imageURL = record["imageURL"] as? String
        self.externalURL = record["externalURL"] as? String
        self.isActive = record["isActive"] as? Bool ?? true
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        self.metro = record["metro"] as? String
        self.source = record["source"] as? String
        self.createdAt = record.creationDate ?? Date()
        self.modifiedAt = record.modificationDate ?? Date()
    }
}
