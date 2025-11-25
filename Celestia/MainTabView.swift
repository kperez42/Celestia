//
//  MainTabView.swift
//  Celestia
//
//  ELITE TAB BAR - Smooth Navigation Experience
//

import SwiftUI
import FirebaseFirestore

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var matchService = MatchService.shared
    @ObservedObject private var messageService = MessageService.shared

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var unreadCount = 0
    @State private var newMatchesCount = 0
    @State private var unreadListener: ListenerRegistration?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                // Discover - Load immediately (tab 0)
                FeedDiscoverView(selectedTab: $selectedTab)
                    .tag(0)

                // Likes - Lazy load
                LazyTabContent(tabIndex: 1, currentTab: selectedTab) {
                    LikesView()
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

                // Viewers - Lazy load
                LazyTabContent(tabIndex: 4, currentTab: selectedTab) {
                    ProfileViewersView()
                }
                .tag(4)

                // Profile - Lazy load
                LazyTabContent(tabIndex: 5, currentTab: selectedTab) {
                    ProfileView()
                }
                .tag(5)
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
        .onChange(of: matchService.matches.count) { _, _ in
            // Update new matches count when matches change (real-time from listener)
            newMatchesCount = matchService.matches.filter { $0.lastMessage == nil }.count
        }
        .task {
            // PERFORMANCE FIX: Use real-time listeners instead of polling
            // This eliminates battery drain from constant polling
            guard let userId = authService.currentUser?.id else { return }

            // Allow the UI to render first before setting up listeners
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay

            // Set up real-time listener for matches (already exists in service)
            matchService.listenToMatches(userId: userId)

            // Set up real-time listener for unread messages
            setupUnreadMessagesListener(userId: userId)
        }
        .onDisappear {
            // PERFORMANCE: Clean up listeners when view disappears
            matchService.stopListening()
            unreadListener?.remove()
            unreadListener = nil
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

                // Likes
                TabBarButton(
                    icon: "heart.fill",
                    title: "Likes",
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

                // Viewers
                TabBarButton(
                    icon: "eye.fill",
                    title: "Viewers",
                    isSelected: selectedTab == 4,
                    badgeCount: 0
                ) {
                    selectedTab = 4
                }

                // Profile
                TabBarButton(
                    icon: "person.fill",
                    title: "Profile",
                    isSelected: selectedTab == 5,
                    badgeCount: 0
                ) {
                    selectedTab = 5
                }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, -20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions

    /// Set up real-time listener for unread message count
    /// PERFORMANCE FIX: Replaces inefficient 10-second polling with real-time updates
    private func setupUnreadMessagesListener(userId: String) {
        unreadListener?.remove()

        unreadListener = Firestore.firestore().collection("messages")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.shared.error("Error listening to unread messages", category: .messaging, error: error)
                    return
                }

                Task { @MainActor in
                    unreadCount = snapshot?.documents.count ?? 0
                    Logger.shared.debug("Unread count updated: \(unreadCount)", category: .messaging)
                }
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
        case "Viewers":
            return "See who viewed your profile"
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
