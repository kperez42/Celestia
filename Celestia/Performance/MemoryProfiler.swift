//
//  MemoryProfiler.swift
//  Celestia
//
//  Profiles memory usage and performance metrics
//  Tracks memory footprint, allocations, and performance issues
//

import Foundation
import SwiftUI
import os.signpost

// MARK: - Memory Profiler

class MemoryProfiler {

    // MARK: - Singleton

    static let shared = MemoryProfiler()

    // MARK: - Properties

    private var memorySnapshots: [MemorySnapshot] = []
    private var performanceMetrics: [PerformanceMetric] = []
    private let queue = DispatchQueue(label: "com.celestia.memory-profiler", attributes: .concurrent)
    private var isEnabled = true
    private var monitoringTimer: Timer?

    // Signpost for Instruments integration
    private let signpostLog = OSLog(subsystem: "com.celestia.app", category: "Memory")
    private let signpostID = OSSignpostID(log: OSLog(subsystem: "com.celestia.app", category: "Memory"))

    // MARK: - Configuration

    var snapshotInterval: TimeInterval = 5.0 // Take snapshot every 5 seconds
    var retentionDuration: TimeInterval = 300.0 // Keep snapshots for 5 minutes

    // MARK: - Initialization

    private init() {
        #if DEBUG
        isEnabled = true
        Logger.shared.info("MemoryProfiler initialized", category: .general)
        startMonitoring()
        #else
        isEnabled = false
        #endif
    }

    // MARK: - Public Methods

    /// Start memory profiling
    func startProfiling() {
        guard isEnabled else { return }

        Logger.shared.info("Starting memory profiling", category: .general)
        startMonitoring()
    }

    /// Stop memory profiling
    func stopProfiling() {
        guard isEnabled else { return }

        Logger.shared.info("Stopping memory profiling", category: .general)
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// Get current memory usage
    func currentMemoryUsage() -> MemoryUsage {
        return MemoryUsage(
            used: usedMemoryInBytes(),
            available: availableMemoryInBytes(),
            footprint: memoryFootprintInBytes()
        )
    }

    /// Take a memory snapshot
    func takeSnapshot(label: String? = nil) {
        guard isEnabled else { return }

        let snapshot = MemorySnapshot(
            timestamp: Date(),
            label: label,
            memoryUsage: currentMemoryUsage(),
            allocatedObjects: getAllocatedObjects()
        )

        queue.async(flags: .barrier) {
            self.memorySnapshots.append(snapshot)
            self.cleanupOldSnapshots()
        }

        Logger.shared.debug(
            "Memory snapshot: \(snapshot.memoryUsage.used.formattedBytes()) used",
            category: .general
        )

        // Report to analytics if usage is high
        if snapshot.memoryUsage.used > 200 * 1024 * 1024 { // > 200MB
            CrashlyticsManager.shared.logEvent("high_memory_usage", parameters: [
                "used_mb": snapshot.memoryUsage.used / (1024 * 1024),
                "label": label ?? "unknown"
            ])
        }
    }

    /// Get memory usage history
    func getMemoryHistory(for duration: TimeInterval = 60.0) -> [MemorySnapshot] {
        let cutoffDate = Date().addingTimeInterval(-duration)
        return queue.sync {
            memorySnapshots.filter { $0.timestamp >= cutoffDate }
        }
    }

    /// Profile a code block
    func profile<T>(label: String, block: () throws -> T) rethrows -> T {
        guard isEnabled else { return try block() }

        let startSnapshot = currentMemoryUsage()
        let startTime = CFAbsoluteTimeGetCurrent()

        os_signpost(.begin, log: signpostLog, name: "Memory Profiling", signpostID: signpostID, "%{public}s", label)

        let result = try block()

        os_signpost(.end, log: signpostLog, name: "Memory Profiling", signpostID: signpostID, "%{public}s", label)

        let endTime = CFAbsoluteTimeGetCurrent()
        let endSnapshot = currentMemoryUsage()

        let metric = PerformanceMetric(
            label: label,
            duration: endTime - startTime,
            memoryBefore: startSnapshot,
            memoryAfter: endSnapshot
        )

        queue.async(flags: .barrier) {
            self.performanceMetrics.append(metric)
        }

        logPerformanceMetric(metric)

        return result
    }

    /// Profile an async code block
    func profileAsync<T>(label: String, block: () async throws -> T) async rethrows -> T {
        guard isEnabled else { return try await block() }

        let startSnapshot = currentMemoryUsage()
        let startTime = CFAbsoluteTimeGetCurrent()

        os_signpost(.begin, log: signpostLog, name: "Memory Profiling", signpostID: signpostID, "%{public}s", label)

        let result = try await block()

        os_signpost(.end, log: signpostLog, name: "Memory Profiling", signpostID: signpostID, "%{public}s", label)

        let endTime = CFAbsoluteTimeGetCurrent()
        let endSnapshot = currentMemoryUsage()

        let metric = PerformanceMetric(
            label: label,
            duration: endTime - startTime,
            memoryBefore: startSnapshot,
            memoryAfter: endSnapshot
        )

        queue.async(flags: .barrier) {
            self.performanceMetrics.append(metric)
        }

        logPerformanceMetric(metric)

        return result
    }

    /// Get performance metrics
    func getPerformanceMetrics(for label: String? = nil) -> [PerformanceMetric] {
        return queue.sync {
            if let label = label {
                return performanceMetrics.filter { $0.label == label }
            }
            return performanceMetrics
        }
    }

    /// Generate memory report
    func generateReport() -> MemoryReport {
        let snapshots = queue.sync { memorySnapshots }
        let metrics = queue.sync { performanceMetrics }

        guard !snapshots.isEmpty else {
            return MemoryReport(
                averageMemoryUsage: 0,
                peakMemoryUsage: 0,
                snapshotCount: 0,
                performanceMetrics: []
            )
        }

        let totalMemory = snapshots.reduce(0) { $0 + $1.memoryUsage.used }
        let averageMemory = totalMemory / snapshots.count
        let peakMemory = snapshots.map { $0.memoryUsage.used }.max() ?? 0

        return MemoryReport(
            averageMemoryUsage: averageMemory,
            peakMemoryUsage: peakMemory,
            snapshotCount: snapshots.count,
            performanceMetrics: metrics
        )
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        guard monitoringTimer == nil else { return }

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            self?.takeSnapshot(label: "Auto")
        }
    }

