//
//  ParentGuideApp.swift
//  ParentGuide
//
//  Created by Justin Lin on 3/10/26.
//

import AuthenticationServices
import SwiftUI

@main
struct ParentGuideApp: App {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var metroService = MetroService.shared
    @State private var showOnboarding: Bool

    init() {
        // Initialize onboarding state from persisted value
        _showOnboarding = State(initialValue: !MetroService.shared.hasCompletedOnboarding)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold).rounded()
        ]
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded()
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView()
                }
                .task {
                    // Restore auth session from Keychain
                    await authService.restoreSession()

                    // If signed in, restore metro from profile
                    if let profile = authService.currentUser {
                        metroService.restoreFromProfile(profile)
                    }

                    // Load subscription status
                    await subscriptionService.updateSubscriptionStatus()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
                    )
                ) { _ in
                    // Apple revoked the credential — sign out
                    print("[ParentGuideApp] Apple credential revoked — signing out")
                    authService.signOut()
                }
        }
    }
}
