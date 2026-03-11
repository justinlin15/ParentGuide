//
//  GuideService.swift
//  ParentGuide
//

import CloudKit
import Foundation

actor GuideService {
    static let shared = GuideService()

    private let cloudKit = CloudKitService.shared

    func fetchKidsEatFreeRestaurants() async throws -> [KidsEatFreeRestaurant] {
        let predicate = NSPredicate(format: "isActive == 1")
        let sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.kidsEatFreeRestaurant,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )

        return records.compactMap { KidsEatFreeRestaurant(record: $0) }
    }

    func fetchParentsNightOutProviders() async throws -> [ParentsNightOutProvider] {
        let predicate = NSPredicate(format: "isActive == 1")
        let sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        let records = try await cloudKit.fetchRecords(
            recordType: CloudKitConfig.RecordType.parentsNightOutProvider,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )

        return records.compactMap { ParentsNightOutProvider(record: $0) }
    }
}
