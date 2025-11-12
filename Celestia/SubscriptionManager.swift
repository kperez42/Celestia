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
        for await result in Transaction.currentEntitlements {
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
    }

    private func updateTier(from transaction: Transaction) async {
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
        autoRenewEnabled = transaction.willAutoRenew

        saveSubscriptionStatus()

        // Track analytics
        AnalyticsManager.shared.logEvent(.subscriptionActive, parameters: [
            "tier": tier.rawValue,
            "auto_renew": autoRenewEnabled
        ])

        Logger.shared.info("Subscription active: \(tier.rawValue)", category: .general)
    }

    // MARK: - Feature Access

    /// Check if user has access to a premium feature
    func hasFeature(_ feature: SubscriptionFeature) -> Bool {
        return currentTier.features.contains(feature)
    }

    // MARK: - Transaction Monitoring

    private func startMonitoringTransactions() {
        statusUpdateTask = Task {
            // Monitor transaction updates
            for await result in Transaction.updates {
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
