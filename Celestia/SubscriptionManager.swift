//
//  SubscriptionManager.swift
//  Celestia
//
//  Manages subscription status and premium features
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

    @Published var currentTier: SubscriptionTier = .free
    @Published var isSubscribed: Bool = false
    @Published var subscriptionStatus: SubscriptionStatus = .inactive
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
        currentTier = .free
        isSubscribed = false
        subscriptionStatus = .inactive
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
            tier = .free
        }

        currentTier = tier
        isSubscribed = tier != .free
        subscriptionStatus = .active
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
    func hasAccess(to feature: PremiumFeature) -> Bool {
        return currentTier.hasAccess(to: feature)
    }

    /// Get remaining count for a limited feature
    func getRemainingCount(for feature: PremiumFeature) -> Int? {
        return currentTier.getLimit(for: feature)
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
            isSubscribed = tier != .free
        }

        if let expirationTimestamp = defaults.object(forKey: Keys.expirationDate) as? TimeInterval {
            expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
        }

        autoRenewEnabled = defaults.bool(forKey: Keys.autoRenew)

        // Update status based on expiration
        if let expirationDate = expirationDate {
            if expirationDate < Date() {
                // Subscription expired
                currentTier = .free
                isSubscribed = false
                subscriptionStatus = .expired
            } else {
                subscriptionStatus = .active
            }
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

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case plus = "plus"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .plus: return "Plus"
        case .premium: return "Premium"
        }
    }

    var icon: String {
        switch self {
        case .free: return "heart"
        case .basic: return "star"
        case .plus: return "star.fill"
        case .premium: return "crown.fill"
        }
    }

    func hasAccess(to feature: PremiumFeature) -> Bool {
        switch self {
        case .free:
            return feature.requiredTier == .free
        case .basic:
            return feature.requiredTier == .free || feature.requiredTier == .basic
        case .plus:
            return feature.requiredTier != .premium
        case .premium:
            return true
        }
    }

    func getLimit(for feature: PremiumFeature) -> Int? {
        switch (self, feature) {
        case (.free, .likes):
            return 10
        case (.free, .superLikes):
            return 1
        case (.basic, .likes):
            return 50
        case (.basic, .superLikes):
            return 5
        case (.plus, .likes):
            return 200
        case (.plus, .superLikes):
            return 10
        case (.premium, _):
            return nil // Unlimited
        default:
            return nil
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: String {
    case active = "active"
    case inactive = "inactive"
    case expired = "expired"
    case cancelled = "cancelled"
}

// MARK: - Premium Feature

enum PremiumFeature {
    case unlimitedLikes
    case superLikes
    case likes
    case rewind
    case seeWhoLikesYou
    case priorityLikes
    case advancedFilters
    case incognito
    case readReceipts
    case travelMode
    case boosts
    case profileControls

    var requiredTier: SubscriptionTier {
        switch self {
        case .likes, .superLikes, .unlimitedLikes:
            return .free // Has limits for free
        case .rewind, .priorityLikes:
            return .basic
        case .seeWhoLikesYou, .advancedFilters, .readReceipts:
            return .plus
        case .incognito, .travelMode, .boosts, .profileControls:
            return .premium
        }
    }

    var displayName: String {
        switch self {
        case .unlimitedLikes: return "Unlimited Likes"
        case .superLikes: return "Super Likes"
        case .likes: return "Likes"
        case .rewind: return "Rewind"
        case .seeWhoLikesYou: return "See Who Likes You"
        case .priorityLikes: return "Priority Likes"
        case .advancedFilters: return "Advanced Filters"
        case .incognito: return "Incognito Mode"
        case .readReceipts: return "Read Receipts"
        case .travelMode: return "Travel Mode"
        case .boosts: return "Profile Boosts"
        case .profileControls: return "Profile Controls"
        }
    }
}

// MARK: - Billing Period

enum BillingPeriod: String, Codable {
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var discountText: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "Save 40%"
        }
    }
}
