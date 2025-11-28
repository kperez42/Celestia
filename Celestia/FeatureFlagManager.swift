//
//  FeatureFlagManager.swift
//  Celestia
//
//  Feature flags system for A/B testing and gradual rollouts
//  Supports remote configuration via Firebase Remote Config
//

import Foundation
import SwiftUI
import FirebaseRemoteConfig
import Combine

// MARK: - Feature Flag Manager

@MainActor
class FeatureFlagManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FeatureFlagManager()

    // MARK: - Published Properties

    @Published private(set) var isReady = false
    @Published private(set) var lastFetchDate: Date?

    // MARK: - Properties

    private let remoteConfig: RemoteConfig
    private var localOverrides: [String: Any] = [:]
    private let defaults: [String: NSObject]

    // MARK: - Configuration

    private let minimumFetchInterval: TimeInterval = 3600 // 1 hour in production
    private let developmentFetchInterval: TimeInterval = 0 // Instant in development

    // MARK: - Initialization

    private init() {
        self.remoteConfig = RemoteConfig.remoteConfig()

        // Set default values for all feature flags
        self.defaults = FeatureFlag.allFlags.reduce(into: [:]) { result, flag in
            result[flag.key] = flag.defaultValue as? NSObject ?? NSNumber(value: 0)
        }

        configureRemoteConfig()
        loadLocalOverrides()
    }

    // MARK: - Setup

    func initialize() async {
        Logger.shared.info("Initializing FeatureFlagManager", category: .general)

        do {
            try await fetchAndActivate()
            isReady = true
            Logger.shared.info("Feature flags initialized successfully", category: .general)
        } catch {
            Logger.shared.error("Failed to initialize feature flags", category: .general, error: error)
            // Use defaults if fetch fails
            isReady = true
        }
    }

    // MARK: - Public Methods

    /// Check if a feature flag is enabled
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        // Check local overrides first (for testing)
        if let override = localOverrides[flag.key] as? Bool {
            Logger.shared.debug("Feature flag '\(flag.key)' using local override: \(override)", category: .general)
            return override
        }

        // Check remote config
        let value = remoteConfig.configValue(forKey: flag.key).boolValue

        Logger.shared.debug("Feature flag '\(flag.key)' = \(value)", category: .general)

        // Track flag usage in analytics
        CrashlyticsManager.shared.logEvent("feature_flag_check", parameters: [
            "flag": flag.key,
            "value": value
        ])

        return value
    }

    /// Get string value for a feature flag
    func stringValue(_ flag: FeatureFlag) -> String {
        if let override = localOverrides[flag.key] as? String {
            return override
        }

        let value = remoteConfig.configValue(forKey: flag.key).stringValue
        return value ?? (flag.defaultValue as? String ?? "")
    }

    /// Get integer value for a feature flag
    func intValue(_ flag: FeatureFlag) -> Int {
        if let override = localOverrides[flag.key] as? Int {
            return override
        }

        return remoteConfig.configValue(forKey: flag.key).numberValue.intValue
    }

    /// Get double value for a feature flag
    func doubleValue(_ flag: FeatureFlag) -> Double {
        if let override = localOverrides[flag.key] as? Double {
            return override
        }

        return remoteConfig.configValue(forKey: flag.key).numberValue.doubleValue
    }

    /// Get JSON object for a feature flag
    func jsonValue(_ flag: FeatureFlag) -> [String: Any]? {
        if let override = localOverrides[flag.key] as? [String: Any] {
            return override
        }

        let data = remoteConfig.configValue(forKey: flag.key).dataValue

        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    /// Set local override for testing
    func setOverride(_ flag: FeatureFlag, value: Any) {
        localOverrides[flag.key] = value
        saveLocalOverrides()
        Logger.shared.info("Set local override for '\(flag.key)': \(value)", category: .general)
        objectWillChange.send()
    }

    /// Clear local override
    func clearOverride(_ flag: FeatureFlag) {
        localOverrides.removeValue(forKey: flag.key)
        saveLocalOverrides()
        Logger.shared.info("Cleared local override for '\(flag.key)'", category: .general)
        objectWillChange.send()
    }

    /// Clear all local overrides
    func clearAllOverrides() {
        localOverrides.removeAll()
        saveLocalOverrides()
        Logger.shared.info("Cleared all local overrides", category: .general)
        objectWillChange.send()
    }

    /// Fetch latest feature flags from remote
    func refresh() async throws {
        try await fetchAndActivate()
        lastFetchDate = Date()
        objectWillChange.send()
    }

    /// Get all feature flags with their values
    func getAllFlags() -> [String: Any] {
        var flags: [String: Any] = [:]

        for flag in FeatureFlag.allFlags {
            if let override = localOverrides[flag.key] {
                flags[flag.key] = override
            } else {
                flags[flag.key] = remoteConfig.configValue(forKey: flag.key).boolValue
            }
        }

        return flags
    }

    // MARK: - Private Methods

    private func configureRemoteConfig() {
        let settings = RemoteConfigSettings()

        #if DEBUG
        settings.minimumFetchInterval = developmentFetchInterval
        #else
        settings.minimumFetchInterval = minimumFetchInterval
        #endif

        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaults)

        Logger.shared.debug("Remote config configured with \(defaults.count) defaults", category: .general)
    }

    private func fetchAndActivate() async throws {
        let status = try await remoteConfig.fetchAndActivate()

        switch status {
        case .successFetchedFromRemote:
            Logger.shared.info("Feature flags fetched from remote", category: .general)
        case .successUsingPreFetchedData:
            Logger.shared.info("Using pre-fetched feature flags", category: .general)
        case .error:
            Logger.shared.error("Error fetching feature flags", category: .general)
            throw FeatureFlagError.fetchFailed
        @unknown default:
            break
        }
    }

    private func loadLocalOverrides() {
        if let data = UserDefaults.standard.data(forKey: "FeatureFlagOverrides"),
           let overrides = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            localOverrides = overrides
            Logger.shared.debug("Loaded \(overrides.count) local overrides", category: .general)
        }
    }

    private func saveLocalOverrides() {
        if let data = try? JSONSerialization.data(withJSONObject: localOverrides) {
            UserDefaults.standard.set(data, forKey: "FeatureFlagOverrides")
        }
    }
}

