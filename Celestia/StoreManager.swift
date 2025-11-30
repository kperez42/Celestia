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

    // Retry configuration
    private let maxRetryAttempts = 5
    private let initialRetryDelay: TimeInterval = 2.0 // 2 seconds
    private let maxRetryDelay: TimeInterval = 60.0 // 60 seconds

    // Track failed transactions for retry
    private var failedTransactions: Set<UInt64> = []

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
        return Task { @MainActor in
            // Iterate through any transactions that don't come from a direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Process transaction with retry logic
                    await self.processTransactionWithRetry(transaction)

                } catch {
                    await MainActor.run {
                        Logger.shared.error("Transaction verification failed: \(error.localizedDescription)", category: .general)

                        // Track verification failures
                        AnalyticsManager.shared.logEvent(.validationError, parameters: [
                            "type": "transaction_verification",
                            "error": error.localizedDescription
                        ])
                    }
                }
            }
        }
    }

    // MARK: - Transaction Processing with Retry

    /// Process a transaction with exponential backoff retry mechanism
    private func processTransactionWithRetry(_ transaction: Transaction) async {
        let transactionId = transaction.id

        // Check if we've already tried processing this transaction too many times
        if failedTransactions.contains(transactionId) {
            Logger.shared.warning("Transaction \(transactionId) exceeded max retry attempts - skipping", category: .general)
            return
        }

        var lastError: Error?
        var attempt = 0

        // Retry loop with exponential backoff
        while attempt < maxRetryAttempts {
            do {
                // Deliver content
                await self.deliverContent(for: transaction)

                // Finish the transaction
                await transaction.finish()

                // Update purchased products
                await self.updatePurchasedProducts()

                // Success! Remove from failed transactions if it was there
                failedTransactions.remove(transactionId)

                Logger.shared.info("Transaction \(transactionId) processed successfully (attempt \(attempt + 1))", category: .general)

                // Track successful processing after retries
                if attempt > 0 {
                    AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                        "feature": "transaction_retry",
                        "action": "succeeded",
                        "transaction_id": String(transactionId),
                        "product_id": transaction.productID,
                        "attempts": attempt + 1
                    ])
                }

                return // Success - exit retry loop

            } catch {
                lastError = error
                attempt += 1

                Logger.shared.warning("Transaction \(transactionId) processing failed (attempt \(attempt)/\(maxRetryAttempts)): \(error.localizedDescription)", category: .general)

                // Check if error is retryable
                guard isRetryableError(error) && attempt < maxRetryAttempts else {
                    break // Non-retryable error or max attempts reached
                }

                // Calculate exponential backoff delay: 2s, 4s, 8s, 16s, 32s (capped at 60s)
                let delay = min(initialRetryDelay * pow(2.0, Double(attempt - 1)), maxRetryDelay)

                Logger.shared.info("Retrying transaction \(transactionId) in \(delay) seconds...", category: .general)

                // Wait before retry
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Check if task was cancelled during sleep
                if Task.isCancelled {
                    Logger.shared.info("Transaction processing cancelled during retry", category: .general)
                    return
                }
            }
        }

        // All retry attempts failed
        failedTransactions.insert(transactionId)

        await MainActor.run {
            Logger.shared.error("Transaction \(transactionId) failed after \(attempt) attempts: \(lastError?.localizedDescription ?? "unknown error")", category: .general)

            // Track final failure
            AnalyticsManager.shared.logEvent(.purchaseFailed, parameters: [
                "type": "transaction_processing",
                "transaction_id": String(transactionId),
                "product_id": transaction.productID,
                "attempts": attempt,
                "error": lastError?.localizedDescription ?? "unknown"
            ])

            // CRITICAL: Alert monitoring system about potential revenue loss
            // In production, this should trigger an alert to the operations team
            Logger.shared.critical("REVENUE ALERT: Failed to process transaction \(transactionId) for product \(transaction.productID) after \(attempt) attempts", category: .general)
        }
    }

    // MARK: - Error Classification

    /// Determine if an error is transient and retryable
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .resourceUnavailable,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }

        // Store errors
        if let storeError = error as? StoreError {
            switch storeError {
            case .networkError:
                return true
            case .verificationFailed, .receiptValidationFailed:
                // These might be transient issues with Apple's servers
                return true
            case .productNotFound, .invalidPromoCode, .subscriptionNotFound:
                // These are permanent errors
                return false
            default:
                // Be conservative - retry other store errors
                return true
            }
        }

        // Check error domain for common transient errors
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return true
        case "SKErrorDomain":
            // StoreKit errors - some are retryable
            switch nsError.code {
            case 0: // SKError.unknown
                return true
            case 1: // SKError.clientInvalid
                return false
            case 2: // SKError.paymentCancelled
                return false
            case 3: // SKError.paymentInvalid
                return true
            case 4: // SKError.paymentNotAllowed
                return false
            case 5: // SKError.storeProductNotAvailable
                return true
            default:
                return true // Be conservative
            }
        default:
            // Unknown error - attempt retry to be safe
            return true
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
        else if productID.contains("boost") {
            return .consumable(.boost)
        } else if productID.contains("spotlight") {
            return .consumable(.spotlight)
        }

        return nil
    }

    /// Get consumable amount from product ID
    private func getConsumableAmount(for productID: String) -> Int {
        if productID == ProductIdentifiers.boost1Hour {
            return 1
        } else if productID == ProductIdentifiers.boost3Hours {
            return 1
        } else if productID == ProductIdentifiers.boost24Hours {
            return 1
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

    // MARK: - Device Fingerprinting & Security

    /// Generate device fingerprint for fraud detection
    /// This helps identify suspicious patterns like multiple accounts from same device
    func generateDeviceFingerprint() -> [String: Any] {
        var deviceInfo: [String: Any] = [:]

        // Device model
        deviceInfo["deviceModel"] = UIDevice.current.model

        // OS version
        deviceInfo["osVersion"] = UIDevice.current.systemVersion

        // App version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            deviceInfo["appVersion"] = appVersion
        }

        // Locale
        deviceInfo["locale"] = Locale.current.identifier

        // Timezone
        deviceInfo["timezone"] = TimeZone.current.identifier

        // Vendor ID (stays same across app installs for same vendor)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            deviceInfo["vendorId"] = vendorId
        }

        // Screen size (helps identify device spoofing)
        let screenBounds = UIScreen.main.bounds
        deviceInfo["screenWidth"] = Int(screenBounds.width)
        deviceInfo["screenHeight"] = Int(screenBounds.height)

        // Device name hash (privacy-preserving)
        let deviceName = UIDevice.current.name
        if let hash = deviceName.data(using: .utf8)?.base64EncodedString() {
            deviceInfo["deviceNameHash"] = String(hash.prefix(16)) // Truncated for privacy
        }

        return deviceInfo
    }

    /// Detect potential jailbreak indicators (basic detection)
    /// Note: Advanced jailbreak detection is done server-side
    func detectJailbreakIndicators() -> [String: Any] {
        var indicators: [String: Any] = [:]
        var suspiciousPaths: [String] = []
        var riskFlags: [String] = []

        // Check for common jailbreak files/paths
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/Applications/Sileo.app",
            "/usr/bin/ssh",
            "/usr/libexec/sftp-server"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                suspiciousPaths.append(path)
            }
        }

        // Check if can write to system directories (jailbreak indicator)
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            riskFlags.append("can_write_to_system")
        } catch {
            // Good - cannot write (not jailbroken)
        }

        // Check if Cydia URL scheme can be opened
        if let cydiaURL = URL(string: "cydia://") {
            if UIApplication.shared.canOpenURL(cydiaURL) {
                riskFlags.append("can_open_cydia")
            }
        }

        // Check for suspicious URL schemes
        let suspiciousSchemes = ["cydia://", "sileo://", "zbra://", "installer://"]
        var openableSchemes: [String] = []

        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                openableSchemes.append(scheme)
            }
        }

        // Check if running on simulator (not jailbreak, but useful info)
        #if targetEnvironment(simulator)
        riskFlags.append("simulator")
        #endif

        // Compile results
        indicators["suspiciousPaths"] = suspiciousPaths
        indicators["riskFlags"] = riskFlags
        indicators["openableSchemes"] = openableSchemes
        indicators["isJailbroken"] = !suspiciousPaths.isEmpty || !riskFlags.isEmpty

        return indicators
    }

    /// Get comprehensive device security info for backend validation
    func getDeviceSecurityInfo() -> [String: Any] {
        var securityInfo: [String: Any] = [:]

        // Device fingerprint
        securityInfo["fingerprint"] = generateDeviceFingerprint()

        // Jailbreak detection
        securityInfo["jailbreakIndicators"] = detectJailbreakIndicators()

        // Additional security metadata
        securityInfo["timestamp"] = Date().timeIntervalSince1970

        return securityInfo
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
// Note: Product already has displayPrice, displayName, and description properties
// in StoreKit 2, so no extension is needed
