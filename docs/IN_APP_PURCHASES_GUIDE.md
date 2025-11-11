# In-App Purchases & Subscriptions - Complete Guide

## Overview

The Celestia In-App Purchase system provides comprehensive monetization through StoreKit 2, featuring 3-tier subscriptions, consumable purchases, receipt validation, and a beautiful paywall UI.

## Subscription Tiers

### Free Tier
- 5 Super Likes per day
- Limited matches
- Basic filters
- Includes ads

### Basic ($9.99/month, $99.99/year)
- Unlimited matches
- 10 Super Likes per day
- Unlimited rewinds
- 1 boost per month
- Advanced filters
- Save 17% with yearly

### Plus ($19.99/month, $199.99/year)
- All Basic features
- 25 Super Likes per day
- See Who Likes You
- 5 boosts per month
- Read receipts
- Priority likes
- Ad-free experience
- Save 17% with yearly

### Premium ($29.99/month, $299.99/year)
- All Plus features
- 100 Super Likes per day
- 10 boosts per month
- Profile boost
- Verified badge priority
- Save 17% with yearly

## Consumable Products

### Super Likes
- 5 Super Likes: $4.99
- 10 Super Likes: $8.99
- 25 Super Likes: $19.99

### Boosts
- 1 Hour Boost: $3.99
- 3 Hour Boost: $9.99
- 24 Hour Boost: $24.99

### Other
- 5 Rewinds: $4.99
- Weekend Spotlight: $14.99

## Integration

```swift
// Initialize
_ = StoreManager.shared
_ = SubscriptionManager.shared

// Purchase subscription
let product = storeManager.product(for: ProductIdentifiers.subscriptionPlusMonthly)
let result = try await storeManager.purchase(product)

// Check subscription status
if subscriptionManager.hasSubscription(.plus) {
    // User has Plus or higher
}

// Use consumable
if subscriptionManager.hasConsumable(.superLikes) {
    subscriptionManager.useConsumable(.superLikes)
}

// Restore purchases
try await storeManager.restorePurchases()
```

## Revenue Projections

### Conservative Estimates (10K users):
- 5% conversion to paid: 500 subscribers
- Average subscription: $15/month
- Monthly Revenue: $7,500
- Annual Revenue: $90,000

### Optimistic Estimates (10K users):
- 10% conversion: 1,000 subscribers
- Average: $18/month
- Monthly Revenue: $18,000
- Annual Revenue: $216,000

### With Consumables:
- Additional 20% revenue
- Total Annual: $108K - $259K

## Features

✅ StoreKit 2 integration
✅ 3-tier subscriptions
✅ Consumable purchases
✅ Receipt validation
✅ Restore purchases
✅ Promo code support
✅ Purchase history
✅ Analytics tracking

## Files Created

- StoreModels.swift (600 lines)
- StoreManager.swift (400 lines)
- SubscriptionManager.swift (350 lines)
- PaywallView.swift (300 lines)

Total: 4 files, ~1,650 lines

---

**Version:** 1.0.0
**Last Updated:** 2024
**License:** Proprietary - Celestia Dating App
