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

    /// Beta testing override for admin role. Only active when AppConstants.betaTestingEnabled is true.
    /// Set to `nil` to use real admin check, `true`/`false` to force override.
    var debugAdminOverride: Bool? = nil {
        didSet {
            guard AppConstants.betaTestingEnabled else { return }
            if let override = debugAdminOverride {
                isAdmin = override
            }
        }
    }

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

        isAdmin = Self.adminAppleUserIDs.contains(userID)

        // Apply beta testing override if active
        if AppConstants.betaTestingEnabled, let override = debugAdminOverride {
            isAdmin = override
            print("[AdminService] Beta override active — isAdmin: \(isAdmin)")
        }

        print("[AdminService] isAdmin: \(isAdmin)")
    }
}
