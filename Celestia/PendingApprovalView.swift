//
//  PendingApprovalView.swift
//  Celestia
//
//  Shows pending approval status to users whose profiles are under review
//

import SwiftUI
import FirebaseFirestore

struct PendingApprovalView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isRefreshing = false
    @State private var appearAnimation = false
    @State private var animateIcon = false
    @State private var pulseAnimation = false
    @State private var progressAnimation = false
    @State private var stepAnimations: [Bool] = [false, false, false]
    @State private var showStillPendingToast = false
    @State private var showEditProfile = false
    @State private var showOnboarding = false

    private var user: User? {
        authService.currentUser
    }

    private var submittedTimeAgo: String {
        guard let timestamp = user?.timestamp else { return "Recently" }
        let interval = Date().timeIntervalSince(timestamp)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Animated Header
                    ZStack {
                        // Outer rotating ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(animateIcon ? 360 : 0))

                        // Inner pulse ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)

                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 90, height: 90)

                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .padding(.top, 40)
                    .scaleEffect(appearAnimation ? 1 : 0.8)
                    .opacity(appearAnimation ? 1 : 0)
                    .onAppear {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            animateIcon = true
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                            appearAnimation = true
                        }
                        // Animate progress steps sequentially
                        for i in 0..<3 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.3) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    stepAnimations[i] = true
                                }
                            }
                        }
                        // Start progress bar animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                progressAnimation = true
                            }
                        }
                    }

                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("Profile Under Review")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("We're making sure everything looks great!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Status card
                    VStack(spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.crop.circle.badge.clock.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.blue, .orange)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Review in Progress")
                                    .font(.headline)
                                Text("Usually takes less than 24 hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Animated dots
                            HStack(spacing: 4) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                        .opacity(pulseAnimation ? (index == 0 ? 1.0 : index == 1 ? 0.6 : 0.3) : (index == 0 ? 0.3 : index == 1 ? 0.6 : 1.0))
                                        .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.2).repeatForever(autoreverses: true), value: pulseAnimation)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)

                    // Progress Timeline
                    VStack(spacing: 0) {
                        HStack {
                            Text("Review Progress")
                                .font(.headline)
                            Spacer()
                            Text("Submitted \(submittedTimeAgo)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 16)

                        // Progress steps
                        HStack(spacing: 0) {
                            // Step 1: Submitted
                            ReviewStepView(
                                icon: "paperplane.fill",
                                title: "Submitted",
                                isCompleted: true,
                                isActive: false,
                                color: .green,
                                isAnimated: stepAnimations[0]
                            )

                            // Connector line
                            ProgressConnector(isCompleted: true, isAnimated: progressAnimation)

                            // Step 2: In Review
                            ReviewStepView(
                                icon: "eye.fill",
                                title: "In Review",
                                isCompleted: false,
                                isActive: true,
                                color: .blue,
                                isAnimated: stepAnimations[1]
                            )

                            // Connector line
                            ProgressConnector(isCompleted: false, isAnimated: progressAnimation)

                            // Step 3: Decision
                            ReviewStepView(
                                icon: "checkmark.seal.fill",
                                title: "Decision",
                                isCompleted: false,
                                isActive: false,
                                color: .purple,
                                isAnimated: stepAnimations[2]
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: appearAnimation)

                    // What we're checking
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checklist")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("What We're Checking")
                                .font(.headline)
                        }

                        VStack(spacing: 12) {
                            ChecklistRow(
                                icon: "person.crop.circle.fill",
                                title: "Profile Photos",
                                description: "Clear, appropriate photos that show you",
                                color: .blue
                            )

                            ChecklistRow(
                                icon: "text.alignleft",
                                title: "Bio & Information",
                                description: "Complete and authentic profile details",
                                color: .purple
                            )

                            ChecklistRow(
                                icon: "shield.checkered",
                                title: "Community Guidelines",
                                description: "Content follows our safety policies",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                    // While you wait card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            }

                            Text("While You Wait")
                                .font(.headline)
                        }

                        Text("Your profile will be visible to others once approved. In the meantime, you can explore the app and get familiar with its features. We'll notify you as soon as your profile is approved!")
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)

                    Spacer(minLength: 30)

                    // Action buttons
                    VStack(spacing: 12) {
                        // Edit Profile button - Goes to Onboarding to update signup info
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showOnboarding = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.title3)
                                Text("Update My Info")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                        }

                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await checkApprovalStatus()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.blue)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Check Status")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .disabled(isRefreshing)

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
                    .padding(.bottom, 30)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Status")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
                    .environmentObject(authService)
            }
            .task {
                // Auto-refresh status after a short delay when view appears
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if !isRefreshing {
                    await authService.fetchUser()
                }
            }
            .overlay(alignment: .top) {
                // Still pending toast
                if showStillPendingToast {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(.blue)
                        Text("Still under review - check back soon!")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    )
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showStillPendingToast = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func checkApprovalStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Refresh user data to check approval status
        await authService.fetchUser()

        if let user = authService.currentUser {
            if user.profileStatus == "approved" || user.profileStatus == "active" {
                HapticManager.shared.notification(.success)
            } else if user.profileStatus == "rejected" {
                HapticManager.shared.notification(.warning)
            } else {
                // Still pending - show friendly toast
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showStillPendingToast = true
                }
            }
        }
    }
}

// MARK: - Review Step Component

private struct ReviewStepView: View {
    let icon: String
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    let color: Color
    let isAnimated: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isCompleted ? color : (isActive ? color.opacity(0.15) : Color(.systemGray5)))
                    .frame(width: 44, height: 44)

                // Pulse ring for active step
                if isActive {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .scaleEffect(isAnimated ? 1.2 : 1.0)
                        .opacity(isAnimated ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimated)
                }

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isCompleted ? .white : (isActive ? color : .gray))
            }
            .scaleEffect(isAnimated ? 1.0 : 0.5)
            .opacity(isAnimated ? 1.0 : 0)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(isCompleted || isActive ? .primary : .secondary)
                .opacity(isAnimated ? 1.0 : 0)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Connector

private struct ProgressConnector: View {
    let isCompleted: Bool
    let isAnimated: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 3)

                // Progress line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: isCompleted ? (isAnimated ? geometry.size.width : 0) : 0, height: 3)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: 50)
        .offset(y: -12) // Center with the circles
    }
}

// MARK: - Checklist Row Component

private struct ChecklistRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
                .font(.body)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview {
    PendingApprovalView()
        .environmentObject(AuthService.shared)
}
