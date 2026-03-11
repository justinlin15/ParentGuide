//
//  PaywallView.swift
//  ParentGuide
//

import AuthenticationServices
import StoreKit
import SwiftUI

/// A reusable paywall overlay shown when non-subscribers try to access locked content.
struct PaywallView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var authService = AuthService.shared
    @State private var purchaseError: String?
    @State private var isSigningIn = false
    @Environment(\.colorScheme) private var colorScheme
    private var metroService: MetroService { MetroService.shared }

    /// Optional title to customize per tab (e.g., "Event Calendar" or "Guides")
    var lockedContentName: String = "this content"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.brandBlue)

                // Hero text
                VStack(spacing: 8) {
                    Text("Unlimited family fun in")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(metroService.selectedMetro.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.brandBlue)

                    Text("Subscribe to access \(lockedContentName), exclusive meet-ups, local discounts and giveaways!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Sign in first if not signed in
                if !authService.isSignedIn {
                    VStack(spacing: 12) {
                        Text("Sign in to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SignInWithAppleButton(.signIn) { request in
                            let nonce = authService.prepareNonce()
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = AuthService.sha256(nonce)
                        } onCompletion: { result in
                            isSigningIn = true
                            Task {
                                await authService.handleAppleSignIn(result: result)
                                isSigningIn = false
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .padding(.horizontal, 32)
                    }
                }

                // Plan cards (show when signed in, or always to preview)
                if authService.isSignedIn {
                    HStack(spacing: 16) {
                        ForEach(SubscriptionPlan.allPlans) { plan in
                            PlanCardView(plan: plan) {
                                Task { await handlePurchase(plan: plan) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Error
                if let error = purchaseError ?? authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }

                // Restore purchases
                Button {
                    Task { await subscriptionService.restorePurchases() }
                } label: {
                    Text("Already a member? Restore Purchases")
                        .font(.caption)
                        .foregroundStyle(Color.brandBlue)
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await subscriptionService.loadProducts()
        }
        .overlay {
            if subscriptionService.isLoading || isSigningIn {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func handlePurchase(plan: SubscriptionPlan) async {
        purchaseError = nil

        guard let product = subscriptionService.product(for: plan.productID) else {
            purchaseError = "Subscription not available. Please try again later."
            return
        }

        do {
            _ = try await subscriptionService.purchase(product)
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }
    }
}

#Preview {
    PaywallView(lockedContentName: "the Event Calendar")
}
