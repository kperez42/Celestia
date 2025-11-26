//
//  SearchFilterView.swift
//  Celestia
//
//  Comprehensive search filter interface
//

import SwiftUI

struct SearchFilterView: View {

    @StateObject private var searchManager = SearchManager.shared
    @StateObject private var presetManager = FilterPresetManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var filter: SearchFilter
    @State private var showingPresetSheet = false
    @State private var showingSavePresetSheet = false

    init(filter: SearchFilter = SearchFilter()) {
        _filter = State(initialValue: filter)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Active filter count
                    if filter.activeFilterCount > 0 {
                        activeFiltersCard
                    }

                    // Location & Distance
                    locationSection

                    // Demographics
                    demographicsSection

                    // Background
                    backgroundSection

                    // Lifestyle
                    lifestyleSection

                    // Relationship
                    relationshipSection

                    // Preferences
                    preferencesSection

                    // Advanced
                    advancedSection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filter.reset()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingSavePresetSheet = true }) {
                            Label("Save as Preset", systemImage: "bookmark")
                        }

                        Button(action: { showingPresetSheet = true }) {
                            Label("Load Preset", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                searchButton
            }
        }
        .sheet(isPresented: $showingPresetSheet) {
            FilterPresetsView(onSelect: { preset in
                filter = preset.filter
                showingPresetSheet = false
            })
        }
        .sheet(isPresented: $showingSavePresetSheet) {
            SavePresetSheet(filter: filter)
        }
    }

    // MARK: - Active Filters Card

    private var activeFiltersCard: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.blue)

            Text("\(filter.activeFilterCount) active filters")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button("Clear All") {
                filter.reset()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        FilterSection(title: "Location", icon: "location.fill") {
            VStack(spacing: 16) {
                // Distance slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Distance")
                            .font(.subheadline)
                        Spacer()
                        Text("\(filter.distanceRadius) miles")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    Slider(value: Binding(
                        get: { Double(filter.distanceRadius) },
                        set: { filter.distanceRadius = Int($0) }
                    ), in: 1...100, step: 1)
                }

                // Use current location toggle
                Toggle("Use my current location", isOn: $filter.useCurrentLocation)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Demographics Section

    private var demographicsSection: some View {
        FilterSection(title: "Demographics", icon: "person.fill") {
            VStack(spacing: 16) {
                // Age range
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Age")
                            .font(.subheadline)
                        Spacer()
                        Text("\(filter.ageRange.min) - \(filter.ageRange.max)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Slider(value: Binding(
                            get: { Double(filter.ageRange.min) },
                            set: { filter.ageRange.min = Int($0) }
                        ), in: 18...99, step: 1)

                        Text("to")
                            .font(.caption)

                        Slider(value: Binding(
                            get: { Double(filter.ageRange.max) },
                            set: { filter.ageRange.max = Int($0) }
                        ), in: 18...99, step: 1)
                    }
                }

                Divider()

                // Height range
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Filter by height", isOn: Binding(
                        get: { filter.heightRange != nil },
                        set: { enabled in
                            filter.heightRange = enabled ? HeightRange() : nil
                        }
                    ))
                    .font(.subheadline)

                    if let heightRange = filter.heightRange {
                        HStack {
                            Text("Height")
                                .font(.caption)
                            Spacer()
                            Text("\(HeightRange.formatHeight(heightRange.minInches)) - \(HeightRange.formatHeight(heightRange.maxInches))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Slider(value: Binding(
                                get: { Double(heightRange.minInches) },
                                set: { filter.heightRange?.minInches = Int($0) }
                            ), in: 48...96, step: 1)

                            Text("to")
                                .font(.caption)

                            Slider(value: Binding(
                                get: { Double(heightRange.maxInches) },
                                set: { filter.heightRange?.maxInches = Int($0) }
                            ), in: 48...96, step: 1)
                        }
                    }
                }

                Divider()

                // Gender
                Picker("Show me", selection: $filter.showMe) {
                    ForEach(ShowMeFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Background Section

    private var backgroundSection: some View {
        FilterSection(title: "Background", icon: "building.columns.fill") {
            VStack(spacing: 16) {
                // Education
                MultiSelectMenu(
                    title: "Education",
                    options: EducationLevel.allCases,
                    selections: $filter.educationLevels,
                    displayName: { $0.displayName }
                )

                Divider()

                // Ethnicity
                MultiSelectMenu(
                    title: "Ethnicity",
                    options: Ethnicity.allCases,
                    selections: $filter.ethnicities,
                    displayName: { $0.displayName }
                )

                Divider()

                // Religion
                MultiSelectMenu(
                    title: "Religion",
                    options: Religion.allCases,
                    selections: $filter.religions,
                    displayName: { $0.displayName }
                )
            }
        }
    }

    // MARK: - Lifestyle Section

    private var lifestyleSection: some View {
        FilterSection(title: "Lifestyle", icon: "heart.fill") {
            VStack(spacing: 16) {
                // Smoking
                Picker("Smoking", selection: $filter.smoking) {
                    ForEach(LifestyleFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                // Drinking
                Picker("Drinking", selection: $filter.drinking) {
                    ForEach(LifestyleFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                // Pets
                Picker("Pets", selection: $filter.pets) {
                    ForEach(PetPreference.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                // Children
                Picker("Has children", selection: $filter.hasChildren) {
                    ForEach(LifestyleFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Wants children", selection: $filter.wantsChildren) {
                    ForEach(LifestyleFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                // Exercise
                Picker("Exercise frequency", selection: Binding(
                    get: { filter.exercise ?? .any },
                    set: { filter.exercise = $0 }
                )) {
                    ForEach(ExerciseFrequency.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                // Diet
                Picker("Diet", selection: Binding(
                    get: { filter.diet ?? .any },
                    set: { filter.diet = $0 }
                )) {
                    ForEach(DietPreference.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Relationship Section

    private var relationshipSection: some View {
        FilterSection(title: "Relationship Goals", icon: "heart.circle.fill") {
            VStack(spacing: 16) {
                MultiSelectMenu(
                    title: "Looking for",
                    options: RelationshipGoal.allCases,
                    selections: $filter.relationshipGoals,
                    displayName: { $0.displayName }
                )
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        FilterSection(title: "Preferences", icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                Toggle("Verified profiles only", isOn: $filter.verifiedOnly)
                    .font(.subheadline)

                Toggle("With photos only", isOn: $filter.withPhotosOnly)
                    .font(.subheadline)

                Divider()

                // Active recently
                Picker("Active in last", selection: Binding(
                    get: { filter.activeInLastDays ?? 0 },
                    set: { filter.activeInLastDays = $0 > 0 ? $0 : nil }
                )) {
                    Text("Any time").tag(0)
                    Text("24 hours").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.menu)

                Toggle("New users only (last 30 days)", isOn: $filter.newUsers)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        FilterSection(title: "Advanced", icon: "gear") {
            VStack(spacing: 16) {
                // Zodiac signs
                MultiSelectMenu(
                    title: "Zodiac Signs",
                    options: ZodiacSign.allCases,
                    selections: $filter.zodiacSigns,
                    displayName: { "\($0.symbol) \($0.displayName)" }
                )

                Divider()

                // Political views
                MultiSelectMenu(
                    title: "Political Views",
                    options: PoliticalView.allCases,
                    selections: $filter.politicalViews,
                    displayName: { $0.displayName }
                )
            }
        }
    }

    // MARK: - Search Button

    private var searchButton: some View {
        Button(action: {
            Task {
                await searchManager.search(with: filter)
                presetManager.addToHistory(filter: filter, resultsCount: searchManager.totalResultsCount)
                dismiss()
            }
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Filter Section Component

struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Multi-Select Menu

struct MultiSelectMenu<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selections: [T]
    let displayName: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)

                Spacer()

                if !selections.isEmpty {
                    Text("\(selections.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Selected items
            if !selections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(selections.enumerated()), id: \.0) { _, item in
                            HStack(spacing: 4) {
                                Text(displayName(item))
                                    .font(.caption)

                                Button(action: {
                                    selections.removeAll { $0 == item }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Selection menu
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        if selections.contains(option) {
                            selections.removeAll { $0 == option }
                        } else {
                            selections.append(option)
                        }
                    }) {
                        HStack {
                            Text(displayName(option))
                            if selections.contains(option) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("Select...")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Save Preset Sheet

struct SavePresetSheet: View {
    @StateObject private var presetManager = FilterPresetManager.shared
    @Environment(\.dismiss) private var dismiss

    let filter: SearchFilter
    @State private var presetName = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Preset Name") {
                    TextField("e.g., Nearby & Active", text: $presetName)
                }

                Section("Filter Summary") {
                    Text("\(filter.activeFilterCount) active filters")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        do {
                            _ = try presetManager.savePreset(name: presetName, filter: filter)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                    .disabled(presetName.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Preview

struct SearchFilterView_Previews: PreviewProvider {
    static var previews: some View {
        SearchFilterView()
    }
}
