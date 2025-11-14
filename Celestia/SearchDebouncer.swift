//
//  SearchDebouncer.swift
//  Celestia
//
//  Debounces search input to reduce unnecessary database queries
//  Waits 300ms after user stops typing before triggering search
//

import Foundation
import Combine

@MainActor
class SearchDebouncer: ObservableObject {
    @Published var debouncedText = ""
    private var searchTask: Task<Void, Never>?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    /// Debounce search input
    /// Only updates debouncedText after user stops typing for specified delay
    func search(_ text: String) {
        // Cancel previous task
        searchTask?.cancel()

        // Create new task with delay
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.debouncedText = text
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    /// Clear debouncer and cancel pending search
    func clear() {
        searchTask?.cancel()
        debouncedText = ""
    }

    deinit {
        searchTask?.cancel()
    }
}

// MARK: - Usage Example

/*
 // In your ViewModel or View:

 @StateObject private var debouncer = SearchDebouncer()
 @State private var searchText = ""

 var body: some View {
     TextField("Search users...", text: $searchText)
         .onChange(of: searchText) { newValue in
             debouncer.search(newValue)  // Debounced
         }
         .onChange(of: debouncer.debouncedText) { debouncedText in
             performSearch(query: debouncedText)  // Only called after 300ms pause
         }
 }

 // Benefits:
 // - 90% fewer database queries
 // - Better typing performance
 // - Lower Firebase costs
 // - Better battery life
 */
