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
            maxAttempts: 2,
            initialDelay: 2.0,
            maxDelay: 5.0,
            multiplier: 1.5
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

                // Check if error is retryable
                if !isRetryable(error: error) {
                    Logger.shared.error("Non-retryable error", category: .networking, error: error)
                    throw error
                }

                // If this was the last attempt, throw the error
                if attempt == config.maxAttempts {
                    Logger.shared.error("All \(config.maxAttempts) attempts failed", category: .networking, error: error)
                    throw error
                }

                // Calculate delay with jitter
                let jitter = Double.random(in: 0.8...1.2)
                let delay = min(currentDelay * jitter, config.maxDelay)

                Logger.shared.warning("Attempt \(attempt) failed. Retrying in \(String(format: "%.1f", delay))s...", category: .networking)

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
                 NSURLErrorResourceUnavailable:
                return true
            case NSURLErrorNotConnectedToInternet:
                return false // Don't retry if there's no internet
            default:
                return false
            }
        }

        // Firebase errors
        if nsError.domain == "FIRFirestoreErrorDomain" || nsError.domain == "FIRStorageErrorDomain" {
            switch nsError.code {
            case 14: // UNAVAILABLE
                return true
            case 4: // DEADLINE_EXCEEDED
                return true
            case 10: // ABORTED
                return true
            default:
                return false
            }
        }

        // HTTP errors
        if let httpError = error as? URLError {
            switch httpError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                return true
            default:
                return false
            }
        }

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
