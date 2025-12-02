//
//  DiscoverFiltersView.swift
//  Celestia
//
//  Professional filter settings for discovery
//

import SwiftUI

struct DiscoverFiltersView: View {
    @ObservedObject var filters = DiscoveryFilters.shared
    @Environment(\.dismiss) var dismiss

    // Section expansion state - basics, interests, and background open by default
    @State private var expandedSections: Set<FilterSection> = [.basics, .interests, .background]

    enum FilterSection: String, CaseIterable {
        case basics = "Basics"
        case interests = "Interests"
        case background = "Background"
        case lifestyle = "Lifestyle"
    }

    let commonInterests = [
        "Travel", "Hiking", "Coffee", "Food", "Photography",
        "Music", "Fitness", "Art", "Reading", "Cooking",
        "Dancing", "Movies", "Gaming", "Yoga", "Sports",
        "Wine", "Dogs", "Cats", "Beach", "Mountains"
    ]

    let educationOptions = [
        "High School", "Some College", "Associate's", "Bachelor's",
        "Master's", "Doctorate", "Trade School"
    ]

    let religionOptions = [
        "Agnostic", "Atheist", "Buddhist", "Catholic", "Christian",
        "Hindu", "Jewish", "Muslim", "Spiritual", "Other", "Prefer not to say"
    ]

    let relationshipGoalOptions = [
        "Casual Dating", "Long-term Relationship", "Marriage",
        "Friendship", "Not Sure Yet"
    ]

