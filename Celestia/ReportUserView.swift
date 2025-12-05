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
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            // PERFORMANCE: Use CachedAsyncImage
                            if let photoURL = URL(string: user.profileImageURL) {
                                CachedAsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text("\(user.age) • \(user.location)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)

                        Text("Reporting this profile will also block them from contacting you.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Reason for Report") {
                    Picker("Select a reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.description).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Additional Information (Optional)") {
                    TextEditor(text: $additionalInfo)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if additionalInfo.isEmpty {
                                    Text("Provide any additional details that might help us review this report...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                Section {
                    Button(role: .destructive) {
                        showBlockConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Block User Only")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Block this user without submitting a report. They won't be able to see your profile or contact you.")
                        .font(.caption)
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Submitting...")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(40)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(16)
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
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = user.effectiveId,
              let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

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
                ProgressView()
            } else if blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No Blocked Users")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Users you block will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack(spacing: 16) {
                            // PERFORMANCE: Use CachedAsyncImage
                            if let photoURL = URL(string: user.profileImageURL) {
                                CachedAsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text("\(user.age) • \(user.location)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Unblock") {
                                userToUnblock = user
                                showUnblockConfirmation = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                }
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
