//
//  FlaggedAccountView.swift
//  Celestia
//
//  Shows feedback to users whose profiles are under moderator review (flagged status).
//
//  FLOW DOCUMENTATION:
//  ------------------
//  When a user's profile is flagged for review:
//  1. User receives push notification via sendProfileStatusNotification() (AdminModerationDashboard.swift:1763)
//  2. ContentView.swift routes user here when profileStatus == "flagged" (ContentView.swift:updateAuthenticationState)
//  3. User can see why they're under review and wait for moderator decision
//  4. Admin reviews in AdminModerationDashboard.swift and either approves or rejects
//  5. User is notified of result and routed to appropriate view
//
//  Related Files:
//  - ContentView.swift - Routes users based on profileStatus
//  - AdminModerationDashboard.swift - Admin actions for flagged profiles
//  - User.swift - profileStatus field and related properties
//  - ProfileRejectionFeedbackView.swift - Shown if profile is rejected after review
//

import SwiftUI
import FirebaseFirestore

struct FlaggedAccountView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isRefreshing = false
    @State private var appearAnimation = false
    @State private var animateIcon = false
    @State private var showEditProfile = false

    private var user: User? {
        authService.currentUser
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header icon - orange theme for "under review" status
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateIcon ? 1.2 : 1.0)
                            .opacity(animateIcon ? 0 : 0.8)

                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .padding(.top, 40)
                    .scaleEffect(appearAnimation ? 1 : 0.8)
                    .opacity(appearAnimation ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                            animateIcon = true
                        }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                            appearAnimation = true
                        }
                    }

                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("Profile Under Review")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("Our team is reviewing your profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // What's happening card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            }

                            Text("What's Happening?")
                                .font(.headline)
                        }

                        Text(user?.profileStatusReason ?? "Your profile has been flagged for review by our moderation team. This is a routine check to ensure all profiles meet our community standards.")
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.85))
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)

                    // What this means section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                            }

                            Text("What This Means")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            BulletPoint(
                                icon: "eye.slash.fill",
                                color: .orange,
                                text: "Your profile is temporarily hidden from other users"
                            )
                            BulletPoint(
                                icon: "clock.badge.checkmark.fill",
                                color: .blue,
                                text: "Reviews typically complete within 24-48 hours"
                            )
                            BulletPoint(
                                icon: "bell.fill",
                                color: .purple,
                                text: "You'll be notified when the review is complete"
                            )
                            BulletPoint(
                                icon: "checkmark.circle.fill",
                                color: .green,
                                text: "If approved, you'll be visible to others again"
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                    // In the meantime section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }

                            Text("In the Meantime")
                                .font(.headline)
                        }

                        Text("You can use this time to make sure your profile is complete and follows our community guidelines. Clear photos and a genuine bio help speed up approval!")
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.85))
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)

                    Spacer(minLength: 40)

                    // Action buttons
                    VStack(spacing: 12) {
                        // Edit Profile button
                        Button(action: {
                            showEditProfile = true
                            HapticManager.shared.impact(.medium)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                Text("Review My Profile")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        }

                        // Check Status button
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await checkStatus()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.orange)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Check Status")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isRefreshing)

                        // Sign Out button
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            authService.signOut()
                        }) {
                            Text("Sign Out")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Review")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authService)
            }
        }
    }

    // MARK: - Helper Methods

    private func checkStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Refresh user data to check if status has changed
        await authService.fetchUser()

        // Check current status
        if let user = authService.currentUser {
            let status = user.profileStatus.lowercased()
            if status == "active" || status == "approved" {
                // Profile was approved!
                HapticManager.shared.notification(.success)
            } else if status == "rejected" {
                // Profile was rejected - ContentView will route to ProfileRejectionFeedbackView
                HapticManager.shared.notification(.warning)
            } else {
                // Still under review
                HapticManager.shared.notification(.warning)
            }
        }
    }
}

// MARK: - Bullet Point Component

private struct BulletPoint: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.85))
        }
    }
}

// MARK: - Preview

#Preview {
    FlaggedAccountView()
        .environmentObject(AuthService.shared)
}
