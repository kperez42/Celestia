//
//  CelestiaApp.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import Firebase

@main
struct CelestiaApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkManager = DeepLinkManager()

    init() {
        FirebaseApp.configure()
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
        print("📱 Deep link received: \(url)")

        // Handle celestia://join/CEL-XXXXXXXX or https://celestia.app/join/CEL-XXXXXXXX
        if url.pathComponents.contains("join"),
           let code = url.pathComponents.last,
           code.hasPrefix("CEL-") {
            deepLinkManager.referralCode = code
            print("✅ Extracted referral code from deep link: \(code)")
        }
    }
}
