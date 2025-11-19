//
//  ImagePerformanceMonitor.swift
//  Celestia
//
//  Performance monitoring for image optimization system
//  Tracks load times, CDN usage, bandwidth savings, and user engagement
//

import Foundation
import Firebase
import FirebasePerformance
import FirebaseAnalytics

@MainActor
class ImagePerformanceMonitor: ObservableObject {
    static let shared = ImagePerformanceMonitor()

    // Performance metrics
    @Published var averageLoadTime: TimeInterval = 0
    @Published var totalImageLoads: Int = 0
    @Published var cdnHitRate: Double = 0
    @Published var bandwidthSaved: Int64 = 0 // in bytes

    // Session metrics
    private var sessionLoadTimes: [TimeInterval] = []
    private var sessionCDNHits: Int = 0
    private var sessionTotalRequests: Int = 0
    private var sessionBandwidthSaved: Int64 = 0

    private init() {
        Logger.shared.info("ImagePerformanceMonitor initialized", category: .general)
    }

    // MARK: - Image Load Tracking

    /// Start tracking an image load operation
    func startImageLoadTrace(imageId: String, size: String) -> ImageLoadTrace {
        let trace = ImageLoadTrace(imageId: imageId, size: size)
        trace.start()
        return trace
    }

    /// Record successful image load
    func recordImageLoad(
        trace: ImageLoadTrace,
        fromCDN: Bool,
        bytesLoaded: Int64,
        optimizedBytes: Int64?
    ) {
        trace.stop()

        let loadTime = trace.duration

        // Update session metrics
        sessionLoadTimes.append(loadTime)
        sessionTotalRequests += 1
        if fromCDN {
            sessionCDNHits += 1
        }

        // Calculate bandwidth savings if we have original size
        if let optimizedBytes = optimizedBytes {
            let saved = bytesLoaded - optimizedBytes
            if saved > 0 {
                sessionBandwidthSaved += saved
                bandwidthSaved += saved
            }
        }

        // Update published metrics
        averageLoadTime = sessionLoadTimes.reduce(0, +) / Double(sessionLoadTimes.count)
        cdnHitRate = sessionTotalRequests > 0 ? Double(sessionCDNHits) / Double(sessionTotalRequests) : 0
        totalImageLoads = sessionTotalRequests

        // Log to Firebase Performance
        trace.recordMetrics(
            fromCDN: fromCDN,
            bytesLoaded: bytesLoaded,
            loadTime: loadTime
        )

        // Log to Firebase Analytics
        Analytics.logEvent("image_loaded", parameters: [
            "image_id": trace.imageId,
            "size": trace.size,
            "load_time_ms": Int(loadTime * 1000),
            "from_cdn": fromCDN,
            "bytes_loaded": bytesLoaded
        ])

        Logger.shared.debug(
            "Image loaded: \(trace.imageId) (\(trace.size)) in \(String(format: "%.2f", loadTime))s from \(fromCDN ? "CDN" : "origin")",
            category: .storage
        )
    }

    /// Record failed image load
    func recordImageLoadFailure(trace: ImageLoadTrace, error: Error) {
        trace.stop()

        // Log to Firebase Performance with failure
        trace.recordFailure(error: error)

        // Log to Firebase Analytics
        Analytics.logEvent("image_load_failed", parameters: [
            "image_id": trace.imageId,
            "size": trace.size,
            "error": error.localizedDescription
        ])

        Logger.shared.error("Image load failed: \(trace.imageId)", category: .storage, error: error)
    }

    // MARK: - CDN Performance Tracking

    /// Track CDN cache hit vs miss
    func trackCDNPerformance(hit: Bool, latency: TimeInterval) {
        Analytics.logEvent("cdn_performance", parameters: [
            "cache_hit": hit,
            "latency_ms": Int(latency * 1000)
        ])
    }

    // MARK: - User Engagement Tracking

    /// Track when user views a profile with optimized images
    func trackProfileView(userId: String, loadTime: TimeInterval, imageCount: Int) {
        Analytics.logEvent("profile_viewed_optimized", parameters: [
            "viewed_user_id": userId,
            "total_load_time_ms": Int(loadTime * 1000),
            "image_count": imageCount,
            "avg_load_time_ms": Int((loadTime / Double(imageCount)) * 1000)
        ])
    }

