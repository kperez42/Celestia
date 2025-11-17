//
//  CrashlyticsManager.swift
//  Celestia
//
//  Manages Firebase Crashlytics and Performance Monitoring
//  Provides crash reporting, custom logging, and performance tracking
//

import Foundation
import FirebaseCrashlytics
import FirebasePerformance

// MARK: - Crashlytics Manager

class CrashlyticsManager {

    // MARK: - Singleton

    static let shared = CrashlyticsManager()

    // MARK: - Properties

    private let crashlytics = Crashlytics.crashlytics()
    private var activeTraces: [String: Trace] = [:]
    private let traceQueue = DispatchQueue(label: "com.celestia.crashlytics.traces")

    // MARK: - Initialization

    private init() {
        setupCrashlytics()
    }

    private func setupCrashlytics() {
        #if DEBUG
        // In debug mode, you can choose to disable crash reporting
        // crashlytics.setCrashlyticsCollectionEnabled(false)
        Logger.shared.info("Crashlytics enabled in DEBUG mode", category: .analytics)
        #else
        crashlytics.setCrashlyticsCollectionEnabled(true)
        Logger.shared.info("Crashlytics enabled in RELEASE mode", category: .analytics)
        #endif
    }

    // MARK: - User Identification

    /// Set user identifier for crash reports
    func setUserId(_ userId: String) {
        crashlytics.setUserID(userId)
        Logger.shared.info("Crashlytics user ID set: \(userId)", category: .analytics)
    }

    /// Clear user identifier (on sign out)
    func clearUserId() {
        crashlytics.setUserID("")
        Logger.shared.info("Crashlytics user ID cleared", category: .analytics)
    }

    /// Set custom user attributes
    func setUserAttribute(key: String, value: String) {
        crashlytics.setCustomValue(value, forKey: key)
    }

    /// Set multiple user attributes
    func setUserAttributes(_ attributes: [String: Any]) {
        for (key, value) in attributes {
            crashlytics.setCustomValue(value, forKey: key)
        }
    }

    // MARK: - Custom Logging

    /// Log a message to Crashlytics (will be included in crash reports)
    func log(_ message: String) {
        crashlytics.log(message)
    }

