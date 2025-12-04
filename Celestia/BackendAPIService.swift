//
//  BackendAPIService.swift
//  Celestia
//
//  Backend API service for server-side validation and operations
//  SECURITY: All critical operations should be validated server-side
//

import Foundation
import StoreKit
import FirebaseFirestore

// MARK: - Response Cache

@MainActor
class ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize = 50
    private let defaultCacheDuration: TimeInterval = 300 // 5 minutes

    struct CachedResponse {
        let data: Data
        let timestamp: Date
        let duration: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > duration
        }
    }

    func get(for key: String) -> Data? {
        guard let cached = cache[key], !cached.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        Logger.shared.debug("📦 Cache hit: \(key)", category: .networking)
        return cached.data
    }

    func set(_ data: Data, for key: String, duration: TimeInterval? = nil) {
        // Limit cache size
        if cache.count >= maxCacheSize {
            // Remove oldest entry
            if let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                cache.removeValue(forKey: oldestKey)
            }
        }

        cache[key] = CachedResponse(
            data: data,
            timestamp: Date(),
            duration: duration ?? defaultCacheDuration
        )

        Logger.shared.debug("💾 Cached response: \(key)", category: .networking)
    }

    func clear() {
        cache.removeAll()
        Logger.shared.info("🗑️ Response cache cleared", category: .networking)
    }

    func clearExpired() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { cache.removeValue(forKey: $0) }

        if !expiredKeys.isEmpty {
            Logger.shared.debug("🗑️ Cleared \(expiredKeys.count) expired cache entries", category: .networking)
        }
    }
}

// MARK: - Backend API Service Protocol

protocol BackendAPIServiceProtocol {
    func validateReceipt(_ transaction: StoreKit.Transaction, userId: String) async throws -> ReceiptValidationResponse
    func validateContent(_ content: String, type: ContentType) async throws -> ContentValidationResponse
    func checkRateLimit(userId: String, action: RateLimitAction) async throws -> RateLimitResponse
    func reportContent(reporterId: String, reportedId: String, reason: String, details: String?) async throws
}

// MARK: - Backend API Service

@MainActor
class BackendAPIService: BackendAPIServiceProtocol {

    static let shared = BackendAPIService()

    private let baseURL: String
    private let session: URLSession
    private var requestInterceptors: [RequestInterceptor] = []
    private var responseInterceptors: [ResponseInterceptor] = []
    private let responseCache: ResponseCache = ResponseCache()

    // MARK: - Configuration

    enum Configuration {
        // DISABLED: Backend API not deployed yet - use client-side fallbacks
        // Set to true when api.celestia.app is available
        static let isEnabled = false

        #if DEBUG
        static let useLocalServer = false // Set to true for local development
        static let localServerURL = "http://localhost:3000/api"
        #endif
    }

    private init() {
        // Use production API URL from Constants
        self.baseURL = AppConstants.API.baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConstants.API.timeout
        config.timeoutIntervalForResource = AppConstants.API.timeout * 2
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        // Register default interceptors
        #if DEBUG
        registerInterceptor(LoggingInterceptor())
        #endif
        registerInterceptor(AnalyticsInterceptor())

        Logger.shared.info("BackendAPIService initialized with URL: \(baseURL)", category: .networking)
    }

    // MARK: - Interceptor Management

    func registerInterceptor<T: RequestInterceptor & ResponseInterceptor>(_ interceptor: T) {
        requestInterceptors.append(interceptor)
        responseInterceptors.append(interceptor)
        Logger.shared.debug("Registered interceptor: \(type(of: interceptor))", category: .networking)
    }

    // MARK: - Receipt Validation

    /// Validate StoreKit transaction with backend server
    /// CRITICAL: This prevents fraud by verifying purchases server-side
    func validateReceipt(_ transaction: StoreKit.Transaction, userId: String) async throws -> ReceiptValidationResponse {
        Logger.shared.info("Validating receipt server-side for transaction: \(transaction.id)", category: .payment)

        // Prepare request payload
        let payload: [String: Any] = [
            "transaction_id": String(transaction.id),
            "product_id": transaction.productID,
            "purchase_date": ISO8601DateFormatter().string(from: transaction.purchaseDate),
            "user_id": userId,
            "original_transaction_id": transaction.originalID,
            "environment": transaction.environment.rawValue
        ]

        // Make API request
        let endpoint = "/v1/purchases/validate"
        let response: ReceiptValidationResponse = try await post(endpoint: endpoint, body: payload)

        Logger.shared.info("Receipt validation response: \(response.isValid ? "VALID" : "INVALID")", category: .payment)

        if !response.isValid {
            Logger.shared.error("Receipt validation failed: \(response.reason ?? "unknown")", category: .payment)
            throw StoreError.receiptValidationFailed
        }

        return response
    }

    // MARK: - Content Validation

