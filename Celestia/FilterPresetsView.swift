//
//  FilterPresetsView.swift
//  Celestia
//
//  Manage and load saved filter presets
//

import SwiftUI

struct FilterPresetsView: View {

    @StateObject private var presetManager = FilterPresetManager.shared
    @Environment(\.dismiss) private var dismiss

    let onSelect: (FilterPreset) -> Void

    @State private var showingDeleteAlert = false
    @State private var presetToDelete: FilterPreset?

    var body: some View {
        NavigationView {
            List {
                if !presetManager.presets.isEmpty {
                    presetsSection
                } else {
                    emptyStateSection
                }

                defaultPresetsSection
            }
            .navigationTitle("Filter Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Preset", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let preset = presetToDelete {
                        presetManager.deletePreset(preset)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this preset?")
            }
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        Section {
            ForEach(presetManager.presets) { preset in
                PresetRow(preset: preset) {
                    _ = presetManager.usePreset(preset) // Track usage
                    onSelect(preset)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presetToDelete = preset
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("My Presets")
        } footer: {
            Text("Swipe left to delete")
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)

                VStack(spacing: 8) {
                    Text("No Saved Presets")
                        .font(.headline)

                    Text("Save your favorite filter combinations for quick access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Default Presets

    private var defaultPresetsSection: some View {
        Section {
            Button(action: {
                presetManager.createDefaultPresets()
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)

                    Text("Create Default Presets")
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Quick Setup")
        } footer: {
            Text("Create 3 pre-configured presets to get started")
        }
    }
}

// MARK: - Preset Row

struct PresetRow: View {

    let preset: FilterPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                HStack {
                    // Filter count
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.caption)

                        Text("\(preset.filter.activeFilterCount) filters")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    // Usage stats
                    if preset.usageCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar")
                                .font(.caption)

                            Text("Used \(preset.usageCount)x")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Last used
                    Text(formatLastUsed(preset.lastUsed))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quick preview of filters
                if preset.filter.activeFilterCount > 0 {
                    filterPreview
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filterPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if preset.filter.distanceRadius != 50 {
                    FilterChip(text: "\(preset.filter.distanceRadius) mi")
                }

                if preset.filter.ageRange.min != 18 || preset.filter.ageRange.max != 99 {
                    FilterChip(text: "\(preset.filter.ageRange.min)-\(preset.filter.ageRange.max) yrs")
                }

                if preset.filter.verifiedOnly {
                    FilterChip(text: "Verified", icon: "checkmark.seal.fill")
                }

                if !preset.filter.relationshipGoals.isEmpty {
                    FilterChip(text: "\(preset.filter.relationshipGoals.count) goals")
                }

                if !preset.filter.educationLevels.isEmpty {
                    FilterChip(text: "\(preset.filter.educationLevels.count) edu")
                }

                if preset.filter.activeInLastDays != nil {
                    FilterChip(text: "Active", icon: "clock")
                }
            }
        }
    }

    private func formatLastUsed(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let text: String
    var icon: String?

    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }

            Text(text)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(6)
    }
}

// MARK: - Search History View

struct SearchHistoryView: View {

    @StateObject private var presetManager = FilterPresetManager.shared
    @Environment(\.dismiss) private var dismiss

    let onSelect: (SearchFilter) -> Void

    var body: some View {
        NavigationView {
            List {
                if !presetManager.searchHistory.isEmpty {
                    historySection
                } else {
                    emptyStateSection
                }
            }
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        presetManager.clearHistory()
                    }
                    .disabled(presetManager.searchHistory.isEmpty)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var historySection: some View {
        Section {
            ForEach(presetManager.getRecentSearches(limit: 20)) { entry in
                Button(action: {
                    onSelect(entry.filter)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(entry.timestamp))
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Text("\(entry.resultsCount) results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.caption)

                            Text("\(entry.filter.activeFilterCount) filters")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Recent Searches")
        }
    }

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)

                VStack(spacing: 8) {
                    Text("No Search History")
                        .font(.headline)

                    Text("Your recent searches will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct FilterPresetsView_Previews: PreviewProvider {
    static var previews: some View {
        FilterPresetsView(onSelect: { _ in })
    }
}