    private func cleanupOldSnapshots() {
        let cutoffDate = Date().addingTimeInterval(-retentionDuration)
        memorySnapshots = memorySnapshots.filter { $0.timestamp >= cutoffDate }
        performanceMetrics = performanceMetrics.filter { $0.timestamp >= cutoffDate }
    }

    private func logPerformanceMetric(_ metric: PerformanceMetric) {
        let memoryDelta = metric.memoryAfter.used - metric.memoryBefore.used
        let message = """
        Performance: \(metric.label)
        Duration: \(String(format: "%.3f", metric.duration))s
        Memory change: \(memoryDelta.formattedBytes())
        """

        Logger.shared.debug(message, category: .general)

        // Warn if operation took significant memory or time
        if abs(memoryDelta) > 10 * 1024 * 1024 || metric.duration > 1.0 {
            Logger.shared.warning("Expensive operation: \(metric.label)", category: .general)
            CrashlyticsManager.shared.logEvent("expensive_operation", parameters: [
                "label": metric.label,
                "duration": metric.duration,
                "memory_delta_mb": memoryDelta / (1024 * 1024)
            ])
        }
    }

    // MARK: - Memory Calculation

    private func usedMemoryInBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    private func availableMemoryInBytes() -> Int {
        let hostPort = mach_host_self()
        var pageSize: vm_size_t = 0
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let hostPageSize = host_page_size(hostPort, &pageSize)
        let hostStatistics = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard hostPageSize == KERN_SUCCESS && hostStatistics == KERN_SUCCESS else {
            return 0
        }

        let freeMemory = Int(vmStat.free_count) * Int(pageSize)
        return freeMemory
    }

    private func memoryFootprintInBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    private func getAllocatedObjects() -> Int {
        // Approximate count of allocated objects
        // In production, you'd use more sophisticated tools
        return 0
    }
}

// MARK: - Supporting Types

struct MemoryUsage: Codable {
    let used: Int
    let available: Int
    let footprint: Int

    var usedMB: Double {
        return Double(used) / (1024 * 1024)
    }

    var availableMB: Double {
        return Double(available) / (1024 * 1024)
    }

    var footprintMB: Double {
        return Double(footprint) / (1024 * 1024)
    }
}

struct MemorySnapshot: Codable {
    let timestamp: Date
    let label: String?
    let memoryUsage: MemoryUsage
    let allocatedObjects: Int
}

struct PerformanceMetric: Codable {
    let label: String
    let duration: TimeInterval
    let memoryBefore: MemoryUsage
    let memoryAfter: MemoryUsage
    let timestamp: Date

    init(label: String, duration: TimeInterval, memoryBefore: MemoryUsage, memoryAfter: MemoryUsage) {
        self.label = label
        self.duration = duration
        self.memoryBefore = memoryBefore
        self.memoryAfter = memoryAfter
        self.timestamp = Date()
    }

    var memoryDelta: Int {
        return memoryAfter.used - memoryBefore.used
    }
}

struct MemoryReport {
    let averageMemoryUsage: Int
    let peakMemoryUsage: Int
    let snapshotCount: Int
    let performanceMetrics: [PerformanceMetric]

    var averageMemoryMB: Double {
        return Double(averageMemoryUsage) / (1024 * 1024)
    }

    var peakMemoryMB: Double {
        return Double(peakMemoryUsage) / (1024 * 1024)
    }
}

// MARK: - Extensions

extension Int {
    func formattedBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(self))
    }
}

// MARK: - SwiftUI Integration

struct MemoryProfileView: View {
    @State private var report: MemoryReport
    @State private var timer: Timer?

    init() {
        _report = State(initialValue: MemoryProfiler.shared.generateReport())
    }

    var body: some View {
        List {
            Section("Memory Usage") {
                HStack {
                    Text("Average")
                    Spacer()
                    Text(String(format: "%.2f MB", report.averageMemoryMB))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Peak")
                    Spacer()
                    Text(String(format: "%.2f MB", report.peakMemoryMB))
                        .foregroundColor(.red)
                }

                HStack {
                    Text("Current")
                    Spacer()
                    Text(MemoryProfiler.shared.currentMemoryUsage().used.formattedBytes())
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Snapshots")
                    Spacer()
                    Text("\(report.snapshotCount)")
                        .foregroundColor(.secondary)
                }
            }

            Section("Performance Metrics") {
                ForEach(report.performanceMetrics.prefix(10), id: \.timestamp) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.label)
                            .font(.headline)

                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text(String(format: "%.3fs", metric.duration))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Memory Δ:")
                            Spacer()
                            Text(metric.memoryDelta.formattedBytes())
                                .foregroundColor(metric.memoryDelta > 0 ? .red : .green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Memory Profiler")
        .onAppear {
            startUpdating()
        }
        .onDisappear {
            stopUpdating()
        }
    }

    private func startUpdating() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            report = MemoryProfiler.shared.generateReport()
        }
    }

    private func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }
}