// MARK: - Feature Flags Definition

enum FeatureFlag: String, CaseIterable {

    // MARK: - User Features

    case enablePremiumFeatures = "enable_premium_features"
    case enableSuperLike = "enable_super_like"
    case enableRewind = "enable_rewind"
    case enableBoost = "enable_boost"
    case enableReadReceipts = "enable_read_receipts"

    // MARK: - Discovery

    case enableSmartMatching = "enable_smart_matching"
    case maxDailyLikes = "max_daily_likes"
    case maxDailySuperLikes = "max_daily_super_likes"
    case discoveryRadius = "discovery_radius_km"

    // MARK: - Social

    case enableVideoChat = "enable_video_chat"
    case enableVoiceNotes = "enable_voice_notes"
    case enableGiphy = "enable_giphy"
    case enableStickers = "enable_stickers"

    // MARK: - Safety & Moderation

    case enableContentModeration = "enable_content_moderation"
    case enableProfileReview = "enable_profile_review"
    case autoModerateMessages = "auto_moderate_messages"

    // MARK: - Referral & Growth

    case enableReferralProgram = "enable_referral_program"
    case referralRewardCredits = "referral_reward_credits"
    case enableSocialSharing = "enable_social_sharing"

    // MARK: - Monetization

    case premiumMonthlyPrice = "premium_monthly_price"
    case premiumYearlyPrice = "premium_yearly_price"
    case enableInAppPurchases = "enable_in_app_purchases"
    case showAds = "show_ads"

    // MARK: - Experimental

    case enableNewMatchAlgorithm = "enable_new_match_algorithm"
    case enableDarkMode = "enable_dark_mode"
    case enableHapticFeedback = "enable_haptic_feedback"
    case enableAnimations = "enable_animations"

    // MARK: - Performance

    case enableImageCaching = "enable_image_caching"
    case maxCacheSize = "max_cache_size_mb"
    case enableOfflineMode = "enable_offline_mode"

    // MARK: - Properties

    var key: String {
        return rawValue
    }

    var defaultValue: Any {
        switch self {
        // Boolean flags
        case .enablePremiumFeatures: return true
        case .enableSuperLike: return true
        case .enableRewind: return false
        case .enableBoost: return true
        case .enableReadReceipts: return true
        case .enableSmartMatching: return true
        case .enableVideoChat: return false
        case .enableVoiceNotes: return true
        case .enableGiphy: return true
        case .enableStickers: return true
        case .enableContentModeration: return true
        case .enableProfileReview: return true
        case .autoModerateMessages: return true
        case .enableReferralProgram: return true
        case .enableSocialSharing: return true
        case .enableInAppPurchases: return true
        case .showAds: return false
        case .enableNewMatchAlgorithm: return false
        case .enableDarkMode: return true
        case .enableHapticFeedback: return true
        case .enableAnimations: return true
        case .enableImageCaching: return true
        case .enableOfflineMode: return false

        // Numeric flags
        case .maxDailyLikes: return 100
        case .maxDailySuperLikes: return 5
        case .discoveryRadius: return 50
        case .referralRewardCredits: return 10
        case .premiumMonthlyPrice: return 9.99
        case .premiumYearlyPrice: return 59.99
        case .maxCacheSize: return 100
        }
    }

