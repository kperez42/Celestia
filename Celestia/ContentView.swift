//
//  ContentView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isAuthenticated = false
    @State private var needsEmailVerification = false

    var body: some View {
        Group {
            if isAuthenticated {
                if needsEmailVerification {
                    EmailVerificationView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: needsEmailVerification)
        .onChange(of: authService.userSession?.uid) { newValue in
            Logger.shared.debug("ContentView: userSession changed to: \(newValue ?? "nil")", category: .general)
            updateAuthenticationState()
        }
        .onChange(of: authService.isEmailVerified) { newValue in
            Logger.shared.debug("ContentView: isEmailVerified changed to: \(newValue)", category: .general)
            updateAuthenticationState()
        }
        .onAppear {
            Logger.shared.debug("ContentView: onAppear - userSession: \(authService.userSession?.uid ?? "nil")", category: .general)
            updateAuthenticationState()
        }
    }

    private func updateAuthenticationState() {
        isAuthenticated = (authService.userSession != nil)
        needsEmailVerification = isAuthenticated && !authService.isEmailVerified
        Logger.shared.debug("ContentView: isAuthenticated=\(isAuthenticated), needsEmailVerification=\(needsEmailVerification)", category: .general)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
