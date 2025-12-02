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
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("Welcome Back")
                                .font(.title.bold())
                            
                            Text("Sign in to continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .focused($emailFieldFocused)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(emailFieldFocused ? LinearGradient.brandPrimary : LinearGradient.clear, lineWidth: 2)
                                    )
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
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
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                                    .accessibilityHint("Toggle password visibility")
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(passwordFieldFocused ? LinearGradient.brandPrimary : LinearGradient.clear, lineWidth: 2)
                                )
                            }
                            
                            // Error message
                            if let errorMessage = authService.errorMessage, !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            
                            // Sign In Button
                            Button {
                                Task {
                                    do {
                                        try await authService.signIn(withEmail: email, password: password)
                                    } catch {
                                        Logger.shared.error("Error signing in", category: .authentication, error: error)
                                        // Error is handled by AuthService setting errorMessage
                                    }
                                }
                            } label: {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .background(LinearGradient.brandSecondary)
                            .cornerRadius(15)
                            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                            .scaleButton()
                            
                            // Forgot Password
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                            }
                            .scaleButton(scale: 0.97)
                        }
                        .padding(.horizontal, 30)
                        
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
