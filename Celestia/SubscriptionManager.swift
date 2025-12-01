//
//  SubscriptionManager.swift
//  Celestia
//
//  Manages subscription status and premium features
//  Types defined in StoreModels.swift: SubscriptionTier, BillingPeriod, SubscriptionStatus
//

import Foundation
import StoreKit
import Combine
import FirebaseFirestore

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var currentTier: SubscriptionTier = .none
    @Published var isSubscribed: Bool = false
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var expirationDate: Date?
    @Published var autoRenewEnabled: Bool = false

    // MARK: - Properties

    private let storeManager = StoreManager.shared
    private let defaults = UserDefaults.standard
    private var statusUpdateTask: Task<Void, Never>?

    // MARK: - Keys

    private enum Keys {
        static let currentTier = "subscription_current_tier"
        static let expirationDate = "subscription_expiration_date"
        static let autoRenew = "subscription_auto_renew"
    }

    // MARK: - Initialization

    private init() {
        loadSubscriptionStatus()
        startMonitoringTransactions()
        Logger.shared.info("SubscriptionManager initialized", category: .general)
    }

    // MARK: - Subscription Status

    /// Check and update subscription status
    func updateSubscriptionStatus() async {
        Logger.shared.info("Updating subscription status", category: .general)

        // Check active subscriptions
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            // Check if subscription is active
            if let expirationDate = transaction.expirationDate {
                if expirationDate > Date() {
                    // Active subscription found
                    await updateTier(from: transaction)
                    return
                }
            }
        }

        // No active subscription found
        currentTier = .none
        isSubscribed = false
        expirationDate = nil
        saveSubscriptionStatus()

        // CRITICAL: Sync expired subscription status with User model
        await syncUserPremiumStatus(tier: .none, expirationDate: nil)
    }

    private func updateTier(from transaction: StoreKit.Transaction) async {
        let productId = transaction.productID

        // Map product ID to tier
        let tier: SubscriptionTier
        if productId.contains("basic") {
            tier = .basic
        } else if productId.contains("plus") {
            tier = .plus
        } else if productId.contains("premium") {
            tier = .premium
        } else {
            tier = .none
        }

        currentTier = tier
        isSubscribed = tier != .none
        expirationDate = transaction.expirationDate
        // Note: willAutoRenew is not available in StoreKit 2
        // Check renewal status via Product.SubscriptionInfo instead if needed
        autoRenewEnabled = true // Default to true for active subscriptions

        saveSubscriptionStatus()

        // CRITICAL: Sync subscription status with User model in Firestore
        // This ensures isPremium is always accurate even for background transactions
        await syncUserPremiumStatus(tier: tier, expirationDate: transaction.expirationDate)

        // Track analytics
        AnalyticsManager.shared.logEvent(.subscriptionActive, parameters: [
            "tier": tier.rawValue,
            "auto_renew": autoRenewEnabled
        ])

        Logger.shared.info("Subscription active: \(tier.rawValue)", category: .general)
    }

    /// Syncs the subscription status with the User model in Firestore
    /// This ensures the isPremium flag is always accurate across all parts of the app
    private func syncUserPremiumStatus(tier: SubscriptionTier, expirationDate: Date?) async {
        guard var user = AuthService.shared.currentUser else {
            Logger.shared.warning("Cannot sync premium status: No user logged in", category: .general)
            return
        }

        let isPremium = tier != .none

        // Only update if status has changed
        guard user.isPremium != isPremium || user.premiumTier != tier.rawValue else {
            Logger.shared.debug("Premium status unchanged, skipping sync", category: .general)
            return
        }

        user.isPremium = isPremium
        user.premiumTier = isPremium ? tier.rawValue : nil
        user.subscriptionExpiryDate = expirationDate

        do {
            try await AuthService.shared.updateUser(user)
            Logger.shared.info("✅ User premium status synced: isPremium=\(isPremium), tier=\(tier.rawValue)", category: .general)
        } catch {
            Logger.shared.error("Failed to sync user premium status: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Feature Access

    /// Check if user has access to a premium feature
    func hasFeature(_ feature: SubscriptionFeature) -> Bool {
        return currentTier.features.contains(feature)
    }

    /// Update subscription from transaction (called by StoreManager)
    func updateSubscription(tier: SubscriptionTier, transaction: StoreKit.Transaction) async {
        await updateTier(from: transaction)
    }

    /// Add consumable purchase
    func addConsumable(_ type: ConsumableType, amount: Int) async {
        Logger.shared.info("Consumable purchase: \(type) x\(amount)", category: .general)

        guard let userId = AuthService.shared.currentUser?.id else {
            Logger.shared.error("Cannot add consumable: No user logged in", category: .general)
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        do {
            switch type {
            case .boost:
                try await userRef.updateData([
                    "boostsRemaining": FieldValue.increment(Int64(amount))
                ])
                Logger.shared.info("✅ Added \(amount) Boosts", category: .general)

            case .spotlight:
                try await userRef.updateData([
                    "spotlightsRemaining": FieldValue.increment(Int64(amount))
                ])
                Logger.shared.info("✅ Added \(amount) Spotlights", category: .general)
            }

            // Refresh user data
            await AuthService.shared.fetchUser()

        } catch {
            Logger.shared.error("Failed to add consumable: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Transaction Monitoring

    private func startMonitoringTransactions() {
        statusUpdateTask = Task {
            // Monitor transaction updates
            for await result in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }

                // Finish transaction
                await transaction.finish()

                // Update subscription status
                await updateSubscriptionStatus()
            }
        }
    }

    // MARK: - Persistence

    private func loadSubscriptionStatus() {
        if let tierRaw = defaults.string(forKey: Keys.currentTier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            currentTier = tier
            isSubscribed = tier != .none
        }

        if let expirationTimestamp = defaults.object(forKey: Keys.expirationDate) as? TimeInterval {
            expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
        }

        autoRenewEnabled = defaults.bool(forKey: Keys.autoRenew)

        // Check if subscription expired
        if let expirationDate = expirationDate, expirationDate < Date() {
            currentTier = .none
            isSubscribed = false
        }
    }

    private func saveSubscriptionStatus() {
        defaults.set(currentTier.rawValue, forKey: Keys.currentTier)
        defaults.set(autoRenewEnabled, forKey: Keys.autoRenew)

        if let expirationDate = expirationDate {
            defaults.set(expirationDate.timeIntervalSince1970, forKey: Keys.expirationDate)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        statusUpdateTask?.cancel()
    }
}
