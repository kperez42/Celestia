//
//  DiscoverFiltersView.swift
//  Celestia
//
//  Filter settings for discovery
//

import SwiftUI

struct DiscoverFiltersView: View {
    @ObservedObject var filters = DiscoveryFilters.shared
    @Environment(\.dismiss) var dismiss

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
                VStack(spacing: 24) {
                    // Distance filter
                    distanceSection

                    Divider()

                    // Age range filter
                    ageRangeSection

                    Divider()

                    // Verification filter
                    verificationSection

                    Divider()

                    // Interest filter
                    interestsSection

                    Divider()

                    // Advanced Filters Header
                    Text("Advanced Filters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Education filter
                    educationSection

                    Divider()

                    // Height filter
                    heightSection

                    Divider()

                    // Religion filter
                    religionSection

                    Divider()

                    // Relationship goals filter
                    relationshipGoalsSection

                    Divider()

                    // Lifestyle filters
                    Text("Lifestyle Preferences")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    smokingSection
                    Divider()
                    drinkingSection
                    Divider()
                    petSection
                    Divider()
                    exerciseSection
                    Divider()
                    dietSection

                    // Reset button
                    if filters.hasActiveFilters {
                        resetButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        HapticManager.shared.impact(.medium)
                        filters.saveToUserDefaults()
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Distance Section

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Maximum Distance")
                    .font(.headline)

                Spacer()

                Text("\(Int(filters.maxDistance)) mi")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Slider(value: $filters.maxDistance, in: 5...100, step: 5)
                .accentColor(.purple)

            HStack {
                Text("5 mi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("100 mi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Age Range Section

    private var ageRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Age Range")
                    .font(.headline)

                Spacer()

                Text("\(filters.minAge) - \(filters.maxAge)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Min age slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum Age: \(filters.minAge)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { Double(filters.minAge) },
                    set: { filters.minAge = Int($0) }
                ), in: 18...Double(filters.maxAge), step: 1)
                .accentColor(.purple)
            }

            // Max age slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Maximum Age: \(filters.maxAge)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { Double(filters.maxAge) },
                    set: { filters.maxAge = Int($0) }
                ), in: Double(filters.minAge)...65, step: 1)
                .accentColor(.purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Verification Section

    private var verificationSection: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Verified Users Only")
                    .font(.headline)

                Text("Show only verified profiles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $filters.showVerifiedOnly)
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Must Have Interests")
                    .font(.headline)

                Spacer()

                if !filters.selectedInterests.isEmpty {
                    Text("\(filters.selectedInterests.count)")
                        .font(.caption)
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
            }

            Text("Show users who have at least one of these interests")
                .font(.caption)
                .foregroundColor(.secondary)

            // Interest chips
            FlowLayout(spacing: 8) {
                ForEach(commonInterests, id: \.self) { interest in
                    InterestChip(
                        interest: interest,
                        isSelected: filters.selectedInterests.contains(interest)
                    ) {
                        toggleInterest(interest)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Education Section

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "graduationcap.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Education Level")
                    .font(.headline)

                Spacer()

                if !filters.educationLevels.isEmpty {
                    Text("\(filters.educationLevels.count)")
                        .font(.caption)
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
            }

            FlowLayout(spacing: 8) {
                ForEach(educationOptions, id: \.self) { option in
                    InterestChip(
                        interest: option,
                        isSelected: filters.educationLevels.contains(option)
                    ) {
                        toggleEducation(option)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Height Section

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Height Range")
                    .font(.headline)

                Spacer()

                if let min = filters.minHeight, let max = filters.maxHeight {
                    Text("\(min) - \(max) cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let min = filters.minHeight {
                    Text("\(min)+ cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let max = filters.maxHeight {
                    Text("≤\(max) cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Min height slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum: \(filters.minHeight ?? 140) cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if filters.minHeight != nil {
                        Button("Clear") {
                            filters.minHeight = nil
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }

                Slider(value: Binding(
                    get: { Double(filters.minHeight ?? 140) },
                    set: { filters.minHeight = Int($0) }
                ), in: 140...220, step: 1)
                .accentColor(.purple)
            }

            // Max height slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum: \(filters.maxHeight ?? 220) cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if filters.maxHeight != nil {
                        Button("Clear") {
                            filters.maxHeight = nil
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }

                Slider(value: Binding(
                    get: { Double(filters.maxHeight ?? 220) },
                    set: { filters.maxHeight = Int($0) }
                ), in: 140...220, step: 1)
                .accentColor(.purple)
            }

            HStack {
                Text("140 cm (4'7\")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("220 cm (7'3\")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Religion Section

    private var religionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Religion/Spirituality")
                    .font(.headline)

                Spacer()

                if !filters.religions.isEmpty {
                    Text("\(filters.religions.count)")
                        .font(.caption)
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
            }

            FlowLayout(spacing: 8) {
                ForEach(religionOptions, id: \.self) { option in
                    InterestChip(
                        interest: option,
                        isSelected: filters.religions.contains(option)
                    ) {
                        toggleReligion(option)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Relationship Goals Section

    private var relationshipGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Relationship Goals")
                    .font(.headline)

                Spacer()

                if !filters.relationshipGoals.isEmpty {
                    Text("\(filters.relationshipGoals.count)")
                        .font(.caption)
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
            }

            FlowLayout(spacing: 8) {
                ForEach(relationshipGoalOptions, id: \.self) { option in
                    InterestChip(
                        interest: option,
                        isSelected: filters.relationshipGoals.contains(option)
                    ) {
                        toggleRelationshipGoal(option)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Smoking Section

    private var smokingSection: some View {
        filterOptionSection(
            title: "Smoking",
            icon: "smoke.fill",
            options: smokingOptions,
            selectedOptions: filters.smokingPreferences,
            toggle: toggleSmoking
        )
    }

    // MARK: - Drinking Section

    private var drinkingSection: some View {
        filterOptionSection(
            title: "Drinking",
            icon: "wineglass.fill",
            options: drinkingOptions,
            selectedOptions: filters.drinkingPreferences,
            toggle: toggleDrinking
        )
    }

    // MARK: - Pet Section

    private var petSection: some View {
        filterOptionSection(
            title: "Pets",
            icon: "pawprint.fill",
            options: petOptions,
            selectedOptions: filters.petPreferences,
            toggle: togglePet
        )
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        filterOptionSection(
            title: "Exercise",
            icon: "figure.run",
            options: exerciseOptions,
            selectedOptions: filters.exercisePreferences,
            toggle: toggleExercise
        )
    }

    // MARK: - Diet Section

    private var dietSection: some View {
        filterOptionSection(
            title: "Diet",
            icon: "leaf.fill",
            options: dietOptions,
            selectedOptions: filters.dietPreferences,
            toggle: toggleDiet
        )
    }

    // MARK: - Generic Filter Option Section

    private func filterOptionSection(
        title: String,
        icon: String,
        options: [String],
        selectedOptions: Set<String>,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(title)
                    .font(.headline)

                Spacer()

                if !selectedOptions.isEmpty {
                    Text("\(selectedOptions.count)")
                        .font(.caption)
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
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    InterestChip(
                        interest: option,
                        isSelected: selectedOptions.contains(option)
                    ) {
                        toggle(option)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            HapticManager.shared.notification(.warning)
            filters.resetFilters()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Filters")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.red)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Helpers

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

    private func toggleSmoking(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.smokingPreferences.contains(option) {
            filters.smokingPreferences.remove(option)
        } else {
            filters.smokingPreferences.insert(option)
        }
    }

    private func toggleDrinking(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.drinkingPreferences.contains(option) {
            filters.drinkingPreferences.remove(option)
        } else {
            filters.drinkingPreferences.insert(option)
        }
    }

    private func togglePet(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.petPreferences.contains(option) {
            filters.petPreferences.remove(option)
        } else {
            filters.petPreferences.insert(option)
        }
    }

    private func toggleExercise(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.exercisePreferences.contains(option) {
            filters.exercisePreferences.remove(option)
        } else {
            filters.exercisePreferences.insert(option)
        }
    }

    private func toggleDiet(_ option: String) {
        HapticManager.shared.impact(.light)
        if filters.dietPreferences.contains(option) {
            filters.dietPreferences.remove(option)
        } else {
            filters.dietPreferences.insert(option)
        }
    }
}

// MARK: - Interest Chip

struct InterestChip: View {
    let interest: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .white : .purple)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.purple.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    DiscoverFiltersView()
}
