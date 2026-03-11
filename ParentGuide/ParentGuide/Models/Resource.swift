//
//  Resource.swift
//  ParentGuide
//

import Foundation
import CloudKit

struct Resource: Identifiable {
    let id: String
    let title: String
    let fileURL: String?
    let thumbnailURL: String?
    let sortOrder: Int
    let createdAt: Date
}

extension Resource {
    init?(record: CKRecord) {
        guard let title = record["title"] as? String else { return nil }

        self.id = record.recordID.recordName
        self.title = title
        self.fileURL = nil
        self.thumbnailURL = nil
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        self.createdAt = record.creationDate ?? Date()
    }
}
