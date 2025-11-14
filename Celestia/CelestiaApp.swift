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
        FirebaseApp.configure()

        // Enable Firestore offline persistence for better offline support
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited // Unlimited cache for full offline support
        Firestore.firestore().settings = settings

        Logger.shared.info("Firestore offline persistence enabled", category: .database)
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
