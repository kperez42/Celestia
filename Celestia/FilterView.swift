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

    let lookingForOptions = ["Men", "Women", "Everyone"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Age Range Section
                    ageRangeSection

                    // Gender Preference Section
                    genderPreferenceSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Save Button
                Button {
                    applyFilters()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save & Apply")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            .onAppear {
                loadCurrentPreferences()
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
            // Header with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "heart.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Age Preference")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Who would you like to meet?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Age range badge
                Text("\(ageRangeMin) - \(ageRangeMax)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }

            // Age pickers
            HStack(spacing: 20) {
                // Min age
                VStack(spacing: 8) {
                    Text("From")
                        .font(.caption)
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

                // Divider
                Text("to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Max age
                VStack(spacing: 8) {
                    Text("To")
                        .font(.caption)
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Gender Preference Section

    private var genderPreferenceSection: some View {
        VStack(spacing: 16) {
            // Header with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Looking For")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Select your preference")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Gender picker
            Picker("Looking for", selection: $lookingFor) {
                ForEach(lookingForOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func applyFilters() {
        Task {
            guard var currentUser = authService.currentUser,
                  let currentUserId = currentUser.effectiveId else { return }

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
                    excludingUserId: currentUserId,
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
