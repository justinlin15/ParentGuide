//
//  AuthService.swift
//  ParentGuide
//

import AuthenticationServices
import CloudKit
import Foundation

@Observable
class AuthService {
    static let shared = AuthService()

    var isSignedIn = false
    var currentUser: UserProfile?
    var errorMessage: String?

    func checkAuthStatus() {
        CKContainer(identifier: AppConstants.cloudKitContainerID).accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isSignedIn = (status == .available)
            }
        }
    }

    func signOut() {
        isSignedIn = false
        currentUser = nil
    }
}
