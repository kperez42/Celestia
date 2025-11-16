//
//  PerformanceMonitor.swift
//  Celestia
//
//  Comprehensive performance monitoring system
//  Tracks FPS, memory, network, database queries, and image loading
//  Helps identify bottlenecks and track performance improvements
//

import Foundation
import SwiftUI

/// Performance monitoring for async operations with real-time metrics
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Published Properties for Real-time Monitoring

    @Published var currentFPS: Double = 60.0
    @Published var memoryUsageMB: Double = 0.0
    @Published var networkLatencyMs: Double = 0.0
    @Published var averageQueryTimeMs: Double = 0.0
    @Published var averageImageLoadTimeMs: Double = 0.0
    @Published var connectionQuality: ConnectionQuality = .excellent
    @Published var isMonitoring: Bool = false
    @Published var isUnderMemoryPressure: Bool = false

    /// Threshold for logging slow operations (milliseconds)
    private let slowOperationThreshold: Double = 1000 // 1 second

    /// Threshold for sending to analytics (milliseconds)
    private let analyticsThreshold: Double = 2000 // 2 seconds

    /// Memory warning tracking
    private var memoryWarningCount = 0
    private var lastMemoryWarning: Date?

    // MEMORY FIX: Store observer token for cleanup
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Connection Quality

    enum ConnectionQuality: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case offline = "Offline"

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .offline: return .gray
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            case .offline: return "bolt.slash.fill"
            }
        }
    }

    // MARK: - Performance Metrics

    struct PerformanceMetrics: Codable {
        var timestamp: Date
        var fps: Double
        var memoryMB: Double
        var networkLatencyMs: Double
        var queryTimeMs: Double
        var imageLoadTimeMs: Double
        var connectionQuality: ConnectionQuality
    }

    // MARK: - Private Properties for Real-time Monitoring

    private var fpsDisplayLink: CADisplayLink?
    private var frameTimestamps: [CFTimeInterval] = []
    private var queryTimes: [Double] = []
    private var imageLoadTimes: [Double] = []
    private var networkLatencies: [Double] = []
    private var metricsHistory: [PerformanceMetrics] = []
    private let maxHistorySize = 100
    private var monitoringTimer: Timer?

    private init() {
        // PERFORMANCE: Register for memory warning notifications
        // MEMORY FIX: Store observer token for proper cleanup
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }

        Logger.shared.info("PerformanceMonitor initialized", category: .performance)
    }

    // MEMORY FIX: Clean up observer to prevent memory leak
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        fpsDisplayLink?.invalidate()
        monitoringTimer?.invalidate()
    }

    // MARK: - Memory Pressure Management

    /// Handle system memory warning
    private func handleMemoryWarning() {
        memoryWarningCount += 1
        lastMemoryWarning = Date()
        isUnderMemoryPressure = true

        Logger.shared.warning(
            "Memory warning \(memoryWarningCount) detected - Memory usage: \(String(format: "%.1f", memoryUsageMB))MB",
            category: .performance
        )

        // Send critical memory warning to analytics
        AnalyticsManager.shared.logEvent(.performance, parameters: [
            "type": "memory_warning",
            "count": memoryWarningCount,
            "memory_mb": memoryUsageMB,
            "connection_quality": connectionQuality.rawValue
        ])

        // Reset pressure flag after 2 minutes
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000_000) // 2 minutes
            await MainActor.run {
                isUnderMemoryPressure = false
            }
        }
    }

    /// Get memory pressure statistics
    func getMemoryPressureStats() -> MemoryPressureStats {
        return MemoryPressureStats(
            isUnderPressure: isUnderMemoryPressure,
            warningCount: memoryWarningCount,
            lastWarning: lastMemoryWarning,
            currentMemoryMB: memoryUsageMB,
            availableMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        )
    }

    struct MemoryPressureStats {
        let isUnderPressure: Bool
        let warningCount: Int
        let lastWarning: Date?
        let currentMemoryMB: Double
        let availableMemoryGB: Double

        var timeSinceLastWarning: TimeInterval? {
            guard let lastWarning = lastWarning else { return nil }
            return Date().timeIntervalSince(lastWarning)
        }
    }

    // MARK: - Start/Stop Monitoring

    /// Start comprehensive performance monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        startFPSMonitoring()
        startMemoryMonitoring()

        Logger.shared.info("Performance monitoring started", category: .performance)
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        stopFPSMonitoring()
        stopMemoryMonitoring()

        Logger.shared.info("Performance monitoring stopped", category: .performance)
    }

    // MARK: - FPS Monitoring

    private func startFPSMonitoring() {
        fpsDisplayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        fpsDisplayLink?.add(to: .main, forMode: .common)
    }

    private func stopFPSMonitoring() {
        fpsDisplayLink?.invalidate()
        fpsDisplayLink = nil
        frameTimestamps.removeAll()
    }

    @objc private func updateFPS() {
        guard let displayLink = fpsDisplayLink else { return }

        let timestamp = displayLink.timestamp
        frameTimestamps.append(timestamp)

        // Keep only last 60 frames
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst()
        }

        // Calculate FPS from frame timestamps
        // SAFETY: Use safe optional access instead of force unwrap
        if frameTimestamps.count >= 2,
           let lastTimestamp = frameTimestamps.last,
           let firstTimestamp = frameTimestamps.first {
            let timeInterval = lastTimestamp - firstTimestamp
            let fps = Double(frameTimestamps.count - 1) / timeInterval
            currentFPS = min(60.0, max(0.0, fps))
        }
    }

    // MARK: - Memory Monitoring

    private func startMemoryMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMemoryUsage()
                self?.updateConnectionQuality()
                self?.saveMetricsSnapshot()
            }
        }
    }

    private func stopMemoryMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }

    // MARK: - Connection Quality Detection

    private func updateConnectionQuality() {
        let avgLatency = networkLatencies.isEmpty ? 0 : networkLatencies.reduce(0, +) / Double(networkLatencies.count)

        if avgLatency == 0 {
            connectionQuality = .offline
        } else if avgLatency < 50 {
            connectionQuality = .excellent
        } else if avgLatency < 150 {
            connectionQuality = .good
        } else if avgLatency < 300 {
            connectionQuality = .fair
        } else {
            connectionQuality = .poor
        }

        networkLatencyMs = avgLatency
    }

    // MARK: - Performance Tracking Methods

    /// Track database query performance
    /// - Parameter duration: Query duration in milliseconds
    func trackQuery(duration: Double) {
        queryTimes.append(duration)

        // Keep only last 50 measurements
        if queryTimes.count > 50 {
            queryTimes.removeFirst()
        }

        averageQueryTimeMs = queryTimes.reduce(0, +) / Double(queryTimes.count)
    }

    /// Track image loading performance
    /// - Parameter duration: Load duration in milliseconds
    func trackImageLoad(duration: Double) {
        imageLoadTimes.append(duration)

        // Keep only last 50 measurements
        if imageLoadTimes.count > 50 {
            imageLoadTimes.removeFirst()
        }

        averageImageLoadTimeMs = imageLoadTimes.reduce(0, +) / Double(imageLoadTimes.count)
    }

    /// Track network latency
    /// - Parameter latency: Network latency in milliseconds
    func trackNetworkLatency(latency: Double) {
        networkLatencies.append(latency)

        // Keep only last 20 measurements
        if networkLatencies.count > 20 {
            networkLatencies.removeFirst()
        }

        updateConnectionQuality()
    }

    // MARK: - Image Preloading Support

    /// Preload images for better performance (preloads next 2 images)
    /// - Parameter urls: Array of image URLs to preload
    func preloadImages(_ urls: [String]) async {
        let start = Date()

        await withTaskGroup(of: Void.self) { group in
            for urlString in urls.prefix(2) { // Preload only next 2 images
                group.addTask {
                    guard let url = URL(string: urlString) else { return }

                    // Check if image is already cached
                    if await ImageCache.shared.image(for: urlString) != nil {
                        return
                    }

                    // Load image data
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            await ImageCache.shared.setImage(image, for: urlString)
                        }
                    } catch {
                        Logger.shared.error("Failed to preload image: \(urlString)", category: .performance, error: error)
                    }
                }
            }
        }

        let duration = Date().timeIntervalSince(start) * 1000
        await trackImageLoad(duration: duration)

        Logger.shared.debug("Preloaded \(min(2, urls.count)) images in \(String(format: "%.0f", duration))ms", category: .performance)
    }

    // MARK: - Metrics History

    private func saveMetricsSnapshot() {
        let metrics = PerformanceMetrics(
            timestamp: Date(),
            fps: currentFPS,
            memoryMB: memoryUsageMB,
            networkLatencyMs: networkLatencyMs,
            queryTimeMs: averageQueryTimeMs,
            imageLoadTimeMs: averageImageLoadTimeMs,
            connectionQuality: connectionQuality
        )

        metricsHistory.append(metrics)

        // Keep only recent history
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
    }

    /// Get performance metrics for a specific time range
    /// - Parameter minutes: Number of minutes to look back
    /// - Returns: Array of performance metrics
    func getMetrics(forLastMinutes minutes: Int) -> [PerformanceMetrics] {
        let cutoffDate = Date().addingTimeInterval(-Double(minutes * 60))
        return metricsHistory.filter { $0.timestamp >= cutoffDate }
    }

    /// Get current performance summary
    /// - Returns: Dictionary of current metrics
    func getCurrentSummary() -> [String: Any] {
        return [
            "fps": currentFPS,
            "memoryMB": memoryUsageMB,
            "networkLatencyMs": networkLatencyMs,
            "avgQueryTimeMs": averageQueryTimeMs,
            "avgImageLoadTimeMs": averageImageLoadTimeMs,
            "connectionQuality": connectionQuality.rawValue
        ]
    }

    /// Log performance summary to console
    func logSummary() {
        Logger.shared.info("""
        Performance Summary:
        - FPS: \(String(format: "%.1f", currentFPS))
        - Memory: \(String(format: "%.1f", memoryUsageMB)) MB
        - Network: \(String(format: "%.0f", networkLatencyMs)) ms (\(connectionQuality.rawValue))
        - Avg Query Time: \(String(format: "%.0f", averageQueryTimeMs)) ms
        - Avg Image Load: \(String(format: "%.0f", averageImageLoadTimeMs)) ms
        """, category: .performance)
    }

    /// Get performance improvement recommendations
    /// - Returns: Array of recommendation strings
    func getRecommendations() -> [String] {
        var recommendations: [String] = []

        if currentFPS < 30 {
            recommendations.append("Low FPS detected. Consider reducing UI complexity or animations.")
        }

        if isUnderMemoryPressure || memoryWarningCount > 0 {
            recommendations.append("Memory pressure detected (\(memoryWarningCount) warnings). System has purged caches.")
        } else if memoryUsageMB > 500 {
            recommendations.append("High memory usage (\(String(format: "%.0f", memoryUsageMB))MB). Consider clearing caches or reducing loaded data.")
        }

        if connectionQuality == .poor || connectionQuality == .offline {
            recommendations.append("Poor network connection. Enable offline mode or reduce data usage.")
        }

        if averageQueryTimeMs > 500 {
            recommendations.append("Slow database queries. Consider adding indexes or caching frequently accessed data.")
        }

        if averageImageLoadTimeMs > 1000 {
            recommendations.append("Slow image loading. Consider optimizing image sizes or implementing better caching.")
        }

        return recommendations
    }

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
        category: LogCategory = .performance,
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
        category: LogCategory = .performance,
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
    func endTimer(_ timerId: UUID, category: LogCategory = .performance) {
        guard let timer = activeTimers.removeValue(forKey: timerId) else {
            Logger.shared.warning("Timer \(timerId) not found", category: .general)
            return
        }

        let duration = (CFAbsoluteTimeGetCurrent() - timer.start) * 1000 // Convert to ms
        logPerformance(name: timer.name, duration: duration, category: category)
    }

    // MARK: - Private

    private var activeTimers: [UUID: (name: String, start: CFTimeInterval)] = [:]

    private func logPerformance(name: String, duration: Double, category: LogCategory) {
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
        AnalyticsManager.shared.logEvent(.performance, parameters: [
            "type": "slow_operation",
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
        if let count = measurements[name]?.count, count > 100 {
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

        // SAFETY: Use safe optionals even though guard above ensures non-empty
        guard let minValue = sorted.first,
              let maxValue = sorted.last else {
            return nil
        }

        return Statistics(
            count: durations.count,
            average: sum / Double(durations.count),
            median: sorted[sorted.count / 2],
            min: minValue,
            max: maxValue,
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
// Performance category is already defined in LogCategory enum

// MARK: - Performance Monitor View (for debugging)

struct PerformanceMonitorView: View {
    @ObservedObject var monitor = PerformanceMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Monitor")
                .font(.headline)
                .fontWeight(.bold)

            performanceRow(title: "FPS", value: String(format: "%.1f", monitor.currentFPS), color: fpsColor)
            performanceRow(title: "Memory", value: String(format: "%.1f MB", monitor.memoryUsageMB), color: memoryColor)
            performanceRow(title: "Network", value: String(format: "%.0f ms", monitor.networkLatencyMs), color: monitor.connectionQuality.color)
            performanceRow(title: "Avg Query", value: String(format: "%.0f ms", monitor.averageQueryTimeMs), color: .blue)
            performanceRow(title: "Avg Image Load", value: String(format: "%.0f ms", monitor.averageImageLoadTimeMs), color: .purple)

            HStack {
                Image(systemName: monitor.connectionQuality.icon)
                    .foregroundColor(monitor.connectionQuality.color)
                Text("Connection: \(monitor.connectionQuality.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(monitor.connectionQuality.color)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }

    private func performanceRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    private var fpsColor: Color {
        if monitor.currentFPS >= 55 { return .green }
        if monitor.currentFPS >= 40 { return .orange }
        return .red
    }

    private var memoryColor: Color {
        if monitor.memoryUsageMB < 300 { return .green }
        if monitor.memoryUsageMB < 500 { return .orange }
        return .red
    }
}

#Preview {
    PerformanceMonitorView()
        .padding()
}
