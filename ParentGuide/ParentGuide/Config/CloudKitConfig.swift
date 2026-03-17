//
//  CloudKitConfig.swift
//  ParentGuide
//

import CloudKit

nonisolated enum CloudKitConfig {
    static let container = CKContainer(identifier: AppConstants.cloudKitContainerID)
    static let publicDatabase = container.publicCloudDatabase
    static let privateDatabase = container.privateCloudDatabase

    enum RecordType {
        static let event = "Event"
        // Phase 2: Guides
        // static let kidsEatFreeRestaurant = "KidsEatFreeRestaurant"
        // static let parentsNightOutProvider = "ParentsNightOutProvider"
        static let resource = "Resource"
        static let aboutSection = "AboutSection"
        static let userProfile = "UserProfile"
        static let eventSuggestion = "EventSuggestion"
    }
}
