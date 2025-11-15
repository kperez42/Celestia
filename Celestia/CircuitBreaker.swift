//
//  CircuitBreaker.swift
//  Celestia
//
//  Circuit breaker pattern to prevent cascading failures
//  Protects backend services from overload and provides graceful degradation
//

import Foundation

/// Circuit breaker state
enum CircuitBreakerState {
    case closed      // Normal operation - requests pass through
    case open        // Failures detected - requests blocked
    case halfOpen    // Testing if service recovered - limited requests allowed
}

/// Circuit breaker configuration
struct CircuitBreakerConfig {
    /// Number of failures before opening circuit
    let failureThreshold: Int

    /// Time window for counting failures (seconds)
    let failureWindow: TimeInterval

    /// Time to wait before attempting recovery (seconds)
    let cooldownPeriod: TimeInterval

    /// Number of successful requests needed to close circuit from half-open
    let successThreshold: Int

    /// Timeout for operations (seconds)
    let timeout: TimeInterval

    static let `default` = CircuitBreakerConfig(
        failureThreshold: 5,
        failureWindow: 60,
        cooldownPeriod: 30,
        successThreshold: 2,
        timeout: 10
    )

    static let aggressive = CircuitBreakerConfig(
        failureThreshold: 3,
        failureWindow: 30,
        cooldownPeriod: 15,
        successThreshold: 2,
        timeout: 5
    )

    static let tolerant = CircuitBreakerConfig(
        failureThreshold: 10,
        failureWindow: 120,
        cooldownPeriod: 60,
        successThreshold: 3,
        timeout: 15
    )
}

/// Circuit breaker error
enum CircuitBreakerError: LocalizedError {
    case circuitOpen(resetAt: Date)
    case timeout
    case maxConcurrencyReached

    var errorDescription: String? {
        switch self {
        case .circuitOpen(let resetAt):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            let timeString = formatter.string(from: Date(), to: resetAt) ?? "soon"
            return "Service temporarily unavailable. Retry in \(timeString)"
        case .timeout:
            return "Operation timed out"
        case .maxConcurrencyReached:
            return "Too many concurrent requests"
        }
    }
}

