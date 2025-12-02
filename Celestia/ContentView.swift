//
//  ContentView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//
//  PROFILE STATUS FLOW DOCUMENTATION:
//  ----------------------------------
//  This view routes users to the appropriate screen based on their account/profile status.
//
//  Profile Status Values (defined in User.swift:67-73):
//  - "pending"   → New account, waiting for admin approval → PendingApprovalView
//  - "active"    → Approved, visible to other users → MainTabView
//  - "rejected"  → Rejected, user must fix issues → ProfileRejectionFeedbackView
//  - "flagged"   → Under moderator review → FlaggedAccountView
//  - "suspended" → Temporarily blocked → SuspendedAccountView
//  - "banned"    → Permanently blocked → BannedAccountView
//
//  Flow:
//  1. User signs up → profileStatus = "pending" (SignUpView.swift)
//  2. Admin reviews in AdminModerationDashboard.swift
//     - approveProfile() → sets profileStatus = "active", showMeInSearch = true
//     - rejectProfile() → sets profileStatus = "rejected" with reason
//     - flagProfile() → sets profileStatus = "flagged" for extended review
//  3. User is notified via push notification (sendProfileStatusNotification)
//  4. ContentView routes to appropriate view based on profileStatus
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var isAuthenticated = false
    @State private var needsEmailVerification = false
    @State private var isProfilePending = false
    @State private var isProfileRejected = false
    @State private var isProfileFlagged = false  // Under moderator review
    @State private var isSuspended = false
    @State private var isBanned = false
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
                    } else if isBanned {
                        // Show banned account view for permanently banned users
                        BannedAccountView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else if isSuspended {
                        // Show suspended account view for suspended users
                        SuspendedAccountView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else if isProfileFlagged {
                        // Show flagged view for profiles under moderator review
                        // User can see status and edit profile while waiting
                        FlaggedAccountView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else if isProfileRejected {
                        // Show rejection feedback view for rejected profiles
                        // User must fix issues and request re-review
                        ProfileRejectionFeedbackView()
                            .environmentObject(authService)
                            .environmentObject(deepLinkManager)
                            .transition(.opacity)
                    } else if isProfilePending {
                        // Show pending approval view while profile is under review
                        PendingApprovalView()
                            .environmentObject(authService)
                            .environmentObject(deepLinkManager)
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
        .animation(.easeInOut(duration: 0.3), value: isProfileFlagged)
        .animation(.easeInOut(duration: 0.3), value: isProfileRejected)
        .animation(.easeInOut(duration: 0.3), value: isSuspended)
        .animation(.easeInOut(duration: 0.3), value: isBanned)
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
        .onChange(of: authService.currentUser?.isBanned) { newValue in
            Logger.shared.debug("ContentView: isBanned changed to: \(String(describing: newValue))", category: .general)
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

        let profileStatus = authService.currentUser?.profileStatus.lowercased()

        // Check statuses in priority order (most severe first)
        // 1. Banned (permanent) - user cannot access app
        isBanned = isAuthenticated && (authService.currentUser?.isBanned == true || profileStatus == "banned")
        // 2. Suspended (temporary) - user must wait for suspension to end
        isSuspended = isAuthenticated && !isBanned && (authService.currentUser?.isSuspended == true || profileStatus == "suspended")
        // 3. Flagged (under review) - user can view status and edit profile
        isProfileFlagged = isAuthenticated && !isBanned && !isSuspended && profileStatus == "flagged"
        // 4. Rejected (needs fixes) - user must fix issues and request re-review
        isProfileRejected = isAuthenticated && !isBanned && !isSuspended && !isProfileFlagged && profileStatus == "rejected"
        // 5. Pending (awaiting approval) - user waits for admin review
        isProfilePending = isAuthenticated && !isBanned && !isSuspended && !isProfileFlagged && !isProfileRejected && profileStatus == "pending"

        // Detect approval transition: was pending/rejected/flagged, now approved/active
        let wasWaitingForApproval = previousProfileStatus == "pending" || previousProfileStatus == "rejected" || previousProfileStatus == "flagged"
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

        Logger.shared.debug("ContentView: isAuthenticated=\(isAuthenticated), needsEmailVerification=\(needsEmailVerification), isBanned=\(isBanned), isSuspended=\(isSuspended), isProfileFlagged=\(isProfileFlagged), isProfileRejected=\(isProfileRejected), isProfilePending=\(isProfilePending)", category: .general)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
