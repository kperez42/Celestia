//
//  SmartRetryManager.swift
//  Celestia
//
//  Smart retry logic with circuit breaker integration and exponential backoff
//  Provides intelligent retry strategies based on error type and service health
//

import Foundation

/// Retry strategy for different scenarios
enum RetryStrategy {
    case exponential        // Exponential backoff (default)
    case linear            // Linear backoff
    case fibonacci         // Fibonacci backoff
    case adaptive          // Adaptive based on error type

    func calculateDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        switch self {
        case .exponential:
            return baseDelay * pow(2.0, Double(attempt - 1))

        case .linear:
            return baseDelay * Double(attempt)

        case .fibonacci:
            let fib = fibonacci(attempt)
            return baseDelay * Double(fib)

        case .adaptive:
            // Adaptive strategy adjusts based on attempt
            if attempt <= 2 {
                return baseDelay
            } else if attempt <= 4 {
                return baseDelay * pow(1.5, Double(attempt - 2))
            } else {
                return baseDelay * pow(2.0, Double(attempt - 4))
            }
        }
    }

    private func fibonacci(_ n: Int) -> Int {
        if n <= 1 { return 1 }
        var a = 1, b = 1
        for _ in 2..<n {
            let temp = a + b
            a = b
            b = temp
        }
        return b
    }
}

/// Smart retry configuration
struct SmartRetryConfig {
    /// Maximum retry attempts
    let maxAttempts: Int

    /// Base delay before first retry (seconds)
    let baseDelay: TimeInterval

    /// Maximum delay between retries (seconds)
    let maxDelay: TimeInterval

    /// Retry strategy to use
    let strategy: RetryStrategy

    /// Whether to use jitter (randomization)
    let useJitter: Bool

    /// Jitter range (0.0 to 1.0)
    let jitterRange: Double

    /// Use circuit breaker
    let useCircuitBreaker: Bool

    /// Circuit breaker configuration
    let circuitBreakerConfig: CircuitBreakerConfig?

    static let `default` = SmartRetryConfig(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        strategy: .exponential,
        useJitter: true,
        jitterRange: 0.2,
        useCircuitBreaker: true,
        circuitBreakerConfig: .default
    )

    static let aggressive = SmartRetryConfig(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 15.0,
        strategy: .exponential,
        useJitter: true,
        jitterRange: 0.3,
        useCircuitBreaker: true,
        circuitBreakerConfig: .aggressive
    )

    static let conservative = SmartRetryConfig(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 5.0,
        strategy: .linear,
        useJitter: false,
        jitterRange: 0.0,
        useCircuitBreaker: true,
        circuitBreakerConfig: .tolerant
    )

    static let noCircuitBreaker = SmartRetryConfig(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        strategy: .exponential,
        useJitter: true,
        jitterRange: 0.2,
        useCircuitBreaker: false,
        circuitBreakerConfig: nil
    )
}

/// Smart retry result
enum SmartRetryResult<T> {
    case success(T, attempts: Int)
    case failure(Error, attempts: Int)
    case circuitBreakerOpen(resetAt: Date)
}

/// Smart retry manager with circuit breaker integration
@MainActor
class SmartRetryManager: ObservableObject {
    static let shared = SmartRetryManager()

    @Published private(set) var activeRetries: [String: Int] = [:]

    private init() {}

    // MARK: - Retry Methods

