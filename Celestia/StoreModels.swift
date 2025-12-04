//
//  StoreModels.swift
//  Celestia
//
//  Product models and types for In-App Purchases
//

import Foundation
import StoreKit

// MARK: - Product Identifiers

struct ProductIdentifiers {

    // MARK: - Subscriptions (Auto-Renewable)

    static let subscriptionBasicMonthly = "com.celestia.subscription.basic.monthly"
    static let subscriptionBasicYearly = "com.celestia.subscription.basic.yearly"

    static let subscriptionPlusMonthly = "com.celestia.subscription.plus.monthly"
    static let subscriptionPlusYearly = "com.celestia.subscription.plus.yearly"

    static let subscriptionPremiumMonthly = "com.celestia.subscription.premium.monthly"
    static let subscriptionPremiumYearly = "com.celestia.subscription.premium.yearly"

    // MARK: - Consumables

    static let boost1Hour = "com.celestia.consumable.boost.1hour"
    static let boost3Hours = "com.celestia.consumable.boost.3hours"
    static let boost24Hours = "com.celestia.consumable.boost.24hours"

    static let spotlightWeekend = "com.celestia.consumable.spotlight.weekend"

    // MARK: - All Products

    static var allSubscriptions: [String] {
        return [
            subscriptionBasicMonthly,
            subscriptionBasicYearly,
            subscriptionPlusMonthly,
            subscriptionPlusYearly,
            subscriptionPremiumMonthly,
            subscriptionPremiumYearly
        ]
    }

    static var allConsumables: [String] {
        return [
            boost1Hour,
            boost3Hours,
            boost24Hours,
            spotlightWeekend
        ]
    }

    static var allProducts: [String] {
        return allSubscriptions + allConsumables
    }
}

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable {
    case none = "none"
    case basic = "basic"
    case plus = "plus"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .none:
            return "Free"
        case .basic:
            return "Basic"
        case .plus:
            return "Plus"
        case .premium:
            return "Premium"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "person"
        case .basic:
            return "star"
        case .plus:
            return "star.fill"
        case .premium:
            return "crown.fill"
        }
    }

    var color: String {
        switch self {
        case .none:
            return "gray"
        case .basic:
            return "blue"
        case .plus:
            return "purple"
        case .premium:
            return "gold"
        }
    }

    var features: [SubscriptionFeature] {
        switch self {
        case .none:
            return [
                .unlimitedMatches(false),
                .unlimitedLikes(false),
                .seeWhoLikesYou(false),
                .boosts(0),
                .advancedFilters(false),
                .readReceipts(false),
                .priorityLikes(false),
                .noAds(false),
                .profileBoost(false)
            ]
        case .basic:
            return [
                .unlimitedMatches(true),
                .unlimitedLikes(true),
                .seeWhoLikesYou(false),
                .boosts(1),
                .advancedFilters(true),
                .readReceipts(false),
                .priorityLikes(false),
                .noAds(false),
                .profileBoost(false)
            ]
        case .plus:
            return [
                .unlimitedMatches(true),
                .unlimitedLikes(true),
                .seeWhoLikesYou(true),
                .boosts(5),
                .advancedFilters(true),
                .readReceipts(true),
                .priorityLikes(true),
                .noAds(true),
                .profileBoost(false)
            ]
        case .premium:
            return [
                .unlimitedMatches(true),
                .unlimitedLikes(true),
                .seeWhoLikesYou(true),
                .boosts(10),
                .advancedFilters(true),
                .readReceipts(true),
                .priorityLikes(true),
                .noAds(true),
                .profileBoost(true)
            ]
        }
    }

    var monthlyPrice: String {
        switch self {
        case .none:
            return "$0"
        case .basic:
            return "$9.99"
        case .plus:
            return "$19.99"
        case .premium:
            return "$29.99"
        }
    }

    var yearlyPrice: String {
        switch self {
        case .none:
            return "$0"
        case .basic:
            return "$99.99"
        case .plus:
            return "$199.99"
        case .premium:
            return "$299.99"
        }
    }
}

// MARK: - Subscription Feature

enum SubscriptionFeature: Equatable {
    case unlimitedMatches(Bool)
    case unlimitedLikes(Bool)
    case seeWhoLikesYou(Bool)
    case boosts(Int)
    case advancedFilters(Bool)
    case readReceipts(Bool)
    case priorityLikes(Bool)
    case noAds(Bool)
    case profileBoost(Bool)

    var displayName: String {
        switch self {
        case .unlimitedMatches(let enabled):
            return enabled ? "Unlimited Matches" : "Limited Matches"
        case .unlimitedLikes(let enabled):
            return enabled ? "Unlimited Likes" : "10 Likes per day"
        case .seeWhoLikesYou(let enabled):
            return enabled ? "See Who Likes You" : "Hidden Likes"
        case .boosts(let count):
            return count > 0 ? "\(count) Boost\(count == 1 ? "" : "s") per month" : "No Boosts"
        case .advancedFilters(let enabled):
            return enabled ? "Advanced Filters" : "Basic Filters"
        case .readReceipts(let enabled):
            return enabled ? "Read Receipts" : "No Read Receipts"
        case .priorityLikes(let enabled):
            return enabled ? "Priority Likes" : "Standard Queue"
        case .noAds(let enabled):
            return enabled ? "Ad-Free Experience" : "Includes Ads"
        case .profileBoost(let enabled):
            return enabled ? "Profile Boost" : "Standard Visibility"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedMatches:
            return "infinity"
        case .unlimitedLikes:
            return "heart.fill"
        case .seeWhoLikesYou:
            return "heart.circle.fill"
        case .boosts:
            return "flame.fill"
        case .advancedFilters:
            return "slider.horizontal.3"
        case .readReceipts:
            return "checkmark.circle.fill"
        case .priorityLikes:
            return "arrow.up.circle.fill"
        case .noAds:
            return "eye.slash.fill"
        case .profileBoost:
            return "bolt.fill"
        }
    }

