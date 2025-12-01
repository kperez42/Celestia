//
//  ProfileRejectionFeedbackView.swift
//  Celestia
//
//  Shows rejection feedback to users whose profiles need corrections
//

import SwiftUI

struct ProfileRejectionFeedbackView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showEditProfile = false
    @State private var isUpdating = false

    private var user: User? {
        authService.currentUser
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 40)

                    // Title
                    Text("Profile Needs Updates")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    // Reason card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("What happened", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text(user?.profileStatusReason ?? "Your profile was reviewed and needs some updates before it can be approved.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Fix instructions card
                    if let instructions = user?.profileStatusFixInstructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("How to fix", systemImage: "wrench.and.screwdriver.fill")
                                .font(.headline)
                                .foregroundColor(.blue)

                            Text(instructions)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    // Common issues section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common Issues")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(getIssuesList(), id: \.self) { issue in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: issue.icon)
                                    .foregroundColor(issue.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(issue.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 40)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showEditProfile = true
                            HapticManager.shared.impact(.medium)
                        }) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                Text("Edit My Profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }

                        Button(action: {
                            Task {
                                await requestReReview()
                            }
                        }) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .tint(.blue)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Request Re-Review")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(16)
                        }
                        .disabled(isUpdating)

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
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile Review")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                ProfileEditView()
                    .environmentObject(authService)
            }
        }
    }

    // MARK: - Helper Methods

    private func getIssuesList() -> [IssueItem] {
        let reasonCode = user?.profileStatusReasonCode ?? ""

        var issues: [IssueItem] = []

        // Add specific issues based on reason code
        if reasonCode.contains("photo") || reasonCode.contains("image") {
            issues.append(IssueItem(
                icon: "photo.fill",
                color: .red,
                title: "Photo Issues",
                description: "Photos must clearly show your face. No filters, sunglasses, or group photos as your main picture."
            ))
        }

        if reasonCode.contains("bio") || reasonCode.contains("text") {
            issues.append(IssueItem(
                icon: "text.bubble.fill",
                color: .orange,
                title: "Bio Content",
                description: "Your bio should describe yourself authentically. Avoid promotional content or contact info."
            ))
        }

        if reasonCode.contains("spam") || reasonCode.contains("fake") {
            issues.append(IssueItem(
                icon: "exclamationmark.shield.fill",
                color: .red,
                title: "Authenticity",
                description: "Your profile should represent the real you. Use genuine photos and information."
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
        defer { isUpdating = false }

        do {
            // Update profile status to "pending" for re-review
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "profileStatus": "pending",
                "profileStatusReason": nil,
                "profileStatusReasonCode": nil,
                "profileStatusFixInstructions": nil,
                "profileStatusUpdatedAt": FieldValue.serverTimestamp()
            ])

            // Refresh user data
            await authService.fetchUser()

            HapticManager.shared.notification(.success)
        } catch {
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

// MARK: - Firestore Import

import FirebaseFirestore

// MARK: - Preview

#Preview {
    ProfileRejectionFeedbackView()
        .environmentObject(AuthService.shared)
}
