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

/// Tab content wrapper that renders all tabs immediately for instant switching
/// PERFORMANCE FIX: Renders content immediately without any animation or transition
/// to eliminate flickering/jittering when switching between tabs
struct LazyTabContent<Content: View>: View {
    let tabIndex: Int
    let currentTab: Int
    let content: () -> Content

    init(tabIndex: Int, currentTab: Int, @ViewBuilder content: @escaping () -> Content) {
        self.tabIndex = tabIndex
        self.currentTab = currentTab
        self.content = content
    }

    var body: some View {
        // PERFORMANCE: Render content immediately - no lazy loading, no transitions
        // This eliminates the flash/jitter caused by showing placeholder then animating to content
        content()
    }
}