    /// Validate content with server-side moderation
    /// SECURITY: Server-side validation can't be bypassed like client-side
    func validateContent(_ content: String, type: ContentType) async throws -> ContentValidationResponse {
        // Return immediately if backend is disabled - use client-side validation
        guard Configuration.isEnabled else {
            return ContentValidationResponse(isAppropriate: true, violations: [], severity: .none, filteredContent: nil)
        }

        Logger.shared.info("Validating content server-side, type: \(type.rawValue)", category: .moderation)

        let payload: [String: Any] = [
            "content": content,
            "type": type.rawValue
        ]

        let endpoint = "/v1/moderation/validate"
        let response: ContentValidationResponse = try await post(endpoint: endpoint, body: payload)

        if !response.isAppropriate {
            Logger.shared.warning("Content flagged: \(response.violations.joined(separator: ", "))", category: .moderation)
        }

        return response
    }

    // MARK: - Rate Limiting

    /// Check rate limit with backend
    /// SECURITY: Server-side rate limiting prevents client bypass
    func checkRateLimit(userId: String, action: RateLimitAction) async throws -> RateLimitResponse {
        // Return immediately if backend is disabled - use client-side rate limiting
        guard Configuration.isEnabled else {
            return RateLimitResponse(allowed: true, remaining: 999, resetAt: nil, retryAfter: nil)
        }

        let payload: [String: Any] = [
            "user_id": userId,
            "action": action.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let endpoint = "/v1/rate-limit/check"
        let response: RateLimitResponse = try await post(endpoint: endpoint, body: payload)

        if !response.allowed {
            Logger.shared.warning("Rate limit exceeded for action: \(action.rawValue)", category: .moderation)
        }

        return response
    }

    // MARK: - Reporting

    /// Report content or user to backend
    func reportContent(reporterId: String, reportedId: String, reason: String, details: String?) async throws {
        let payload: [String: Any] = [
            "reporter_id": reporterId,
            "reported_id": reportedId,
            "reason": reason,
            "details": details ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let endpoint = "/v1/reports/create"
        let _: EmptyResponse = try await post(endpoint: endpoint, body: payload)

        Logger.shared.info("Report submitted successfully", category: .moderation)
    }

    // MARK: - Push Notifications

    /// Send push notification via backend
    func sendPushNotification<T: Encodable>(_ notification: T) async throws {
        let payload: [String: Any]

        // Convert Encodable to dictionary
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(notification)
        payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let endpoint = "/v1/notifications/send"
        let _: EmptyResponse = try await post(endpoint: endpoint, body: payload)

        Logger.shared.debug("Push notification sent via backend", category: .general)
    }

    /// Update push notification tokens for a user
    func updatePushTokens(userId: String, apnsToken: String?, fcmToken: String?) async throws {
        Logger.shared.info("Updating push tokens for user: \(userId)", category: .general)

        // Save directly to Firestore (required for Cloud Function notifications)
        var firestoreData: [String: Any] = [
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
        ]
        if let fcmToken = fcmToken {
            firestoreData["fcmToken"] = fcmToken
        }
        if let apnsToken = apnsToken {
            firestoreData["apnsToken"] = apnsToken
        }

        do {
            try await Firestore.firestore().collection("users").document(userId).updateData(firestoreData)
            Logger.shared.info("FCM token saved to Firestore", category: .general)
        } catch {
            Logger.shared.error("Failed to save FCM token to Firestore", category: .general, error: error)
        }

        // Also send to backend API (for other purposes)
        var payload: [String: Any] = [
            "user_id": userId,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let apnsToken = apnsToken {
            payload["apns_token"] = apnsToken
        }

        if let fcmToken = fcmToken {
            payload["fcm_token"] = fcmToken
        }

        do {
            let endpoint = "/v1/users/push-tokens"
            let _: EmptyResponse = try await post(endpoint: endpoint, body: payload)
            Logger.shared.debug("Push tokens updated successfully", category: .general)
        } catch {
            // Backend API might not be available - that's OK, we saved to Firestore
            Logger.shared.warning("Backend API for push tokens failed (Firestore save succeeded)", category: .general)
        }
    }

    // MARK: - Generic HTTP Methods

    private func post<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw BackendAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication header
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request with retry logic
        return try await performRequestWithRetry(request: request)
    }

    private func performRequestWithRetry<T: Decodable>(request: URLRequest, attempt: Int = 1, useCache: Bool = false) async throws -> T {
        var mutableRequest = request

        // Generate cache key from request
        let cacheKey = generateCacheKey(from: request)

        // Check cache if enabled
        if useCache, let cachedData = responseCache.get(for: cacheKey) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: cachedData)
        }

        // Apply request interceptors
        for interceptor in requestInterceptors {
            try await interceptor.intercept(request: &mutableRequest)
        }

        do {
            let (responseData, response) = try await session.data(for: mutableRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendAPIError.invalidResponse
            }

            // Apply response interceptors
            var processedData = responseData
            for interceptor in responseInterceptors {
                processedData = try await interceptor.intercept(data: processedData, response: response)
            }

            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Cache successful responses if caching is enabled
                if useCache {
                    responseCache.set(processedData, for: cacheKey)
                }

                // Success - decode response
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: processedData)

            case 401:
                throw BackendAPIError.unauthorized

            case 429:
                throw BackendAPIError.rateLimitExceeded

            case 500...599:
                // Server error - retry if we haven't exceeded max attempts
                if attempt < AppConstants.API.retryAttempts {
                    Logger.shared.warning("Server error (attempt \(attempt)/\(AppConstants.API.retryAttempts)), retrying...", category: .networking)
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)) // Exponential backoff
                    return try await performRequestWithRetry(request: request, attempt: attempt + 1, useCache: useCache)
                }
                throw BackendAPIError.serverError(httpResponse.statusCode)

            default:
                throw BackendAPIError.httpError(httpResponse.statusCode)
            }

        } catch let error as BackendAPIError {
            throw error
        } catch {
            // Check if this is a TLS/SSL error
            let nsError = error as NSError
            let isTLSError = nsError.domain == NSURLErrorDomain &&
                            (nsError.code == NSURLErrorSecureConnectionFailed ||
                             nsError.code == NSURLErrorServerCertificateUntrusted ||
                             nsError.code == NSURLErrorClientCertificateRejected ||
                             nsError.code == -1200) // Generic SSL error

            if isTLSError {
                // Log detailed TLS error information
                Logger.shared.error("TLS/SSL connection error to backend API - domain: \(nsError.domain), code: \(nsError.code), url: \(request.url?.absoluteString ?? "unknown")", category: .networking)

                // For TLS errors, don't retry as it's likely a server-side certificate issue
                // Log analytics for monitoring
                Task { @MainActor in
                    AnalyticsManager.shared.logEvent(.validationError, parameters: [
                        "type": "tls_failure",
                        "error_code": nsError.code,
                        "endpoint": request.url?.path ?? "unknown",
                        "attempt": attempt
                    ])
                }

                // Throw immediately without retry for TLS errors
                throw BackendAPIError.tlsError(nsError)
            }

            // Network error - retry if we haven't exceeded max attempts
            if attempt < AppConstants.API.retryAttempts {
                Logger.shared.warning("Network error (attempt \(attempt)/\(AppConstants.API.retryAttempts)), retrying...", category: .networking)
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                return try await performRequestWithRetry(request: request, attempt: attempt + 1, useCache: useCache)
            }
            throw BackendAPIError.networkError(error)
        }
    }

    private func generateCacheKey(from request: URLRequest) -> String {
        var key = request.url?.absoluteString ?? ""
        key += "-\(request.httpMethod ?? "GET")"

        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            key += "-\(bodyString.hashValue)"
        }

        return key
    }

    // MARK: - Authentication

    private func getAuthToken() async -> String? {
        // Get Firebase ID token for backend authentication
        do {
            let user = AuthService.shared.userSession
            let token = try await user?.getIDToken()
            return token
        } catch {
            Logger.shared.error("Failed to get auth token: \(error)", category: .authentication)
            return nil
        }
    }
}

