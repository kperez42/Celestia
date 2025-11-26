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
    
    @State private var ageRange: ClosedRange<Double> = 18...99
    @State private var showAllCountries = true
    @State private var selectedCountry = ""
    @State private var lookingFor = "Everyone"
    @State private var isLoading = false
    @State private var showSaveConfirmation = false

    let lookingForOptions = ["Men", "Women", "Everyone"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Age Range") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(Int(ageRange.lowerBound)) - \(Int(ageRange.upperBound)) years old")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text("\(Int(ageRange.lowerBound))")
                            Slider(value: Binding(
                                get: { ageRange.lowerBound },
                                set: { newValue in
                                    ageRange = min(newValue, ageRange.upperBound)...ageRange.upperBound
                                }
                            ), in: 18...99, step: 1)
                            Text("\(Int(ageRange.upperBound))")
                        }
                        
                        HStack {
                            Text("\(Int(ageRange.lowerBound))")
                            Slider(value: Binding(
                                get: { ageRange.upperBound },
                                set: { newValue in
                                    ageRange = ageRange.lowerBound...max(newValue, ageRange.lowerBound)
                                }
                            ), in: 18...99, step: 1)
                            Text("\(Int(ageRange.upperBound))")
                        }
                    }
                }
                
                Section("Gender Preference") {
                    Picker("Looking for", selection: $lookingFor) {
                        ForEach(lookingForOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Location") {
                    Toggle("Show all countries", isOn: $showAllCountries)
                    
                    if !showAllCountries {
                        TextField("Country", text: $selectedCountry)
                    }
                }
                
                Section {
                    Button {
                        applyFilters()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Save & Apply")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
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
    
    private func applyFilters() {
        Task {
            guard var currentUser = authService.currentUser else { return }

            isLoading = true

            let ageRangeInt = Int(ageRange.lowerBound)...Int(ageRange.upperBound)
            let country = showAllCountries ? nil : selectedCountry

            do {
                // Update user's preferences in their profile
                currentUser.lookingFor = lookingFor
                currentUser.ageRangeMin = Int(ageRange.lowerBound)
                currentUser.ageRangeMax = Int(ageRange.upperBound)

                // Save to Firebase
                try await authService.updateUser(currentUser)

                // Fetch users with new filters
                try await userService.fetchUsers(
                    excludingUserId: currentUser.id ?? "",
                    lookingFor: lookingFor == "Everyone" ? nil : lookingFor,
                    ageRange: ageRangeInt,
                    country: country
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
        ageRange = Double(currentUser.ageRangeMin)...Double(currentUser.ageRangeMax)
    }
    
    private func resetFilters() {
        loadCurrentPreferences()
        showAllCountries = true
        selectedCountry = ""
    }
}

#Preview {
    FilterView()
        .environmentObject(AuthService.shared)
}
