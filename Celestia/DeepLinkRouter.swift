//
//  DeepLinkRouter.swift
//  Celestia
//
//  Deep link routing system for Universal Links and URL schemes
//  Handles navigation from external sources (emails, web, referrals)
//

import Foundation
import SwiftUI

// MARK: - Deep Link Types

enum DeepLink: Equatable {
    case home
    case profile(userId: String)
    case match(matchId: String)
    case message(matchId: String)
    case referral(code: String)
    case emailVerification(token: String)
    case resetPassword(token: String)
    case upgrade
    case settings
    case notifications
    case unknown(url: URL)

    var analyticsName: String {
        switch self {
        case .home: return "deep_link_home"
        case .profile: return "deep_link_profile"
        case .match: return "deep_link_match"
        case .message: return "deep_link_message"
        case .referral: return "deep_link_referral"
        case .emailVerification: return "deep_link_email_verification"
        case .resetPassword: return "deep_link_reset_password"
        case .upgrade: return "deep_link_upgrade"
        case .settings: return "deep_link_settings"
        case .notifications: return "deep_link_notifications"
        case .unknown: return "deep_link_unknown"
        }
    }
}

// MARK: - Deep Link Router

@MainActor
class DeepLinkRouter: ObservableObject {

    // MARK: - Singleton

    static let shared = DeepLinkRouter()

    // MARK: - Published Properties

    @Published var currentDeepLink: DeepLink?
    @Published var isProcessingDeepLink = false

    // MARK: - Private Properties

    private var pendingDeepLink: DeepLink?
    private let logger = Logger.shared

    // MARK: - Initialization

    private init() {
        logger.info("DeepLinkRouter initialized", category: .general)
    }

    // MARK: - URL Handling

    /// Handle incoming URL from Universal Links or URL Scheme
    func handleURL(_ url: URL) -> Bool {
        logger.info("Handling URL: \(url.absoluteString)", category: .general)

        guard let deepLink = parseURL(url) else {
            logger.warning("Failed to parse URL: \(url.absoluteString)", category: .general)
            CrashlyticsManager.shared.logEvent("deep_link_parse_failed", parameters: [
                "url": url.absoluteString
            ])
            return false
        }

        // Track in analytics
        CrashlyticsManager.shared.logEvent(deepLink.analyticsName, parameters: [
            "url": url.absoluteString,
            "scheme": url.scheme ?? "unknown"
        ])

        return handle(deepLink: deepLink)
    }

    /// Handle a deep link navigation
    func handle(deepLink: DeepLink) -> Bool {
        logger.info("Handling deep link: \(deepLink)", category: .general)

        // Check if user is authenticated for protected routes
        if requiresAuthentication(deepLink) {
            guard AuthService.shared.userSession != nil else {
                logger.warning("Deep link requires authentication, storing for later", category: .general)
                pendingDeepLink = deepLink
                return false
            }
        }

        // Set current deep link for SwiftUI navigation
        isProcessingDeepLink = true
        currentDeepLink = deepLink

        // Process the deep link
        Task {
            await processDeepLink(deepLink)
            isProcessingDeepLink = false
        }

        return true
    }

    /// Process pending deep link (call after user signs in)
    func processPendingDeepLink() {
        guard let pending = pendingDeepLink else { return }
        logger.info("Processing pending deep link: \(pending)", category: .general)
        pendingDeepLink = nil
        _ = handle(deepLink: pending)
    }

    /// Clear pending deep link
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    // MARK: - URL Parsing

    private func parseURL(_ url: URL) -> DeepLink? {
        // Handle Universal Links (https://celestia.app/...)
        if url.scheme == "https" && (url.host == "celestia.app" || url.host == "www.celestia.app") {
            return parseUniversalLink(url)
        }

        // Handle URL Scheme (celestia://...)
        if url.scheme == "celestia" {
            return parseURLScheme(url)
        }

        return .unknown(url: url)
    }

    private func parseUniversalLink(_ url: URL) -> DeepLink? {
        let path = url.path
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return .home
        }

