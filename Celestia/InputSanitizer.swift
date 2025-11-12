//
//  InputSanitizer.swift
//  Celestia
//
//  Centralized input sanitization to prevent injection attacks and malformed data
//  Eliminates code duplication across services
//

import Foundation

/// Input sanitization utility
/// Provides centralized, consistent sanitization logic across the app
enum InputSanitizer {

    // MARK: - Sanitization Levels

    /// Basic sanitization - trim whitespace only
    /// Use for: email addresses, simple text fields
    static func basic(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Standard sanitization - remove dangerous patterns
    /// Use for: messages, bio, profile fields
    static func standard(_ text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove potentially dangerous HTML/script tags
        let dangerousPatterns = [
            "<script>", "</script>",
            "<iframe>", "</iframe>",
            "javascript:",
            "onerror=", "onclick=", "onload="
        ]

        for pattern in dangerousPatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        // Remove null bytes and control characters
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined()
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        return sanitized
    }

    /// Strict sanitization - for sensitive fields
    /// Use for: usernames, display names, referral codes
    static func strict(_ text: String) -> String {
        var sanitized = standard(text)

        // Remove additional potentially dangerous characters
        let forbiddenChars = CharacterSet(charactersIn: "<>{}[]|\\^`\"'")
        sanitized = sanitized.components(separatedBy: forbiddenChars).joined()

        // Collapse multiple spaces to single space
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitize referral code - uppercase and trim
    /// Use for: referral codes
    static func referralCode(_ code: String) -> String {
        return code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    // MARK: - Specialized Sanitization

    /// Sanitize email - lowercase and trim
    static func email(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Sanitize URL - trim and validate format
    static func url(_ urlString: String) -> String? {
        let sanitized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic URL validation
        guard let url = URL(string: sanitized),
              (url.scheme == "http" || url.scheme == "https") else {
            return nil
        }

        return sanitized
    }

    /// Sanitize numeric string - remove non-digits
    static func numericString(_ text: String) -> String {
        return text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    /// Sanitize alphanumeric string - keep only letters, numbers, spaces
    static func alphanumeric(_ text: String, allowSpaces: Bool = true) -> String {
        var allowed = CharacterSet.alphanumerics
        if allowSpaces {
            allowed.insert(charactersIn: " ")
        }

        let filtered = text.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation Helpers

    /// Check if text is empty after sanitization
    static func isEmpty(_ text: String, level: SanitizationLevel = .basic) -> Bool {
        switch level {
        case .basic:
            return basic(text).isEmpty
        case .standard:
            return standard(text).isEmpty
        case .strict:
            return strict(text).isEmpty
        }
    }

    /// Get sanitized length
    static func length(_ text: String, level: SanitizationLevel = .basic) -> Int {
        switch level {
        case .basic:
            return basic(text).count
        case .standard:
            return standard(text).count
        case .strict:
            return strict(text).count
        }
    }
}

// MARK: - Sanitization Level Enum

enum SanitizationLevel {
    case basic      // Trim only
    case standard   // Remove dangerous patterns
    case strict     // Maximum sanitization
}

// MARK: - String Extension

extension String {
    /// Convenience method for basic sanitization
    var sanitized: String {
        return InputSanitizer.basic(self)
    }

    /// Convenience method for standard sanitization
    var sanitizedStandard: String {
        return InputSanitizer.standard(self)
    }

    /// Convenience method for strict sanitization
    var sanitizedStrict: String {
        return InputSanitizer.strict(self)
    }
}