// MARK: - Response Models

struct ReceiptValidationResponse: Codable {
    let isValid: Bool
    let transactionId: String
    let productId: String
    let subscriptionTier: String?
    let expirationDate: Date?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case transactionId = "transaction_id"
        case productId = "product_id"
        case subscriptionTier = "subscription_tier"
        case expirationDate = "expiration_date"
        case reason
    }
}

struct ContentValidationResponse: Codable {
    let isAppropriate: Bool
    let violations: [String]
    let severity: ContentSeverity
    let filteredContent: String?

    enum CodingKeys: String, CodingKey {
        case isAppropriate = "is_appropriate"
        case violations
        case severity
        case filteredContent = "filtered_content"
    }
}

struct RateLimitResponse: Codable {
    let allowed: Bool
    let remaining: Int
    let resetAt: Date?
    let retryAfter: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case allowed
        case remaining
        case resetAt = "reset_at"
        case retryAfter = "retry_after"
    }
}

struct EmptyResponse: Codable {}

// MARK: - Enums

enum ContentType: String, Codable {
    case message = "message"
    case bio = "bio"
    case interestMessage = "interest_message"
    case username = "username"
}

enum ContentSeverity: String, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum RateLimitAction: String, Codable {
    case sendMessage = "send_message"
    case sendLike = "send_like"
    case sendSuperLike = "send_super_like"
    case swipe = "swipe"
    case updateProfile = "update_profile"
    case uploadPhoto = "upload_photo"
    case report = "report"
}

// MARK: - Errors

enum BackendAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case serverError(Int)
    case httpError(Int)
    case networkError(Error)
    case tlsError(NSError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .rateLimitExceeded:
            return "Rate limit exceeded - please try again later"
        case .serverError(let code):
            return "Server error (\(code)) - please try again"
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .tlsError(let error):
            return "Secure connection failed (TLS/SSL error \(error.code)). The backend server may have a certificate configuration issue."
        }
    }
}
