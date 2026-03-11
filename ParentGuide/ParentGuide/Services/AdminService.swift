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

    // Hardcoded admin Apple user identifiers.
    // To find yours: sign in with Apple, check console for "[AdminService] Apple User ID: ..."
    private static let adminAppleUserIDs: Set<String> = [
        // Add your Apple user ID here after first Sign in with Apple
    ]

    func checkAdminStatus() async {
        // Check if user is signed in with Apple and get their ID
        guard let userID = KeychainService.read(key: KeychainService.appleUserIdentifier) else {
            print("[AdminService] No Apple user ID found — user not signed in")
            isAdmin = false
            return
        }

        appleUserID = userID
        isAdmin = Self.adminAppleUserIDs.contains(userID)
        print("[AdminService] Apple User ID: \(userID)")
        print("[AdminService] isAdmin: \(isAdmin)")

        // If no admin IDs configured, auto-grant admin (development convenience)
        if Self.adminAppleUserIDs.isEmpty {
            print("[AdminService] No admin IDs configured — granting admin access by default.")
            print("[AdminService] Add \"\(userID)\" to AdminService.adminAppleUserIDs for production.")
            isAdmin = true
        }
    }
}
