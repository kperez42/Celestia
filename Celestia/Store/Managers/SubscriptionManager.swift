//
//  SubscriptionManager.swift
//  Celestia
//
//  Manages subscription status and consumable balances
//

import Foundation
import StoreKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var consumableBalance: ConsumableBalance = ConsumableBalance()
    @Published var purchaseHistory: [PurchaseHistoryEntry] = []

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let db = Firestore.firestore()

    private enum Keys {
        static let subscriptionStatus = "subscription_status"
        static let consumableBalance = "consumable_balance"
        static let purchaseHistory = "purchase_history"
    }

    // MARK: - Initialization

    private init() {
        loadSubscriptionStatus()
        loadConsumableBalance()
        loadPurchaseHistory()
        Logger.shared.info("SubscriptionManager initialized", category: .general)

        Task {
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Subscription Status

    /// Update subscription from transaction
    func updateSubscription(tier: SubscriptionTier, transaction: Transaction) async {
        Logger.shared.info("Updating subscription: \(tier.displayName)", category: .general)

        // Determine billing period from product ID
        let period: BillingPeriod = transaction.productID.contains("yearly") ? .yearly : .monthly

        // Calculate expiration date
        let expirationDate = transaction.expirationDate

        subscriptionStatus = SubscriptionStatus(
            tier: tier,
            period: period,
            isActive: true,
            expirationDate: expirationDate,
            renewalDate: expirationDate,
            isInGracePeriod: false,
            isBillingRetry: false,
            autoRenewEnabled: true
        )

        saveSubscriptionStatus()

        // Sync with Firestore
        await syncSubscriptionToFirestore(transaction: transaction)

        // Add to purchase history
        addToPurchaseHistory(transaction: transaction, productName: tier.displayName)

        // Track analytics
        AnalyticsManager.shared.logEvent(.subscriptionStarted, parameters: [
            "tier": tier.rawValue,
            "period": period.rawValue,
            "price": transaction.price?.description ?? "unknown"
        ])
    }

    /// Update subscription status from App Store
    func updateSubscriptionStatus() async {
        Logger.shared.info("Checking subscription status", category: .general)

        // Get current subscription status
        guard let subscription = await getCurrentSubscription() else {
            // No active subscription
            if subscriptionStatus.isActive {
                // Subscription expired
                subscriptionStatus.isActive = false
                saveSubscriptionStatus()

                // Sync expiration to Firestore
                await syncSubscriptionExpirationToFirestore()

                // Track analytics
                AnalyticsManager.shared.logEvent(.subscriptionExpired, parameters: [
                    "tier": subscriptionStatus.tier.rawValue
                ])

                Logger.shared.info("Subscription expired", category: .general)
            }
            return
        }

        let status = subscription.status

        // Update status
        for await result in status {
            guard case .verified(let renewalInfo) = result.renewalInfo,
                  case .verified(let transaction) = result.transaction else {
                continue
            }

            // Get tier from product ID
            guard let productType = getProductType(for: transaction.productID),
                  case .subscription(let tier, let period) = productType else {
                continue
            }

            subscriptionStatus = SubscriptionStatus(
                tier: tier,
                period: period,
                isActive: result.state == .subscribed,
                expirationDate: transaction.expirationDate,
                renewalDate: renewalInfo.renewalDate,
                isInGracePeriod: result.state == .inGracePeriod,
                isBillingRetry: result.state == .inBillingRetryPeriod,
                autoRenewEnabled: renewalInfo.willAutoRenew
            )

            saveSubscriptionStatus()

            Logger.shared.info("Subscription status updated: \(tier.displayName), active: \(result.state == .subscribed)", category: .general)

            break // Only process the first (current) subscription
        }
    }

    private func getCurrentSubscription() async -> Product.SubscriptionInfo? {
        // Find any subscription product
        let subscriptionProducts = StoreManager.shared.subscriptionProducts

        for product in subscriptionProducts {
            if let subscription = product.subscription {
                return subscription
            }
        }

        return nil
    }

    // MARK: - Consumables

    /// Add consumable to balance
    func addConsumable(_ type: ConsumableType, amount: Int) {
        Logger.shared.info("Adding \(amount) \(type.displayName)", category: .general)

        consumableBalance.add(type, amount: amount)
        saveConsumableBalance()

        // Track analytics
        AnalyticsManager.shared.logEvent(.consumablePurchased, parameters: [
            "type": type.rawValue,
            "amount": amount,
            "new_balance": consumableBalance.balance(for: type)
        ])
    }

    /// Use consumable
    func useConsumable(_ type: ConsumableType, amount: Int = 1) -> Bool {
        guard consumableBalance.use(type, amount: amount) else {
            Logger.shared.warning("Insufficient \(type.displayName)", category: .general)
            return false
        }

        Logger.shared.info("Used \(amount) \(type.displayName)", category: .general)

        saveConsumableBalance()

        // Track analytics
        AnalyticsManager.shared.logEvent(.consumableUsed, parameters: [
            "type": type.rawValue,
            "amount": amount,
            "remaining": consumableBalance.balance(for: type)
        ])

        return true
    }

    /// Get balance for consumable type
    func balance(for type: ConsumableType) -> Int {
        return consumableBalance.balance(for: type)
    }

    /// Check if user has consumable
    func hasConsumable(_ type: ConsumableType) -> Bool {
        return consumableBalance.balance(for: type) > 0
    }

    // MARK: - Features

    /// Check if user has access to feature
    func hasFeature(_ feature: SubscriptionFeature) -> Bool {
        return subscriptionStatus.tier.features.contains(feature)
    }

    /// Check if user has subscription tier
    func hasSubscription(_ tier: SubscriptionTier) -> Bool {
        return subscriptionStatus.isActive && subscriptionStatus.tier.rawValue >= tier.rawValue
    }

    /// Get feature value
    func featureValue<T>(for feature: SubscriptionFeature) -> T? {
        guard let matchingFeature = subscriptionStatus.tier.features.first(where: {
            type(of: $0) == type(of: feature)
        }) else {
            return nil
        }

        switch matchingFeature {
        case .superLikesPerDay(let count):
            return count as? T
        case .boosts(let count):
            return count as? T
        case .unlimitedMatches(let enabled),
             .rewinds(let enabled),
             .seeWhoLikesYou(let enabled),
             .advancedFilters(let enabled),
             .readReceipts(let enabled),
             .priorityLikes(let enabled),
             .noAds(let enabled),
             .profileBoost(let enabled):
            return enabled as? T
        }
    }

    // MARK: - Purchase History

    private func addToPurchaseHistory(transaction: Transaction, productName: String) {
        let entry = PurchaseHistoryEntry(
            id: UUID().uuidString,
            productId: transaction.productID,
            productName: productName,
            price: transaction.price?.description ?? "N/A",
            purchaseDate: transaction.purchaseDate,
            transactionId: String(transaction.id),
            isRestored: transaction.isUpgraded
        )

        purchaseHistory.insert(entry, at: 0)

        // Keep only last 100 entries
        if purchaseHistory.count > 100 {
            purchaseHistory = Array(purchaseHistory.prefix(100))
        }

        savePurchaseHistory()
    }

    // MARK: - Persistence

    private func saveSubscriptionStatus() {
        if let data = try? JSONEncoder().encode(subscriptionStatus) {
            defaults.set(data, forKey: Keys.subscriptionStatus)
        }
    }

    private func loadSubscriptionStatus() {
        if let data = defaults.data(forKey: Keys.subscriptionStatus),
           let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
            subscriptionStatus = status
        }
    }

    private func saveConsumableBalance() {
        if let data = try? JSONEncoder().encode(consumableBalance) {
            defaults.set(data, forKey: Keys.consumableBalance)
        }
    }

    private func loadConsumableBalance() {
        if let data = defaults.data(forKey: Keys.consumableBalance),
           let balance = try? JSONDecoder().decode(ConsumableBalance.self, from: data) {
            consumableBalance = balance
        }
    }

    private func savePurchaseHistory() {
        if let data = try? JSONEncoder().encode(purchaseHistory) {
            defaults.set(data, forKey: Keys.purchaseHistory)
        }
    }

    private func loadPurchaseHistory() {
        if let data = defaults.data(forKey: Keys.purchaseHistory),
           let history = try? JSONDecoder().decode([PurchaseHistoryEntry].self, from: data) {
            purchaseHistory = history
        }
    }

    // MARK: - Helpers

    private func getProductType(for productID: String) -> ProductType? {
        // Same logic as StoreManager
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

        return nil
    }

    // MARK: - Cancel Subscription

    /// Open subscription management in Settings
    func manageSubscription() async {
        #if !targetEnvironment(simulator)
        do {
            try await AppStore.showManageSubscriptions(in: UIApplication.shared.connectedScenes.first as? UIWindowScene)

            // Track analytics
            AnalyticsManager.shared.logEvent(.subscriptionManaged, parameters: [:])

        } catch {
            Logger.shared.error("Failed to open subscription management: \(error.localizedDescription)", category: .general)
        }
        #else
        Logger.shared.warning("Subscription management not available on simulator", category: .general)
        #endif
    }

    // MARK: - Firebase Integration

    /// Sync subscription to Firestore
    private func syncSubscriptionToFirestore(transaction: Transaction) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.shared.warning("No user logged in for Firestore sync", category: .general)
            return
        }

        Logger.shared.info("Syncing subscription to Firestore for user: \(userId)", category: .general)

        do {
            let userRef = db.collection("users").document(userId)

            // Get tier from product ID
            let tier = subscriptionStatus.tier
            let expirationDate = subscriptionStatus.expirationDate ?? Date()

            try await userRef.updateData([
                "isPremium": true,
                "premiumTier": tier.rawValue,
                "subscriptionTier": tier.displayName,
                "subscriptionPeriod": subscriptionStatus.period.rawValue,
                "subscriptionExpiryDate": Timestamp(date: expirationDate),
                "lastPurchaseDate": Timestamp(date: transaction.purchaseDate),
                "originalTransactionId": transaction.originalID,
                "transactionId": String(transaction.id),
                "autoRenewEnabled": subscriptionStatus.autoRenewEnabled,
                "lastSyncDate": Timestamp(date: Date())
            ])

            Logger.shared.info("Firestore updated successfully", category: .general)

        } catch {
            Logger.shared.error("Failed to update Firestore: \(error.localizedDescription)", category: .general)
        }
    }

    /// Update Firestore when subscription expires
    func syncSubscriptionExpirationToFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "isPremium": false,
                "subscriptionStatus": "expired",
                "lastSyncDate": Timestamp(date: Date())
            ])

            Logger.shared.info("Subscription expiration synced to Firestore", category: .general)

        } catch {
            Logger.shared.error("Failed to sync expiration to Firestore: \(error.localizedDescription)", category: .general)
        }
    }

    /// Restore subscription from Firestore (useful for cross-device sync)
    func restoreFromFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Logger.shared.info("Restoring subscription from Firestore", category: .general)

        do {
            let userRef = db.collection("users").document(userId)
            let snapshot = try await userRef.getDocument()

            guard let data = snapshot.data(),
                  let isPremium = data["isPremium"] as? Bool,
                  isPremium else {
                Logger.shared.info("No premium status in Firestore", category: .general)
                return
            }

            // This is informational only - actual subscription status comes from StoreKit
            Logger.shared.info("Premium status in Firestore: true", category: .general)

        } catch {
            Logger.shared.error("Failed to restore from Firestore: \(error.localizedDescription)", category: .general)
        }
    }
}
