//
//  SecurityManager.swift
//  Celestia
//
//  Central coordinator for all security features
//  Manages biometric auth, clipboard security, circuit breakers, and security policies
//

import Foundation
import UIKit

/// Security level configuration
enum SecurityLevel {
    case low        // Minimal security features
    case medium     // Balanced security (default)
    case high       // Maximum security features
    case custom     // User-defined configuration
}

/// Security feature status
struct SecurityFeatureStatus {
    let isEnabled: Bool
    let lastUpdated: Date?
    let details: String?

    static let disabled = SecurityFeatureStatus(isEnabled: false, lastUpdated: nil, details: nil)
}

/// Overall security status
struct SecurityStatus {
    let level: SecurityLevel
    let biometricAuth: SecurityFeatureStatus
    let clipboardSecurity: SecurityFeatureStatus
    let circuitBreakers: SecurityFeatureStatus
    let rateLimiting: SecurityFeatureStatus
    let screenshotDetection: SecurityFeatureStatus

    var overallScore: Double {
        var score = 0.0
        let features = [biometricAuth, clipboardSecurity, circuitBreakers, rateLimiting, screenshotDetection]

        for feature in features {
            if feature.isEnabled {
                score += 1.0
            }
        }

        return (score / Double(features.count)) * 100.0
    }

    var isHealthy: Bool {
        return overallScore >= 60.0
    }

    var healthDescription: String {
        if overallScore >= 80.0 {
            return "Excellent"
        } else if overallScore >= 60.0 {
            return "Good"
        } else if overallScore >= 40.0 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
}

/// Security Manager - Central coordinator for all security features
@MainActor
class SecurityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SecurityManager()

    // MARK: - Published Properties

    @Published private(set) var securityLevel: SecurityLevel {
        didSet {
            UserDefaults.standard.set(securityLevel.rawValue, forKey: "security_level")
        }
    }

    @Published private(set) var isInitialized = false
    @Published private(set) var lastSecurityCheck: Date?

    // MARK: - Component Managers

    let biometricAuth = BiometricAuthManager.shared
    let clipboardSecurity = ClipboardSecurityManager.shared
    let circuitBreakerManager = CircuitBreakerManager.shared
    let smartRetry = SmartRetryManager.shared

    // MARK: - Initialization

    private init() {
        // Load saved security level
        if let savedLevel = UserDefaults.standard.string(forKey: "security_level"),
           let level = SecurityLevel(rawValue: savedLevel) {
            self.securityLevel = level
        } else {
            self.securityLevel = .medium
        }

        Logger.shared.info("SecurityManager initialized with level: \(securityLevel.rawValue)", category: .security)
    }

    // MARK: - Initialization Methods