    /// Execute operation with smart retry logic
    /// - Parameters:
    ///   - serviceName: Name of service for circuit breaker
    ///   - config: Retry configuration
    ///   - operation: Async operation to execute
    /// - Returns: Result of operation
    func execute<T>(
        serviceName: String,
        config: SmartRetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async -> SmartRetryResult<T> {

        // Get circuit breaker if enabled
        let circuitBreaker: CircuitBreaker? = config.useCircuitBreaker
            ? CircuitBreakerManager.shared.getBreaker(
                for: serviceName,
                config: config.circuitBreakerConfig ?? .default
            )
            : nil

        var attempt = 0
        var lastError: Error?

        activeRetries[serviceName] = 0

        while attempt < config.maxAttempts {
            attempt += 1
            activeRetries[serviceName] = attempt

            Logger.shared.debug("Attempt \(attempt)/\(config.maxAttempts) for \(serviceName)", category: .networking)

            do {
                // Execute with circuit breaker if enabled
                let result: T
                if let breaker = circuitBreaker {
                    result = try await breaker.execute(operation)
                } else {
                    result = try await operation()
                }

                // Success!
                activeRetries.removeValue(forKey: serviceName)
                Logger.shared.info("✅ Operation succeeded for \(serviceName) on attempt \(attempt)", category: .networking)

                return .success(result, attempts: attempt)

            } catch let error as CircuitBreakerError {
                // Circuit breaker error - stop retrying
                activeRetries.removeValue(forKey: serviceName)

                if case .circuitOpen(let resetAt) = error {
                    Logger.shared.error("🔴 Circuit breaker open for \(serviceName)", category: .networking)
                    return .circuitBreakerOpen(resetAt: resetAt)
                }

                lastError = error

            } catch {
                lastError = error

                // Check if error is retryable
                if !isRetryable(error: error) {
                    activeRetries.removeValue(forKey: serviceName)
                    Logger.shared.error("❌ Non-retryable error for \(serviceName): \(error.localizedDescription)", category: .networking)
                    return .failure(error, attempts: attempt)
                }

                // Check if we should continue retrying
                if attempt >= config.maxAttempts {
                    activeRetries.removeValue(forKey: serviceName)
                    Logger.shared.error("❌ Max attempts reached for \(serviceName)", category: .networking)
                    return .failure(error, attempts: attempt)
                }

                // Calculate delay for next retry
                let delay = calculateRetryDelay(
                    attempt: attempt,
                    config: config,
                    error: error
                )

                Logger.shared.warning("⚠️ Attempt \(attempt) failed for \(serviceName). Retrying in \(String(format: "%.1f", delay))s...", category: .networking)

                // Wait before retrying
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // All attempts failed
        activeRetries.removeValue(forKey: serviceName)
        let finalError = lastError ?? CelestiaError.unknown("Max retry attempts exceeded")
        return .failure(finalError, attempts: attempt)
    }

    /// Execute with Result type
    func executeWithResult<T>(
        serviceName: String,
        config: SmartRetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {

        let result = await execute(serviceName: serviceName, config: config, operation: operation)

        switch result {
        case .success(let value, _):
            return .success(value)

        case .failure(let error, _):
            return .failure(error)

        case .circuitBreakerOpen(let resetAt):
            return .failure(CircuitBreakerError.circuitOpen(resetAt: resetAt))
        }
    }

    // MARK: - Helper Methods

    /// Calculate retry delay with jitter
    private func calculateRetryDelay(
        attempt: Int,
        config: SmartRetryConfig,
        error: Error
    ) -> TimeInterval {

        // Base delay from strategy
        var delay = config.strategy.calculateDelay(attempt: attempt, baseDelay: config.baseDelay)

        // Apply jitter if enabled
        if config.useJitter {
            let jitter = 1.0 + Double.random(in: -config.jitterRange...config.jitterRange)
            delay *= jitter
        }

        // Cap at max delay
        delay = min(delay, config.maxDelay)

        // Adjust based on error type
        delay = adjustDelayForError(delay: delay, error: error)

        return delay
    }

    /// Adjust delay based on error type
    private func adjustDelayForError(delay: TimeInterval, error: Error) -> TimeInterval {
        let nsError = error as NSError

        // Rate limit errors - use longer delay
        if let backendError = error as? BackendAPIError {
            if case .rateLimitExceeded = backendError {
                return max(delay * 2.0, 5.0)
            }
        }

        // HTTP 429 (Too Many Requests) - use longer delay
        // Note: URLError doesn't directly expose HTTP status codes
        // This is handled by BackendAPIError.rateLimitExceeded above

        // Server errors (5xx) - use moderate delay
        if nsError.domain == NSURLErrorDomain && nsError.code >= 500 {
            return delay * 1.5
        }

        return delay
    }

    /// Check if error is retryable
    private func isRetryable(error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors
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
                return false // Don't retry if offline

            default:
                return false
            }
        }

        // Firebase errors
        if nsError.domain == "FIRFirestoreErrorDomain" || nsError.domain == "FIRStorageErrorDomain" {
            switch nsError.code {
            case 14: // UNAVAILABLE
                return true
            case 4:  // DEADLINE_EXCEEDED
                return true
            case 10: // ABORTED
                return true
            default:
                return false
            }
        }

        // Backend API errors
        if let backendError = error as? BackendAPIError {
            switch backendError {
            case .serverError:
                return true
            case .networkError:
                return true
            case .rateLimitExceeded:
                return true
            case .tlsError:
                return false // TLS errors are certificate issues, not retryable
            case .unauthorized, .invalidURL, .invalidResponse, .httpError:
                return false
            }
        }

        // Circuit breaker errors
        if error is CircuitBreakerError {
            return false
        }

        // Default: don't retry unknown errors
        return false
    }

    // MARK: - Status Methods

    /// Check if service has active retries
    func hasActiveRetries(for serviceName: String) -> Bool {
        return activeRetries[serviceName] != nil
    }

    /// Get current retry attempt for service
    func getCurrentAttempt(for serviceName: String) -> Int? {
        return activeRetries[serviceName]
    }

    /// Get all services with active retries
    func getActiveServices() -> [String] {
        return Array(activeRetries.keys)
    }

    // MARK: - Convenience Methods

    /// Retry network operation
    func retryNetworkOperation<T>(
        serviceName: String,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        await executeWithResult(
            serviceName: serviceName,
            config: .aggressive,
            operation: operation
        )
    }

    /// Retry database operation
    func retryDatabaseOperation<T>(
        serviceName: String,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        await executeWithResult(
            serviceName: serviceName,
            config: .default,
            operation: operation
        )
    }

    /// Retry with custom config
    func retry<T>(
        serviceName: String,
        maxAttempts: Int,
        baseDelay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {

        let config = SmartRetryConfig(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            maxDelay: baseDelay * 10,
            strategy: .exponential,
            useJitter: true,
            jitterRange: 0.2,
            useCircuitBreaker: true,
            circuitBreakerConfig: .default
        )

        return await executeWithResult(
            serviceName: serviceName,
            config: config,
            operation: operation
        )
    }
}

// MARK: - Smart Retryable Protocol

protocol SmartRetryable {
    func performWithSmartRetry<T>(
        serviceName: String,
        config: SmartRetryConfig,
        operation: @escaping () async throws -> T
    ) async -> SmartRetryResult<T>
}

extension SmartRetryable {
    func performWithSmartRetry<T>(
        serviceName: String,
        config: SmartRetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async -> SmartRetryResult<T> {
        await SmartRetryManager.shared.execute(
            serviceName: serviceName,
            config: config,
            operation: operation
        )
    }
}
