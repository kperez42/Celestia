//
//  AnalyticsViewModifier.swift
//  Celestia
//
//  SwiftUI view modifiers for automatic analytics tracking
//  Provides easy-to-use extensions for screen views and performance metrics
//

import SwiftUI

// MARK: - Screen View Tracking Modifier

struct ScreenViewModifier: ViewModifier {
    let screenName: String
    @State private var viewLoadStartTime = Date()

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Track screen view
                AnalyticsManager.shared.trackScreenView(screenName)

                // Calculate and track view load time
                let loadTime = Date().timeIntervalSince(viewLoadStartTime)
                AnalyticsManager.shared.trackViewLoad(viewName: screenName, duration: loadTime)

                Logger.shared.debug("Screen appeared: \(screenName)", category: .analytics)
            }
            .onDisappear {
                Logger.shared.debug("Screen disappeared: \(screenName)", category: .analytics)
            }
    }
}

// MARK: - Performance Tracking Modifier

struct PerformanceTrackingModifier: ViewModifier {
    let operationName: String
    @State private var startTime = Date()

    func body(content: Content) -> some View {
        content
            .onAppear {
                startTime = Date()
            }
            .onDisappear {
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsManager.shared.trackPerformance(
                    operation: operationName,
                    duration: duration,
                    success: true
                )
            }
    }
}

// MARK: - Journey Step Modifier

struct JourneyStepModifier: ViewModifier {
    let journey: String
    let step: String
    let metadata: [String: Any]

    func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsManager.shared.trackJourneyStep(
                    journey: journey,
                    step: step,
                    metadata: metadata
                )
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Track screen view automatically
    /// Usage: .trackScreenView("HomeScreen")
    func trackScreenView(_ screenName: String) -> some View {
        modifier(ScreenViewModifier(screenName: screenName))
    }

    /// Track operation performance
    /// Usage: .trackPerformance("LoadUserProfile")
    func trackPerformance(_ operationName: String) -> some View {
        modifier(PerformanceTrackingModifier(operationName: operationName))
    }

    /// Track user journey step
    /// Usage: .trackJourneyStep(journey: "onboarding", step: "profile_setup")
    func trackJourneyStep(journey: String, step: String, metadata: [String: Any] = [:]) -> some View {
        modifier(JourneyStepModifier(journey: journey, step: step, metadata: metadata))
    }

    /// Track button tap
    func trackTap(feature: String, action: String) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                AnalyticsManager.shared.trackFeatureUsage(
                    feature: feature,
                    action: action
                )
            }
        )
    }
}

// MARK: - App Launch Tracker

@MainActor
class AppLaunchTracker: ObservableObject {
    static let shared = AppLaunchTracker()

    private var launchStartTime: Date?
    private var isWarmStart = false

    private init() {
        launchStartTime = Date()
    }

    func trackLaunchCompleted() {
        guard let startTime = launchStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        AnalyticsManager.shared.trackAppLaunch(duration: duration, isWarmStart: isWarmStart)

        // Mark subsequent launches as warm starts
        isWarmStart = true
        launchStartTime = nil
    }

    func reset() {
        launchStartTime = Date()
        isWarmStart = false
    }
}

// MARK: - View Load Timer

struct ViewLoadTimer {
    private let startTime: Date
    private let viewName: String

    init(viewName: String) {
        self.viewName = viewName
        self.startTime = Date()
    }

    func complete() {
        let duration = Date().timeIntervalSince(startTime)
        AnalyticsManager.shared.trackViewLoad(viewName: viewName, duration: duration)
    }
}

// MARK: - Analytics Button

struct AnalyticsButton<Label: View>: View {
    let feature: String
    let action: String
    let label: Label
    let onTap: () -> Void

    init(
        feature: String,
        action: String,
        @ViewBuilder label: () -> Label,
        onTap: @escaping () -> Void
    ) {
        self.feature = feature
        self.action = action
        self.label = label()
        self.onTap = onTap
    }

    var body: some View {
        Button {
            // Track analytics
            AnalyticsManager.shared.trackFeatureUsage(feature: feature, action: action)

            // Haptic feedback
            HapticManager.shared.impact(.light)

            // Execute action
            onTap()
        } label: {
            label
        }
    }
}

// MARK: - Example Usage

/*

 // Example 1: Track screen view
 struct ProfileView: View {
     var body: some View {
         VStack {
             Text("Profile")
         }
         .trackScreenView("ProfileScreen")
     }
 }

 // Example 2: Track journey step
 struct OnboardingStepView: View {
     var body: some View {
         VStack {
             Text("Step 1")
         }
         .trackJourneyStep(
             journey: "onboarding",
             step: "personal_info",
             metadata: ["step_number": 1]
         )
     }
 }

 // Example 3: Track button with analytics
 struct SettingsView: View {
     var body: some View {
         AnalyticsButton(
             feature: "settings",
             action: "logout_tapped",
             label: {
                 Text("Log Out")
             },
             onTap: {
                 // Handle logout
             }
         )
     }
 }

 // Example 4: Track app launch
 @main
 struct CelestiaApp: App {
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .onAppear {
                     AppLaunchTracker.shared.trackLaunchCompleted()
                 }
         }
     }
 }

 */
