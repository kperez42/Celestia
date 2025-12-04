//
//  ReportUserView.swift
//  Celestia
//
//  Created by Claude
//  UI for reporting and blocking users
//

import SwiftUI

struct ReportUserView: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    @StateObject private var reportService = BlockReportService.shared

    @State private var selectedReason: ReportReason = .inappropriateContent
    @State private var additionalInfo = ""
    @State private var showBlockConfirmation = false
    @State private var showReportSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User Card Section
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // PERFORMANCE: Use CachedAsyncImage
                            if let photoURL = URL(string: user.profileImageURL) {
                                CachedAsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 70, height: 70)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.red.opacity(0.3), Color.orange.opacity(0.2)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                } placeholder: {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.fullName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                    Text("\(user.age) • \(user.location)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Reporting this profile will also block them from contacting you.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.08))
                        )
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)

                    // Reason Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Reason for Report")
                                .font(.headline)
                        }

                        Menu {
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                Button {
                                    selectedReason = reason
                                    HapticManager.shared.selection()
                                } label: {
                                    Text(reason.description)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedReason.description)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                                    )
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)

                    // Additional Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "text.alignleft")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Additional Information")
                                    .font(.headline)
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $additionalInfo)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )

                            if additionalInfo.isEmpty {
                                Text("Provide any additional details that might help us review this report...")
                                    .foregroundColor(.gray)
                                    .font(.body)
                                    .padding(.top, 20)
                                    .padding(.leading, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)

                    // Block Only Option
                    VStack(spacing: 12) {
                        Button {
                            showBlockConfirmation = true
                            HapticManager.shared.impact(.medium)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "hand.raised.fill")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Block User Only")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Without submitting a report")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        }

                        Text("Block this user without submitting a report. They won't be able to see your profile or contact you.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }

                    // Submit Button
                    Button {
                        submitReport()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "flag.fill")
                                .font(.callout)
                            Text("Submit Report")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange, .red.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .red.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(isSubmitting)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
            }
            .disabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                    .frame(width: 56, height: 56)

                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 56, height: 56)
                                    .rotationEffect(.degrees(isSubmitting ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSubmitting)
                            }

                            VStack(spacing: 6) {
                                Text("Submitting Report")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Please wait...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(36)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    }
                }
            }
            .alert("Block User", isPresented: $showBlockConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    blockUserOnly()
                }
            } message: {
                Text("Are you sure you want to block \(user.fullName)? They won't be able to see your profile or contact you.")
            }
            .alert("Report Submitted", isPresented: $showReportSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for helping keep Celestia safe. We'll review this report and take appropriate action.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitReport() {
        guard let userId = user.id,
              let currentUserId = AuthService.shared.currentUser?.id else { return }

        isSubmitting = true
        HapticManager.shared.impact(.medium)

        Task {
            do {
                try await reportService.reportUser(
                    userId: userId,
                    currentUserId: currentUserId,
                    reason: selectedReason,
                    additionalDetails: additionalInfo.isEmpty ? nil : additionalInfo
                )

                await MainActor.run {
                    isSubmitting = false
                    showReportSuccess = true
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func blockUserOnly() {
        guard let userId = user.id,
              let currentUserId = AuthService.shared.currentUser?.id else { return }

        isSubmitting = true
        HapticManager.shared.impact(.medium)

        Task {
            do {
                try await reportService.blockUser(userId: userId, currentUserId: currentUserId)

                await MainActor.run {
                    isSubmitting = false
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Blocked Users List View

struct BlockedUsersView: View {
    @StateObject private var reportService = BlockReportService.shared
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    @State private var showUnblockConfirmation = false
    @State private var userToUnblock: User?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if blockedUsers.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.gray.opacity(0.12), Color.clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 140, height: 140)

                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 100)

                            Image(systemName: "hand.raised.slash")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }

                    VStack(spacing: 8) {
                        Text("No Blocked Users")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)

                        Text("Users you block will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(blockedUsers) { user in
                            HStack(spacing: 14) {
                                // PERFORMANCE: Use CachedAsyncImage
                                if let photoURL = URL(string: user.profileImageURL) {
                                    CachedAsyncImage(url: photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 56, height: 56)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                            )
                                    } placeholder: {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 56, height: 56)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.fullName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("\(user.age) • \(user.location)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    userToUnblock = user
                                    showUnblockConfirmation = true
                                    HapticManager.shared.impact(.light)
                                } label: {
                                    Text("Unblock")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                        .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)
                                }
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBlockedUsers()
        }
        .alert("Unblock User", isPresented: $showUnblockConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unblock") {
                if let user = userToUnblock {
                    unblockUser(user)
                }
            }
        } message: {
            if let user = userToUnblock {
                Text("Are you sure you want to unblock \(user.fullName)? They'll be able to see your profile again.")
            }
        }
    }

    private func loadBlockedUsers() {
        isLoading = true

        Task {
            do {
                let users = try await reportService.getBlockedUsers()
                await MainActor.run {
                    blockedUsers = users
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                Logger.shared.error("Error loading blocked users", category: .moderation, error: error)
            }
        }
    }

    private func unblockUser(_ user: User) {
        guard let userId = user.id,
              let currentUserId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                try await reportService.unblockUser(blockerId: currentUserId, blockedId: userId)
                await MainActor.run {
                    blockedUsers.removeAll { $0.id == userId }
                    HapticManager.shared.success()
                }
            } catch {
                Logger.shared.error("Error unblocking user", category: .moderation, error: error)
                HapticManager.shared.error()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportUserView(user: User(
            email: "test@test.com",
            fullName: "Test User",
            age: 25,
            gender: "Male",
            lookingFor: "Female",
            location: "New York",
            country: "USA"
        ))
    }
}
