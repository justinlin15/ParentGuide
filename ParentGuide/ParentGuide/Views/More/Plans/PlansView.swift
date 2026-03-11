//
//  PlansView.swift
//  ParentGuide
//

import StoreKit
import SwiftUI

struct PlansView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var authService = AuthService.shared
    @State private var showLogin = false
    @State private var purchaseError: String?
    private var metroService: MetroService { MetroService.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero text
                VStack(spacing: 12) {
                    Text("Unlimited family fun in")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(metroService.selectedMetro.name)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.brandBlue)

                    Text("Become a member and access over 1,500 monthly events, exclusive subscriber meet-ups, local partner discounts and free giveaways!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Already subscribed banner
                if subscriptionService.isSubscribed {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("You're a member!")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }

                // Plan cards
                if !subscriptionService.isSubscribed {
                    HStack(spacing: 16) {
                        ForEach(SubscriptionPlan.allPlans) { plan in
                            PlanCardView(plan: plan) {
                                Task { await handlePurchase(plan: plan) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Error message
                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }

                // Restore purchases
                Button {
                    Task { await subscriptionService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandBlue)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await subscriptionService.loadProducts()
        }
        .overlay {
            if subscriptionService.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            NavigationStack {
                LoginView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { showLogin = false }
                        }
                    }
            }
        }
    }

    private func handlePurchase(plan: SubscriptionPlan) async {
        purchaseError = nil

        // Must be signed in to purchase
        guard authService.isSignedIn else {
            showLogin = true
            return
        }

        // Get the StoreKit product
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

struct PlanCardView: View {
    let plan: SubscriptionPlan
    var onSubscribe: () -> Void = {}

    // Not private so the memberwise init stays internal (accessible from other files)
    var subscriptionService = SubscriptionService.shared

    /// Use real App Store price if available, otherwise fall back to hardcoded.
    private var displayPrice: String {
        if let product = subscriptionService.product(for: plan.productID) {
            return product.displayPrice
        }
        return plan.price
    }

    var body: some View {
        VStack(spacing: 16) {
            if plan.isBestValue {
                Text("Best value")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.brandLavender)
                    .foregroundStyle(.white)
                    .cornerRadius(4)
            }

            Text(plan.name)
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 2) {
                Text(displayPrice)
                    .font(.system(size: 36, weight: .bold))
                Text(plan.period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(plan.trialDays) day free trial")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSubscribe) {
                Text("Start free trial")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandBlue)
                    .cornerRadius(20)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(feature)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(plan.isBestValue ? Color.brandNavy : Color(.systemBackground))
        .foregroundStyle(plan.isBestValue ? .white : .primary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(plan.isBestValue ? Color.clear : Color(.systemGray4), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PlansView()
    }
}
