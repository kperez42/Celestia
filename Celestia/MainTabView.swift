//
//  MainTabView.swift
//  Celestia
//
//  ELITE TAB BAR - Smooth Navigation Experience
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var matchService = MatchService.shared
    @ObservedObject private var messageService = MessageService.shared

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var unreadCount = 0
    @State private var newMatchesCount = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                // Discover - Load immediately (tab 0)
                FeedDiscoverView(selectedTab: $selectedTab)
                    .tag(0)

                // Matches - Lazy load
                LazyTabContent(tabIndex: 1, currentTab: selectedTab) {
                    MatchesView()
                }
                .tag(1)

                // Messages - Lazy load
                LazyTabContent(tabIndex: 2, currentTab: selectedTab) {
                    MessagesView(selectedTab: $selectedTab)
                }
                .tag(2)

                // Saved - Lazy load
                LazyTabContent(tabIndex: 3, currentTab: selectedTab) {
                    SavedProfilesView()
                }
                .tag(3)

                // Profile - Lazy load
                LazyTabContent(tabIndex: 4, currentTab: selectedTab) {
                    ProfileView()
                }
                .tag(4)
            }
            .tabViewStyle(.automatic)
            .ignoresSafeArea(.keyboard)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
            HapticManager.shared.selection()
        }
        .task {
            // PERFORMANCE: Defer badge loading to not block initial render
            // Allow the UI to render first, then load badges in background
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            await updateBadgesPeriodically()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToMessages"))) { notification in
            // Navigate to Messages tab when a match occurs
            selectedTab = 2
            HapticManager.shared.notification(.success)

            // Optional: Extract matched user ID for future use (e.g., scroll to conversation)
            if let matchedUserId = notification.userInfo?["matchedUserId"] as? String {
                Logger.shared.info("Navigating to messages for match: \(matchedUserId)", category: .ui)
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
                // Discover
                TabBarButton(
                    icon: "flame.fill",
                    title: "Discover",
                    isSelected: selectedTab == 0,
                    badgeCount: 0
                ) {
                    selectedTab = 0
                }

                // Matches
                TabBarButton(
                    icon: "heart.fill",
                    title: "Matches",
                    isSelected: selectedTab == 1,
                    badgeCount: newMatchesCount
                ) {
                    selectedTab = 1
                }

                // Messages
                TabBarButton(
                    icon: "message.fill",
                    title: "Messages",
                    isSelected: selectedTab == 2,
                    badgeCount: unreadCount
                ) {
                    selectedTab = 2
                }

                // Saved
                TabBarButton(
                    icon: "bookmark.fill",
                    title: "Saved",
                    isSelected: selectedTab == 3,
                    badgeCount: 0
                ) {
                    selectedTab = 3
                }

                // Profile
                TabBarButton(
                    icon: "person.fill",
                    title: "Profile",
                    isSelected: selectedTab == 4,
                    badgeCount: 0
                ) {
                    selectedTab = 4
                }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, -20)
        .background(
            ZStack {
                // PREMIUM: Glass morphism effect
                Color(.systemBackground)

                // PREMIUM: Subtle gradient overlay with glow
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0.95),
                        Color.purple.opacity(0.02),
                        Color.pink.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // PREMIUM: Top border glow
                VStack {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.3),
                            Color.pink.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1)
                    .blur(radius: 2)

                    Spacer()
                }
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
    }
    
    // MARK: - Helper Functions

    private func updateBadgesPeriodically() async {
        guard let userId = authService.currentUser?.id else { return }

        // Continuous polling loop - automatically cancelled when view disappears
        while !Task.isCancelled {
            // Load unread messages count
            unreadCount = await messageService.getUnreadMessageCount(userId: userId)

            // Load new matches count
            do {
                try await matchService.fetchMatches(userId: userId)
                newMatchesCount = matchService.matches.filter { $0.lastMessage == nil }.count
            } catch {
                Logger.shared.error("Error loading badge counts", category: .general, error: error)
            }

            // Wait 10 seconds before next update
            // Using Task.sleep instead of Timer - automatically handles cancellation
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        }
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    @State private var isPressed = false

    private var accessibilityHint: String {
        switch title {
        case "Discover":
            return "Browse potential matches"
        case "Matches":
            return "View your matches"
        case "Messages":
            return "Read and send messages"
        case "Saved":
            return "View saved profiles"
        case "Profile":
            return "Edit your profile and settings"
        default:
            return ""
        }
    }

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
            }
        }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Icon (clean, no glow)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(
                            isSelected ?
                            LinearGradient.brandPrimaryDiagonal :
                            LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 24)
                        .scaleEffect(isPressed ? 0.85 : 1.0)

                    // Clean badge - no pulse
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .offset(x: 12, y: -6)
                    }
                }

                // Title with smooth color transition
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ?
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                // Clean background - no shadow, no glow
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
            )
            // Accessibility
            .accessibilityLabel("\(title) tab")
            .accessibilityHint(accessibilityHint)
            .accessibilityValue(badgeCount > 0 ? "\(badgeCount) unread" : "")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: badgeCount)
    }
}

// MARK: - Animated Tab Indicator

struct AnimatedTabIndicator: View {
    let selectedTab: Int
    let totalTabs: Int
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(totalTabs)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: tabWidth * 0.5, height: 3)
                .offset(x: tabWidth * CGFloat(selectedTab) + tabWidth * 0.25)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
        }
        .frame(height: 3)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
