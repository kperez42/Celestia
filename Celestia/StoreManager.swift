//
//  StoreManager.swift
//  Celestia
//
//  Manages in-app purchases and subscriptions using StoreKit 2
//  Extracted from PremiumUpgradeView for better separation of concerns
//

import Foundation
import StoreKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Premium Plan

enum PremiumPlan: String, CaseIterable {
    case monthly = "monthly"
    case sixMonth = "6month"
    case annual = "annual"

    var name: String {
        switch self {
        case .monthly: return "Monthly"
        case .sixMonth: return "6 Months"
        case .annual: return "Annual"
        }
    }

    var price: String {
        switch self {
        case .monthly: return "$19.99"
        case .sixMonth: return "$14.99"
        case .annual: return "$9.99"
        }
    }

    var period: String {
        switch self {
        case .monthly: return "month"
        case .sixMonth: return "month"
        case .annual: return "month"
        }
    }

    var totalPrice: String {
        switch self {
        case .monthly: return "$19.99/month"
        case .sixMonth: return "$89.94 total"
        case .annual: return "$119.88 total"
        }
    }

    var savings: Int {
        switch self {
        case .monthly: return 0
        case .sixMonth: return 25
        case .annual: return 50
        }
    }

    var productID: String {
        switch self {
        case .monthly: return "com.celestia.premium.monthly"
        case .sixMonth: return "com.celestia.premium.sixmonth"
        case .annual: return "com.celestia.premium.annual"
        }
    }

    var expiryDate: Date {
        let calendar = Calendar.current
        switch self {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case .sixMonth:
            return calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: LocalizedError {
    case productNotFound
    case failedVerification
    case purchaseFailed
    case networkError
    case serverValidationFailed
    case subscriptionExpired

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not available. Please try again."
        case .failedVerification:
            return "Purchase verification failed. Please contact support."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .serverValidationFailed:
            return "Server validation failed. Please contact support."
        case .subscriptionExpired:
            return "Your subscription has expired. Please renew."
        }
    }
}

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var hasActiveSubscription = false
    @Published var currentSubscription: Product.SubscriptionInfo?
    @Published var subscriptionStatus: Product.SubscriptionInfo.Status?

    private var updates: Task<Void, Never>?
    private let db = Firestore.firestore()

    private init() {
        updates = observeTransactionUpdates()
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Product Loading

    /// Load products from App Store
    func loadProducts() async {
        do {
            let productIDs = PremiumPlan.allCases.map { $0.productID }
            products = try await Product.products(for: productIDs)

            print("✅ Loaded \(products.count) products from App Store")

            await updatePurchasedProducts()
            await checkSubscriptionStatus()
        } catch {
            print("❌ Failed to load products: \(error.localizedDescription)")
        }
    }

    /// Get product for a specific plan
    func getProduct(for plan: PremiumPlan) -> Product? {
        return products.first { $0.id == plan.productID }
    }

    // MARK: - Purchase Flow

    /// Purchase a product with StoreKit 2
    func purchase(_ product: Product) async throws -> Bool {
        print("🔵 Starting purchase for: \(product.displayName)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            print("✅ Purchase successful, verifying...")

            // Verify the transaction
            let transaction = try checkVerified(verification)

            // Validate with backend (if you have one)
            try await validatePurchaseWithBackend(transaction: transaction)

            // Update Firestore
            try await updateUserPremiumStatus(transaction: transaction)

            // Finish the transaction
            await transaction.finish()

            // Update local state
            await updatePurchasedProducts()
            await checkSubscriptionStatus()

            print("✅ Purchase completed successfully")
            return true

        case .userCancelled:
            print("ℹ️ User cancelled purchase")
            return false

        case .pending:
            print("⏳ Purchase pending approval")
            return false

        @unknown default:
            print("⚠️ Unknown purchase result")
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async throws {
        print("🔵 Restoring purchases...")

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            await checkSubscriptionStatus()

            if hasActiveSubscription {
                print("✅ Purchases restored successfully")

                // Update Firestore with restored subscription
                if let userId = Auth.auth().currentUser?.uid,
                   let subscription = currentSubscription {
                    try await updateUserPremiumStatusFromSubscription(
                        userId: userId,
                        subscription: subscription
                    )
                }
            } else {
                print("ℹ️ No active subscriptions found")
            }
        } catch {
            print("❌ Failed to restore purchases: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Transaction Verification

    /// Verify a transaction using StoreKit 2's verification
    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(let unverifiedTransaction, let error):
            print("❌ Transaction verification failed: \(error)")
            throw PurchaseError.failedVerification

        case .verified(let verified):
            print("✅ Transaction verified by StoreKit")
            return verified
        }
    }

    // MARK: - Backend Validation

    /// Validate purchase with your backend server (optional but recommended)
    private func validatePurchaseWithBackend(transaction: Transaction) async throws {
        // In a production app, you would send the transaction to your server
        // for server-side receipt validation. This prevents fraud.

        // Example implementation:
        /*
        guard let userId = Auth.auth().currentUser?.uid else {
            throw PurchaseError.notAuthenticated
        }

        let validationData: [String: Any] = [
            "userId": userId,
            "transactionId": transaction.id,
            "productId": transaction.productID,
            "purchaseDate": transaction.purchaseDate.timeIntervalSince1970,
            "originalTransactionId": transaction.originalID
        ]

        // Call your backend API
        let response = try await YourBackendAPI.validatePurchase(validationData)

        if !response.isValid {
            throw PurchaseError.serverValidationFailed
        }
        */

        print("ℹ️ Server-side validation: Implement this in production")
    }

    // MARK: - Firestore Updates

    /// Update user's premium status in Firestore
    private func updateUserPremiumStatus(transaction: Transaction) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in")
            return
        }

        print("🔵 Updating Firestore for user: \(userId)")

        // Determine expiry date based on product
        let calendar = Calendar.current
        var expiryDate = Date()

        if transaction.productID.contains("monthly") {
            expiryDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        } else if transaction.productID.contains("sixmonth") {
            expiryDate = calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        } else if transaction.productID.contains("annual") {
            expiryDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        }

        // Update Firestore
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "isPremium": true,
            "premiumTier": transaction.productID,
            "subscriptionExpiryDate": Timestamp(date: expiryDate),
            "lastPurchaseDate": Timestamp(date: transaction.purchaseDate),
            "originalTransactionId": transaction.originalID
        ])

