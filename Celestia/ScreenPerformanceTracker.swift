//
//  ScreenPerformanceTracker.swift
//  Celestia
//
//  Automatic screen load time tracking for all views
//  Integrates with Firebase Performance and PerformanceMonitor
//

import SwiftUI
import FirebasePerformance

/// View modifier that automatically tracks screen load time
struct ScreenPerformanceModifier: ViewModifier {
    let screenName: String

    @State private var trace: Trace?
    @State private var loadStartTime: Date?

    func body(content: Content) -> some View {
        content
            .onAppear {
                startTracking()
            }
            .onDisappear {
                stopTracking()
            }
    }

    private func startTracking() {
        loadStartTime = Date()

        // Start Firebase Performance trace
        trace = Performance.startTrace(name: "screen_\(screenName)")
        trace?.setValue(screenName, forAttribute: "screen_name")

        // Log to Crashlytics
        CrashlyticsManager.shared.logScreenView(screenName)

        Logger.shared.debug("Started tracking screen: \(screenName)", category: .performance)
    }

    private func stopTracking() {
        guard let startTime = loadStartTime else { return }

        let loadTime = Date().timeIntervalSince(startTime) * 1000 // milliseconds

        // Stop Firebase trace
        trace?.stop()

        // Track in PerformanceMonitor
        Task {
            await PerformanceMonitor.shared.trackScreenLoad(screen: screenName, duration: loadTime)
        }

        // Log completion
        if loadTime > 2000 {
            Logger.shared.warning("⏱️ SLOW: Screen '\(screenName)' loaded in \(String(format: "%.0f", loadTime))ms", category: .performance)

            // Send to analytics if very slow
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "type": "slow_screen_load",
                "screen_name": screenName,
                "load_time_ms": loadTime,
                "threshold_ms": 2000
            ])
        } else {
            Logger.shared.debug("Screen '\(screenName)' loaded in \(String(format: "%.0f", loadTime))ms", category: .performance)
        }
    }
}

/// View extension for easy screen tracking
extension View {
    /// Track screen load performance
    /// - Parameter screenName: Name of the screen (e.g., "DiscoverView", "ProfileView")
    /// - Returns: View with performance tracking
    func trackScreenPerformance(_ screenName: String) -> some View {
        self.modifier(ScreenPerformanceModifier(screenName: screenName))
    }
}

// MARK: - PerformanceMonitor Extension

extension PerformanceMonitor {

    /// Track screen load time
    func trackScreenLoad(screen: String, duration: Double) {
        screenLoadTimes.append((screen: screen, duration: duration))

        // Keep only last 50 measurements
        if screenLoadTimes.count > 50 {
            screenLoadTimes.removeFirst()
        }

        // Calculate average for this screen
        let screenDurations = screenLoadTimes.filter { $0.screen == screen }.map { $0.duration }
        if !screenDurations.isEmpty {
            let avgDuration = screenDurations.reduce(0, +) / Double(screenDurations.count)
            screenLoadAverages[screen] = avgDuration
        }

        // Track in statistics
        PerformanceStatistics.shared.record("screen_\(screen)", duration: duration)
    }

    /// Get average screen load time
    func getAverageScreenLoadTime(for screen: String) -> Double? {
        return screenLoadAverages[screen]
    }

    /// Get all screen load statistics
    func getAllScreenStats() -> [String: Double] {
        return screenLoadAverages
    }

    // MARK: - Private Storage

    private var screenLoadTimes: [(screen: String, duration: Double)] {
        get {
            return (objc_getAssociatedObject(self, &AssociatedKeys.screenLoadTimes) as? [(screen: String, duration: Double)]) ?? []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.screenLoadTimes, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var screenLoadAverages: [String: Double] {
        get {
            return (objc_getAssociatedObject(self, &AssociatedKeys.screenLoadAverages) as? [String: Double]) ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.screenLoadAverages, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private struct AssociatedKeys {
        static var screenLoadTimes: UInt8 = 0
        static var screenLoadAverages: UInt8 = 0
    }
}

// MARK: - Common Screen Names

extension ScreenPerformanceModifier {
    /// Common screen names for consistency
    enum Screen {
        static let discover = "DiscoverView"
        static let profile = "ProfileView"
        static let matches = "MatchesView"
        static let messages = "MessagesView"
        static let chat = "ChatView"
        static let settings = "SettingsView"
        static let editProfile = "EditProfileView"
        static let photoUpload = "PhotoUploadView"
        static let verification = "VerificationView"
        static let premium = "PremiumView"
        static let login = "LoginView"
        static let signup = "SignupView"
        static let onboarding = "OnboardingView"
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Track main views
 struct DiscoverView: View {
     var body: some View {
         VStack {
             // Your view content
         }
         .trackScreenPerformance(ScreenPerformanceModifier.Screen.discover)
     }
 }

 // Example 2: Track with custom name
 struct UserProfileView: View {
     let userId: String

     var body: some View {
         VStack {
             // Profile content
         }
         .trackScreenPerformance("UserProfile_\(userId)")
     }
 }

 // Example 3: Track modal/sheet views
 .sheet(isPresented: $showSettings) {
     SettingsView()
         .trackScreenPerformance(ScreenPerformanceModifier.Screen.settings)
 }

 // Results in Firebase Performance:
 // - screen_DiscoverView: avg 450ms, p95 890ms
 // - screen_ProfileView: avg 620ms, p95 1200ms
 // - screen_ChatView: avg 280ms, p95 550ms
 */
