//
//  LazyView.swift
//  Celestia
//
//  Lazy view wrapper for performance optimization
//  PERFORMANCE: Pre-renders adjacent tabs for instant switching
//

import SwiftUI

/// Wrapper that defers view creation until it's actually needed
/// Useful for TabView tabs to prevent all tabs from loading data simultaneously
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

/// Tab content wrapper with smart preloading - renders adjacent tabs for instant switching
/// PERFORMANCE FIX: Pre-renders tabs within 1 position of current tab
/// This ensures smooth, instant tab switching without any flash or loading state
struct LazyTabContent<Content: View>: View {
    let tabIndex: Int
    let currentTab: Int
    let content: () -> Content

    // Track if this tab has ever been visited - once true, content stays rendered
    @State private var hasBeenVisited = false

    init(tabIndex: Int, currentTab: Int, @ViewBuilder content: @escaping () -> Content) {
        self.tabIndex = tabIndex
        self.currentTab = currentTab
        self.content = content
    }

    // PERFORMANCE: Determine if this tab should be rendered
    // Render if: currently selected, adjacent to current, or previously visited
    private var shouldRender: Bool {
        // Always render if visited before (preserves state)
        if hasBeenVisited { return true }
        // Render current tab
        if tabIndex == currentTab { return true }
        // PRELOAD: Render adjacent tabs (within 1 position) for instant switching
        if abs(tabIndex - currentTab) <= 1 { return true }
        return false
    }

    var body: some View {
        Group {
            if shouldRender {
                content()
                    .onAppear {
                        // Mark as visited on first appearance - content will stay rendered
                        if !hasBeenVisited {
                            hasBeenVisited = true
                        }
                    }
            } else {
                // Placeholder for distant unvisited tabs - matches background color
                Color(.systemGroupedBackground)
            }
        }
    }
}
