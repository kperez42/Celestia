//
//  SignInView.swift
//  Celestia
//
//  Sign in screen
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                // Premium gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.94, blue: 1.0),
                        Color(red: 1.0, green: 0.98, blue: 0.98),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Header with radial glow
                        VStack(spacing: 16) {
                            ZStack {
                                // Outer glow rings
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 90
                                        )
                                    )
                                    .frame(width: 160, height: 160)

                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 110, height: 110)

                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                            }

                            VStack(spacing: 8) {
                                Text("Welcome Back")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                Text("Sign in to continue your journey")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 40)

                        // Form Card
                        VStack(spacing: 24) {
                            // Email
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope.fill")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                        )
                                    Text("Email")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                }

                                TextField("Enter your email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .focused($emailFieldFocused)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                emailFieldFocused ?
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.5), Color.pink.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ) :
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: emailFieldFocused ? 2 : 1
                                            )
                                    )
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                        )
                                    Text("Password")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .focused($passwordFieldFocused)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .focused($passwordFieldFocused)
                                    }

                                    Button {
                                        showPassword.toggle()
                                        HapticManager.shared.impact(.light)
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(
                                                LinearGradient(colors: [.purple.opacity(0.6), .pink.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                                            )
                                    }
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                                    .accessibilityHint("Toggle password visibility")
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            passwordFieldFocused ?
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.5), Color.pink.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: passwordFieldFocused ? 2 : 1
                                        )
                                )
                            }

                            // Error message with enhanced styling
                            if let errorMessage = authService.errorMessage, !errorMessage.isEmpty {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.12))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    Text(errorMessage)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.red)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.08))
                                )
                            }

                            // Sign In Button with premium styling
                            Button {
                                HapticManager.shared.impact(.medium)
                                Task {
                                    do {
                                        try await authService.signIn(withEmail: email, password: password)
                                    } catch {
                                        Logger.shared.error("Error signing in", category: .authentication, error: error)
                                        // Error is handled by AuthService setting errorMessage
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.callout)
                                        Text("Sign In")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .background(
                                (email.isEmpty || password.isEmpty) ?
                                LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(
                                    colors: [.purple, .pink, .purple.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: (email.isEmpty || password.isEmpty) ? .clear : .purple.opacity(0.4), radius: 12, y: 6)
                            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                            .scaleButton()

                            // Forgot Password with gradient text
                            Button {
                                showForgotPassword = true
                                HapticManager.shared.impact(.light)
                            } label: {
                                Text("Forgot Password?")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            .scaleButton(scale: 0.97)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: authService.userSession) { session in
            if session != nil {
                dismiss()
            }
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            Button("Cancel", role: .cancel) {
                resetEmail = ""
            }

            Button("Send Reset Link") {
                Task {
                    do {
                        try await AuthService.shared.resetPassword(email: resetEmail)
                        resetEmail = ""
                        showResetSuccess = true
                    } catch {
                        // Error is handled by AuthService
                    }
                }
            }
        } message: {
            Text("Enter your email address and we'll send you a link to reset your password.")
        }
        .alert("Email Sent", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Password reset link has been sent to your email.")
        }
        .onAppear {
            // Clear any error messages from other screens
            authService.errorMessage = nil
        }
        .onDisappear {
            // Clear error messages when leaving
            authService.errorMessage = nil
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthService.shared)
}