    var description: String {
        switch self {
        case .enablePremiumFeatures: return "Enable premium features"
        case .enableSuperLike: return "Enable super like feature"
        case .enableRewind: return "Enable rewind last swipe"
        case .enableBoost: return "Enable profile boost"
        case .enableReadReceipts: return "Enable message read receipts"
        case .enableSmartMatching: return "Enable smart matching algorithm"
        case .maxDailyLikes: return "Maximum daily likes"
        case .maxDailySuperLikes: return "Maximum daily super likes"
        case .discoveryRadius: return "Discovery radius in kilometers"
        case .enableVideoChat: return "Enable video chat"
        case .enableVoiceNotes: return "Enable voice notes"
        case .enableGiphy: return "Enable Giphy integration"
        case .enableStickers: return "Enable stickers"
        case .enableContentModeration: return "Enable content moderation"
        case .enableProfileReview: return "Enable profile review"
        case .autoModerateMessages: return "Auto moderate messages"
        case .enableReferralProgram: return "Enable referral program"
        case .referralRewardCredits: return "Referral reward credits"
        case .enableSocialSharing: return "Enable social sharing"
        case .premiumMonthlyPrice: return "Premium monthly price"
        case .premiumYearlyPrice: return "Premium yearly price"
        case .enableInAppPurchases: return "Enable in-app purchases"
        case .showAds: return "Show advertisements"
        case .enableNewMatchAlgorithm: return "Enable new match algorithm (experimental)"
        case .enableDarkMode: return "Enable dark mode"
        case .enableHapticFeedback: return "Enable haptic feedback"
        case .enableAnimations: return "Enable animations"
        case .enableImageCaching: return "Enable image caching"
        case .maxCacheSize: return "Maximum cache size (MB)"
        case .enableOfflineMode: return "Enable offline mode"
        }
    }

    static var allFlags: [FeatureFlag] {
        return FeatureFlag.allCases
    }
}

// MARK: - Errors

enum FeatureFlagError: Error {
    case fetchFailed
    case notInitialized
}

// MARK: - SwiftUI Extensions

extension View {
    /// Show view only if feature flag is enabled
    @ViewBuilder
    func featureFlag(_ flag: FeatureFlag) -> some View {
        if FeatureFlagManager.shared.isEnabled(flag) {
            self
        }
    }

    /// Show different views based on feature flag
    @ViewBuilder
    func featureFlag<TrueContent: View, FalseContent: View>(
        _ flag: FeatureFlag,
        @ViewBuilder if enabled: () -> TrueContent,
        @ViewBuilder else disabled: () -> FalseContent
    ) -> some View {
        if FeatureFlagManager.shared.isEnabled(flag) {
            enabled()
        } else {
            disabled()
        }
    }
}

// MARK: - Property Wrapper

@propertyWrapper
struct FeatureFlagged {
    let flag: FeatureFlag

    @MainActor
    var wrappedValue: Bool {
        return FeatureFlagManager.shared.isEnabled(flag)
    }
}

// MARK: - Debug UI

#if DEBUG
struct FeatureFlagDebugView: View {
    @ObservedObject private var manager = FeatureFlagManager.shared
    @State private var flags: [String: Any] = [:]

    var body: some View {
        List {
            Section("Status") {
                HStack {
                    Text("Ready")
                    Spacer()
                    Image(systemName: manager.isReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(manager.isReady ? .green : .red)
                }

                if let lastFetch = manager.lastFetchDate {
                    HStack {
                        Text("Last Fetch")
                        Spacer()
                        Text(lastFetch, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Refresh Flags") {
                    Task {
                        try? await manager.refresh()
                        loadFlags()
                    }
                }
            }

            Section("Feature Flags") {
                ForEach(FeatureFlag.allFlags, id: \.rawValue) { flag in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(flag.key)
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { manager.isEnabled(flag) },
                                set: { manager.setOverride(flag, value: $0) }
                            ))
                        }

                        Text(flag.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("Clear All Overrides") {
                    manager.clearAllOverrides()
                    loadFlags()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Feature Flags")
        .onAppear {
            loadFlags()
        }
    }

    func loadFlags() {
        flags = manager.getAllFlags()
    }
}
#endif
