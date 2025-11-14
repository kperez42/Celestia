//
//  LocalizationManager.swift
//  Celestia
//
//  Centralized localization management
//  Provides type-safe string access and language switching
//

import Foundation
import SwiftUI

// MARK: - Localization Manager

@MainActor
class LocalizationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LocalizationManager()

    // MARK: - Published Properties

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.code, forKey: "AppLanguage")
            NotificationCenter.default.post(name: .languageChanged, object: nil)
            Logger.shared.info("Language changed to: \(currentLanguage.name)", category: .general)
        }
    }

    // MARK: - Supported Languages

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case portuguese = "pt"
        case italian = "it"
        case japanese = "ja"
        case korean = "ko"
        case chinese = "zh"

        var id: String { rawValue }

        var code: String { rawValue }

        var name: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            case .portuguese: return "Português"
            case .italian: return "Italiano"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .chinese: return "中文"
            }
        }

        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .spanish: return "🇪🇸"
            case .french: return "🇫🇷"
            case .german: return "🇩🇪"
            case .portuguese: return "🇵🇹"
            case .italian: return "🇮🇹"
            case .japanese: return "🇯🇵"
            case .korean: return "🇰🇷"
            case .chinese: return "🇨🇳"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved language or use device language
        if let savedLanguageCode = UserDefaults.standard.string(forKey: "AppLanguage"),
           let savedLanguage = Language(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        } else {
            self.currentLanguage = Self.deviceLanguage()
        }
    }

    // MARK: - Language Detection

    private static func deviceLanguage() -> Language {
        let deviceLanguageCode = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        return Language(rawValue: String(deviceLanguageCode)) ?? .english
    }

    // MARK: - Localized Strings

    func string(for key: LocalizedStringKey, comment: String = "") -> String {
        return NSLocalizedString(
            String(describing: key),
            bundle: Bundle.main,
            comment: comment
        )
    }

    // MARK: - String Formatting

    func formattedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageChanged = Notification.Name("com.celestia.languageChanged")
}

// MARK: - Localized String Keys

enum LocalizedStrings {

    // MARK: - Common

    enum Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let save = "common.save"
        static let delete = "common.delete"
        static let edit = "common.edit"
        static let done = "common.done"
        static let next = "common.next"
        static let back = "common.back"
        static let yes = "common.yes"
        static let no = "common.no"
        static let loading = "common.loading"
        static let error = "common.error"
        static let success = "common.success"
    }

    // MARK: - Authentication

    enum Auth {
        static let signIn = "auth.sign_in"
        static let signUp = "auth.sign_up"
        static let signOut = "auth.sign_out"
        static let email = "auth.email"
        static let password = "auth.password"
        static let fullName = "auth.full_name"
        static let age = "auth.age"
        static let forgotPassword = "auth.forgot_password"
        static let resetPassword = "auth.reset_password"
        static let createAccount = "auth.create_account"
        static let alreadyHaveAccount = "auth.already_have_account"
        static let dontHaveAccount = "auth.dont_have_account"
        static let verifyEmail = "auth.verify_email"
        static let emailVerified = "auth.email_verified"
        static let resendVerification = "auth.resend_verification"
    }

    // MARK: - Profile

    enum Profile {
        static let profile = "profile.profile"
        static let editProfile = "profile.edit_profile"
        static let bio = "profile.bio"
        static let photos = "profile.photos"
        static let addPhoto = "profile.add_photo"
        static let settings = "profile.settings"
        static let age = "profile.age"
        static let location = "profile.location"
        static let gender = "profile.gender"
        static let lookingFor = "profile.looking_for"
        static let male = "profile.male"
        static let female = "profile.female"
        static let nonBinary = "profile.non_binary"
    }

    // MARK: - Swipe

    enum Swipe {
        static let discover = "swipe.discover"
        static let like = "swipe.like"
        static let dislike = "swipe.dislike"
        static let superLike = "swipe.super_like"
        static let itsAMatch = "swipe.its_a_match"
        static let sendMessage = "swipe.send_message"
        static let keepSwiping = "swipe.keep_swiping"
        static let noMoreProfiles = "swipe.no_more_profiles"
    }

    // MARK: - Matches

    enum Matches {
        static let matches = "matches.matches"
        static let newMatch = "matches.new_match"
        static let noMatches = "matches.no_matches"
        static let unmatch = "matches.unmatch"
        static let unmatchConfirm = "matches.unmatch_confirm"
        static let matchedWith = "matches.matched_with"
    }

    // MARK: - Messages

    enum Messages {
        static let messages = "messages.messages"
        static let typeMessage = "messages.type_message"
        static let send = "messages.send"
        static let noMessages = "messages.no_messages"
        static let delivered = "messages.delivered"
        static let read = "messages.read"
        static let typing = "messages.typing"
    }

    // MARK: - Premium

    enum Premium {
        static let premium = "premium.premium"
        static let upgradeToPremium = "premium.upgrade_to_premium"
        static let monthlyPlan = "premium.monthly_plan"
        static let yearlyPlan = "premium.yearly_plan"
        static let subscribe = "premium.subscribe"
        static let restorePurchases = "premium.restore_purchases"
        static let features = "premium.features"
        static let unlimitedLikes = "premium.unlimited_likes"
        static let seeWhoLikesYou = "premium.see_who_likes_you"
        static let rewind = "premium.rewind"
        static let boostProfile = "premium.boost_profile"
    }

    // MARK: - Settings

    enum Settings {
        static let settings = "settings.settings"
        static let account = "settings.account"
        static let notifications = "settings.notifications"
        static let privacy = "settings.privacy"
        static let language = "settings.language"
        static let help = "settings.help"
        static let about = "settings.about"
        static let termsOfService = "settings.terms_of_service"
        static let privacyPolicy = "settings.privacy_policy"
    }

    // MARK: - Errors

    enum Errors {
        static let genericError = "error.generic"
        static let networkError = "error.network"
        static let invalidEmail = "error.invalid_email"
        static let invalidPassword = "error.invalid_password"
        static let emailAlreadyInUse = "error.email_already_in_use"
        static let weakPassword = "error.weak_password"
        static let userNotFound = "error.user_not_found"
        static let wrongPassword = "error.wrong_password"
    }
}

// MARK: - SwiftUI Extension

extension String {
    /// Localize a string using the current language
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Localize a string with arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

extension Text {
    /// Create localized Text
    init(localized key: String) {
        self.init(NSLocalizedString(key, comment: ""))
    }
}

// MARK: - Date Formatting

extension LocalizationManager {

    /// Format date according to current locale
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: date)
    }

    /// Format time according to current locale
    func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: date)
    }

    /// Format date and time according to current locale
    func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: date)
    }

    /// Format relative date (e.g., "2 hours ago")
    func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: currentLanguage.code)
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Number Formatting

extension LocalizationManager {

    /// Format number according to current locale
    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format currency according to current locale
    func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    /// Format percentage according to current locale
    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale(identifier: currentLanguage.code)
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)%"
    }
}
