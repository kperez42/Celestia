//
//  ClipboardSecurityManager.swift
//  Celestia
//
//  Manages clipboard security to protect sensitive user data
//  Prevents accidental leakage of private messages and personal information
//

import Foundation
import UIKit

/// Clipboard security policy
enum ClipboardSecurityPolicy {
    case unrestricted      // No restrictions (default iOS behavior)
    case restricted        // Limited clipboard access with auto-clear
    case strict            // Disabled clipboard for sensitive content
}

/// Content sensitivity level
enum ContentSensitivityLevel {
    case `public`          // Can be freely copied
    case `private`         // Should be protected
    case sensitive         // Highly sensitive (messages, personal info)
    case critical          // Never allow copying (passwords, etc.)
}

/// Clipboard security manager
@MainActor
class ClipboardSecurityManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "clipboard_security_enabled")
            if isEnabled {
                Logger.shared.info("Clipboard security enabled", category: .security)
            }
        }
    }

    @Published var autoClearEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoClearEnabled, forKey: "clipboard_auto_clear_enabled")
        }
    }

    @Published var autoClearDelay: TimeInterval {
        didSet {
            UserDefaults.standard.set(autoClearDelay, forKey: "clipboard_auto_clear_delay")
        }
    }

    @Published var blockSensitiveContent: Bool {
        didSet {
            UserDefaults.standard.set(blockSensitiveContent, forKey: "clipboard_block_sensitive")
        }
    }

    // MARK: - Properties

    static let shared = ClipboardSecurityManager()

    private var autoClearTimer: Timer?
    private var lastCopiedContent: String?
    private var copiedContentTimestamp: Date?
    private var clipboardObserver: NSObjectProtocol?

    // MARK: - Configuration

    struct Config {
        static let defaultAutoClearDelay: TimeInterval = 30.0 // 30 seconds
        static let messageAutoClearDelay: TimeInterval = 60.0 // 1 minute
        static let sensitiveAutoClearDelay: TimeInterval = 10.0 // 10 seconds
    }

    // MARK: - Initialization

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "clipboard_security_enabled")
        self.autoClearEnabled = UserDefaults.standard.bool(forKey: "clipboard_auto_clear_enabled")
        self.autoClearDelay = UserDefaults.standard.double(forKey: "clipboard_auto_clear_delay")
        self.blockSensitiveContent = UserDefaults.standard.bool(forKey: "clipboard_block_sensitive")

        // Set default delay if not configured
        if autoClearDelay == 0 {
            autoClearDelay = Config.defaultAutoClearDelay
        }

        // Start monitoring clipboard if enabled
        if isEnabled {
            startMonitoring()
        }
    }

    // MARK: - Public Methods

    /// Copy text to clipboard with security policies
    /// - Parameters:
    ///   - text: Text to copy
    ///   - sensitivity: Sensitivity level of content
    /// - Returns: True if copy was allowed
    @discardableResult
    func copy(_ text: String, sensitivity: ContentSensitivityLevel = .public) -> Bool {
        guard isEnabled else {
            // Security disabled - use standard clipboard
            UIPasteboard.general.string = text
            return true
        }

        // Check if content should be blocked
        if blockSensitiveContent && shouldBlockCopy(sensitivity: sensitivity) {
            Logger.shared.warning("Clipboard copy blocked for sensitive content", category: .security)

            AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                "feature": "clipboard_security",
                "action": "copy_blocked",
                "sensitivity": sensitivity.rawValue
            ])

            return false
        }

        // Copy to clipboard
        UIPasteboard.general.string = text
        lastCopiedContent = text
        copiedContentTimestamp = Date()

        Logger.shared.debug("Content copied to clipboard (sensitivity: \(sensitivity.rawValue))", category: .security)

        // Schedule auto-clear if enabled
        if autoClearEnabled {
            scheduleAutoClear(delay: getAutoClearDelay(for: sensitivity))
        }

        // Track clipboard usage
        trackClipboardUsage(sensitivity: sensitivity, action: "copy")

        return true
    }

    /// Paste text from clipboard
    /// - Returns: Clipboard content if allowed
    func paste() -> String? {
        guard isEnabled else {
            return UIPasteboard.general.string
        }

        let content = UIPasteboard.general.string

        Logger.shared.debug("Content pasted from clipboard", category: .security)

        // Track clipboard usage
        if content != nil {
            trackClipboardUsage(sensitivity: .public, action: "paste")
        }

        return content
    }

    /// Clear clipboard immediately
    func clearClipboard() {
        UIPasteboard.general.string = ""
        lastCopiedContent = nil
        copiedContentTimestamp = nil
        autoClearTimer?.invalidate()

        Logger.shared.info("Clipboard cleared", category: .security)

        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "clipboard_security",
            "action": "cleared"
        ])
    }

    /// Check if clipboard contains sensitive data
    func containsSensitiveData() -> Bool {
        guard let content = UIPasteboard.general.string else {
            return false
        }

        return detectSensitiveContent(content)
    }

    /// Enable clipboard security
    func enable() {
        isEnabled = true
        startMonitoring()
    }

    /// Disable clipboard security
    func disable() {
        isEnabled = false
        stopMonitoring()
        autoClearTimer?.invalidate()
    }

    // MARK: - Private Methods

    /// Check if content should be blocked from copying
    private func shouldBlockCopy(sensitivity: ContentSensitivityLevel) -> Bool {
        switch sensitivity {
        case .public, .private:
            return false
        case .sensitive:
            return blockSensitiveContent
        case .critical:
            return true // Always block critical content
        }
    }

    /// Get auto-clear delay based on content sensitivity
    private func getAutoClearDelay(for sensitivity: ContentSensitivityLevel) -> TimeInterval {
        switch sensitivity {
        case .public:
            return autoClearDelay
        case .private:
            return min(autoClearDelay, Config.messageAutoClearDelay)
        case .sensitive, .critical:
            return Config.sensitiveAutoClearDelay
        }
    }

    /// Schedule automatic clipboard clearing
    private func scheduleAutoClear(delay: TimeInterval) {
        // Invalidate existing timer
        autoClearTimer?.invalidate()

        // Create new timer
        autoClearTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearClipboard()
                Logger.shared.info("Clipboard auto-cleared after \(delay)s", category: .security)
            }
        }
    }

    /// Detect sensitive content in text
    private func detectSensitiveContent(_ text: String) -> Bool {
        // Check for patterns that indicate sensitive data

        // Email addresses - REFACTORED: Use ValidationHelper for consistency
        // Check if text contains any email-like pattern
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if ValidationHelper.isValidEmail(word) {
                return true
            }
        }

        // Phone numbers
        let phoneRegex = "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"
        if text.range(of: phoneRegex, options: .regularExpression) != nil {
            return true
        }

        // Credit card numbers (basic check)
        let cardRegex = "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
        if text.range(of: cardRegex, options: .regularExpression) != nil {
            return true
        }

        // Social security numbers
        let ssnRegex = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        if text.range(of: ssnRegex, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Start monitoring clipboard changes
    private func startMonitoring() {
        clipboardObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleClipboardChange()
            }
        }
    }

    /// Stop monitoring clipboard changes
    private func stopMonitoring() {
        if let observer = clipboardObserver {
            NotificationCenter.default.removeObserver(observer)
            clipboardObserver = nil
        }
    }

    /// Handle clipboard content change
    private func handleClipboardChange() {
        guard isEnabled else { return }

        let currentContent = UIPasteboard.general.string

        // Check if content changed externally (not by our app)
        if currentContent != lastCopiedContent {
            Logger.shared.debug("External clipboard change detected", category: .security)

            // Check if new content is sensitive
            if let content = currentContent, detectSensitiveContent(content) {
                Logger.shared.warning("Sensitive data detected in clipboard", category: .security)

                if autoClearEnabled {
                    scheduleAutoClear(delay: Config.sensitiveAutoClearDelay)
                }
            }
        }
    }

    /// Track clipboard usage analytics
    private func trackClipboardUsage(sensitivity: ContentSensitivityLevel, action: String) {
        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "clipboard_security",
            "action": action,
            "sensitivity": sensitivity.rawValue,
            "security_enabled": isEnabled,
            "auto_clear_enabled": autoClearEnabled
        ])
    }

    // MARK: - Utility Methods

    /// Get time since last copy
    var timeSinceLastCopy: TimeInterval? {
        guard let timestamp = copiedContentTimestamp else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }

    /// Check if clipboard has content
    var hasContent: Bool {
        return UIPasteboard.general.hasStrings
    }

    /// Get clipboard content length
    var contentLength: Int {
        return UIPasteboard.general.string?.count ?? 0
    }
}

