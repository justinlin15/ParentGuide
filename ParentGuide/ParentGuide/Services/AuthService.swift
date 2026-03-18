//
//  AuthService.swift
//  ParentGuide
//

import AuthenticationServices
import CloudKit
import CryptoKit
import Foundation

@Observable
class AuthService {
    static let shared = AuthService()

    // MARK: - Published State

    var isSignedIn = false
    var isLoading = true
    var currentUser: UserProfile?
    var errorMessage: String?

    // MARK: - Apple Sign-In

    /// The current nonce used for Apple Sign-In requests.
    /// Must be set before presenting the Sign in with Apple sheet.
    var currentNonce: String?

    private let cloudKit = CloudKitService.shared

    // MARK: - Init

    private init() {}

    // MARK: - Session Restore

    /// Called on app launch to check if user has a valid session.
    func restoreSession() async {
        guard let userID = KeychainService.read(key: KeychainService.appleUserIdentifier) else {
            print("[AuthService] No saved Apple user ID in Keychain")
            isLoading = false
            return
        }

        print("[AuthService] Found saved Apple user ID: \(userID)")

        // Verify credential state with Apple
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
            switch state {
            case .authorized:
                print("[AuthService] Apple credential still valid")
                await fetchOrCreateProfile(appleUserID: userID)
                isSignedIn = true
            case .revoked:
                print("[AuthService] Apple credential was revoked")
                signOut()
            case .notFound:
                print("[AuthService] Apple credential not found")
                signOut()
            default:
                print("[AuthService] Unknown credential state: \(state.rawValue)")
                signOut()
            }
        } catch {
            print("[AuthService] Error checking credential state: \(error)")
            // Network error — trust the cached session
            await fetchOrCreateProfile(appleUserID: userID)
            isSignedIn = true
        }

        isLoading = false
    }

    // MARK: - Handle Apple Sign-In Result

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential type"
                return
            }

            let userID = credential.user
            print("[AuthService] Apple Sign-In success. User ID: \(userID)")

            // Save user ID to Keychain (always available)
            KeychainService.save(key: KeychainService.appleUserIdentifier, value: userID)

            // Apple only sends email/name on FIRST sign-in — save if present
            if let email = credential.email {
                KeychainService.save(key: KeychainService.appleEmail, value: email)
                print("[AuthService] Saved email: \(email)")
            }

            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty {
                    KeychainService.save(key: KeychainService.appleDisplayName, value: displayName)
                    print("[AuthService] Saved display name: \(displayName)")
                }
            }

            // Create or fetch profile from CloudKit
            await fetchOrCreateProfile(appleUserID: userID)

            isSignedIn = true
            errorMessage = nil

        case .failure(let error):
            // User cancelled is not a real error
            if (error as? ASAuthorizationError)?.code == .canceled {
                print("[AuthService] User cancelled Apple Sign-In")
                return
            }
            print("[AuthService] Apple Sign-In failed: \(error.localizedDescription)")
            errorMessage = "Sign in failed. Please try again."
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainService.clearAll()
        isSignedIn = false
        currentUser = nil
        errorMessage = nil
        print("[AuthService] Signed out and cleared Keychain")
    }

    // MARK: - CloudKit Profile Management

    private func fetchOrCreateProfile(appleUserID: String) async {
        let recordID = CKRecord.ID(recordName: "profile_\(appleUserID)")

        do {
            // Try to fetch existing profile
            let record = try await cloudKit.fetchRecord(recordID: recordID)
            currentUser = UserProfile(record: record)
            print("[AuthService] Loaded existing profile from CloudKit")
        } catch let error as CKError where error.code == .unknownItem {
            // Profile doesn't exist — create one
            print("[AuthService] No existing profile — creating new one")
            await createNewProfile(appleUserID: appleUserID)
        } catch {
            print("[AuthService] Error fetching profile: \(error)")
            // Use a basic local profile as fallback
            currentUser = makeLocalProfile(appleUserID: appleUserID)
        }
    }

    private func createNewProfile(appleUserID: String) async {
        let profile = makeLocalProfile(appleUserID: appleUserID)

        do {
            let record = profile.toCKRecord()
            let savedRecord = try await cloudKit.savePublicRecord(record)
            currentUser = UserProfile(record: savedRecord)
            print("[AuthService] Created new profile in CloudKit")
        } catch {
            print("[AuthService] Failed to create profile: \(error)")
            currentUser = profile
        }
    }

    private func makeLocalProfile(appleUserID: String) -> UserProfile {
        UserProfile(
            id: "profile_\(appleUserID)",
            displayName: KeychainService.read(key: KeychainService.appleDisplayName) ?? "Parent",
            email: KeychainService.read(key: KeychainService.appleEmail) ?? ""
        )
    }

    /// Refresh the local profile from Keychain (e.g., after name edit).
    func refreshProfile() async {
        guard let appleUserID = KeychainService.read(key: KeychainService.appleUserIdentifier) else { return }
        currentUser = makeLocalProfile(appleUserID: appleUserID)
    }

    /// Update profile fields (e.g., home location) and save to CloudKit.
    func updateProfile(_ updatedProfile: UserProfile) async {
        currentUser = updatedProfile

        do {
            let recordID = CKRecord.ID(recordName: updatedProfile.id)
            let record: CKRecord
            do {
                record = try await cloudKit.fetchRecord(recordID: recordID)
            } catch {
                record = updatedProfile.toCKRecord()
            }
            updatedProfile.applyFields(to: record)
            _ = try await cloudKit.savePublicRecord(record)
            NSLog("[AuthService] Profile updated in CloudKit")
        } catch {
            NSLog("[AuthService] Failed to update profile: %@", error.localizedDescription)
        }
    }

    // MARK: - Nonce Helpers (for Sign in with Apple security)

    /// Generates a random nonce string and stores it. Call before presenting the Sign in with Apple sheet.
    func prepareNonce() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return nonce
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