    let smokingOptions = ["Never", "Socially", "Regularly", "Trying to Quit"]
    let drinkingOptions = ["Never", "Socially", "Regularly", "Rarely"]
    let petOptions = ["Dog", "Cat", "Both", "Other Pets", "No Pets", "Want Pets"]
    let exerciseOptions = ["Daily", "Often", "Sometimes", "Rarely", "Never"]
    let dietOptions = ["Vegan", "Vegetarian", "Pescatarian", "Kosher", "Halal", "No Restrictions"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Active Filters Summary (no quick filters - cleaner UI)
                    if filters.hasActiveFilters {
                        activeFiltersSummary
                    }

                    // Filter Sections
                    VStack(spacing: 12) {
                        // Basics Section (no distance - advertising in specific city)
                        filterSection(
                            section: .basics,
                            icon: "slider.horizontal.3",
                            content: {
                                VStack(spacing: 20) {
                                    ageRangeSection
                                    Divider().padding(.horizontal)
                                    verificationSection
                                }
                            }
                        )

                        // Interests Section
                        filterSection(
                            section: .interests,
                            icon: "star.circle.fill",
                            content: {
                                interestsSection
                            }
                        )

                        // Background Section
                        filterSection(
                            section: .background,
                            icon: "person.text.rectangle",
                            content: {
                                VStack(spacing: 20) {
                                    educationSection
                                    Divider().padding(.horizontal)
                                    heightSection
                                    Divider().padding(.horizontal)
                                    religionSection
                                    Divider().padding(.horizontal)
                                    relationshipGoalsSection
                                }
                            }
                        )

                        // Lifestyle Section
                        filterSection(
                            section: .lifestyle,
                            icon: "leaf.circle.fill",
                            content: {
                                VStack(spacing: 20) {
                                    lifestyleChipsSection("Smoking", icon: "smoke.fill", options: smokingOptions, selected: $filters.smokingPreferences)
                                    Divider().padding(.horizontal)
                                    lifestyleChipsSection("Drinking", icon: "wineglass.fill", options: drinkingOptions, selected: $filters.drinkingPreferences)
                                    Divider().padding(.horizontal)
                                    lifestyleChipsSection("Pets", icon: "pawprint.fill", options: petOptions, selected: $filters.petPreferences)
                                    Divider().padding(.horizontal)
                                    lifestyleChipsSection("Exercise", icon: "figure.run", options: exerciseOptions, selected: $filters.exercisePreferences)
                                    Divider().padding(.horizontal)
                                    lifestyleChipsSection("Diet", icon: "leaf.fill", options: dietOptions, selected: $filters.dietPreferences)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Reset button
                    if filters.hasActiveFilters {
                        resetButton
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    } else {
                        Spacer().frame(height: 32)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.impact(.medium)
                        filters.saveToUserDefaults()
                        dismiss()
                    } label: {
                        Text("Apply")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
    }

    // MARK: - Active Filters Summary

    private var activeFiltersSummary: some View {
        let activeCount = countActiveFilters()

        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.purple)

            Text("\(activeCount) filter\(activeCount == 1 ? "" : "s") active")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Button {
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.3)) {
                    filters.resetFilters()
                }
            } label: {
                Text("Clear All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.08))
    }

    // MARK: - Filter Section Container

    private func filterSection<Content: View>(
        section: FilterSection,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Section Header
            Button {
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32)

                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Section filter count badge
                    if let count = sectionFilterCount(section), count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expandedSections.contains(section) ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            // Section Content
            if expandedSections.contains(section) {
                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Age Range Section

    private var ageRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Age Range")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(filters.minAge) - \(filters.maxAge)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }

            // Combined range slider visualization
            VStack(spacing: 8) {
                // Min age slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min: \(filters.minAge)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(filters.minAge) },
                        set: { filters.minAge = Int($0) }
                    ), in: 18...Double(filters.maxAge - 1), step: 1)
                    .tint(.purple)
                }

                // Max age slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max: \(filters.maxAge)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(filters.maxAge) },
                        set: { filters.maxAge = Int($0) }
                    ), in: Double(filters.minAge + 1)...65, step: 1)
                    .tint(.pink)
                }
            }
        }
    }

    // MARK: - Verification Section

    private var verificationSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Verified Users Only")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Only show profiles with ID verification")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $filters.showVerifiedOnly)
                .labelsHidden()
                .tint(.purple)
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Match users with these interests")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !filters.selectedInterests.isEmpty {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        filters.selectedInterests.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(commonInterests, id: \.self) { interest in
                    SelectableFilterChip(
                        title: interest,
                        isSelected: filters.selectedInterests.contains(interest)
                    ) {
                        toggleInterest(interest)
                    }
                }
            }
        }
    }

    // MARK: - Education Section

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Education Level")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if !filters.educationLevels.isEmpty {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        filters.educationLevels.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(educationOptions, id: \.self) { option in
                    SelectableFilterChip(
                        title: option,
                        isSelected: filters.educationLevels.contains(option)
                    ) {
                        toggleEducation(option)
                    }
                }
            }
        }
    }

    // MARK: - Height Section

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Height Range")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if filters.minHeight != nil || filters.maxHeight != nil {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        filters.minHeight = nil
                        filters.maxHeight = nil
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            VStack(spacing: 12) {
                // Min height
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min: \(filters.minHeight ?? 140) cm (\(heightToFeetInches(filters.minHeight ?? 140)))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(filters.minHeight ?? 140) },
                        set: { filters.minHeight = Int($0) }
                    ), in: 140...220, step: 1)
                    .tint(.purple)
                }

                // Max height
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max: \(filters.maxHeight ?? 220) cm (\(heightToFeetInches(filters.maxHeight ?? 220)))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(filters.maxHeight ?? 220) },
                        set: { filters.maxHeight = Int($0) }
                    ), in: 140...220, step: 1)
                    .tint(.pink)
                }
            }
        }
    }

    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    // MARK: - Religion Section

    private var religionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Religion/Spirituality")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if !filters.religions.isEmpty {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        filters.religions.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(religionOptions, id: \.self) { option in
                    SelectableFilterChip(
                        title: option,
                        isSelected: filters.religions.contains(option)
                    ) {
                        toggleReligion(option)
                    }
                }
            }
        }
    }

    // MARK: - Relationship Goals Section

    private var relationshipGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Looking For")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if !filters.relationshipGoals.isEmpty {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        filters.relationshipGoals.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(relationshipGoalOptions, id: \.self) { option in
                    SelectableFilterChip(
                        title: option,
                        isSelected: filters.relationshipGoals.contains(option)
                    ) {
                        toggleRelationshipGoal(option)
                    }
                }
            }
        }
    }

    // MARK: - Lifestyle Chips Section

    private func lifestyleChipsSection(_ title: String, icon: String, options: [String], selected: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.purple)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if !selected.wrappedValue.isEmpty {
                    Button("Clear") {
                        HapticManager.shared.impact(.light)
                        selected.wrappedValue.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    SelectableFilterChip(
                        title: option,
                        isSelected: selected.wrappedValue.contains(option)
                    ) {
                        HapticManager.shared.impact(.light)
                        if selected.wrappedValue.contains(option) {
                            selected.wrappedValue.remove(option)
                        } else {
                            selected.wrappedValue.insert(option)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            HapticManager.shared.notification(.warning)
            withAnimation(.spring(response: 0.3)) {
                filters.resetFilters()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body.weight(.medium))
                Text("Reset All Filters")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.red)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Helper Functions

    private func countActiveFilters() -> Int {
        var count = 0
        // Removed distance filter - not needed for city-specific advertising
        if filters.minAge > 18 { count += 1 }
        if filters.maxAge < 65 { count += 1 }
        if filters.showVerifiedOnly { count += 1 }
        count += filters.selectedInterests.count
        count += filters.educationLevels.count
        if filters.minHeight != nil { count += 1 }
        if filters.maxHeight != nil { count += 1 }
        count += filters.religions.count
        count += filters.relationshipGoals.count
        count += filters.smokingPreferences.count
        count += filters.drinkingPreferences.count
        count += filters.petPreferences.count
        count += filters.exercisePreferences.count
        count += filters.dietPreferences.count
        return count
    }

    private func sectionFilterCount(_ section: FilterSection) -> Int? {
        switch section {
        case .basics:
            var count = 0
            // Removed distance filter
            if filters.minAge > 18 || filters.maxAge < 65 { count += 1 }
            if filters.showVerifiedOnly { count += 1 }
            return count > 0 ? count : nil
        case .interests:
            return filters.selectedInterests.isEmpty ? nil : filters.selectedInterests.count
        case .background:
            var count = 0
            count += filters.educationLevels.count
            if filters.minHeight != nil || filters.maxHeight != nil { count += 1 }
            count += filters.religions.count
            count += filters.relationshipGoals.count
            return count > 0 ? count : nil
        case .lifestyle:
            let count = filters.smokingPreferences.count +
                       filters.drinkingPreferences.count +
                       filters.petPreferences.count +
                       filters.exercisePreferences.count +
                       filters.dietPreferences.count
            return count > 0 ? count : nil
        }
    }

    private func toggleInterest(_ interest: String) {
        HapticManager.shared.impact(.light)
        if filters.selectedInterests.contains(interest) {
            filters.selectedInterests.remove(interest)
        } else {
            filters.selectedInterests.insert(interest)
        }
    }

    private func toggleEducation(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.educationLevels.contains(option) {
            filters.educationLevels.remove(option)
        } else {
            filters.educationLevels.insert(option)
        }
    }

    private func toggleReligion(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.religions.contains(option) {
            filters.religions.remove(option)
        } else {
            filters.religions.insert(option)
        }
    }

    private func toggleRelationshipGoal(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.relationshipGoals.contains(option) {
            filters.relationshipGoals.remove(option)
        } else {
            filters.relationshipGoals.insert(option)
        }
    }
}

// MARK: - Quick Filter Chip

struct QuickFilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isActive ? .white : color)
            .background(
                isActive ?
                AnyShapeStyle(color) :
                AnyShapeStyle(color.opacity(0.1))
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(isActive ? 0 : 0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Selectable Filter Chip

struct SelectableFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .white : .primary)
                .background(
                    isSelected ?
                    Color.purple :
                    Color(.systemGray6)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Interest Chip (Legacy support)

struct InterestChip: View {
    let interest: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SelectableFilterChip(title: interest, isSelected: isSelected, action: action)
    }
}

#Preview {
    DiscoverFiltersView()
}
