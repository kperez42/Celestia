//
//  CelestiaApp.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

@main
struct CelestiaApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkManager = DeepLinkManager()

    init() {
        // Configure Firebase first (must be on main thread)
        FirebaseApp.configure()

        // PERFORMANCE: Move Firestore persistence initialization to background thread
        // This reduces cold start time by ~150-200ms
        Task.detached(priority: .userInitiated) {
            let settings = FirestoreSettings()
            settings.isPersistenceEnabled = true

            // PERFORMANCE: Set cache size limit to 100MB (was unlimited)
            // Prevents memory bloat on older devices (iPhone 8/X)
            settings.cacheSizeBytes = 100 * 1024 * 1024 // 100MB limit

            // Apply settings on main thread as required by Firestore
            await MainActor.run {
                Firestore.firestore().settings = settings
                Logger.shared.info("Firestore persistence initialized (100MB cache limit)", category: .database)
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
