//
//  StripeIdentityVerificationView.swift
//  Celestia
//
//  SwiftUI view for Stripe Identity verification flow
//  This is the primary and recommended method for ID verification
//

import SwiftUI

// MARK: - Stripe Identity Verification View

struct StripeIdentityVerificationView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var stripeManager = StripeIdentityManager.shared

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var verificationComplete = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Status or Start Button
                    if verificationComplete {
                        successSection
                    } else if stripeManager.verificationStatus == .processing {
                        processingSection
                    } else {
                        startVerificationSection
                    }

                    // How it works
                    howItWorksSection

                    // Privacy info
                    privacySection
                }
                .padding()
            }
            .navigationTitle("ID Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Verification Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Stripe Identity Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.purple)
            }

            Text("Verify Your Identity")
                .font(.title2)
                .fontWeight(.bold)

            Text("Quick and secure ID verification powered by Stripe")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Trust badges
            HStack(spacing: 16) {
                trustBadge(icon: "lock.shield.fill", text: "Secure")
                trustBadge(icon: "clock.fill", text: "Fast")
                trustBadge(icon: "checkmark.seal.fill", text: "Trusted")
            }
        }
    }

    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Start Verification Section

    private var startVerificationSection: some View {
        VStack(spacing: 20) {
            // Points earned
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("+35 Trust Score Points")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)

            // What you'll need
            VStack(alignment: .leading, spacing: 12) {
                Text("What you'll need:")
                    .font(.headline)

                requirementRow(icon: "person.text.rectangle", text: "Valid government-issued ID")
                requirementRow(icon: "camera.fill", text: "Camera access for selfie")
                requirementRow(icon: "light.max", text: "Good lighting")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Start button
            Button(action: startVerification) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Start Verification")
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading ? Color.gray : Color.purple)
                .cornerRadius(12)
            }
            .disabled(isLoading)

            // Accepted IDs
            VStack(alignment: .leading, spacing: 8) {
                Text("Accepted IDs")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    idTypeBadge("Passport")
                    idTypeBadge("Driver's License")
                    idTypeBadge("National ID")
                }
            }
        }
    }

    private func requirementRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func idTypeBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .foregroundColor(.purple)
            .cornerRadius(4)
    }

    // MARK: - Success Section

    private var successSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            Text("Verification Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)

            Text("Your identity has been verified. You now have a verified badge on your profile!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { dismiss() }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Verification in Progress")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your verification is being reviewed. This usually takes just a few moments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("You can close this screen. We'll notify you when verification is complete.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - How It Works Section

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works")
                .font(.headline)

            stepRow(number: 1, title: "Scan your ID", description: "Take a photo of your government-issued ID")
            stepRow(number: 2, title: "Take a selfie", description: "We'll match your face to your ID photo")
            stepRow(number: 3, title: "Get verified", description: "Receive your verified badge instantly")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func stepRow(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                Text("Your privacy is protected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text("Your ID information is processed securely by Stripe and is never stored on our servers. Only the verification result is saved.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                Text("Powered by Stripe Identity")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func startVerification() {
        isLoading = true

        Task {
            do {
                // Get the presenting view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw StripeIdentityError.sdkNotConfigured
                }

                // Find the topmost presented view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                // Start Stripe Identity verification
                let result = try await stripeManager.startVerification(from: topController)

                await MainActor.run {
                    isLoading = false

                    if result.isVerified {
                        verificationComplete = true
                    } else if result.status == .processing {
                        // Still processing, UI will show processing state
                    } else if result.status == .canceled {
                        // User canceled, just dismiss
                    } else {
                        errorMessage = result.failureReason ?? "Verification failed. Please try again."
                        showingError = true
                    }
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StripeIdentityVerificationView()
}
