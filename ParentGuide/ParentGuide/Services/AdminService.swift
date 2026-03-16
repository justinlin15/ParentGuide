//
//  AdminService.swift
//  ParentGuide
//

import CloudKit
import Foundation

@Observable
class AdminService {
        static let shared = AdminService()

        private(set) var isAdmin = false
        private(set) var appleUserID: String?

        // Admin Apple user identifiers.
        // To find yours: sign in with Apple, check console for "[AdminService] Apple User ID: ..."
        private static let adminAppleUserIDs: Set<String> = [
                    "000662.78dbcb5830514081bc8fef91896e6666.1909"
        ]

        func checkAdminStatus() async {
                    // Check if user is signed in with Apple and get their ID
                    guard let userID = KeychainService.read(key: KeychainService.appleUserIdentifier) else {
                                    print("[AdminService] No Apple user ID found — user not signed in")
                                    isAdmin = false
                                    return
                    }

                    appleUserID = userID
                    print("[AdminService] Apple User ID: \(userID)")

                    #if DEBUG
                    // In debug builds, log the user ID for easy admin setup
                    if Self.adminAppleUserIDs.isEmpty {
                                    print("[AdminService] DEBUG: No admin IDs configured.")
                                    print("[AdminService] DEBUG: Add \"\(userID)\" to AdminService.adminAppleUserIDs to enable admin features.")
                    }
                    #endif

                    isAdmin = Self.adminAppleUserIDs.contains(userID)
                    print("[AdminService] isAdmin: \(isAdmin)")
        }
}
