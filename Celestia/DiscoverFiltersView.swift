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

#Preview {
    DiscoverFiltersView()
}
