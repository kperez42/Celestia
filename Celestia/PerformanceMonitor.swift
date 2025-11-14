//
//  PerformanceMonitor.swift
//  Celestia
//
//  Monitors and logs performance metrics for slow operations
//  Helps identify bottlenecks and track performance improvements
//

import Foundation

/// Performance monitoring for async operations
class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    /// Threshold for logging slow operations (milliseconds)
    private let slowOperationThreshold: Double = 1000 // 1 second

    /// Threshold for sending to analytics (milliseconds)
    private let analyticsThreshold: Double = 2000 // 2 seconds

    private init() {}

    // MARK: - Public Methods

    /// Measure execution time of an async operation
    /// Logs performance and sends to analytics if operation is slow
    ///
    /// - Parameters:
    ///   - name: Operation name for logging
    ///   - category: Logger category
    ///   - operation: Async operation to measure
    /// - Returns: Result of the operation
    func measureAsync<T>(
        _ name: String,
        category: Logger.Category = .performance,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()

        let result = try await operation()

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // Convert to ms

        logPerformance(name: name, duration: duration, category: category)

        return result
    }

    /// Measure execution time of a synchronous operation
    ///
    /// - Parameters:
    ///   - name: Operation name for logging
    ///   - category: Logger category
    ///   - operation: Operation to measure
    /// - Returns: Result of the operation
    func measureSync<T>(
        _ name: String,
        category: Logger.Category = .performance,
        operation: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()

        let result = try operation()

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // Convert to ms

        logPerformance(name: name, duration: duration, category: category)

        return result
    }

    /// Start a timer for manual measurement
    /// - Parameter name: Operation name
    /// - Returns: Timer ID
    func startTimer(_ name: String) -> UUID {
        let timerId = UUID()
        activeTimers[timerId] = (name: name, start: CFAbsoluteTimeGetCurrent())
        return timerId
    }

    /// End a timer and log performance
    /// - Parameter timerId: Timer ID from startTimer
    func endTimer(_ timerId: UUID, category: Logger.Category = .performance) {
        guard let timer = activeTimers.removeValue(forKey: timerId) else {
            Logger.shared.warning("Timer \(timerId) not found", category: .general)
            return
        }

        let duration = (CFAbsoluteTimeGetCurrent() - timer.start) * 1000 // Convert to ms
        logPerformance(name: timer.name, duration: duration, category: category)
    }

    // MARK: - Private

    private var activeTimers: [UUID: (name: String, start: CFTimeInterval)] = [:]

    private func logPerformance(name: String, duration: Double, category: Logger.Category) {
        let formattedDuration = String(format: "%.2f", duration)

        if duration > slowOperationThreshold {
            Logger.shared.warning("⏱️ SLOW: \(name) took \(formattedDuration)ms", category: category)

            // Send to analytics if really slow
            if duration > analyticsThreshold {
                sendToAnalytics(name: name, duration: duration)
            }
        } else if duration > 500 {
            Logger.shared.info("⏱️ \(name) took \(formattedDuration)ms", category: category)
        } else {
            Logger.shared.debug("⏱️ \(name) took \(formattedDuration)ms", category: category)
        }
    }

    private func sendToAnalytics(name: String, duration: Double) {
        AnalyticsManager.shared.logEvent("slow_operation", parameters: [
            "operation_name": name,
            "duration_ms": duration,
            "threshold_ms": analyticsThreshold
        ])
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Measure async operation
 let users = await PerformanceMonitor.shared.measureAsync("Load Users") {
     try await UserService.shared.fetchUsers(limit: 20)
 }

 // Example 2: Measure sync operation
 let filtered = PerformanceMonitor.shared.measureSync("Filter Users") {
     users.filter { $0.age > 18 }
 }

 // Example 3: Manual timer
 let timerId = PerformanceMonitor.shared.startTimer("Complex Operation")
 // ... do work ...
 PerformanceMonitor.shared.endTimer(timerId)

 // Output examples:
 // ✅ ⏱️ Load Users took 125.43ms           (fast)
 // ⚠️  ⏱️ Load Users took 856.12ms           (noticeable)
 // ❌ ⏱️ SLOW: Load Users took 2341.56ms    (slow, sent to analytics)
 */

// MARK: - Performance Categories

extension PerformanceMonitor {
    /// Common performance measurement points
    enum Metric {
        static let userLoad = "User List Load"
        static let profileLoad = "Profile Load"
        static let imageLoad = "Image Load"
        static let messageLoad = "Message Load"
        static let matchLoad = "Match Load"
        static let search = "Search Query"
        static let filter = "Apply Filters"
        static let save = "Save Data"
        static let upload = "Upload Image"
        static let authentication = "Authentication"
    }
}

// MARK: - Performance Statistics

/// Track performance statistics over time
@MainActor
class PerformanceStatistics {
    static let shared = PerformanceStatistics()

    private var measurements: [String: [Double]] = [:]

    private init() {}

    /// Record a measurement
    func record(_ name: String, duration: Double) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(duration)

        // Keep only last 100 measurements per operation
        if measurements[name]!.count > 100 {
            measurements[name]?.removeFirst()
        }
    }

    /// Get statistics for an operation
    func statistics(for name: String) -> Statistics? {
        guard let durations = measurements[name], !durations.isEmpty else {
            return nil
        }

        let sorted = durations.sorted()
        let sum = durations.reduce(0, +)

        return Statistics(
            count: durations.count,
            average: sum / Double(durations.count),
            median: sorted[sorted.count / 2],
            min: sorted.first!,
            max: sorted.last!,
            p95: sorted[Int(Double(sorted.count) * 0.95)]
        )
    }

    /// Get all statistics
    func allStatistics() -> [String: Statistics] {
        var stats: [String: Statistics] = [:]
        for name in measurements.keys {
            if let stat = statistics(for: name) {
                stats[name] = stat
            }
        }
        return stats
    }

    /// Clear all measurements
    func clear() {
        measurements.removeAll()
    }

    struct Statistics {
        let count: Int
        let average: Double
        let median: Double
        let min: Double
        let max: Double
        let p95: Double // 95th percentile

        var description: String {
            return """
            Count: \(count)
            Average: \(String(format: "%.2f", average))ms
            Median: \(String(format: "%.2f", median))ms
            Min: \(String(format: "%.2f", min))ms
            Max: \(String(format: "%.2f", max))ms
            P95: \(String(format: "%.2f", p95))ms
            """
        }
    }
}

// MARK: - Integration with Logger

extension Logger.Category {
    static let performance = Logger.Category.general // Add dedicated performance category if needed
}
