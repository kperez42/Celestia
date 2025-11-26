//
//  AdvancedFiltersSheet.swift
//  Celestia
//
//  Advanced filtering options for user discovery
//

import SwiftUI

struct AdvancedFiltersSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var ageRange: ClosedRange<Int>
    @Binding var gender: String
    @Binding var verifiedOnly: Bool

    @State private var selectedCountry = ""
    @State private var onlineOnly = false
    @State private var hasPhotos = true
    @State private var hasBio = false
    @State private var sortBy: SortOption = .newest

    enum SortOption: String, CaseIterable {
        case newest = "Newest Members"
        case active = "Recently Active"
        case popular = "Most Popular"
    }
    
    let genderOptions = ["Everyone", "Men", "Women", "Non-binary"]
    let countries = ["All Countries", "United States", "United Kingdom", "Canada", "Australia", "Germany", "France", "Spain", "Italy", "Mexico", "Brazil"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Gender preference
                        genderSection
                        
                        // Age range
                        ageRangeSection

                        // Location
                        locationSection
                        
                        // Sort by
                        sortBySection
                        
                        // Additional filters
                        additionalFiltersSection
                        
                        // Apply button
                        applyButton
                    }
                    .padding(20)
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
                    .foregroundColor(.purple)
                }
            }
        }
    }
    
    // MARK: - Gender Section
    
    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "person.2.fill", title: "Show Me")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(genderOptions, id: \.self) { option in
                    FilterOptionButton(
                        title: option,
                        isSelected: gender == option
                    ) {
                        gender = option
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Age Range Section
    
    private var ageRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar", title: "Age Range")
            
            HStack {
                Text("\(Int(ageRange.lowerBound))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                    .frame(width: 50)
                
                Spacer()
                
                Text("to")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(ageRange.upperBound))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                    .frame(width: 50)
            }
            
            // Min age slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum age")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Slider(
                    value: Binding(
                        get: { Double(ageRange.lowerBound) },
                        set: { newValue in
                            let minValue = Int(newValue)
                            ageRange = min(minValue, Int(ageRange.upperBound))...Int(ageRange.upperBound)
                        }
                    ),
                    in: 18...99,
                    step: 1
                )
                .accentColor(.purple)
            }
            
            // Max age slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Maximum age")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Slider(
                    value: Binding(
                        get: { Double(ageRange.upperBound) },
                        set: { newValue in
                            let maxValue = Int(newValue)
                            ageRange = Int(ageRange.lowerBound)...max(maxValue, Int(ageRange.lowerBound))
                        }
                    ),
                    in: 18...99,
                    step: 1
                )
                .accentColor(.purple)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "flag.fill", title: "Country")
            
            Menu {
                ForEach(countries, id: \.self) { country in
                    Button(country) {
                        selectedCountry = country
                    }
                }
            } label: {
                HStack {
                    Text(selectedCountry.isEmpty ? "All Countries" : selectedCountry)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Sort By Section
    
    private var sortBySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "arrow.up.arrow.down", title: "Sort By")
            
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    sortBy = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if sortBy == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Additional Filters Section
    
    private var additionalFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "slider.horizontal.3", title: "Additional Filters")
            
            FilterToggle(
                icon: "checkmark.seal.fill",
                title: "Verified only",
                isOn: $verifiedOnly
            )
            
            FilterToggle(
                icon: "circle.fill",
                title: "Online now",
                isOn: $onlineOnly
            )
            
            FilterToggle(
                icon: "photo.fill",
                title: "Has photos",
                isOn: $hasPhotos
            )
            
            FilterToggle(
                icon: "text.alignleft",
                title: "Has bio",
                isOn: $hasBio
            )
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        Button {
            applyFilters()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Apply Filters")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.purple)
            Text(title)
                .font(.headline)
        }
    }
    
    // MARK: - Actions
    
    private func applyFilters() {
        // Filters are bound, so they're already updated
        let haptics = HapticManager.shared
        haptics.notification(.success)
        dismiss()
    }
    
    private func resetFilters() {
        ageRange = 18...99
        gender = "Everyone"
        verifiedOnly = false
        selectedCountry = ""
        onlineOnly = false
        hasPhotos = true
        hasBio = false
        sortBy = .newest

        let haptics = HapticManager.shared
        haptics.impact(.medium)
    }
}

// MARK: - Filter Option Button

struct FilterOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isSelected ?
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ) :
                    AnyShapeStyle(Color(.systemGray6))
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Filter Toggle

struct FilterToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(isOn ? .purple : .gray)
                Text(title)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .tint(.purple)
    }
}

// MARK: - Boost Profile Sheet

struct BoostProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDuration: BoostDuration = .thirtyMinutes
    @State private var showPurchaseSuccess = false
    
    enum BoostDuration: String, CaseIterable {
        case thirtyMinutes = "30 Minutes"
        case oneHour = "1 Hour"
        case threeHours = "3 Hours"
        case twentyFourHours = "24 Hours"
        
        var price: String {
            switch self {
            case .thirtyMinutes: return "$4.99"
            case .oneHour: return "$7.99"
            case .threeHours: return "$14.99"
            case .twentyFourHours: return "$24.99"
            }
        }
        
        var multiplier: String {
            switch self {
            case .thirtyMinutes: return "3x"
            case .oneHour: return "5x"
            case .threeHours: return "10x"
            case .twentyFourHours: return "15x"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection
                        
                        // Benefits
                        benefitsSection
                        
                        // Duration options
                        durationOptions
                        
                        // Boost button
                        boostButton
                        
                        // Disclaimer
                        disclaimerText
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Boost Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("Boost Activated! ⚡", isPresented: $showPurchaseSuccess) {
                Button("Start Swiping") {
                    dismiss()
                }
            } message: {
                Text("Your profile is now boosted for \(selectedDuration.rawValue.lowercased())!")
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 10)
            }
            
            VStack(spacing: 8) {
                Text("Get More Matches")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Boost your profile to be seen by more people")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(spacing: 12) {
            BenefitRow(icon: "eye.fill", text: "Be one of the top profiles in your area")
            BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Get up to 15x more profile views")
            BenefitRow(icon: "heart.fill", text: "Increase your chances of matching")
            BenefitRow(icon: "timer", text: "Instant activation")
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Duration Options
    
    private var durationOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Choose Duration")
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            ForEach(BoostDuration.allCases, id: \.self) { duration in
                Button {
                    selectedDuration = duration
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(duration.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(duration.multiplier) more views")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text(duration.price)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                            
                            if selectedDuration == duration {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        selectedDuration == duration ?
                        Color.purple.opacity(0.1) :
                        Color(.systemGray6)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedDuration == duration ? Color.purple : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }
        }
    }
    
    // MARK: - Boost Button
    
    private var boostButton: some View {
        Button {
            activateBoost()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                Text("Boost for \(selectedDuration.price)")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .orange.opacity(0.5), radius: 15, y: 8)
        }
    }
    
    // MARK: - Disclaimer
    
    private var disclaimerText: some View {
        Text("Boosts are one-time purchases and expire after the selected duration. Results may vary based on your profile quality and location.")
            .font(.caption)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }
    
    // MARK: - Actions

    private func activateBoost() {
        // In a real app, this would process the payment
        let haptics = HapticManager.shared
        haptics.notification(.success)
        showPurchaseSuccess = true
    }
}

// MARK: - Previews

#Preview("Advanced Filters") {
    AdvancedFiltersSheet(
        ageRange: .constant(18...35),
        gender: .constant("Everyone"),
        verifiedOnly: .constant(false)
    )
}

#Preview("Boost Profile") {
    BoostProfileSheet()
}