        print("✅ Firestore updated successfully")
    }

    /// Update user premium status from subscription info
    private func updateUserPremiumStatusFromSubscription(
        userId: String,
        subscription: Product.SubscriptionInfo
    ) async throws {
        let userRef = db.collection("users").document(userId)

        try await userRef.updateData([
            "isPremium": true,
            "subscriptionStatus": subscription.subscriptionStatus.debugDescription
        ])
    }

    // MARK: - Subscription Status

    /// Check current subscription status
    private func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    currentSubscription = try? await product.subscription
                    subscriptionStatus = try? await product.subscription?.status.first

                    print("✅ Active subscription found: \(transaction.productID)")
                    return
                }
            }
        }

        currentSubscription = nil
        subscriptionStatus = nil
        print("ℹ️ No active subscription")
    }

    // MARK: - Update Purchased Products

    /// Update the list of purchased product IDs
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var hasActive = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if subscription is still active
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                    hasActive = true

                    print("✅ Active entitlement: \(transaction.productID)")
                }
            }
        }

        self.purchasedProductIDs = purchasedIDs
        self.hasActiveSubscription = hasActive

        print("ℹ️ Total active subscriptions: \(purchasedIDs.count)")
    }

    // MARK: - Transaction Updates Observer

    /// Observe transaction updates in background
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                if case .verified(let transaction) = result {
                    print("🔔 Transaction update received: \(transaction.productID)")

                    // Update Firestore with new transaction
                    try? await self.updateUserPremiumStatus(transaction: transaction)

                    // Finish the transaction
                    await transaction.finish()

                    // Update local state
                    await self.updatePurchasedProducts()
                    await self.checkSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Subscription Management

    /// Check if a specific product ID has an active subscription
    func hasActiveSubscription(for productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    /// Get subscription renewal date
    func getSubscriptionRenewalDate() async -> Date? {
        guard let subscription = currentSubscription else { return nil }

        do {
            let status = try await subscription.status.first
            return status?.renewalInfo.expirationDate
        } catch {
            print("❌ Failed to get renewal date: \(error)")
            return nil
        }
    }

    /// Check if subscription is in grace period
    func isInGracePeriod() async -> Bool {
        guard let status = subscriptionStatus else { return false }

        switch status.state {
        case .inGracePeriod:
            return true
        default:
            return false
        }
    }

    /// Check if subscription is in billing retry
    func isInBillingRetry() async -> Bool {
        guard let status = subscriptionStatus else { return false }

        switch status.state {
        case .inBillingRetryPeriod:
            return true
        default:
            return false
        }
    }

    // MARK: - Helper Methods

    /// Get localized price for a product
    func getLocalizedPrice(for plan: PremiumPlan) -> String? {
        guard let product = getProduct(for: plan) else { return nil }
        return product.displayPrice
    }

    /// Check if user can make payments
    func canMakePayments() -> Bool {
        return AppStore.canMakePayments
    }

    /// Log purchase analytics
    private func logPurchaseAnalytics(transaction: Transaction) {
        AnalyticsManager.shared.log(
            event: AppConstants.AnalyticsEvents.premiumPurchased,
            parameters: [
                "product_id": transaction.productID,
                "transaction_id": transaction.id,
                "purchase_date": transaction.purchaseDate.timeIntervalSince1970
            ]
        )
    }
}
