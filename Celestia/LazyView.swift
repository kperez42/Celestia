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

/// Tab content wrapper that pre-loads adjacent tabs for instant switching
/// PERFORMANCE FIX: Instead of showing blank Color.clear and waiting for selection,
/// this now pre-renders tabs within 1 position of current tab so they're ready instantly
struct LazyTabContent<Content: View>: View {
    let tabIndex: Int
    let currentTab: Int
    let content: () -> Content

    @State private var hasBeenLoaded = false

    init(tabIndex: Int, currentTab: Int, @ViewBuilder content: @escaping () -> Content) {
        self.tabIndex = tabIndex
        self.currentTab = currentTab
        self.content = content
    }

    /// Check if this tab should be pre-rendered (current or adjacent)
    private var shouldPreRender: Bool {
        // Always load if it's the current tab
        if tabIndex == currentTab { return true }
        // Pre-render adjacent tabs (within 1 position) for instant switching
        let distance = abs(tabIndex - currentTab)
        return distance <= 1
    }

    var body: some View {
        Group {
            if hasBeenLoaded {
                content()
                    .transition(.opacity)
            } else {
                // PERFORMANCE: Show background color matching system background
                // instead of Color.clear to avoid blank flash
                Color(.systemGroupedBackground)
                    .onAppear {
                        // Load immediately if this is the current tab or adjacent
                        if shouldPreRender {
                            withAnimation(.butterSmooth) {
                                hasBeenLoaded = true
                            }
                        }
                    }
                    .onChange(of: currentTab) { _, newTab in
                        // Pre-render when user gets close to this tab
                        if !hasBeenLoaded {
                            let distance = abs(tabIndex - newTab)
                            if distance <= 1 {
                                withAnimation(.butterSmooth) {
                                    hasBeenLoaded = true
                                }
                            }
                        }
                    }
            }
        }
        .animation(.tabSwitch, value: hasBeenLoaded)
    }
}
