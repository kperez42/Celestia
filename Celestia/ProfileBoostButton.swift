//
//  ProfileBoostButton.swift
//  Celestia
//
//  UI component for activating profile boost
//

import SwiftUI

struct ProfileBoostButton: View {
    @ObservedObject private var boostService = ProfileBoostService.shared
    @EnvironmentObject var authService: AuthService
    @State private var showingBoostSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        if boostService.isBoostActive {
            // Active boost indicator
            activeBoostView
        } else {
            // Boost activation button
            boostActivationButton
        }
    }

    // MARK: - Active Boost View

    private var activeBoostView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Boost Active!")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Time remaining: \(boostService.getFormattedTimeRemaining())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("10x")
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )

            // Cancel button
            Button {
                Task {
                    await boostService.cancelBoost()
                }
            } label: {
                Text("Cancel Boost")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Boost Activation Button

    private var boostActivationButton: some View {
        Button {
            showingBoostSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Boost Your Profile")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let user = authService.currentUser {
                        Text("\(user.boostsRemaining) boost\(user.boostsRemaining == 1 ? "" : "s") remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingBoostSheet) {
            BoostConfirmationSheet(
                onConfirm: {
                    Task {
                        await activateBoost()
                    }
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func activateBoost() async {
        do {
            try await boostService.activateBoost()
            showingBoostSheet = false
        } catch let error as ProfileBoostError {
            errorMessage = error.errorDescription ?? "Unknown error"
            showingError = true
        } catch {
            errorMessage = "Failed to activate boost. Please try again."
            showingError = true
            Logger.shared.error("Error activating boost", category: .user, error: error)
        }
    }
}

// MARK: - Boost Confirmation Sheet

struct BoostConfirmationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 40)

                // Title and description
                VStack(spacing: 12) {
                    Text("Boost Your Profile")
                        .font(.title.bold())

                    Text("Be seen by 10x more people for 30 minutes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "eye.fill", text: "Get 10x more profile views", color: .blue)
                    BenefitRow(icon: "heart.fill", text: "Receive more likes and matches", color: .pink)
                    BenefitRow(icon: "clock.fill", text: "Boost lasts for 30 minutes", color: .purple)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                Spacer()

                // Boosts remaining
                if let user = authService.currentUser {
                    Text("You have \(user.boostsRemaining) boost\(user.boostsRemaining == 1 ? "" : "s") remaining")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Activate Boost")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled((authService.currentUser?.boostsRemaining ?? 0) <= 0)

                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.horizontal)
            .navigationTitle("Profile Boost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VStack {
            ProfileBoostButton()
                .environmentObject(AuthService.shared)
            Spacer()
        }
    }
}
