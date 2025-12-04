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
            ZStack {
                // Premium gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.05),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

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
            }
            .navigationTitle("Phone Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 18) {
            // Premium icon with radial glow
            ZStack {
                // Outer radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (service.verificationState == .verified ? Color.green : Color.blue).opacity(0.25),
                                (service.verificationState == .verified ? Color.mint : Color.purple).opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 25,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(showSuccessAnimation ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showSuccessAnimation)

                // Inner glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: service.verificationState == .verified ?
                            [.green.opacity(0.4), .mint.opacity(0.2)] :
                            [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)

                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: service.verificationState == .verified ?
                            [.green.opacity(0.2), .blue.opacity(0.15)] :
                            [.blue.opacity(0.15), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: (service.verificationState == .verified ? Color.green : Color.blue).opacity(0.2), radius: 15)

                Image(systemName: service.verificationState == .verified ? "checkmark.shield.fill" : "phone.fill")
                    .font(.system(size: 45, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: service.verificationState == .verified ? [.green, .mint] : [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: (service.verificationState == .verified ? Color.green : Color.blue).opacity(0.3), radius: 8)
                    .scaleEffect(showSuccessAnimation ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSuccessAnimation)
            }

            Text("Verify Your Phone Number")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("We'll send you a verification code via SMS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .onAppear {
            showSuccessAnimation = true
        }
    }

    // MARK: - Phone Number Input

    private var phoneNumberInput: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Phone Number")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    TextField("+1 234 567 8900", text: $phoneInput)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.body)
                        .fontWeight(.medium)
                        .disabled(service.verificationState == .sendingCode)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .blue.opacity(0.08), radius: 10, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )

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
                HStack(spacing: 10) {
                    if service.verificationState == .sendingCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(service.verificationState == .sendingCode ? "Sending..." : "Send Code")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: phoneInput.isEmpty ? [.gray.opacity(0.5), .gray.opacity(0.4)] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(
                    color: phoneInput.isEmpty ? .clear : .blue.opacity(0.4),
                    radius: 12,
                    y: 6
                )
                .shadow(
                    color: phoneInput.isEmpty ? .clear : .purple.opacity(0.3),
                    radius: 6,
                    y: 3
                )
            }
            .disabled(phoneInput.isEmpty || service.verificationState == .sendingCode)

            // Premium info box
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
        VStack(spacing: 22) {
            infoBox(
                icon: "message.fill",
                title: "Code Sent!",
                message: "We sent a 6-digit code to \(phoneInput)"
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Verification Code")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.15), .blue.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    TextField("123456", text: $codeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
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
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .green.opacity(0.08), radius: 10, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .blue.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )

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
                HStack(spacing: 10) {
                    if service.verificationState == .verifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(service.verificationState == .verifying ? "Verifying..." : "Verify Code")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: codeInput.count != 6 ? [.gray.opacity(0.5), .gray.opacity(0.4)] : [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(
                    color: codeInput.count != 6 ? .clear : .green.opacity(0.4),
                    radius: 12,
                    y: 6
                )
                .shadow(
                    color: codeInput.count != 6 ? .clear : .blue.opacity(0.3),
                    radius: 6,
                    y: 3
                )
            }
            .disabled(codeInput.count != 6 || service.verificationState == .verifying)

            // Premium resend code button
            Button(action: {
                Task {
                    await resendCode()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Didn't receive code? Resend")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .padding(.top)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 28) {
            // Premium success icon with radial glow
            ZStack {
                // Outer radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.green.opacity(0.3),
                                Color.mint.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(showSuccessAnimation ? 1.1 : 0.8)

                // Inner glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.4), .mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 130, height: 130)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.3), radius: 20)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 55, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .green.opacity(0.4), radius: 10)
            }
            .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
            .opacity(showSuccessAnimation ? 1.0 : 0.0)

            Text("Phone Verified!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Your phone number has been successfully verified")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("Done")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.green, .mint, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                .shadow(color: .mint.opacity(0.3), radius: 6, y: 3)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 22) {
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
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Try Again")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)
                .shadow(color: .purple.opacity(0.3), radius: 6, y: 3)
            }
        }
        .padding(.top)
    }

    // MARK: - Helper Views

    private func infoBox(icon: String, title: String, message: String, color: Color = .blue) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.1), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
