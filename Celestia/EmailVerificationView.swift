//
//  EmailVerificationView.swift
//  Celestia
//
//  Email verification screen shown after signup
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isChecking = false
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss

    var userEmail: String {
        return authService.userSession?.email ?? "your email"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)

            // Title
            Text("Verify Your Email")
                .font(.title)
                .fontWeight(.bold)

            // Message
            Text("We've sent a verification link to")
                .font(.body)
                .foregroundColor(.secondary)

            Text(userEmail)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Click the link in the email to verify your account and continue.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Spam folder warning - styled to match page theme
            HStack(spacing: 12) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check your spam folder")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("The email might be in your spam or junk folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 32)

            Spacer()

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Success message
            if showSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Verification email sent!")
                }
                .font(.subheadline)
                .foregroundColor(.green)
                .padding(.vertical, 8)
            }

            // Buttons
            VStack(spacing: 12) {
                // Check if verified button
                Button {
                    checkVerification()
                } label: {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("I've Verified My Email")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isChecking)

                // Resend email button
                Button {
                    resendVerification()
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Resend Verification Email")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(isSending)

                // Sign out button
                Button {
                    Task {
                        await authService.signOut()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func checkVerification() {
        isChecking = true
        errorMessage = nil
        showSuccess = false

        Task {
            do {
                try await authService.reloadUser()

                if authService.isEmailVerified {
                    // Email is verified! Dismiss this view
                    await MainActor.run {
                        isChecking = false
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isChecking = false
                        errorMessage = "Email not verified yet. Please check your inbox (and spam/junk folder) and click the verification link."
                    }
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    errorMessage = "Error checking verification status. Please try again."
                }
            }
        }
    }

    private func resendVerification() {
        isSending = true
        errorMessage = nil
        showSuccess = false

        Task {
            do {
                try await authService.sendEmailVerification()

                await MainActor.run {
                    isSending = false
                    showSuccess = true

                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    if let celestiaError = error as? CelestiaError {
                        errorMessage = celestiaError.errorDescription
                    } else {
                        errorMessage = "Failed to send verification email. Please try again."
                    }
                }
            }
        }
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthService.shared)
}
