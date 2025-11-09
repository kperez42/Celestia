//
//  PhotoVerificationView.swift
//  Celestia
//
//  Complete photo verification flow with camera and results
//

import SwiftUI

struct PhotoVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var verificationService = PhotoVerification.shared

    let userId: String

    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var verificationState: VerificationState = .instructions
    @State private var verificationResult: VerificationResult?
    @State private var showingSuccess = false

    enum VerificationState {
        case instructions
        case camera
        case verifying
        case success
        case error
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.pink.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Content
                Group {
                    switch verificationState {
                    case .instructions:
                        instructionsView
                    case .camera:
                        cameraView
                    case .verifying:
                        verifyingView
                    case .success:
                        successView
                    case .error:
                        errorView
                    }
                }
            }
            .navigationTitle("Get Verified")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if verificationState == .instructions {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.purple)
                    }
                }
            }
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 40)

                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Get the Blue Checkmark")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Verified profiles get 3x more matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Benefits
                VStack(spacing: 20) {
                    BenefitRow(
                        icon: "checkmark.shield.fill",
                        title: "Build Trust",
                        description: "Show you're real and serious about dating"
                    )

                    BenefitRow(
                        icon: "eye.fill",
                        title: "Stand Out",
                        description: "Get priority visibility in Discovery"
                    )

                    BenefitRow(
                        icon: "heart.fill",
                        title: "More Matches",
                        description: "People prefer verified profiles"
                    )
                }
                .padding(.horizontal, 24)

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("How it works:")
                        .font(.headline)
                        .padding(.horizontal)

                    InstructionStep(
                        number: 1,
                        text: "Take a selfie following our guidelines"
                    )

                    InstructionStep(
                        number: 2,
                        text: "We'll verify your face matches your profile"
                    )

                    InstructionStep(
                        number: 3,
                        text: "Get your blue checkmark instantly"
                    )
                }
                .padding(.horizontal, 24)

                // Start button
                Button {
                    HapticManager.shared.impact(.medium)
                    verificationState = .camera
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                        Text("Start Verification")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        CameraView(
            onPhotoCaptured: { image in
                capturedImage = image
                verificationState = .verifying
                startVerification(image: image)
            },
            onCancel: {
                verificationState = .instructions
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Verifying View

    private var verifyingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Processing animation
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: verificationService.verificationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: verificationService.verificationProgress)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Verifying your photo...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(verificationStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var verificationStatusText: String {
        let progress = verificationService.verificationProgress
        if progress < 0.3 {
            return "Detecting face..."
        } else if progress < 0.5 {
            return "Checking image quality..."
        } else if progress < 0.8 {
            return "Matching with profile photos..."
        } else {
            return "Finalizing verification..."
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            .scaleEffect(showingSuccess ? 1 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showingSuccess)

            VStack(spacing: 12) {
                Text("You're Verified!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your profile now has the blue checkmark")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .opacity(showingSuccess ? 1 : 0)
            .offset(y: showingSuccess ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: showingSuccess)

            // Stats
            HStack(spacing: 32) {
                StatBadge(value: "3x", label: "More Matches")
                StatBadge(value: "Top", label: "Visibility")
                StatBadge(value: "100%", label: "Authentic")
            }
            .opacity(showingSuccess ? 1 : 0)
            .offset(y: showingSuccess ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: showingSuccess)

            Spacer()

            Button {
                HapticManager.shared.impact(.medium)
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(showingSuccess ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: showingSuccess)
        }
        .onAppear {
            withAnimation {
                showingSuccess = true
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Error icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.2), .orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.red)
            }

            VStack(spacing: 12) {
                Text("Verification Failed")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let error = verificationService.verificationError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                Text("Tips for success:")
                    .font(.headline)

                TipRow(icon: "lightbulb.fill", text: "Make sure you're well lit")
                TipRow(icon: "camera.fill", text: "Face the camera directly")
                TipRow(icon: "eye.fill", text: "Remove sunglasses or hats")
                TipRow(icon: "person.fill", text: "Match your profile photos")
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            Spacer()

            // Retry button
            Button {
                HapticManager.shared.impact(.medium)
                verificationService.reset()
                verificationState = .camera
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func startVerification(image: UIImage) {
        Task {
            do {
                let result = try await verificationService.verifyPhoto(image: image, userId: userId)
                verificationResult = result
                await MainActor.run {
                    verificationState = .success
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    verificationState = .error
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(.purple)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoVerificationView(userId: "test-user-id")
}
