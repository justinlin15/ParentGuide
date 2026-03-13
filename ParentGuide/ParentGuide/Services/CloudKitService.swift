//
//  CloudKitService.swift
//  ParentGuide
//

import CloudKit

actor CloudKitService {
    static let shared = CloudKitService()

    private let publicDB = CloudKitConfig.publicDatabase
    private let privateDB = CloudKitConfig.privateDatabase

    // MARK: - Public Database Fetch

    /// Fetch records using CKQuery. Requires queryable indexes on the predicate fields.
    func fetchRecords(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor] = [],
        resultsLimit: Int = 100
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        // First batch
        let (results, nextCursor) = try await publicDB.records(matching: query, resultsLimit: resultsLimit)
        allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })
        cursor = nextCursor

        // Fetch remaining batches if needed
        while let currentCursor = cursor {
            let (moreResults, moreCursor) = try await publicDB.records(continuingMatchFrom: currentCursor, resultsLimit: resultsLimit)
            allRecords.append(contentsOf: moreResults.compactMap { try? $0.1.get() })
            cursor = moreCursor
        }

        return allRecords
    }

    /// Fetch ALL records of a given type using zone changes API (no queryable index needed).
    /// This bypasses CKQuery entirely, which avoids "recordName not queryable" errors
    /// when the CloudKit schema was auto-created via REST API without indexes.
    func fetchAllRecords(recordType: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []

        let changes = try await publicDB.recordZoneChanges(
            inZoneWith: .default,
            since: nil
        )

        for (_, result) in changes.modificationResultsByID {
            if case .success(let modification) = result {
                let record = modification.record
                if record.recordType == recordType {
                    allRecords.append(record)
                }
            }
        }

        return allRecords
    }

    func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord {
        try await publicDB.record(for: recordID)
    }

    // MARK: - Public Database Write/Delete

    func savePublicRecord(_ record: CKRecord) async throws -> CKRecord {
        try await publicDB.save(record)
    }

    func deletePublicRecord(recordID: CKRecord.ID) async throws {
        try await publicDB.deleteRecord(withID: recordID)
    }

    // MARK: - Private Database (User Profile)

    func fetchPrivateRecords(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true)
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let (results, _) = try await privateDB.records(matching: query)
        return results.compactMap { try? $0.1.get() }
    }

    func savePrivateRecord(_ record: CKRecord) async throws -> CKRecord {
        try await privateDB.save(record)
    }

    // MARK: - Asset Helper

    static func assetURL(from record: CKRecord, key: String) -> URL? {
        guard let asset = record[key] as? CKAsset else { return nil }
        return asset.fileURL
    }
}
