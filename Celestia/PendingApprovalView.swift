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

    private var user: User? {
        authService.currentUser
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
                        Button(action: {
                            Task {
                                await checkApprovalStatus()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Check Status")
                                        .fontWeight(.semibold)
                                }
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
                        .disabled(isRefreshing)

                        Button(action: {
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
                // Still pending
                HapticManager.shared.impact(.light)
            }
        }
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