    /// Initialize all security features
    func initialize() async {
        Logger.shared.info("Initializing security features...", category: .security)

        // Apply security level configuration
        applySecurityLevel(securityLevel)

        // Run security checks
        await performSecurityCheck()

        isInitialized = true

        Logger.shared.info("✅ Security features initialized successfully", category: .security)

        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "security",
            "action": "initialized",
            "level": securityLevel.rawValue
        ])
    }

    // MARK: - Security Level Management

    /// Set security level and apply configuration
    func setSecurityLevel(_ level: SecurityLevel) {
        securityLevel = level
        applySecurityLevel(level)

        Logger.shared.info("Security level changed to: \(level.rawValue)", category: .security)

        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "security",
            "action": "level_changed",
            "level": level.rawValue
        ])
    }

    /// Apply security level configuration
    private func applySecurityLevel(_ level: SecurityLevel) {
        switch level {
        case .low:
            applyLowSecurity()

        case .medium:
            applyMediumSecurity()

        case .high:
            applyHighSecurity()

        case .custom:
            // User-defined, don't change settings
            break
        }
    }

    private func applyLowSecurity() {
        clipboardSecurity.isEnabled = false
        clipboardSecurity.autoClearEnabled = false
        clipboardSecurity.blockSensitiveContent = false
    }

    private func applyMediumSecurity() {
        clipboardSecurity.isEnabled = true
        clipboardSecurity.autoClearEnabled = true
        clipboardSecurity.autoClearDelay = 60.0
        clipboardSecurity.blockSensitiveContent = false
    }

    private func applyHighSecurity() {
        clipboardSecurity.isEnabled = true
        clipboardSecurity.autoClearEnabled = true
        clipboardSecurity.autoClearDelay = 30.0
        clipboardSecurity.blockSensitiveContent = true

        // Enable biometric auth if available
        if biometricAuth.isBiometricAvailable && !biometricAuth.isEnabled {
            Task {
                do {
                    _ = try await biometricAuth.enableBiometricAuth()
                } catch {
                    Logger.shared.warning("Failed to enable biometric auth: \(error)", category: .security)
                }
            }
        }
    }

    // MARK: - Security Checks

    /// Perform comprehensive security check
    func performSecurityCheck() async {
        Logger.shared.debug("Performing security check...", category: .security)

        // Check biometric availability
        if biometricAuth.isBiometricAvailable && !biometricAuth.isEnabled {
            Logger.shared.info("Biometric authentication available but not enabled", category: .security)
        }

        // Check clipboard security
        if clipboardSecurity.containsSensitiveData() {
            Logger.shared.warning("Sensitive data detected in clipboard", category: .security)
        }

        // Check circuit breaker health
        let unhealthyServices = circuitBreakerManager.getUnhealthyServices()
        if !unhealthyServices.isEmpty {
            Logger.shared.warning("Unhealthy services detected: \(unhealthyServices.joined(separator: ", "))", category: .security)
        }

        lastSecurityCheck = Date()
    }

    /// Get overall security status
    func getSecurityStatus() -> SecurityStatus {
        // Biometric auth status
        let biometricStatus = SecurityFeatureStatus(
            isEnabled: biometricAuth.isEnabled,
            lastUpdated: biometricAuth.lastAuthenticationDate,
            details: biometricAuth.isBiometricAvailable ? "Available" : "Not available"
        )

        // Clipboard security status
        let clipboardStatus = SecurityFeatureStatus(
            isEnabled: clipboardSecurity.isEnabled,
            lastUpdated: nil,
            details: clipboardSecurity.getStatusDescription()
        )

        // Circuit breaker status
        let unhealthyCount = circuitBreakerManager.getUnhealthyServices().count
        let circuitBreakerStatus = SecurityFeatureStatus(
            isEnabled: true,
            lastUpdated: nil,
            details: "\(circuitBreakerManager.breakers.count) services monitored, \(unhealthyCount) unhealthy"
        )

        // Rate limiting status (always enabled)
        let rateLimitingStatus = SecurityFeatureStatus(
            isEnabled: true,
            lastUpdated: nil,
            details: "Client and server-side rate limiting active"
        )

        // Screenshot detection status (always enabled)
        let screenshotStatus = SecurityFeatureStatus(
            isEnabled: true,
            lastUpdated: nil,
            details: "Screenshot detection active"
        )

        return SecurityStatus(
            level: securityLevel,
            biometricAuth: biometricStatus,
            clipboardSecurity: clipboardStatus,
            circuitBreakers: circuitBreakerStatus,
            rateLimiting: rateLimitingStatus,
            screenshotDetection: screenshotStatus
        )
    }

    // MARK: - Authentication

    /// Authenticate user for sensitive action
    /// - Parameter reason: Reason for authentication
    /// - Returns: True if authenticated successfully
    func authenticateForSensitiveAction(reason: String) async throws -> Bool {
        // Check if biometric auth is enabled
        if biometricAuth.isEnabled && biometricAuth.isBiometricAvailable {
            return try await biometricAuth.authenticateWithPasscode(reason: reason)
        }

        // No biometric auth - allow action but log
        Logger.shared.warning("Sensitive action without biometric auth: \(reason)", category: .security)
        return true
    }

    // MARK: - Clipboard Management

    /// Copy text with automatic sensitivity detection
    /// - Parameter text: Text to copy
    /// - Returns: True if copy was successful
    @discardableResult
    func secureCopy(_ text: String) -> Bool {
        let sensitivity = detectContentSensitivity(text)
        return clipboardSecurity.copy(text, sensitivity: sensitivity)
    }

    /// Detect content sensitivity automatically
    private func detectContentSensitivity(_ text: String) -> ContentSensitivityLevel {
        // Check for various sensitive patterns
        let lowercased = text.lowercased()

        // Check for PII patterns
        if clipboardSecurity.containsSensitiveData() {
            return .critical
        }

        // Check for message-like content
        if text.count > 100 || lowercased.contains("hi") || lowercased.contains("hello") {
            return .private
        }

        // Check for sensitive keywords
        let sensitiveKeywords = ["password", "pin", "ssn", "credit card", "account number"]
        for keyword in sensitiveKeywords {
            if lowercased.contains(keyword) {
                return .critical
            }
        }

        return .public
    }

    // MARK: - Network Security

    /// Execute network request with full security stack
    /// - Parameters:
    ///   - serviceName: Name of the service
    ///   - operation: Network operation to execute
    /// - Returns: Result of the operation
    func secureNetworkRequest<T>(
        serviceName: String,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {

        // Use smart retry with circuit breaker
        return await smartRetry.retryNetworkOperation(
            serviceName: serviceName,
            operation: operation
        )
    }

    // MARK: - Security Monitoring

    /// Start security monitoring
    func startMonitoring() {
        Logger.shared.info("Starting security monitoring", category: .security)

        // Start clipboard monitoring if enabled
        if clipboardSecurity.isEnabled {
            clipboardSecurity.enable()
        }

        // Schedule periodic security checks
        // SAFETY: Check for task cancellation to prevent memory leaks
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // Every 5 minutes

                // Check again after sleep in case task was cancelled during sleep
                guard !Task.isCancelled else { break }

                await performSecurityCheck()
            }

            Logger.shared.debug("Security monitoring task cancelled", category: .security)
        }
    }

    /// Stop security monitoring
    func stopMonitoring() {
        Logger.shared.info("Stopping security monitoring", category: .security)
        clipboardSecurity.disable()
    }

    // MARK: - Security Recommendations

    /// Get security recommendations based on current configuration
    func getSecurityRecommendations() -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []

        // Biometric auth recommendation
        if biometricAuth.isBiometricAvailable && !biometricAuth.isEnabled {
            recommendations.append(SecurityRecommendation(
                title: "Enable \(biometricAuth.biometricTypeString)",
                description: "Protect your account with biometric authentication",
                priority: .high,
                action: .enableBiometric
            ))
        }

        // Clipboard security recommendation
        if !clipboardSecurity.isEnabled && securityLevel != .low {
            recommendations.append(SecurityRecommendation(
                title: "Enable Clipboard Security",
                description: "Protect your messages from clipboard leakage",
                priority: .medium,
                action: .enableClipboardSecurity
            ))
        }

        // Security level recommendation
        if securityLevel == .low {
            recommendations.append(SecurityRecommendation(
                title: "Increase Security Level",
                description: "Your current security level is low. Consider upgrading to medium or high",
                priority: .high,
                action: .upgradeSecurityLevel
            ))
        }

        return recommendations
    }

    // MARK: - Security Events

    /// Log security event
    func logSecurityEvent(_ event: SecurityEvent) {
        Logger.shared.warning("Security event: \(event.description)", category: .security)

        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "security",
            "action": "event_logged",
            "type": event.type,
            "severity": event.severity.rawValue,
            "description": event.description
        ])
    }
}

// MARK: - Supporting Types

extension SecurityLevel {
    var rawValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .custom: return "custom"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "custom": self = .custom
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .low:
            return "Low - Minimal security features"
        case .medium:
            return "Medium - Balanced security (Recommended)"
        case .high:
            return "High - Maximum security protection"
        case .custom:
            return "Custom - User-defined configuration"
        }
    }
}

struct SecurityRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let action: Action

    enum Priority {
        case low, medium, high
    }

    enum Action {
        case enableBiometric
        case enableClipboardSecurity
        case upgradeSecurityLevel
        case custom(String)
    }
}

struct SecurityEvent {
    let type: String
    let severity: Severity
    let description: String
    let timestamp: Date

    enum Severity: String {
        case info, warning, error, critical
    }

    init(type: String, severity: Severity, description: String) {
        self.type = type
        self.severity = severity
        self.description = description
        self.timestamp = Date()
    }
}