        switch components[0] {
        case "join":
            // celestia.app/join/REFERRAL_CODE
            guard components.count > 1 else { return .home }
            return .referral(code: components[1])

        case "profile":
            // celestia.app/profile/USER_ID
            guard components.count > 1 else { return .home }
            return .profile(userId: components[1])

        case "match":
            // celestia.app/match/MATCH_ID
            guard components.count > 1 else { return .home }
            return .match(matchId: components[1])

        case "message":
            // celestia.app/message/MATCH_ID
            guard components.count > 1 else { return .home }
            return .message(matchId: components[1])

        case "verify-email":
            // celestia.app/verify-email?token=TOKEN
            if let token = extractQueryParameter(from: url, parameter: "token") {
                return .emailVerification(token: token)
            }
            return .home

        case "reset-password":
            // celestia.app/reset-password?token=TOKEN
            if let token = extractQueryParameter(from: url, parameter: "token") {
                return .resetPassword(token: token)
            }
            return .home

        case "upgrade":
            // celestia.app/upgrade
            return .upgrade

        case "settings":
            // celestia.app/settings
            return .settings

        case "notifications":
            // celestia.app/notifications
            return .notifications

        default:
            return .unknown(url: url)
        }
    }

    private func parseURLScheme(_ url: URL) -> DeepLink? {
        guard let host = url.host else { return .unknown(url: url) }

        switch host {
        case "home":
            return .home

        case "join":
            // celestia://join?code=REFERRAL_CODE
            if let code = extractQueryParameter(from: url, parameter: "code") {
                return .referral(code: code)
            }
            return .home

        case "profile":
            // celestia://profile?id=USER_ID
            if let userId = extractQueryParameter(from: url, parameter: "id") {
                return .profile(userId: userId)
            }
            return .home

        case "match":
            // celestia://match?id=MATCH_ID
            if let matchId = extractQueryParameter(from: url, parameter: "id") {
                return .match(matchId: matchId)
            }
            return .home

        case "message":
            // celestia://message?id=MATCH_ID
            if let matchId = extractQueryParameter(from: url, parameter: "id") {
                return .message(matchId: matchId)
            }
            return .home

        case "upgrade":
            return .upgrade

        case "settings":
            return .settings

        case "notifications":
            return .notifications

        default:
            return .unknown(url: url)
        }
    }

    private func extractQueryParameter(from url: URL, parameter: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        return queryItems.first(where: { $0.name == parameter })?.value
    }

    // MARK: - Deep Link Processing

    private func processDeepLink(_ deepLink: DeepLink) async {
        switch deepLink {
        case .referral(let code):
            await handleReferralLink(code: code)

        case .emailVerification(let token):
            await handleEmailVerification(token: token)

        case .resetPassword(let token):
            await handleResetPassword(token: token)

        case .profile(let userId):
            logger.info("Navigating to profile: \(userId)", category: .general)

        case .match(let matchId):
            logger.info("Navigating to match: \(matchId)", category: .general)

        case .message(let matchId):
            logger.info("Navigating to message: \(matchId)", category: .general)

        case .upgrade:
            logger.info("Navigating to upgrade", category: .general)

        case .settings:
            logger.info("Navigating to settings", category: .general)

        case .notifications:
            logger.info("Navigating to notifications", category: .general)

        case .home:
            logger.info("Navigating to home", category: .general)

        case .unknown(let url):
            logger.warning("Unknown deep link: \(url.absoluteString)", category: .general)
        }
    }

    private func handleReferralLink(code: String) async {
        logger.info("Processing referral code: \(code)", category: .general)

        // Track referral link click
        CrashlyticsManager.shared.logEvent("referral_link_opened", parameters: [
            "code": code
        ])

        // Store referral code for use during signup
        UserDefaults.standard.set(code, forKey: "pendingReferralCode")

        // If user is not signed in, show signup flow
        // The signup flow will automatically use the pending referral code
    }

    private func handleEmailVerification(token: String) async {
        logger.info("Processing email verification token", category: .general)

        CrashlyticsManager.shared.logEvent("email_verification_link_opened")

        do {
            // Apply the verification action code
            try await AuthService.shared.verifyEmail(withToken: token)

            logger.info("Email verification completed successfully", category: .general)
            CrashlyticsManager.shared.logEvent("email_verification_success")

            // Show success message to user
            // You can use a toast/alert system here

        } catch {
            logger.error("Email verification failed", category: .general, error: error)
            // SECURITY FIX: Never send tokens to analytics/crash reporting
            CrashlyticsManager.shared.recordError(error, userInfo: [
                "action": "email_verification",
                "token_length": token.count,
                "token_hash": token.hashValue
            ])

            // Show error message to user
        }
    }

    private func handleResetPassword(token: String) async {
        logger.info("Processing password reset token", category: .general)

        CrashlyticsManager.shared.logEvent("password_reset_link_opened")

        // SECURITY FIX: Store password reset token in Keychain instead of UserDefaults
        // Keychain provides encrypted storage for sensitive data
        KeychainManager.shared.savePasswordResetToken(token)
    }

    // MARK: - Authentication Check

    private func requiresAuthentication(_ deepLink: DeepLink) -> Bool {
        switch deepLink {
        case .profile, .match, .message, .settings, .notifications, .upgrade:
            return true
        case .home, .referral, .emailVerification, .resetPassword, .unknown:
            return false
        }
    }

    // MARK: - URL Generation

    /// Generate a shareable referral link
    func generateReferralLink(code: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "celestia.app"
        components.path = "/join/\(code)"

        return components.url
    }

    /// Generate a profile share link
    func generateProfileLink(userId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "celestia.app"
        components.path = "/profile/\(userId)"

        return components.url
    }

    /// Generate an email verification link
    func generateEmailVerificationLink(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "celestia.app"
        components.path = "/verify-email"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        return components.url
    }

    /// Generate a password reset link
    func generatePasswordResetLink(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "celestia.app"
        components.path = "/reset-password"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        return components.url
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Handle deep links in SwiftUI views
    func handleDeepLinks() -> some View {
        self.onOpenURL { url in
            _ = DeepLinkRouter.shared.handleURL(url)
        }
    }
}

// MARK: - App Delegate Integration

extension DeepLinkRouter {
    /// Call this from AppDelegate or SceneDelegate
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return handleURL(url)
    }

    /// Call this from SceneDelegate for Universal Links
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        return handleURL(url)
    }
}

// MARK: - Convenience Extensions

extension DeepLinkRouter {
    /// Check if there's a pending referral code
    var pendingReferralCode: String? {
        UserDefaults.standard.string(forKey: "pendingReferralCode")
    }

    /// Clear pending referral code (call after user signs up)
    func clearPendingReferralCode() {
        UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
    }

    /// Check if there's a password reset token
    var passwordResetToken: String? {
        UserDefaults.standard.string(forKey: "passwordResetToken")
    }

    /// Clear password reset token
    func clearPasswordResetToken() {
        UserDefaults.standard.removeObject(forKey: "passwordResetToken")
    }
}
