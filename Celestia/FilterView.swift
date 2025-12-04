//
//  FilterView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var userService = UserService.shared

    @State private var ageRangeMin: Int = 18
    @State private var ageRangeMax: Int = 99
    @State private var lookingFor = "Everyone"
    @State private var isLoading = false
    @State private var showSaveConfirmation = false
    @State private var animateHeader = false

    let lookingForOptions = ["Men", "Women", "Everyone"]

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium gradient background
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.08),
                        Color.pink.opacity(0.05),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Age Range Section
                        ageRangeSection

                        // Gender Preference Section
                        genderPreferenceSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        resetFilters()
                    } label: {
                        Text("Reset")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Premium Save Button
                Button {
                    applyFilters()
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Save & Apply")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink, .purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
                    .shadow(color: .pink.opacity(0.3), radius: 6, y: 3)
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                )
            }
            .onAppear {
                loadCurrentPreferences()
                animateHeader = true
            }
            .alert("Preferences Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your preferences have been updated successfully.")
            }
        }
    }

    // MARK: - Age Range Section

    private var ageRangeSection: some View {
        VStack(spacing: 16) {
            // Premium header with radial glow icon
            HStack(spacing: 14) {
                ZStack {
                    // Radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.pink.opacity(0.3), Color.pink.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Age Preference")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Who would you like to meet?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Premium age range badge
                Text("\(ageRangeMin) - \(ageRangeMax)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .pink.opacity(0.3), radius: 6, y: 3)
            }

            // Age pickers
            HStack(spacing: 20) {
                // Min age
                VStack(spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Picker("Min Age", selection: $ageRangeMin) {
                        ForEach(18..<99, id: \.self) { age in
                            Text("\(age)").tag(age)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .clipped()
                    .onChange(of: ageRangeMin) { _, newValue in
                        if newValue >= ageRangeMax {
                            ageRangeMax = newValue + 1
                        }
                    }
                }

                // Premium divider
                VStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Max age
                VStack(spacing: 8) {
                    Text("To")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Picker("Max Age", selection: $ageRangeMax) {
                        ForEach(19..<100, id: \.self) { age in
                            Text("\(age)").tag(age)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .clipped()
                    .onChange(of: ageRangeMax) { _, newValue in
                        if newValue <= ageRangeMin {
                            ageRangeMin = newValue - 1
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .purple.opacity(0.08), radius: 12, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.pink.opacity(0.2), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Gender Preference Section

    private var genderPreferenceSection: some View {
        VStack(spacing: 18) {
            // Premium header with radial glow icon
            HStack(spacing: 14) {
                ZStack {
                    // Radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Looking For")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Select your preference")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Premium gender picker options
            HStack(spacing: 12) {
                ForEach(lookingForOptions, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            lookingFor = option
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconForOption(option))
                                .font(.system(size: 14, weight: .semibold))

                            Text(option)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            lookingFor == option ?
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color(.systemGray6), Color(.systemGray6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(lookingFor == option ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(
                            color: lookingFor == option ? .purple.opacity(0.3) : .clear,
                            radius: 8,
                            y: 4
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .purple.opacity(0.08), radius: 12, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func iconForOption(_ option: String) -> String {
        switch option {
        case "Men": return "person.fill"
        case "Women": return "person.fill"
        case "Everyone": return "person.2.fill"
        default: return "person.fill"
        }
    }

    // MARK: - Actions

    private func applyFilters() {
        Task {
            guard var currentUser = authService.currentUser else { return }

            isLoading = true

            let ageRangeInt = ageRangeMin...ageRangeMax

            do {
                // Update user's preferences in their profile
                currentUser.lookingFor = lookingFor
                currentUser.ageRangeMin = ageRangeMin
                currentUser.ageRangeMax = ageRangeMax

                // Save to Firebase
                try await authService.updateUser(currentUser)

                // Fetch users with new filters
                try await userService.fetchUsers(
                    excludingUserId: currentUser.id ?? "",
                    lookingFor: lookingFor == "Everyone" ? nil : lookingFor,
                    ageRange: ageRangeInt,
                    country: nil
                )

                await MainActor.run {
                    isLoading = false
                    showSaveConfirmation = true
                }
            } catch {
                Logger.shared.error("Error applying filters", category: .database, error: error)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func loadCurrentPreferences() {
        guard let currentUser = authService.currentUser else { return }

        lookingFor = currentUser.lookingFor
        ageRangeMin = currentUser.ageRangeMin
        ageRangeMax = currentUser.ageRangeMax
    }

    private func resetFilters() {
        loadCurrentPreferences()
    }
}

#Preview {
    FilterView()
        .environmentObject(AuthService.shared)
}
