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
        // TODO: Add real Apple User IDs here, e.g.:
        // "000000.abcdef1234567890abcdef1234567890.1234"
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
        // In debug builds, auto-grant admin if no admin IDs are configured yet
        if Self.adminAppleUserIDs.isEmpty {
            print("[AdminService] DEBUG: No admin IDs configured — granting admin access for development.")
            print("[AdminService] DEBUG: Add \"\(userID)\" to AdminService.adminAppleUserIDs for production.")
            isAdmin = true
            return
        }
        #endif

        isAdmin = Self.adminAppleUserIDs.contains(userID)
        print("[AdminService] isAdmin: \(isAdmin)")
    }
}
