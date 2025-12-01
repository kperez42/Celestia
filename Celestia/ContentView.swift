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
    @State private var isProfilePending = false
    @State private var isProfileRejected = false
    @State private var isSuspended = false
    @State private var isLoading = true  // Start with splash screen
    @State private var showApprovalCelebration = false
    @State private var previousProfileStatus: String?

    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    // Show splash screen during initial auth check
                    SplashView()
                        .transition(.opacity)
                } else if isAuthenticated {
                    if needsEmailVerification {
                        EmailVerificationView()
                            .transition(.opacity)
                    } else if isSuspended {
                        // Show suspended account view for suspended users
                        SuspendedAccountView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else if isProfileRejected {
                        // Show rejection feedback view for rejected profiles
                        ProfileRejectionFeedbackView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else if isProfilePending {
                        // Show pending approval view while profile is under review
                        PendingApprovalView()
                            .environmentObject(authService)
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

            // Celebration overlay when profile gets approved
            if showApprovalCelebration {
                ProfileApprovedCelebrationView(onDismiss: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showApprovalCelebration = false
                    }
                })
                .environmentObject(authService)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: needsEmailVerification)
        .animation(.easeInOut(duration: 0.3), value: isProfilePending)
        .animation(.easeInOut(duration: 0.3), value: isProfileRejected)
        .animation(.easeInOut(duration: 0.3), value: isSuspended)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showApprovalCelebration)
        .onChange(of: authService.userSession?.uid) { newValue in
            Logger.shared.debug("ContentView: userSession changed to: \(newValue ?? "nil")", category: .general)
            updateAuthenticationState()
        }
        .onChange(of: authService.isEmailVerified) { newValue in
            Logger.shared.debug("ContentView: isEmailVerified changed to: \(newValue)", category: .general)
            updateAuthenticationState()
        }
        .onChange(of: authService.currentUser?.profileStatus) { newValue in
            Logger.shared.debug("ContentView: profileStatus changed to: \(newValue ?? "nil")", category: .general)
            updateAuthenticationState()
        }
        .onChange(of: authService.currentUser?.isSuspended) { newValue in
            Logger.shared.debug("ContentView: isSuspended changed to: \(String(describing: newValue))", category: .general)
            updateAuthenticationState()
        }
        .onAppear {
            Logger.shared.debug("ContentView: onAppear - userSession: \(authService.userSession?.uid ?? "nil")", category: .general)
            updateAuthenticationState()

            // Hide splash screen after minimum display time
            // This ensures splash doesn't flash too quickly
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds minimum
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
            }
        }
    }

    private func updateAuthenticationState() {
        isAuthenticated = (authService.userSession != nil)
        needsEmailVerification = isAuthenticated && !authService.isEmailVerified

        let profileStatus = authService.currentUser?.profileStatus?.lowercased()

        // Check if account is suspended
        isSuspended = isAuthenticated && (authService.currentUser?.isSuspended == true || profileStatus == "suspended")
        // Check if profile is rejected and needs user action
        isProfileRejected = isAuthenticated && profileStatus == "rejected"
        // Check if profile is pending approval
        isProfilePending = isAuthenticated && profileStatus == "pending"

        // Detect approval transition: was pending/rejected, now approved/active
        let wasWaitingForApproval = previousProfileStatus == "pending" || previousProfileStatus == "rejected"
        let isNowApproved = profileStatus == "approved" || profileStatus == "active"

        if wasWaitingForApproval && isNowApproved && !isLoading {
            // User just got approved! Show celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showApprovalCelebration = true
                }
            }
        }

        // Update previous status for next comparison
        previousProfileStatus = profileStatus

        Logger.shared.debug("ContentView: isAuthenticated=\(isAuthenticated), needsEmailVerification=\(needsEmailVerification), isSuspended=\(isSuspended), isProfileRejected=\(isProfileRejected), isProfilePending=\(isProfilePending)", category: .general)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
