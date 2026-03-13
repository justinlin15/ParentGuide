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

        if let asset = record["file"] as? CKAsset, let url = asset.fileURL {
            self.fileURL = url.absoluteString
        } else {
            self.fileURL = nil
        }

        if let asset = record["thumbnail"] as? CKAsset, let url = asset.fileURL {
            self.thumbnailURL = url.absoluteString
        } else {
            self.thumbnailURL = nil
        }
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        self.createdAt = record.creationDate ?? Date()
    }
}
