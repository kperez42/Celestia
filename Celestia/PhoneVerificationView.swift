//
//  PhoneVerificationView.swift
//  Celestia
//
//  Full phone number verification flow with SMS OTP
//

import SwiftUI

struct PhoneVerificationView: View {
    @StateObject private var service = PhoneVerificationService.shared
    @Environment(\.dismiss) var dismiss
    @State private var phoneInput: String = ""
    @State private var codeInput: String = ""
    @State private var showSuccessAnimation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    header

                    // Main content based on state
                    switch service.verificationState {
                    case .initial, .sendingCode:
                        phoneNumberInput
                    case .codeSent, .verifying:
                        codeVerificationInput
                    case .verified:
                        successView
                    case .failed:
                        errorView
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Phone Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: service.verificationState == .verified ? "checkmark.shield.fill" : "phone.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: service.verificationState == .verified ? [.green, .blue] : [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showSuccessAnimation ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSuccessAnimation)
            }

            Text("Verify Your Phone Number")
                .font(.title2.bold())

            Text("We'll send you a verification code via SMS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Phone Number Input

    private var phoneNumberInput: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)

                    TextField("+1 234 567 8900", text: $phoneInput)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.body)
                        .disabled(service.verificationState == .sendingCode)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text("Enter your number in international format (e.g., +1234567890)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            Button(action: {
                Task {
                    await sendCode()
                }
            }) {
                HStack {
                    if service.verificationState == .sendingCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(service.verificationState == .sendingCode ? "Sending..." : "Send Code")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: phoneInput.isEmpty ? [.gray, .gray] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(phoneInput.isEmpty || service.verificationState == .sendingCode)

            // Example format
            infoBox(
                icon: "info.circle.fill",
                title: "International Format Required",
                message: "Start with your country code:\n+1 for USA/Canada\n+44 for UK\n+91 for India"
            )
        }
        .padding(.top)
    }

    // MARK: - Code Verification Input

    private var codeVerificationInput: some View {
        VStack(spacing: 20) {
            infoBox(
                icon: "message.fill",
                title: "Code Sent!",
                message: "We sent a 6-digit code to \(phoneInput)"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Code")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.secondary)

                    TextField("123456", text: $codeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.title3.monospacedDigit())
                        .disabled(service.verificationState == .verifying)
                        .onChange(of: codeInput) { _, newValue in
                            // Auto-verify when 6 digits entered
                            if newValue.count == 6 {
                                Task {
                                    await verifyCode()
                                }
                            }
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text("Enter the 6-digit code we sent you")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            Button(action: {
                Task {
                    await verifyCode()
                }
            }) {
                HStack {
                    if service.verificationState == .verifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(service.verificationState == .verifying ? "Verifying..." : "Verify Code")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: codeInput.count != 6 ? [.gray, .gray] : [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(codeInput.count != 6 || service.verificationState == .verifying)

            // Resend code button
            Button(action: {
                Task {
                    await resendCode()
                }
            }) {
                Text("Didn't receive code? Resend")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
            .opacity(showSuccessAnimation ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showSuccessAnimation = true
                }
            }

            Text("Phone Verified!")
                .font(.title.bold())

            Text("Your phone number has been successfully verified")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Done")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            infoBox(
                icon: "exclamationmark.triangle.fill",
                title: "Verification Failed",
                message: service.errorMessage ?? "An error occurred. Please try again.",
                color: .red
            )

            Button(action: {
                service.reset()
                phoneInput = ""
                codeInput = ""
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
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
                .cornerRadius(12)
            }
        }
        .padding(.top)
    }

    // MARK: - Helper Views

    private func infoBox(icon: String, title: String, message: String, color: Color = .blue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(color)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func sendCode() async {
        do {
            try await service.sendVerificationCode(phoneNumber: phoneInput)
        } catch {
            Logger.shared.error("Failed to send verification code", category: .authentication, error: error)
        }
    }

    private func verifyCode() async {
        do {
            try await service.verifyCode(codeInput)
        } catch {
            Logger.shared.error("Failed to verify code", category: .authentication, error: error)
        }
    }

    private func resendCode() async {
        codeInput = ""
        do {
            try await service.resendCode()
        } catch {
            Logger.shared.error("Failed to resend code", category: .authentication, error: error)
        }
    }
}

#Preview {
    PhoneVerificationView()
}
