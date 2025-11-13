//
//  LazyView.swift
//  Celestia
//
//  Lazy view wrapper for performance optimization
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

/// Tab content wrapper that only loads when the tab is first selected
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

    var body: some View {
        Group {
            if hasBeenLoaded {
                content()
            } else {
                // Show placeholder until tab is selected
                Color.clear
                    .onAppear {
                        // Load immediately if this is the current tab
                        if tabIndex == currentTab {
                            hasBeenLoaded = true
                        }
                    }
                    .onChange(of: currentTab) { _, newTab in
                        // Load when user switches to this tab
                        if newTab == tabIndex && !hasBeenLoaded {
                            hasBeenLoaded = true
                        }
                    }
            }
        }
    }
}
