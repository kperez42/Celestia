//
//  RetryManager.swift
//  Celestia
//
//  Retry logic with exponential backoff for failed operations
//

import Foundation

@MainActor
class RetryManager {
    static let shared = RetryManager()

    private init() {}

    // MARK: - Retry Configuration

    struct RetryConfig {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double

        static let `default` = RetryConfig(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0
        )

        static let aggressive = RetryConfig(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 15.0,
            multiplier: 2.0
        )

        static let conservative = RetryConfig(
            maxAttempts: 3,  // Increased from 2 - WiFi can have momentary issues
            initialDelay: 1.0,  // Reduced initial delay for faster retry
            maxDelay: 10.0,  // Increased max delay
            multiplier: 2.0
        )
    }

    // MARK: - Retry Methods

    /// Retry an async operation with exponential backoff
    func retry<T>(
        config: RetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var currentDelay = config.initialDelay
        var lastError: Error?

        for attempt in 1...config.maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    Logger.shared.info("Operation succeeded on attempt \(attempt)", category: .networking)
                }
                return result
            } catch {
                lastError = error

                // Log error details for debugging
                let nsError = error as NSError
                Logger.shared.warning("🔄 Retry: Attempt \(attempt) failed - domain: \(nsError.domain), code: \(nsError.code)", category: .networking)

                // Check if error is retryable
                let retryable = isRetryable(error: error)
                if !retryable {
                    Logger.shared.error("🔄 Retry: Error is NOT retryable - throwing immediately", category: .networking, error: error)
                    throw error
                }

                // If this was the last attempt, throw the error
                if attempt == config.maxAttempts {
                    Logger.shared.error("🔄 Retry: All \(config.maxAttempts) attempts exhausted", category: .networking, error: error)
                    throw error
                }

                // Calculate delay with jitter
                let jitter = Double.random(in: 0.8...1.2)
                let delay = min(currentDelay * jitter, config.maxDelay)

                Logger.shared.info("🔄 Retry: Error is retryable - waiting \(String(format: "%.1f", delay))s before attempt \(attempt + 1)...", category: .networking)

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Increase delay for next attempt
                currentDelay = min(currentDelay * config.multiplier, config.maxDelay)
            }
        }

        throw lastError ?? CelestiaError.unknown("All retry attempts failed")
    }

    /// Retry with a completion handler
    func retry<T>(
        config: RetryConfig = .default,
        operation: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await retry(config: config, operation: operation)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Error Analysis

    /// Determine if an error is retryable
    private func isRetryable(error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors that are retryable
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorResourceUnavailable,
                 NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted:
                Logger.shared.debug("🔄 isRetryable: NSURLError \(nsError.code) - YES (network issue)", category: .networking)
                return true
            case NSURLErrorNotConnectedToInternet:
                Logger.shared.debug("🔄 isRetryable: NSURLError \(nsError.code) - NO (no internet)", category: .networking)
                return false // Don't retry if there's no internet
            default:
                Logger.shared.debug("🔄 isRetryable: NSURLError \(nsError.code) - NO (unknown)", category: .networking)
                return false
            }
        }

        // Firebase Storage errors (domain varies by Firebase version)
        if nsError.domain == "FIRFirestoreErrorDomain" ||
           nsError.domain == "FIRStorageErrorDomain" ||
           nsError.domain.contains("Firebase") ||
           nsError.domain.contains("Storage") {
            switch nsError.code {
            case 14: // UNAVAILABLE
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - YES (unavailable)", category: .networking)
                return true
            case 4: // DEADLINE_EXCEEDED
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - YES (deadline exceeded)", category: .networking)
                return true
            case 10: // ABORTED
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - YES (aborted)", category: .networking)
                return true
            case 13: // INTERNAL
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - YES (internal error)", category: .networking)
                return true
            case -13000: // FIRStorageErrorCodeUnknown
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - YES (unknown storage error)", category: .networking)
                return true
            case -13010: // FIRStorageErrorCodeRetryLimitExceeded
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - NO (Firebase retry limit)", category: .networking)
                return false
            default:
                Logger.shared.debug("🔄 isRetryable: Firebase \(nsError.code) - NO (unhandled)", category: .networking)
                return false
            }
        }

        // HTTP errors
        if let httpError = error as? URLError {
            switch httpError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                Logger.shared.debug("🔄 isRetryable: URLError \(httpError.code) - YES", category: .networking)
                return true
            default:
                Logger.shared.debug("🔄 isRetryable: URLError \(httpError.code) - NO", category: .networking)
                return false
            }
        }

        Logger.shared.debug("🔄 isRetryable: Unknown error domain \(nsError.domain) - NO", category: .networking)
        return false
    }

    // MARK: - Convenience Methods

    /// Quick retry for network operations
    func retryNetworkOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retry(config: .aggressive, operation: operation)
    }

    /// Quick retry for database operations
    func retryDatabaseOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retry(config: .default, operation: operation)
    }

    /// Quick retry for upload operations
    func retryUploadOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retry(config: .conservative, operation: operation)
    }
}

// MARK: - Retryable Protocol

protocol Retryable {
    func performWithRetry<T>(
        config: RetryManager.RetryConfig,
        operation: @escaping () async throws -> T
    ) async throws -> T
}

extension Retryable {
    func performWithRetry<T>(
        config: RetryManager.RetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await RetryManager.shared.retry(config: config, operation: operation)
    }
}
