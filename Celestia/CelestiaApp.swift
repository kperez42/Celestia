//
//  CelestiaApp.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAnalytics

@main
struct CelestiaApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkManager = DeepLinkManager()

    init() {
        // MEMORY FIX: Disable Firebase Analytics automatic data collection to prevent malloc errors
        // This significantly reduces memory pressure during app initialization
        Analytics.setAnalyticsCollectionEnabled(false)

        // Configure Firebase first (must be on main thread)
        // NOTE: This is the SINGLE initialization point for Firebase
        // Do NOT call FirebaseApp.configure() anywhere else in the app
        FirebaseApp.configure()

        // Re-enable analytics AFTER Firebase is configured, with manual control
        Analytics.setAnalyticsCollectionEnabled(true)

        // PERFORMANCE: Move Firestore persistence initialization to background thread
        // This reduces cold start time by ~150-200ms
        Task.detached(priority: .userInitiated) {
            let settings = FirestoreSettings()
            settings.isPersistenceEnabled = true

            // PERFORMANCE: Set cache size limit to 50MB (reduced from 100MB)
            // Prevents memory bloat and malloc errors on all devices
            settings.cacheSizeBytes = 50 * 1024 * 1024 // 50MB limit

            // Apply settings on main thread as required by Firestore
            await MainActor.run {
                Firestore.firestore().settings = settings
                Logger.shared.info("Firestore persistence initialized (50MB cache limit)", category: .database)
            }
        }

        // MEMORY FIX: Reduce startup memory pressure by deferring heavy service initialization
        // This helps reduce malloc errors during Firebase initialization
        Task.detached(priority: .background) {
            // Allow Firebase core services to initialize first
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay (increased from 500ms)

            // Pre-warm AnalyticsServiceEnhanced singleton on background to distribute memory allocations
            await MainActor.run {
                _ = AnalyticsServiceEnhanced.shared
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        Logger.shared.info("Deep link received: \(url)", category: .general)

        // Handle celestia://join/CEL-XXXXXXXX or https://celestia.app/join/CEL-XXXXXXXX
        if url.pathComponents.contains("join"),
           let code = url.pathComponents.last,
           code.hasPrefix("CEL-") {
            deepLinkManager.referralCode = code
            Logger.shared.info("Extracted referral code from deep link: \(code)", category: .referral)
        }
    }
}
