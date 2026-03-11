//
//  SubscriptionService.swift
//  ParentGuide
//

import Foundation
import StoreKit

@Observable
class SubscriptionService {
    static let shared = SubscriptionService()

    // MARK: - Product IDs

    static let monthlyID = "com.iw.ParentGuide.monthly"
    static let annualID = "com.iw.ParentGuide.annual"
    static let allProductIDs: Set<String> = [monthlyID, annualID]

    // MARK: - State

    var products: [Product] = []
    var isSubscribed = false
    var currentSubscription: StoreKit.Transaction?
    var isLoading = false
    var errorMessage: String?

    /// The active subscription product ID (monthly or annual), if any.
    var activeProductID: String?

    /// Expiration date of the current subscription, if known.
    var expirationDate: Date?

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            // Sort: monthly first, then annual
            products = storeProducts.sorted { a, _ in
                a.id == Self.monthlyID
            }
            print("[SubscriptionService] Loaded \(products.count) products")
            for product in products {
                print("[SubscriptionService]   \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("[SubscriptionService] Failed to load products: \(error)")
            errorMessage = "Could not load subscription options."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                isLoading = false
                print("[SubscriptionService] Purchase successful: \(product.id)")
                return transaction

            case .userCancelled:
                isLoading = false
                print("[SubscriptionService] User cancelled purchase")
                return nil

            case .pending:
                isLoading = false
                print("[SubscriptionService] Purchase pending (Ask to Buy?)")
                errorMessage = "Purchase is pending approval."
                return nil

            @unknown default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            print("[SubscriptionService] Purchase error: \(error)")
            errorMessage = "Purchase failed. Please try again."
            throw error
        }
    }

    // MARK: - Check Subscription Status

    func updateSubscriptionStatus() async {
        var foundTransaction: StoreKit.Transaction?

        // Iterate through current entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if Self.allProductIDs.contains(transaction.productID) {
                    foundTransaction = transaction
                    break
                }
            }
        }

        currentSubscription = foundTransaction
        isSubscribed = foundTransaction != nil
        activeProductID = foundTransaction?.productID
        expirationDate = foundTransaction?.expirationDate

        if let tx = foundTransaction {
            print("[SubscriptionService] Active subscription: \(tx.productID), expires: \(tx.expirationDate?.formatted() ?? "unknown")")
        } else {
            print("[SubscriptionService] No active subscription")
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("[SubscriptionService] Restore complete, subscribed: \(isSubscribed)")
        } catch {
            print("[SubscriptionService] Restore failed: \(error)")
            errorMessage = "Could not restore purchases."
        }
        isLoading = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                    print("[SubscriptionService] Transaction update: \(transaction.productID)")
                }
            }
        }
    }

    // MARK: - Helpers

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    /// Convenience to get the Product for a given plan.
    func product(for planID: String) -> Product? {
        products.first { $0.id == planID }
    }

    /// The monthly Product, if loaded.
    var monthlyProduct: Product? {
        product(for: Self.monthlyID)
    }

    /// The annual Product, if loaded.
    var annualProduct: Product? {
        product(for: Self.annualID)
    }
}
