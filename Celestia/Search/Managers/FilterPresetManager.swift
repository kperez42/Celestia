//
//  FilterPresetManager.swift
//  Celestia
//
//  Manages saved filter presets and search history
//

import Foundation

// MARK: - Filter Preset Manager

@MainActor
class FilterPresetManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FilterPresetManager()

    // MARK: - Published Properties

    @Published var presets: [FilterPreset] = []
    @Published var searchHistory: [SearchHistoryEntry] = []

    // MARK: - Private Properties

    private let maxPresets = 10
    private let maxHistoryEntries = 50

    private enum Keys {
        static let presets = "filter_presets"
        static let searchHistory = "search_history"
    }

    // MARK: - Initialization

    private init() {
        loadPresets()
        loadSearchHistory()
        Logger.shared.info("FilterPresetManager initialized", category: .general)
    }

    // MARK: - Presets

    /// Save a new filter preset
    func savePreset(name: String, filter: SearchFilter) throws -> FilterPreset {
        // Check max limit
        guard presets.count < maxPresets else {
            throw PresetError.maxPresetsReached
        }

        // Check for duplicate name
        if presets.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            throw PresetError.duplicateName
        }

        let preset = FilterPreset(
            name: name,
            filter: filter,
            usageCount: 0
        )

        presets.append(preset)
        savePresets()

        // Track analytics
        AnalyticsManager.shared.logEvent(.filterPresetSaved, parameters: [
            "name": name,
            "filter_count": filter.activeFilterCount
        ])

        Logger.shared.info("Preset saved: \(name)", category: .general)

        return preset
    }

    /// Update existing preset
    func updatePreset(_ preset: FilterPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
            Logger.shared.debug("Preset updated: \(preset.name)", category: .general)
        }
    }

    /// Delete preset
    func deletePreset(_ preset: FilterPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
        Logger.shared.info("Preset deleted: \(preset.name)", category: .general)
    }

    /// Load and use preset
    func usePreset(_ preset: FilterPreset) -> SearchFilter {
        // Update usage stats
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index].lastUsed = Date()
            presets[index].usageCount += 1
            savePresets()
        }

        // Track analytics
        AnalyticsManager.shared.logEvent(.filterPresetUsed, parameters: [
            "preset_name": preset.name,
            "usage_count": preset.usageCount
        ])

        Logger.shared.info("Preset used: \(preset.name)", category: .general)

        return preset.filter
    }

    /// Get most used presets
    func getMostUsedPresets(limit: Int = 5) -> [FilterPreset] {
        return presets.sorted { $0.usageCount > $1.usageCount }.prefix(limit).map { $0 }
    }

    /// Get recently used presets
    func getRecentPresets(limit: Int = 5) -> [FilterPreset] {
        return presets.sorted { $0.lastUsed > $1.lastUsed }.prefix(limit).map { $0 }
    }

    // MARK: - Default Presets

    func createDefaultPresets() {
        // Preset 1: Nearby & Verified
        var nearbyVerified = SearchFilter()
        nearbyVerified.distanceRadius = 10
        nearbyVerified.verifiedOnly = true
        _ = try? savePreset(name: "Nearby & Verified", filter: nearbyVerified)

        // Preset 2: Active This Week
        var activeThisWeek = SearchFilter()
        activeThisWeek.activeInLastDays = 7
        activeThisWeek.withPhotosOnly = true
        _ = try? savePreset(name: "Active This Week", filter: activeThisWeek)

        // Preset 3: Long-term Relationship
        var longTerm = SearchFilter()
        longTerm.relationshipGoals = [.longTerm, .marriage]
        longTerm.verifiedOnly = true
        _ = try? savePreset(name: "Looking for Love", filter: longTerm)

        Logger.shared.info("Default presets created", category: .general)
    }

    // MARK: - Search History

    /// Add search to history
    func addToHistory(filter: SearchFilter, resultsCount: Int) {
        let entry = SearchHistoryEntry(
            filter: filter,
            resultsCount: resultsCount
        )

        searchHistory.insert(entry, at: 0)

        // Limit history size
        if searchHistory.count > maxHistoryEntries {
            searchHistory = Array(searchHistory.prefix(maxHistoryEntries))
        }

        saveSearchHistory()

        Logger.shared.debug("Added to search history: \(resultsCount) results", category: .general)
    }

    /// Get recent searches
    func getRecentSearches(limit: Int = 10) -> [SearchHistoryEntry] {
        return Array(searchHistory.prefix(limit))
    }

    /// Clear search history
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
        Logger.shared.info("Search history cleared", category: .general)
    }

    /// Get most popular filter combinations
    func getPopularFilters() -> [(filter: SearchFilter, count: Int)] {
        // Group by filter similarity and count usage
        var filterCounts: [String: (filter: SearchFilter, count: Int)] = [:]

        for entry in searchHistory {
            let key = filterKey(entry.filter)
            if var existing = filterCounts[key] {
                existing.count += 1
                filterCounts[key] = existing
            } else {
                filterCounts[key] = (entry.filter, 1)
            }
        }

        return filterCounts.values.sorted { $0.count > $1.count }
    }

    private func filterKey(_ filter: SearchFilter) -> String {
        // Create a unique key based on filter settings
        return "\(filter.distanceRadius)_\(filter.ageRange.min)-\(filter.ageRange.max)_\(filter.verifiedOnly)"
    }

    // MARK: - Persistence

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Keys.presets)
        }
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: Keys.presets),
           let decoded = try? JSONDecoder().decode([FilterPreset].self, from: data) {
            presets = decoded
            Logger.shared.debug("Loaded \(presets.count) presets", category: .general)
        }
    }

    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: Keys.searchHistory)
        }
    }

    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: Keys.searchHistory),
           let decoded = try? JSONDecoder().decode([SearchHistoryEntry].self, from: data) {
            searchHistory = decoded
            Logger.shared.debug("Loaded \(searchHistory.count) history entries", category: .general)
        }
    }

    // MARK: - Export/Import

    /// Export presets to JSON
    func exportPresets() -> Data? {
        return try? JSONEncoder().encode(presets)
    }

    /// Import presets from JSON
    func importPresets(from data: Data) throws {
        let imported = try JSONDecoder().decode([FilterPreset].self, from: data)

        // Add non-duplicate presets
        for preset in imported {
            if !presets.contains(where: { $0.name == preset.name }) {
                presets.append(preset)
            }
        }

        savePresets()
        Logger.shared.info("Imported \(imported.count) presets", category: .general)
    }
}

// MARK: - Errors

enum PresetError: LocalizedError {
    case maxPresetsReached
    case duplicateName
    case presetNotFound

    var errorDescription: String? {
        switch self {
        case .maxPresetsReached:
            return "You can only save up to 10 filter presets"
        case .duplicateName:
            return "A preset with this name already exists"
        case .presetNotFound:
            return "Preset not found"
        }
    }
}