// MARK: - Content Sensitivity Extension

extension ContentSensitivityLevel {
    var rawValue: String {
        switch self {
        case .public:
            return "public"
        case .private:
            return "private"
        case .sensitive:
            return "sensitive"
        case .critical:
            return "critical"
        }
    }

    var description: String {
        switch self {
        case .public:
            return "Public content"
        case .private:
            return "Private content"
        case .sensitive:
            return "Sensitive content"
        case .critical:
            return "Critical content"
        }
    }

    var icon: String {
        switch self {
        case .public:
            return "doc.text"
        case .private:
            return "lock"
        case .sensitive:
            return "lock.shield"
        case .critical:
            return "exclamationmark.shield"
        }
    }
}

// MARK: - UI Helper Extensions

extension ClipboardSecurityManager {
    /// Show clipboard security alert
    func showSecurityAlert(message: String) {
        // This can be used to show alerts when clipboard operations are blocked
        Logger.shared.warning("Clipboard security alert: \(message)", category: .security)
    }

    /// Get security status description
    func getStatusDescription() -> String {
        if !isEnabled {
            return "Clipboard security is disabled"
        }

        var status = "Clipboard security is enabled"

        if autoClearEnabled {
            status += " with auto-clear after \(Int(autoClearDelay))s"
        }

        if blockSensitiveContent {
            status += " (blocking sensitive content)"
        }

        return status
    }
}
