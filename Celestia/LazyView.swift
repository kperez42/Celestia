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

/// Tab content wrapper with true lazy loading - only renders when tab is visited
/// PERFORMANCE FIX: Defers content creation until tab is first selected
/// Once rendered, content stays in memory to preserve state and enable instant switching
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

    var body: some View {
        Group {
            // Render content if: currently selected OR has been visited before
            // This ensures:
            // 1. First visit: content loads when user navigates to tab
            // 2. Subsequent visits: content is already rendered (instant switch)
            // 3. No double-render: content only builds once
            if hasBeenVisited || tabIndex == currentTab {
                content()
                    .onAppear {
                        // Mark as visited on first appearance - content will stay rendered
                        if !hasBeenVisited {
                            hasBeenVisited = true
                        }
                    }
            } else {
                // Placeholder for unvisited tabs - matches background color
                Color(.systemGroupedBackground)
            }
        }
    }
}