    var isEnabled: Bool {
        switch self {
        case .unlimitedMatches(let enabled),
             .unlimitedLikes(let enabled),
             .seeWhoLikesYou(let enabled),
             .advancedFilters(let enabled),
             .readReceipts(let enabled),
             .priorityLikes(let enabled),
             .noAds(let enabled),
             .profileBoost(let enabled):
            return enabled
        case .boosts(let count):
            return count > 0
        }
    }
}

// MARK: - Billing Period

enum BillingPeriod: String, Codable {
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }

    var savingsPercentage: Int {
        switch self {
        case .monthly:
            return 0
        case .yearly:
            return 20 // 20% savings on yearly
        }
    }
}

// MARK: - Product Type

enum ProductType {
    case subscription(SubscriptionTier, BillingPeriod)
    case consumable(ConsumableType)

    var displayName: String {
        switch self {
        case .subscription(let tier, let period):
            return "\(tier.displayName) - \(period.displayName)"
        case .consumable(let type):
            return type.displayName
        }
    }
}

// MARK: - Consumable Type

enum ConsumableType: String, Codable {
    case boost = "boost"
    case spotlight = "spotlight"

    var displayName: String {
        switch self {
        case .boost:
            return "Profile Boost"
        case .spotlight:
            return "Spotlight"
        }
    }

    var icon: String {
        switch self {
        case .boost:
            return "flame.fill"
        case .spotlight:
            return "sparkles"
        }
    }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success(Transaction)
    case pending
    case cancelled
    case failed(Error)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

// MARK: - Subscription Status

struct SubscriptionStatus: Codable {
    var tier: SubscriptionTier
    var period: BillingPeriod?
    var isActive: Bool
    var expirationDate: Date?
    var renewalDate: Date?
    var isInGracePeriod: Bool
    var isBillingRetry: Bool
    var autoRenewEnabled: Bool

    var daysRemaining: Int? {
        guard let expirationDate = expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
        return max(0, days ?? 0)
    }

    var isExpiringSoon: Bool {
        guard let days = daysRemaining else { return false }
        return days <= 7
    }

    static var free: SubscriptionStatus {
        return SubscriptionStatus(
            tier: .none,
            period: nil,
            isActive: false,
            expirationDate: nil,
            renewalDate: nil,
            isInGracePeriod: false,
            isBillingRetry: false,
            autoRenewEnabled: false
        )
    }
}

// MARK: - Consumable Balance

struct ConsumableBalance: Codable {
    var boosts: Int = 0
    var spotlights: Int = 0

    mutating func add(_ type: ConsumableType, amount: Int) {
        switch type {
        case .boost:
            boosts += amount
        case .spotlight:
            spotlights += amount
        }
    }

    mutating func use(_ type: ConsumableType, amount: Int = 1) -> Bool {
        switch type {
        case .boost:
            guard boosts >= amount else { return false }
            boosts -= amount
            return true
        case .spotlight:
            guard spotlights >= amount else { return false }
            spotlights -= amount
            return true
        }
    }

    func balance(for type: ConsumableType) -> Int {
        switch type {
        case .boost:
            return boosts
        case .spotlight:
            return spotlights
        }
    }
}

// MARK: - Promo Code

struct PromoCode: Codable {
    let code: String
    let discount: Int // Percentage (0-100)
    let tier: SubscriptionTier?
    let expirationDate: Date?
    var isUsed: Bool

    var isValid: Bool {
        guard !isUsed else { return false }

        if let expiration = expirationDate {
            return Date() < expiration
        }

        return true
    }
}

// MARK: - Purchase History Entry

struct PurchaseHistoryEntry: Codable, Identifiable {
    let id: String
    let productId: String
    let productName: String
    let price: String
    let purchaseDate: Date
    let transactionId: String
    let isRestored: Bool

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: purchaseDate)
    }
}

// MARK: - Store Error

enum StoreError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case verificationFailed
    case networkError
    case invalidPromoCode
    case subscriptionNotFound
    case restorationFailed
    case receiptValidationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in the App Store"
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .verificationFailed:
            return "Unable to verify purchase"
        case .networkError:
            return "Network error. Please check your connection."
        case .invalidPromoCode:
            return "Invalid or expired promo code"
        case .subscriptionNotFound:
            return "No active subscription found"
        case .restorationFailed:
            return "Unable to restore purchases"
        case .receiptValidationFailed:
            return "Receipt validation failed"
        }
    }
}

// MARK: - Premium Plan (Legacy)

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
        case .sixMonth: return "$15.00"
        case .annual: return "$10.00"
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
        case .sixMonth: return "$89.99 total"
        case .annual: return "$119.99 total"
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
        // Must match ProductIdentifiers for StoreManager to find products
        case .monthly: return ProductIdentifiers.subscriptionPremiumMonthly
        case .sixMonth: return ProductIdentifiers.subscriptionPlusYearly // Map to Plus yearly as closest equivalent
        case .annual: return ProductIdentifiers.subscriptionPremiumYearly
        }
    }
}
