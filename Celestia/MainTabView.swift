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
    @State private var showWarningBanner = false
    @State private var showWarningAlert = false

    // Admin check
    private var isAdminUser: Bool {
        if authService.currentUser?.isAdmin == true {
            return true
        }
        guard let email = authService.currentUser?.email else { return false }
        let adminEmails = ["perezkevin640@gmail.com", "admin@celestia.app"]
        return adminEmails.contains(email.lowercased())
    }

    // AUDIT FIX: Removed separate unreadListener
    // Now using Match.unreadCount from matchService which:
    // 1. Only counts from active matches
    // 2. Is already in sync with server state
    // 3. Excludes blocked/unmatched users
    // 4. Uses already-fetched data (no extra query)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Warning banner for users who have received a warning
                if showWarningBanner {
                    warningBanner
                }

                // Main content - All views stay loaded, use opacity for instant switching
                ZStack {
                    // Discover
                    FeedDiscoverView(selectedTab: $selectedTab)
                        .opacity(selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 0)

                    // Likes
                    LikesView()
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)

                    // Messages
                    MessagesView(selectedTab: $selectedTab)
                        .opacity(selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 2)

                    // Saved
                    SavedProfilesView()
                        .opacity(selectedTab == 3 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 3)

                    // Profile
                    ProfileView(selectedTab: $selectedTab)
                        .opacity(selectedTab == 4 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 4)

                    // Admin - Only for admin users
                    if isAdminUser {
                        AdminModerationDashboard()
                            .opacity(selectedTab == 5 ? 1 : 0)
                            .allowsHitTesting(selectedTab == 5)
                    }
                }
                .ignoresSafeArea(.keyboard)
            } // End VStack

            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .alert("Account Warning", isPresented: $showWarningAlert) {
            Button("I Understand", role: .cancel) {
                dismissWarning()
            }
        } message: {
            Text(authService.currentUser?.lastWarningReason ?? "Your account has received a warning. Please review our community guidelines to avoid future warnings.")
        }
        .onAppear {
            // Check if user has an unread warning
            checkForUnreadWarning()
        }
        .onChange(of: authService.currentUser?.hasUnreadWarning) { _, newValue in
            if newValue == true {
                checkForUnreadWarning()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
            // Removed haptic for faster feel
        }
        .onChange(of: matchService.matches) { _, newMatches in
            // AUDIT FIX: Calculate both counts from authoritative Match data
            // BUGFIX: Use effectiveId for reliable user identification
            guard let userId = authService.currentUser?.effectiveId else { return }

            // Update new matches count (matches without any messages yet)
            newMatchesCount = newMatches.filter { $0.lastMessage == nil }.count

            // AUDIT FIX: Calculate unread count from Match.unreadCount
            // This is the authoritative source, updated when messages are sent/read
            unreadCount = newMatches.reduce(0) { total, match in
                total + (match.unreadCount[userId] ?? 0)
            }

            Logger.shared.debug("Badge counts updated - unread: \(unreadCount), newMatches: \(newMatchesCount)", category: .messaging)
        }
        .task {
            // PERFORMANCE FIX: Use real-time listeners instead of polling
            // This eliminates battery drain from constant polling
            // BUGFIX: Use effectiveId for reliable user identification
            guard let userId = authService.currentUser?.effectiveId else { return }

            // Small delay to ensure auth token is fully propagated
            // This prevents brief "permission denied" errors in logs during signup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Verify user is still authenticated after delay
            guard authService.currentUser?.effectiveId == userId else { return }

            // PUSH NOTIFICATIONS: Initialize and request permissions
            await PushNotificationManager.shared.initialize()
            let granted = await PushNotificationManager.shared.requestAuthorization()
            if granted {
                Logger.shared.info("Push notifications enabled for user", category: .general)
                // Save FCM token to user profile for backend notifications
                if let fcmToken = PushNotificationManager.shared.fcmToken {
                    await NotificationService.shared.saveFCMToken(userId: userId, token: fcmToken)
                }
            }

            // Set up real-time listener for matches
            // AUDIT FIX: This single listener now handles both:
            // - Match updates (for newMatchesCount)
            // - Unread counts (from Match.unreadCount field)
            matchService.listenToMatches(userId: userId)

            // AUDIT FIX: Calculate initial counts immediately
            newMatchesCount = matchService.matches.filter { $0.lastMessage == nil }.count
            unreadCount = matchService.matches.reduce(0) { total, match in
                total + (match.unreadCount[userId] ?? 0)
            }
        }
        .onDisappear {
            // PERFORMANCE: Clean up listeners when view disappears
            matchService.stopListening()
            // AUDIT FIX: Removed separate unreadListener cleanup
            // Match listener already handles unread counts
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMessages)) { notification in
            // Navigate to Messages tab when a match occurs
            selectedTab = 2
            HapticManager.shared.notification(.success)

            // Optional: Extract matched user ID for future use (e.g., scroll to conversation)
            if let matchedUserId = notification.userInfo?["matchedUserId"] as? String {
                Logger.shared.info("Navigating to messages for match: \(matchedUserId)", category: .ui)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAdminDashboard)) { notification in
            // Navigate to Admin tab when admin notification is tapped
            guard isAdminUser else { return }

            selectedTab = 5
            HapticManager.shared.notification(.warning)

            // Log the admin alert type
            if let alertType = notification.userInfo?["alertType"] as? String {
                Logger.shared.info("Navigating to admin dashboard for alert: \(alertType)", category: .ui)
            }
        }
    }
    
    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Top separator
            Rectangle()
                .fill(Color(.separator).opacity(0.2))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                // Discover
                TabBarButton(
                    icon: "flame.fill",
                    title: "Discover",
                    isSelected: selectedTab == 0,
                    badgeCount: 0,
                    color: .orange
                ) {
                    selectedTab = 0
                }

                // Likes
                TabBarButton(
                    icon: "heart.fill",
                    title: "Likes",
                    isSelected: selectedTab == 1,
                    badgeCount: newMatchesCount,
                    color: .pink
                ) {
                    selectedTab = 1
                }

                // Messages
                TabBarButton(
                    icon: "message.fill",
                    title: "Messages",
                    isSelected: selectedTab == 2,
                    badgeCount: unreadCount,
                    color: .blue
                ) {
                    selectedTab = 2
                }

                // Saved
                TabBarButton(
                    icon: "bookmark.fill",
                    title: "Saved",
                    isSelected: selectedTab == 3,
                    badgeCount: 0,
                    color: .yellow
                ) {
                    selectedTab = 3
                }

                // Profile
                TabBarButton(
                    icon: "person.fill",
                    title: "Profile",
                    isSelected: selectedTab == 4,
                    badgeCount: 0,
                    color: .purple
                ) {
                    selectedTab = 4
                }

                // Admin (only for admin users)
                if isAdminUser {
                    TabBarButton(
                        icon: "shield.fill",
                        title: "Admin",
                        isSelected: selectedTab == 5,
                        badgeCount: 0,
                        color: .indigo
                    ) {
                        selectedTab = 5
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .background {
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: - Warning Banner

    private var warningBanner: some View {
        Button(action: {
            showWarningAlert = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Account Warning")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Tap to view details")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helper Functions

    private func checkForUnreadWarning() {
        if authService.currentUser?.hasUnreadWarning == true {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showWarningBanner = true
            }
        }
    }

    private func dismissWarning() {
        guard let userId = authService.currentUser?.effectiveId else { return }

        // Hide banner with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showWarningBanner = false
        }

        // Mark warning as read in Firestore
        Task {
            do {
                try await Firestore.firestore().collection("users").document(userId).updateData([
                    "hasUnreadWarning": false
                ])
                await authService.fetchUser()
            } catch {
                Logger.shared.error("Failed to dismiss warning", category: .database, error: error)
            }
        }
    }

    // AUDIT FIX: Removed setupUnreadMessagesListener()
    // Now using Match.unreadCount from matchService.matches which is:
    // - Already fetched by listenToMatches()
    // - The authoritative source for unread counts
    // - Properly filtered by active matches only
    // - Updated in real-time when messages are read
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    let color: Color
    let action: () -> Void

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
        case "Admin":
            return "Admin moderation dashboard"
        default:
            return ""
        }
    }

    var body: some View {
        Button(action: {
            // Execute action immediately, haptic async for responsiveness
            action()
            Task { @MainActor in
                HapticManager.shared.selection()
            }
        }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Icon with background circle when selected
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 36, height: 36)
                        }

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? color : Color(.systemGray2))
                    }
                    .frame(width: 36, height: 36)

                    // Badge
                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                                    .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
                            )
                            .offset(x: 10, y: -4)
                    }
                }

                // Title
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? color : Color(.systemGray2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            // Accessibility
            .accessibilityLabel("\(title) tab")
            .accessibilityHint(accessibilityHint)
            .accessibilityValue(badgeCount > 0 ? "\(badgeCount) unread" : "")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
        .buttonStyle(TabBarButtonStyle())
    }
}

// MARK: - Tab Bar Button Style (Fast, Responsive)

struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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
                .fill(Color.purple)
                .frame(width: tabWidth * 0.5, height: 3)
                .offset(x: tabWidth * CGFloat(selectedTab) + tabWidth * 0.25)
        }
        .frame(height: 3)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