    /// Log an event with custom data
    func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        var logMessage = "Event: \(event)"
        if !parameters.isEmpty {
            let paramsString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage += " | Params: \(paramsString)"
        }
        crashlytics.log(logMessage)
    }

    // MARK: - Error Reporting

    /// Record a non-fatal error
    func recordError(_ error: Error, userInfo: [String: Any] = [:]) {
        crashlytics.record(error: error, userInfo: userInfo)
        Logger.shared.error("Non-fatal error recorded to Crashlytics", category: .analytics, error: error)
    }

    /// Record a custom error
    func recordError(
        domain: String,
        code: Int,
        message: String,
        userInfo: [String: Any] = [:]
    ) {
        var fullUserInfo = userInfo
        fullUserInfo[NSLocalizedDescriptionKey] = message

        let error = NSError(domain: domain, code: code, userInfo: fullUserInfo)
        crashlytics.record(error: error)
        Logger.shared.error("Custom error recorded: \(message)", category: .analytics)
    }

    /// Record Celestia-specific errors
    func recordCelestiaError(_ error: CelestiaError, context: [String: Any] = [:]) {
        var userInfo = context
        userInfo["errorType"] = String(describing: error)
        userInfo["errorDescription"] = error.errorDescription ?? "Unknown"

        if let recoverySuggestion = error.recoverySuggestion {
            userInfo["recoverySuggestion"] = recoverySuggestion
        }

        let nsError = NSError(
            domain: "com.celestia.error",
            code: 1000,
            userInfo: userInfo
        )

        crashlytics.record(error: nsError)
        Logger.shared.error("Celestia error recorded: \(error)", category: .analytics)
    }

    // MARK: - Breadcrumbs

    /// Log a breadcrumb (for tracking user flow before crash)
    func logBreadcrumb(_ breadcrumb: String, category: String = "navigation") {
        let message = "[\(category)] \(breadcrumb)"
        crashlytics.log(message)
    }

    /// Log screen view
    func logScreenView(_ screenName: String) {
        logBreadcrumb("Viewed: \(screenName)", category: "screen")
    }

    /// Log user action
    func logUserAction(_ action: String, details: String = "") {
        var message = "Action: \(action)"
        if !details.isEmpty {
            message += " | \(details)"
        }
        logBreadcrumb(message, category: "action")
    }

    // MARK: - Performance Monitoring

    /// Start a performance trace
    func startTrace(name: String) {
        traceQueue.async { [weak self] in
            guard let self = self else { return }

            if self.activeTraces[name] != nil {
                Logger.shared.warning("Trace '\(name)' already active", category: .analytics)
                return
            }

            let trace = Performance.startTrace(name: name)
            self.activeTraces[name] = trace
            Logger.shared.debug("Started performance trace: \(name)", category: .analytics)
        }
    }

    /// Stop a performance trace
    func stopTrace(name: String) {
        traceQueue.async { [weak self] in
            guard let self = self else { return }

            guard let trace = self.activeTraces.removeValue(forKey: name) else {
                Logger.shared.warning("No active trace found for '\(name)'", category: .analytics)
                return
            }

            trace.stop()
            Logger.shared.debug("Stopped performance trace: \(name)", category: .analytics)
        }
    }

    /// Add metric to active trace
    func incrementMetric(traceName: String, metric: String, by value: Int64 = 1) {
        traceQueue.async { [weak self] in
            guard let self = self else { return }
            guard let trace = self.activeTraces[traceName] else {
                Logger.shared.warning("No active trace found for '\(traceName)'", category: .analytics)
                return
            }

            trace.incrementMetric(metric, by: value)
        }
    }

    /// Set attribute on active trace
    func setTraceAttribute(traceName: String, key: String, value: String) {
        traceQueue.async { [weak self] in
            guard let self = self else { return }
            guard let trace = self.activeTraces[traceName] else {
                Logger.shared.warning("No active trace found for '\(traceName)'", category: .analytics)
                return
            }

            trace.setValue(value, forAttribute: key)
        }
    }

    // MARK: - Network Monitoring

    /// Convert string HTTP method to Firebase HTTPMethod enum
    private func httpMethodFromString(_ method: String) -> HTTPMethod {
        switch method.uppercased() {
        case "GET":
            return .get
        case "POST":
            return .post
        case "PUT":
            return .put
        case "DELETE":
            return .delete
        case "HEAD":
            return .head
        case "PATCH":
            return .patch
        case "OPTIONS":
            return .options
        case "TRACE":
            return .trace
        case "CONNECT":
            return .connect
        default:
            return .get
        }
    }

    /// Track a network request
    func trackNetworkRequest(
        url: URL,
        httpMethod: String,
        startTime: Date,
        endTime: Date,
        responseCode: Int,
        requestSize: Int64 = 0,
        responseSize: Int64 = 0
    ) {
        let method = httpMethodFromString(httpMethod)
        let metric = HTTPMetric(url: url, httpMethod: method)

        metric?.responseCode = responseCode
        metric?.requestPayloadSize = Int(requestSize)
        metric?.responsePayloadSize = Int(responseSize)

        Logger.shared.debug(
            "Network request tracked: \(httpMethod) \(url.path) - \(responseCode)",
            category: .networking
        )
    }

    // MARK: - Crash Testing (DEBUG only)

    #if DEBUG
    /// Force a crash for testing (DEBUG only)
    func testCrash() {
        Logger.shared.warning("Test crash triggered!", category: .analytics)
        crashlytics.log("Test crash about to occur")
        assertionFailure("Test crash triggered from CrashlyticsManager")
    }

    /// Force a non-fatal error for testing
    func testNonFatalError() {
        let error = NSError(
            domain: "com.celestia.test",
            code: 9999,
            userInfo: [
                NSLocalizedDescriptionKey: "This is a test non-fatal error"
            ]
        )
        recordError(error, userInfo: ["testKey": "testValue"])
        Logger.shared.info("Test non-fatal error recorded", category: .analytics)
    }
    #endif

    // MARK: - Crash Context

    /// Add context that will be included in crash reports
    func setCrashContext(_ context: [String: Any]) {
        for (key, value) in context {
            crashlytics.setCustomValue(value, forKey: key)
        }
    }

    /// Clear crash context
    func clearCrashContext(keys: [String]) {
        for key in keys {
            crashlytics.setCustomValue(nil, forKey: key)
        }
    }

    // MARK: - App State

    /// Log app state for debugging
    func logAppState() {
        let state: [String: Any] = [
            "memoryUsage": getMemoryUsage(),
            "diskSpace": getAvailableDiskSpace(),
            "batteryLevel": getBatteryLevel(),
            "networkType": getNetworkType()
        ]

        setCrashContext(state)
        Logger.shared.debug("App state logged to Crashlytics", category: .analytics)
    }

    // MARK: - Helper Methods

    private func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return "Unknown" }

        let usedMB = Double(info.resident_size) / 1024 / 1024
        return String(format: "%.2f MB", usedMB)
    }

    private func getAvailableDiskSpace() -> String {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            let freeGB = Double(freeSize) / 1024 / 1024 / 1024
            return String(format: "%.2f GB", freeGB)
        }
        return "Unknown"
    }

    private func getBatteryLevel() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false

        if level < 0 {
            return "Unknown"
        }
        return String(format: "%.0f%%", level * 100)
    }

    private func getNetworkType() -> String {
        // Simplified network type detection
        // In production, use Reachability or Network framework
        return "Unknown"
    }
}

// MARK: - Convenience Extensions

extension CrashlyticsManager {

    /// Track authentication event
    func trackAuthEvent(_ event: String, success: Bool, error: Error? = nil) {
        logEvent("auth_\(event)", parameters: [
            "success": success,
            "error": error?.localizedDescription ?? "none"
        ])

        if let error = error {
            recordError(error, userInfo: ["authEvent": event])
        }
    }

    /// Track match event
    func trackMatchEvent(_ event: String, matchId: String? = nil) {
        var params: [String: Any] = ["event": event]
        if let matchId = matchId {
            params["matchId"] = matchId
        }
        logEvent("match_\(event)", parameters: params)
    }

    /// Track message event
    func trackMessageEvent(_ event: String, success: Bool) {
        logEvent("message_\(event)", parameters: ["success": success])
    }

    /// Track purchase event
    func trackPurchaseEvent(_ event: String, productId: String?, success: Bool, error: Error? = nil) {
        var params: [String: Any] = [
            "success": success
        ]
        if let productId = productId {
            params["productId"] = productId
        }
        if let error = error {
            params["error"] = error.localizedDescription
        }

        logEvent("purchase_\(event)", parameters: params)

        if let error = error {
            recordError(error, userInfo: ["purchaseEvent": event])
        }
    }
}

// MARK: - UIKit Integration

import UIKit

extension CrashlyticsManager {

    /// Setup automatic crash context
    func setupAutomaticContext() {
        // Log app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            setUserAttribute(key: "app_version", value: "\(version) (\(build))")
        }

        // Log device info
        setUserAttribute(key: "device_model", value: UIDevice.current.model)
        setUserAttribute(key: "ios_version", value: UIDevice.current.systemVersion)

        // Log app state
        logAppState()
    }
}
