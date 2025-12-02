//
//  ProfileRejectionFeedbackView.swift
//  Celestia
//
//  Shows rejection feedback to users whose profiles need corrections
//

import SwiftUI

struct ProfileRejectionFeedbackView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var showSignUpEdit = false
    @State private var isUpdating = false
    @State private var animateIcon = false
    @State private var showSuccessAlert = false
    @State private var appearAnimation = false

    private var user: User? {
        authService.currentUser
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Animated Header
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                            .frame(width: 130, height: 130)
                            .scaleEffect(animateIcon ? 1.2 : 1.0)
                            .opacity(animateIcon ? 0 : 0.8)

                        // Background circles
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)

                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 85, height: 85)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .padding(.top, 30)
                    .scaleEffect(appearAnimation ? 1 : 0.8)
                    .opacity(appearAnimation ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                            animateIcon = true
                        }
                        // Staggered entrance animation
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                            appearAnimation = true
                        }
                    }

                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("Profile Needs Updates")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Don't worry - just a few quick fixes!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Steps to fix card
                    VStack(spacing: 0) {
                        // Step 1: Review Reason
                        StepRow(
                            number: 1,
                            title: "Review the Reason",
                            subtitle: "See why your profile needs changes",
                            color: .orange,
                            isLast: false
                        )

                        // Step 2: Make Changes
                        StepRow(
                            number: 2,
                            title: "Edit Your Profile",
                            subtitle: "Update photos or bio as needed",
                            color: .blue,
                            isLast: false
                        )

                        // Step 3: Request Review
                        StepRow(
                            number: 3,
                            title: "Request Re-Review",
                            subtitle: "We'll check your profile again",
                            color: .green,
                            isLast: true
                        )
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)

                    // Reason card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            }

                            Text("Why This Happened")
                                .font(.headline)
                        }

                        Text(user?.profileStatusReason ?? "Your profile was reviewed and needs some updates before it can be approved.")
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                    // Fix instructions card
                    if let instructions = user?.profileStatusFixInstructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }

                                Text("How to Fix It")
                                    .font(.headline)
                            }

                            Text(instructions)
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)
                    }

                    // Common issues section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "checklist")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("Common Issues to Check")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 10) {
                            ForEach(getIssuesList(), id: \.self) { issue in
                                IssueRow(issue: issue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 4)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)

                    Spacer(minLength: 20)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showSignUpEdit = true
                            HapticManager.shared.impact(.medium)
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
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        }

                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await requestReReview()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isUpdating {
                                    ProgressView()
                                        .tint(.green)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Request Re-Review")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1.5)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isUpdating)

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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: appearAnimation)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Review")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showSignUpEdit) {
                SignUpView(isEditingProfile: true)
                    .environmentObject(authService)
                    .environmentObject(deepLinkManager)
            }
            .alert("Re-Review Requested!", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your profile has been submitted for re-review. We'll check it again soon!")
            }
        }
    }

    // MARK: - Helper Methods

    private func getIssuesList() -> [IssueItem] {
        let reasonCode = user?.profileStatusReasonCode ?? ""

        var issues: [IssueItem] = []

        // Photo-related issues
        if reasonCode.contains("no_face") || reasonCode.contains("face_photo") {
            issues.append(IssueItem(
                icon: "person.crop.circle.badge.exclamationmark",
                color: .orange,
                title: "Face Photo Required",
                description: "Your main photo must clearly show your face. No sunglasses, masks, or group shots."
            ))
        }

        if reasonCode.contains("low_quality") || reasonCode.contains("blurry") {
            issues.append(IssueItem(
                icon: "camera.metering.unknown",
                color: .purple,
                title: "Photo Quality",
                description: "Use clear, well-lit photos. Avoid blurry or pixelated images."
            ))
        }

        if reasonCode.contains("inappropriate") || reasonCode.contains("adult") {
            issues.append(IssueItem(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                title: "Content Guidelines",
                description: "Remove any inappropriate, explicit, or suggestive content from your profile."
            ))
        }

        if reasonCode.contains("fake") || reasonCode.contains("stock") {
            issues.append(IssueItem(
                icon: "person.fill.questionmark",
                color: .red,
                title: "Authentic Photos Only",
                description: "Use real photos of yourself. No celebrity, stock, or borrowed images."
            ))
        }

        // Bio-related issues
        if reasonCode.contains("bio") || reasonCode.contains("incomplete") {
            issues.append(IssueItem(
                icon: "text.bubble.fill",
                color: .blue,
                title: "Complete Your Bio",
                description: "Write at least a few sentences about yourself, your interests, and what you're looking for."
            ))
        }

        if reasonCode.contains("contact") {
            issues.append(IssueItem(
                icon: "phone.badge.xmark",
                color: .orange,
                title: "No Contact Info",
                description: "Don't include phone numbers, emails, or social handles in your bio."
            ))
        }

        // Account issues
        if reasonCode.contains("spam") || reasonCode.contains("promotional") {
            issues.append(IssueItem(
                icon: "megaphone.fill",
                color: .orange,
                title: "No Self-Promotion",
                description: "This platform is for genuine connections, not advertising or business."
            ))
        }

        if reasonCode.contains("offensive") {
            issues.append(IssueItem(
                icon: "hand.raised.fill",
                color: .red,
                title: "Community Guidelines",
                description: "Remove any hateful, discriminatory, or offensive content."
            ))
        }

        if reasonCode.contains("underage") {
            issues.append(IssueItem(
                icon: "person.badge.shield.checkmark.fill",
                color: .purple,
                title: "Age Verification",
                description: "All users must be 18 or older. Contact support if this is an error."
            ))
        }

        if reasonCode.contains("multiple") {
            issues.append(IssueItem(
                icon: "person.2.slash.fill",
                color: .red,
                title: "One Account Only",
                description: "Please use only one account. Delete any duplicate accounts."
            ))
        }

        // Default issues if none specific
        if issues.isEmpty {
            issues = [
                IssueItem(
                    icon: "person.crop.circle.fill",
                    color: .blue,
                    title: "Clear Profile Photo",
                    description: "Your main photo should clearly show your face"
                ),
                IssueItem(
                    icon: "text.alignleft",
                    color: .purple,
                    title: "Complete Bio",
                    description: "Add a bio that tells others about yourself"
                ),
                IssueItem(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    title: "Authentic Content",
                    description: "Make sure all information is accurate and genuine"
                )
            ]
        }

        return issues
    }

    private func requestReReview() async {
        guard let userId = user?.id else { return }

        isUpdating = true

        do {
            // Update profile status to "pending" for re-review
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "profileStatus": "pending",
                "profileStatusReason": FieldValue.delete(),
                "profileStatusReasonCode": FieldValue.delete(),
                "profileStatusFixInstructions": FieldValue.delete(),
                "profileStatusUpdatedAt": FieldValue.serverTimestamp()
            ])

            HapticManager.shared.notification(.success)

            // Brief delay to show success animation before transitioning
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Refresh user data - this will trigger navigation to main app
            await authService.fetchUser()

            isUpdating = false
        } catch {
            isUpdating = false
            Logger.shared.error("Failed to request re-review", category: .database, error: error)
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Issue Item Model

private struct IssueItem: Hashable {
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - Step Row Component

private struct StepRow: View {
    let number: Int
    let title: String
    let subtitle: String
    let color: Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number with connector line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 32, height: 32)

                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 30)
                }
            }

            // Step content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            Spacer()
        }
    }
}

// MARK: - Issue Row Component

private struct IssueRow: View {
    let issue: IssueItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(issue.color.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: issue.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(issue.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(issue.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(issue.color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Firestore Import

import FirebaseFirestore

// MARK: - Preview

#Preview {
    ProfileRejectionFeedbackView()
        .environmentObject(AuthService.shared)
        .environmentObject(DeepLinkManager())
}