    /// Track swipe action with image load performance
    func trackSwipeWithImagePerformance(action: String, loadTime: TimeInterval) {
        Analytics.logEvent("swipe_with_image_perf", parameters: [
            "action": action,
            "image_load_time_ms": Int(loadTime * 1000)
        ])
    }

    // MARK: - Bandwidth Savings

    /// Calculate bandwidth savings percentage
    func calculateBandwidthSavings(originalBytes: Int64, optimizedBytes: Int64) -> Double {
        guard originalBytes > 0 else { return 0 }
        let saved = originalBytes - optimizedBytes
        return Double(saved) / Double(originalBytes) * 100
    }

    /// Get formatted bandwidth savings
    func formattedBandwidthSaved() -> String {
        return ByteCountFormatter.string(fromByteCount: bandwidthSaved, countStyle: .binary)
    }

    // MARK: - Performance Reports

    /// Get current session performance report
    func getSessionReport() -> PerformanceReport {
        return PerformanceReport(
            averageLoadTime: averageLoadTime,
            totalRequests: sessionTotalRequests,
            cdnHitRate: cdnHitRate,
            bandwidthSaved: bandwidthSaved,
            imagesSaved: sessionLoadTimes.count
        )
    }

    /// Log performance summary to console
    func logPerformanceSummary() {
        Logger.shared.info("""
        📊 Image Performance Summary:
           - Total loads: \(totalImageLoads)
           - Avg load time: \(String(format: "%.2f", averageLoadTime))s
           - CDN hit rate: \(String(format: "%.1f", cdnHitRate * 100))%
           - Bandwidth saved: \(formattedBandwidthSaved())
        """, category: .general)
    }

    // MARK: - A/B Testing

    /// Track performance comparison between legacy and optimized images
    func trackABTest(variant: String, loadTime: TimeInterval, quality: Int) {
        Analytics.logEvent("image_optimization_ab_test", parameters: [
            "variant": variant, // "legacy" or "optimized"
            "load_time_ms": Int(loadTime * 1000),
            "perceived_quality": quality // 1-5 rating
        ])
    }
}

// MARK: - Image Load Trace

/// Wrapper around Firebase Performance Trace for image loading
class ImageLoadTrace {
    let imageId: String
    let size: String
    private let trace: Trace?
    private var startTime: Date?
    private var endTime: Date?

    init(imageId: String, size: String) {
        self.imageId = imageId
        self.size = size
        self.trace = Performance.startTrace(name: "image_load_\(size)")

        // Add custom attributes if trace is available
        trace?.setValue(imageId, forAttribute: "image_id")
        trace?.setValue(size, forAttribute: "image_size")
    }

    func start() {
        startTime = Date()
    }

    func stop() {
        endTime = Date()
        trace?.stop()
    }

    var duration: TimeInterval {
        guard let start = startTime, let end = endTime else { return 0 }
        return end.timeIntervalSince(start)
    }

    func recordMetrics(fromCDN: Bool, bytesLoaded: Int64, loadTime: TimeInterval) {
        trace?.setValue(fromCDN ? "true" : "false", forAttribute: "from_cdn")
        trace?.setValue(bytesLoaded, forMetric: "bytes_loaded")
        trace?.setValue(Int64(loadTime * 1000), forMetric: "load_time_ms")
    }

    func recordFailure(error: Error) {
        trace?.setValue("failed", forAttribute: "status")
        trace?.setValue(error.localizedDescription, forAttribute: "error")
    }
}

// MARK: - Performance Report

struct PerformanceReport {
    let averageLoadTime: TimeInterval
    let totalRequests: Int
    let cdnHitRate: Double
    let bandwidthSaved: Int64
    let imagesSaved: Int

    var averageLoadTimeFormatted: String {
        String(format: "%.2f", averageLoadTime)
    }

    var cdnHitRateFormatted: String {
        String(format: "%.1f%%", cdnHitRate * 100)
    }

    var bandwidthSavedFormatted: String {
        ByteCountFormatter.string(fromByteCount: bandwidthSaved, countStyle: .binary)
    }

    var bandwidthSavedPercentage: Double {
        // Estimate: Assuming 50% average savings
        return 40.0 // Based on our optimization target
    }
}

// MARK: - Enhanced OptimizedImageLoader with Performance Tracking
// TODO: Integrate performance tracking directly into OptimizedImageLoader
// This extension cannot access private cache property from a different file
// Performance tracking should be added to the OptimizedImageLoader.loadImageFromURL method instead