/// Circuit breaker implementation
@MainActor
class CircuitBreaker: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: CircuitBreakerState = .closed
    @Published private(set) var failureCount: Int = 0
    @Published private(set) var successCount: Int = 0

    // MARK: - Properties

    private let config: CircuitBreakerConfig
    private let serviceName: String

    private var failureTimestamps: [Date] = []
    private var lastFailureTime: Date?
    private var circuitOpenedAt: Date?
    private var currentConcurrency: Int = 0
    private let maxConcurrency: Int = 10

    // MARK: - Callbacks

    var onStateChange: ((CircuitBreakerState) -> Void)?
    var onCircuitOpen: (() -> Void)?
    var onCircuitClose: (() -> Void)?

    // MARK: - Initialization

    init(serviceName: String, config: CircuitBreakerConfig = .default) {
        self.serviceName = serviceName
        self.config = config

        Logger.shared.debug("Circuit breaker initialized for \(serviceName)", category: .networking)
    }

    // MARK: - Public Methods

    /// Execute an operation with circuit breaker protection
    /// - Parameter operation: Async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: CircuitBreakerError if circuit is open or operation fails
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Check if we can execute
        try checkCircuitState()

        // Check concurrency limit
        guard currentConcurrency < maxConcurrency else {
            throw CircuitBreakerError.maxConcurrencyReached
        }

        currentConcurrency += 1
        defer { currentConcurrency -= 1 }

        do {
            // Execute with timeout
            let result = try await executeWithTimeout(operation)

            // Record success
            await recordSuccess()

            return result

        } catch {
            // Record failure
            await recordFailure(error)
            throw error
        }
    }

    /// Execute with timeout protection
    private func executeWithTimeout<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add operation task
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.config.timeout * 1_000_000_000))
                throw CircuitBreakerError.timeout
            }

            // Return first result (success or timeout)
            // CODE QUALITY FIX: Removed force unwrapping - handle nil case properly
            guard let result = try await group.next() else {
                // This should never happen since we added 2 tasks, but handle it safely
                group.cancelAll()
                throw CircuitBreakerError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    /// Check if circuit breaker allows execution
    private func checkCircuitState() throws {
        switch state {
        case .closed:
            // Normal operation - allow all requests
            return

        case .open:
            // Circuit is open - check if cooldown period has passed
            guard let openedAt = circuitOpenedAt else {
                // Should not happen, but reset to closed if no timestamp
                transitionTo(.closed)
                return
            }

            let cooldownEnded = Date().timeIntervalSince(openedAt) >= config.cooldownPeriod

            if cooldownEnded {
                // Try half-open state
                transitionTo(.halfOpen)
                Logger.shared.info("Circuit breaker entering half-open state for \(serviceName)", category: .networking)
            } else {
                // Still in cooldown
                let resetAt = openedAt.addingTimeInterval(config.cooldownPeriod)
                throw CircuitBreakerError.circuitOpen(resetAt: resetAt)
            }

        case .halfOpen:
            // Allow limited requests to test service recovery
            return
        }
    }

    /// Record successful operation
    private func recordSuccess() {
        switch state {
        case .closed:
            // Normal operation - just clear old failures
            cleanupOldFailures()

        case .halfOpen:
            // In recovery mode - count successes
            successCount += 1

            if successCount >= config.successThreshold {
                // Service recovered - close circuit
                transitionTo(.closed)
                failureTimestamps.removeAll()
                successCount = 0

                Logger.shared.info("Circuit breaker closed for \(serviceName) - service recovered", category: .networking)

                AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                    "feature": "circuit_breaker",
                    "action": "closed",
                    "service": serviceName,
                    "success_count": successCount
                ])
            }

        case .open:
            // Should not happen (requests blocked), but reset if it does
            transitionTo(.closed)
        }
    }

    /// Record failed operation
    private func recordFailure(_ error: Error) {
        lastFailureTime = Date()
        failureTimestamps.append(Date())

        // Clean up old failures outside the window
        cleanupOldFailures()

        failureCount = failureTimestamps.count

        // Log failure
        Logger.shared.warning("Circuit breaker failure for \(serviceName): \(error.localizedDescription)", category: .networking)

        switch state {
        case .closed:
            // Check if we should open circuit
            if failureTimestamps.count >= config.failureThreshold {
                openCircuit()
            }

        case .halfOpen:
            // Recovery failed - reopen circuit
            openCircuit()
            successCount = 0

        case .open:
            // Already open - extend cooldown
            circuitOpenedAt = Date()
        }
    }

    /// Open the circuit (block requests)
    private func openCircuit() {
        circuitOpenedAt = Date()
        transitionTo(.open)

        Logger.shared.error("Circuit breaker OPENED for \(serviceName) - service unavailable", category: .networking)

        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "circuit_breaker",
            "action": "opened",
            "service": serviceName,
            "failure_count": failureTimestamps.count
        ])

        onCircuitOpen?()
    }

    /// Transition to a new state
    private func transitionTo(_ newState: CircuitBreakerState) {
        let oldState = state
        state = newState

        if oldState != newState {
            onStateChange?(newState)

            if newState == .closed {
                onCircuitClose?()
            }
        }
    }

    /// Remove failures outside the time window
    private func cleanupOldFailures() {
        let cutoffTime = Date().addingTimeInterval(-config.failureWindow)
        failureTimestamps = failureTimestamps.filter { $0 > cutoffTime }
        failureCount = failureTimestamps.count
    }

    // MARK: - Status Methods

    /// Check if circuit is healthy
    var isHealthy: Bool {
        return state == .closed
    }

    /// Get failure rate (0.0 to 1.0)
    var failureRate: Double {
        cleanupOldFailures()
        return Double(failureTimestamps.count) / Double(config.failureThreshold)
    }

    /// Get time until circuit can be tested (seconds)
    var timeUntilRetry: TimeInterval? {
        guard state == .open, let openedAt = circuitOpenedAt else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(openedAt)
        let remaining = config.cooldownPeriod - elapsed

        return remaining > 0 ? remaining : 0
    }

    /// Reset circuit breaker (for testing or manual intervention)
    func reset() {
        failureTimestamps.removeAll()
        successCount = 0
        failureCount = 0
        circuitOpenedAt = nil
        lastFailureTime = nil
        transitionTo(.closed)

        Logger.shared.info("Circuit breaker manually reset for \(serviceName)", category: .networking)
    }

    /// Get circuit breaker status
    func getStatus() -> CircuitBreakerStatus {
        cleanupOldFailures()

        return CircuitBreakerStatus(
            serviceName: serviceName,
            state: state,
            failureCount: failureTimestamps.count,
            successCount: successCount,
            failureRate: failureRate,
            timeUntilRetry: timeUntilRetry,
            lastFailureTime: lastFailureTime,
            currentConcurrency: currentConcurrency
        )
    }
}

// MARK: - Circuit Breaker Status

struct CircuitBreakerStatus {
    let serviceName: String
    let state: CircuitBreakerState
    let failureCount: Int
    let successCount: Int
    let failureRate: Double
    let timeUntilRetry: TimeInterval?
    let lastFailureTime: Date?
    let currentConcurrency: Int

    var isHealthy: Bool {
        state == .closed && failureRate < 0.5
    }

    var healthDescription: String {
        switch state {
        case .closed:
            return "Healthy"
        case .open:
            return "Unavailable"
        case .halfOpen:
            return "Recovering"
        }
    }
}

// MARK: - Circuit Breaker Manager

/// Global manager for all circuit breakers
@MainActor
class CircuitBreakerManager: ObservableObject {
    static let shared = CircuitBreakerManager()

    @Published private(set) var breakers: [String: CircuitBreaker] = [:]

    private init() {}

    /// Get or create circuit breaker for a service
    func getBreaker(for service: String, config: CircuitBreakerConfig = .default) -> CircuitBreaker {
        if let existing = breakers[service] {
            return existing
        }

        let breaker = CircuitBreaker(serviceName: service, config: config)
        breakers[service] = breaker

        return breaker
    }

    /// Get all circuit breaker statuses
    func getAllStatuses() -> [CircuitBreakerStatus] {
        return breakers.values.map { $0.getStatus() }
    }

    /// Reset all circuit breakers
    func resetAll() {
        breakers.values.forEach { $0.reset() }
        Logger.shared.info("All circuit breakers reset", category: .networking)
    }

    /// Get unhealthy services
    func getUnhealthyServices() -> [String] {
        return breakers.filter { $0.value.state != .closed }.map { $0.key }
    }
}
