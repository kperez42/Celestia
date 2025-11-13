//
//  StoreManager.swift
//  Celestia
//
//  StoreKit 2 manager for In-App Purchases
//

import Foundation
import StoreKit
import UIKit

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {

    // MARK: - Singleton

    static let shared = StoreManager()

    // MARK: - Published Properties

    @Published var products: [Product] = []
    @Published var subscriptionProducts: [Product] = []
    @Published var consumableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization

    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        Logger.shared.info("StoreManager initialized", category: .general)

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true

        Logger.shared.info("Loading products from App Store", category: .general)

        do {
            // Load all products
            products = try await Product.products(for: ProductIdentifiers.allProducts)

            // Separate by type
            subscriptionProducts = products.filter { product in
                ProductIdentifiers.allSubscriptions.contains(product.id)
            }

            consumableProducts = products.filter { product in
                ProductIdentifiers.allConsumables.contains(product.id)
            }

            Logger.shared.info("Loaded \(products.count) products", category: .general)

        } catch {
            Logger.shared.error("Failed to load products: \(error.localizedDescription)", category: .general)
        }

        isLoading = false
    }

    // MARK: - Purchase

    /// Purchase a product
    func purchase(_ product: Product) async throws -> PurchaseResult {
        Logger.shared.info("Attempting purchase: \(product.displayName)", category: .general)

        // Track analytics
        AnalyticsManager.shared.logEvent(.purchaseInitiated, parameters: [
            "product_id": product.id,
            "product_name": product.displayName,
            "price": product.displayPrice
        ])

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Deliver content
                await deliverContent(for: transaction)

                // Finish the transaction
                await transaction.finish()

                // Update purchased products
                await updatePurchasedProducts()

                // Track analytics
                AnalyticsManager.shared.logEvent(.purchaseCompleted, parameters: [
                    "product_id": product.id,
                    "transaction_id": String(transaction.id)
                ])

                Logger.shared.info("Purchase successful: \(product.displayName)", category: .general)

                return .success(transaction)

            case .pending:
                Logger.shared.info("Purchase pending: \(product.displayName)", category: .general)
                return .pending

            case .userCancelled:
                Logger.shared.info("Purchase cancelled: \(product.displayName)", category: .general)

                // Track analytics
                AnalyticsManager.shared.logEvent(.purchaseCancelled, parameters: [
                    "product_id": product.id
                ])

                return .cancelled

            @unknown default:
                Logger.shared.warning("Unknown purchase result", category: .general)
                return .cancelled
            }

        } catch {
            Logger.shared.error("Purchase failed: \(error.localizedDescription)", category: .general)

            // Track analytics
            AnalyticsManager.shared.logEvent(.purchaseFailed, parameters: [
                "product_id": product.id,
                "error": error.localizedDescription
            ])

            return .failed(error)
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async throws {
        Logger.shared.info("Restoring purchases", category: .general)

        isLoading = true

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update purchased products
            await updatePurchasedProducts()

            Logger.shared.info("Purchases restored successfully", category: .general)

            // Track analytics
            AnalyticsManager.shared.logEvent(.purchasesRestored, parameters: [:])

        } catch {
            Logger.shared.error("Failed to restore purchases: \(error.localizedDescription)", category: .general)
            throw StoreError.restorationFailed
        }

        isLoading = false
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            Logger.shared.error("Transaction verification failed", category: .general)
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Deliver Content

    private func deliverContent(for transaction: StoreKit.Transaction) async {
        Logger.shared.info("Delivering content for transaction: \(transaction.id)", category: .general)

        // CRITICAL: Validate receipt server-side before delivering content
        // This prevents fraud by ensuring purchases are legitimate
        guard let userId = AuthService.shared.currentUser?.id else {
            Logger.shared.error("Cannot deliver content: no user ID", category: .general)
            return
        }

        do {
            // Validate with backend server
            let validationResponse = try await BackendAPIService.shared.validateReceipt(transaction, userId: userId)

            guard validationResponse.isValid else {
                Logger.shared.error("Server-side validation failed: \(validationResponse.reason ?? "unknown")", category: .general)
                // Track fraud attempt
                AnalyticsManager.shared.logEvent(.fraudDetected, parameters: [
                    "transaction_id": String(transaction.id),
                    "product_id": transaction.productID,
                    "reason": validationResponse.reason ?? "validation_failed"
                ])
                return
            }

            Logger.shared.info("Server-side validation successful ✅", category: .general)

        } catch {
            Logger.shared.error("Receipt validation error: \(error.localizedDescription)", category: .general)
            // SECURITY: Don't deliver content if validation fails
            // Track validation errors for monitoring
            AnalyticsManager.shared.logEvent(.validationError, parameters: [
                "transaction_id": String(transaction.id),
                "error": error.localizedDescription
            ])
            return
        }

        // Validation passed - deliver content
        guard let productType = getProductType(for: transaction.productID) else {
            Logger.shared.error("Unknown product type: \(transaction.productID)", category: .general)
            return
        }

        switch productType {
        case .subscription(let tier, _):
            // Update subscription status
            await SubscriptionManager.shared.updateSubscription(tier: tier, transaction: transaction)

        case .consumable(let type):
            // Add consumable to balance
            let amount = getConsumableAmount(for: transaction.productID)
            await SubscriptionManager.shared.addConsumable(type, amount: amount)
        }
    }

    // MARK: - Update Purchased Products

    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }

        self.purchasedProductIDs = purchasedIDs

        Logger.shared.debug("Updated purchased products: \(purchasedIDs.count)", category: .general)
    }

    // MARK: - Listen for Transactions

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Deliver content
                    await self.deliverContent(for: transaction)

                    // Finish the transaction
                    await transaction.finish()

                    // Update purchased products
                    await self.updatePurchasedProducts()

                } catch {
                    await MainActor.run {
                        Logger.shared.error("Transaction update failed: \(error.localizedDescription)", category: .general)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Get product type from product ID
    private func getProductType(for productID: String) -> ProductType? {
        // Subscriptions
        if productID == ProductIdentifiers.subscriptionBasicMonthly {
            return .subscription(.basic, .monthly)
        } else if productID == ProductIdentifiers.subscriptionBasicYearly {
            return .subscription(.basic, .yearly)
        } else if productID == ProductIdentifiers.subscriptionPlusMonthly {
            return .subscription(.plus, .monthly)
        } else if productID == ProductIdentifiers.subscriptionPlusYearly {
            return .subscription(.plus, .yearly)
        } else if productID == ProductIdentifiers.subscriptionPremiumMonthly {
            return .subscription(.premium, .monthly)
        } else if productID == ProductIdentifiers.subscriptionPremiumYearly {
            return .subscription(.premium, .yearly)
        }

        // Consumables
        else if productID.contains("superlikes") {
            return .consumable(.superLikes)
        } else if productID.contains("boost") {
            return .consumable(.boost)
        } else if productID.contains("rewinds") {
            return .consumable(.rewind)
        } else if productID.contains("spotlight") {
            return .consumable(.spotlight)
        }

        return nil
    }

    /// Get consumable amount from product ID
    private func getConsumableAmount(for productID: String) -> Int {
        if productID == ProductIdentifiers.superLikes5 {
            return 5
        } else if productID == ProductIdentifiers.superLikes10 {
            return 10
        } else if productID == ProductIdentifiers.superLikes25 {
            return 25
        } else if productID == ProductIdentifiers.boost1Hour {
            return 1
        } else if productID == ProductIdentifiers.boost3Hours {
            return 1
        } else if productID == ProductIdentifiers.boost24Hours {
            return 1
        } else if productID == ProductIdentifiers.rewinds5 {
            return 5
        } else if productID == ProductIdentifiers.spotlightWeekend {
            return 1
        }

        return 1 // Default
    }

    /// Get product by ID
    func product(for id: String) -> Product? {
        return products.first { $0.id == id }
    }

    /// Check if product is purchased
    func isPurchased(_ product: Product) -> Bool {
        return purchasedProductIDs.contains(product.id)
    }

    /// Get subscription products for a tier
    func subscriptionProducts(for tier: SubscriptionTier) -> [Product] {
        return subscriptionProducts.filter { product in
            switch tier {
            case .basic:
                return product.id.contains("basic")
            case .plus:
                return product.id.contains("plus")
            case .premium:
                return product.id.contains("premium")
            case .none:
                return false
            }
        }
    }

    // MARK: - Promo Codes

    /// Present promo code redemption sheet
    func presentPromoCodeRedemption() async {
        #if !targetEnvironment(simulator)
        // Use StoreKit 2 API for offer code redemption
        await MainActor.run {
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        // Get the active window scene
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                            Logger.shared.error("No window scene available for offer code redemption", category: .general)
                            return
                        }

                        try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)

                        // Track analytics
                        await AnalyticsManager.shared.logEvent(.promoCodeRedeemed, parameters: [:])
                    } catch {
                        Logger.shared.error("Failed to present offer code sheet", category: .general, error: error)
                    }
                }
            } else {
                Logger.shared.warning("Offer code redemption requires iOS 16+", category: .general)
            }
        }
        #else
        Logger.shared.warning("Promo code redemption not available on simulator", category: .general)
        #endif
    }

    /// Get product for a premium plan
    func getProduct(for plan: PremiumPlan) -> Product? {
        let productID = plan.productID
        return products.first { $0.id == productID }
    }

    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        return SubscriptionManager.shared.subscriptionStatus?.isActive ?? false
    }
}

// MARK: - PurchaseError

enum PurchaseError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case verificationFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        case .verificationFailed:
            return "Purchase verification failed"
        case .userCancelled:
            return "Purchase cancelled"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var displayPrice: String {
        return self.displayPrice
    }

    var displayName: String {
        return self.displayName
    }

    var localizedDescription: String {
        return self.description
    }
}
