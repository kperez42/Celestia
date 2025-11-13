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
    
    let lookingForOptions = ["Male", "Female", "Everyone"]
    
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
                            Text("Apply Filters")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
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
        }
    }
    
    private func applyFilters() {
        Task {
            guard let currentUserId = authService.currentUser?.id else { return }
            
            let ageRangeInt = Int(ageRange.lowerBound)...Int(ageRange.upperBound)
            let country = showAllCountries ? nil : selectedCountry
            
            do {
                try await userService.fetchUsers(
                    excludingUserId: currentUserId,
                    lookingFor: lookingFor == "Everyone" ? nil : lookingFor,
                    ageRange: ageRangeInt,
                    country: country
                )
                dismiss()
            } catch {
                Logger.shared.error("Error applying filters", category: .database, error: error)
            }
        }
    }
    
    private func resetFilters() {
        ageRange = 18...99
        showAllCountries = true
        selectedCountry = ""
        lookingFor = authService.currentUser?.lookingFor ?? "Everyone"
    }
}

#Preview {
    FilterView()
        .environmentObject(AuthService.shared)
}
