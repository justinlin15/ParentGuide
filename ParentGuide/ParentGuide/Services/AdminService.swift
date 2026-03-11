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
    private(set) var userRecordName: String?

    // Hardcoded admin iCloud user record names.
    // To find yours: run the app, check console for "iCloud userRecordName: ..."
    private static let adminRecordNames: Set<String> = [
        // Add your iCloud user record name here after first launch
    ]

    func checkAdminStatus() async {
        do {
            let container = CKContainer(identifier: AppConstants.cloudKitContainerID)
            let recordID = try await container.userRecordID()
            let recordName = recordID.recordName
            userRecordName = recordName
            isAdmin = Self.adminRecordNames.contains(recordName)
            print("[AdminService] iCloud userRecordName: \(recordName)")
            print("[AdminService] isAdmin: \(isAdmin)")

            // If adminRecordNames is empty, auto-grant admin to first user (development convenience)
            if Self.adminRecordNames.isEmpty {
                print("[AdminService] No admin IDs configured — granting admin access by default.")
                print("[AdminService] Add \"\(recordName)\" to AdminService.adminRecordNames for production.")
                isAdmin = true
            }
        } catch {
            print("[AdminService] Could not fetch user record: \(error)")
            isAdmin = false
        }
    }
}
