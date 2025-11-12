//
//  BackendAPIService.swift
//  Celestia
//
//  Backend API service for server-side validation and operations
//  SECURITY: All critical operations should be validated server-side
//

import Foundation
import StoreKit

// MARK: - Backend API Service Protocol

protocol BackendAPIServiceProtocol {
    func validateReceipt(_ transaction: Transaction, userId: String) async throws -> ReceiptValidationResponse
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

    // MARK: - Configuration

    enum Configuration {
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

        Logger.shared.info("BackendAPIService initialized with URL: \(baseURL)", category: .network)
    }

    // MARK: - Receipt Validation

    /// Validate StoreKit transaction with backend server
    /// CRITICAL: This prevents fraud by verifying purchases server-side
    func validateReceipt(_ transaction: Transaction, userId: String) async throws -> ReceiptValidationResponse {
        Logger.shared.info("Validating receipt server-side for transaction: \(transaction.id)", category: .purchase)

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

        Logger.shared.info("Receipt validation response: \(response.isValid ? "VALID" : "INVALID")", category: .purchase)

        if !response.isValid {
            Logger.shared.error("Receipt validation failed: \(response.reason ?? "unknown")", category: .purchase)
            throw StoreError.receiptValidationFailed
        }

        return response
    }

    // MARK: - Content Validation

    /// Validate content with server-side moderation
    /// SECURITY: Server-side validation can't be bypassed like client-side
    func validateContent(_ content: String, type: ContentType) async throws -> ContentValidationResponse {
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
        let payload: [String: Any] = [
            "user_id": userId,
            "action": action.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let endpoint = "/v1/rate-limit/check"
        let response: RateLimitResponse = try await post(endpoint: endpoint, body: payload)

        if !response.allowed {
            Logger.shared.warning("Rate limit exceeded for action: \(action.rawValue)", category: .security)
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

        Logger.shared.info("Report submitted successfully", category: .security)
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

    private func performRequestWithRetry<T: Decodable>(request: URLRequest, attempt: Int = 1) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendAPIError.invalidResponse
            }

            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)

            case 401:
                throw BackendAPIError.unauthorized

            case 429:
                throw BackendAPIError.rateLimitExceeded

            case 500...599:
                // Server error - retry if we haven't exceeded max attempts
                if attempt < AppConstants.API.retryAttempts {
                    Logger.shared.warning("Server error (attempt \(attempt)/\(AppConstants.API.retryAttempts)), retrying...", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)) // Exponential backoff
                    return try await performRequestWithRetry(request: request, attempt: attempt + 1)
                }
                throw BackendAPIError.serverError(httpResponse.statusCode)

            default:
                throw BackendAPIError.httpError(httpResponse.statusCode)
            }

        } catch let error as BackendAPIError {
            throw error
        } catch {
            // Network error - retry if we haven't exceeded max attempts
            if attempt < AppConstants.API.retryAttempts {
                Logger.shared.warning("Network error (attempt \(attempt)/\(AppConstants.API.retryAttempts)), retrying...", category: .network)
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                return try await performRequestWithRetry(request: request, attempt: attempt + 1)
            }
            throw BackendAPIError.networkError(error)
        }
    }

    // MARK: - Authentication

    private func getAuthToken() async -> String? {
        // Get Firebase ID token for backend authentication
        do {
            let user = AuthService.shared.userSession
            let token = try await user?.getIDToken()
            return token
        } catch {
            Logger.shared.error("Failed to get auth token: \(error)", category: .auth)
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
        }
    }
}
