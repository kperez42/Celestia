//
//  MessagesView.swift
//  Celestia
//
//  ELITE MESSAGES VIEW - Premium Chat Experience
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var matchService = MatchService.shared
    @ObservedObject private var userService = UserService.shared
    @ObservedObject private var messageService = MessageService.shared
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)

    @Binding var selectedTab: Int

    @State private var matchedUsers: [String: User] = [:]
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var chatPresentation: ChatPresentation?

    // Wrapper for item-based sheet presentation
    struct ChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    // PERFORMANCE: Memoized conversation lists to avoid O(n) on every render
    @State private var cachedConversations: [(Match, User)] = []
    @State private var cachedFilteredConversations: [(Match, User)] = []

    // PERFORMANCE: Cache management to prevent reloads on every tab switch
    @State private var lastFetchTime: Date?
    // PERFORMANCE: Increased cache duration - data updates via real-time listeners anyway
    private let cacheDuration: TimeInterval = 300 // 5 minute cache - real-time updates handle freshness

    // PERFORMANCE: Track if initial load is complete for instant subsequent displays
    @State private var hasCompletedInitialLoad = false

    // PERFORMANCE: Use cached values
    var conversations: [(Match, User)] { cachedConversations }
    var filteredConversations: [(Match, User)] { cachedFilteredConversations }

    // PERFORMANCE: Update cached conversations only when dependencies change
    private func updateCachedConversations() {
        // Build base conversations sorted by most recent activity
        cachedConversations = matchService.matches.compactMap { match in
            guard let user = getMatchedUser(match) else { return nil }
            return (match, user)
        }
        updateFilteredConversations()
    }

    private func updateFilteredConversations() {
        guard !searchDebouncer.debouncedText.isEmpty else {
            cachedFilteredConversations = cachedConversations
            return
        }
        cachedFilteredConversations = cachedConversations.filter { _, user in
            user.fullName.localizedCaseInsensitiveContains(searchDebouncer.debouncedText) ||
            user.location.localizedCaseInsensitiveContains(searchDebouncer.debouncedText)
        }
    }

    var totalUnread: Int {
        #if DEBUG
        let userId = authService.currentUser?.effectiveId ?? "current_user"
        #else
        guard let userId = authService.currentUser?.effectiveId else { return 0 }
        #endif
        return matchService.matches.reduce(0) { $0 + ($1.unreadCount[userId] ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Search bar
                    if showSearch {
                        searchBar
                            .transition(.opacity)
                    }

                    // Content - single unified list of all conversations
                    // PERFORMANCE: Only show loading skeleton on very first app launch
                    // when we have absolutely no data. Otherwise show content instantly.
                    // Check matchService.matches directly to avoid flash from local cache init
                    if matchService.isLoading && !hasCompletedInitialLoad && matchService.matches.isEmpty && conversations.isEmpty {
                        loadingView
                    } else if conversations.isEmpty && matchService.matches.isEmpty {
                        emptyStateView
                    } else if filteredConversations.isEmpty && !searchDebouncer.debouncedText.isEmpty {
                        // No search results
                        noSearchResultsView
                    } else {
                        conversationsListView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                // PERFORMANCE: Immediately populate cache from existing matchService data
                // This runs synchronously before any async tasks, preventing flash
                if cachedConversations.isEmpty && !matchService.matches.isEmpty {
                    updateCachedConversations()
                    Logger.shared.debug("MessagesView instant cache populate from matchService", category: .performance)
                }
            }
            .task {
                // PERFORMANCE: Show cached data immediately, fetch in background if stale
                if hasCompletedInitialLoad && !cachedConversations.isEmpty {
                    // Cache hit - show cached data instantly
                    Logger.shared.debug("MessagesView cache HIT - instant display", category: .performance)

                    // Background refresh if cache is stale (non-blocking)
                    if let lastFetch = lastFetchTime,
                       Date().timeIntervalSince(lastFetch) > cacheDuration {
                        Task.detached(priority: .background) {
                            await MainActor.run {
                                Task {
                                    await loadData()
                                    updateCachedConversations()
                                    lastFetchTime = Date()
                                }
                            }
                        }
                    }
                    return
                }

                // First load - fetch data
                await loadData()
                updateCachedConversations()
                lastFetchTime = Date()
                hasCompletedInitialLoad = true
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await loadData()
                updateCachedConversations()
                lastFetchTime = Date()
                HapticManager.shared.notification(.success)
            }
            // PERFORMANCE: Update cached conversations when matches change
            // Watch the full array to catch lastMessage updates, not just count changes
            .onChange(of: matchService.matches) { _, _ in
                updateCachedConversations()
            }
            .onChange(of: matchedUsers.count) { _, _ in
                updateCachedConversations()
            }
            .onChange(of: searchDebouncer.debouncedText) { _, _ in
                updateFilteredConversations()
            }
            .sheet(item: $chatPresentation) { presentation in
                NavigationStack {
                    ChatView(match: presentation.match, otherUser: presentation.user)
                        .environmentObject(authService)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openChatWithUser)) { notification in
                // Open chat with specific user when notification is received
                guard let userId = notification.userInfo?["userId"] as? String,
                      let user = notification.userInfo?["user"] as? User else {
                    Logger.shared.warning("OpenChatWithUser notification missing user data", category: .messaging)
                    return
                }

                // Find the match for this user
                if let matchPair = conversations.first(where: { $0.1.id == userId }) {
                    chatPresentation = ChatPresentation(match: matchPair.0, user: matchPair.1)
                    HapticManager.shared.impact(.medium)
                    Logger.shared.info("Opening chat with \(user.fullName) from Discover", category: .messaging)
                } else {
                    Logger.shared.warning("No match found for user \(userId) in conversations", category: .messaging)
                }
            }
        }
        .networkStatusBanner() // UX: Show offline status
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.9),
                    Color.pink.opacity(0.7),
                    Color.blue.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .offset(x: -30, y: 20)
                
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 15)
                    .offset(x: geo.size.width - 50, y: 40)
            }
            
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    // Title section
                    HStack(spacing: 12) {
                        Image(systemName: "message.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .yellow.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.4), radius: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Messages")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.caption)
                                    Text("\(conversations.count) chats")
                                        .fontWeight(.semibold)
                                }

                                if totalUnread > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 4, height: 4)

                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                        Text("\(totalUnread) unread")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.95))
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    HStack(spacing: 12) {
                        // Search toggle
                        Button {
                            withAnimation(.quick) {
                                showSearch.toggle()
                                if !showSearch {
                                    searchText = ""
                                }
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(showSearch ? 0.25 : 0.15))
                                .clipShape(Circle())
                        }
                        
                        // Unread indicator
                        if totalUnread > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .white.opacity(0.4), radius: 8)
                                
                                Text("\(totalUnread)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }
            .padding(.bottom, 16)
        }
        .frame(height: 140)
    }

    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search conversations...", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { newValue in
                    searchDebouncer.search(newValue)
                }

            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                        searchDebouncer.clear()
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Conversations List
    
    private var conversationsListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredConversations, id: \.0.id) { match, user in
                    ConversationRow(
                        match: match,
                        user: user,
                        currentUserId: authService.currentUser?.effectiveId ?? "current_user"
                    )
                    .onTapGesture {
                        HapticManager.shared.impact(.medium)
                        chatPresentation = ChatPresentation(match: match, user: user)
                    }
                    .onAppear {
                        // PERFORMANCE: Prefetch user images as conversations appear
                        ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { _ in
                    ConversationRowSkeleton()
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Messages Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("When you match with someone, you'll be able to chat here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // CTA Button
            Button {
                selectedTab = 0
                HapticManager.shared.impact(.medium)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                    Text("Start Swiping")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Search Results

    private var noSearchResultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Results")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("No conversations match \"\(searchDebouncer.debouncedText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions
    
    private func loadData() async {
        // Track performance for messages loading
        let loadStart = Date()

        guard let userId = authService.currentUser?.effectiveId else {
            return
        }

        do {
            try await matchService.fetchMatches(userId: userId)

            // PERFORMANCE FIX: Batch fetch all users at once instead of N individual fetches
            // This reduces network calls from N to ceil(N/10) using Firestore's whereIn limit
            let otherUserIds = matchService.matches.map { match in
                match.user1Id == userId ? match.user2Id : match.user1Id
            }

            if !otherUserIds.isEmpty {
                let fetchedUsers = try await userService.fetchUsersBatched(ids: otherUserIds)
                await MainActor.run {
                    matchedUsers = fetchedUsers
                }
            }

            let duration = Date().timeIntervalSince(loadStart) * 1000
            await PerformanceMonitor.shared.trackQuery(duration: duration)

            Logger.shared.info("Loaded \(matchService.matches.count) matches in \(String(format: "%.0f", duration))ms (batch query)", category: .messaging)
        } catch {
            Logger.shared.error("Error loading messages", category: .messaging, error: error)
        }
    }
    
    private func getMatchedUser(_ match: Match) -> User? {
        guard let currentUserId = authService.currentUser?.effectiveId else { return nil }
        let otherUserId = match.user1Id == currentUserId ? match.user2Id : match.user1Id
        return matchedUsers[otherUserId]
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let match: Match
    let user: User
    let currentUserId: String
    
    private var unreadCount: Int {
        match.unreadCount[currentUserId] ?? 0
    }
    
    private var isNewMatch: Bool {
        match.lastMessage == nil
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image with online indicator
            ZStack(alignment: .topTrailing) {
                profileImage

                // Consider user active if they're online OR were active in the last 5 minutes
                let interval = Date().timeIntervalSince(user.lastActive)
                let isActive = user.isOnline || interval < 300

                if isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Name and time
                HStack {
                    HStack(spacing: 6) {
                        Text(user.fullName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if user.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    if let timestamp = match.lastMessageTimestamp {
                        Text(timeAgo(from: timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Last message or new match indicator
                HStack(spacing: 0) {
                    if isNewMatch {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("New match! Say hi 👋")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    } else if let lastMessage = match.lastMessage {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(unreadCount > 0 ? .primary : .secondary)
                            .fontWeight(unreadCount > 0 ? .semibold : .regular)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Unread badge
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(18)
        .background(
            ZStack {
                if unreadCount > 0 {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.08),
                            Color.pink.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.white
                }
            }
        )
        .cornerRadius(20)
        .shadow(
            color: unreadCount > 0 ? Color.purple.opacity(0.15) : Color.black.opacity(0.05),
            radius: 8,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    unreadCount > 0 || isNewMatch ?
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.5
                )
        )
    }
    
    private var profileImage: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                CachedProfileImage(url: imageURL, size: 70)
            } else {
                placeholderImage
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            }
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.3),
                            Color.pink.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.7),
                    Color.pink.opacity(0.6),
                    Color.blue.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(user.fullName.prefix(1))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var unreadBadge: some View {
        Text("\(unreadCount)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 6)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.3), radius: 5)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 { return "now" }
        else if interval < 3600 { return "\(Int(interval / 60))m" }
        else if interval < 86400 { return "\(Int(interval / 3600))h" }
        else if interval < 604800 { return "\(Int(interval / 86400))d" }
        else { return "\(Int(interval / 604800))w" }
    }
}

// MARK: - Helper Struct

struct IdentifiableMatchUser: Identifiable {
    let id = UUID()
    let match: Match
    let user: User
}

#Preview {
    NavigationStack {
        MessagesView(selectedTab: .constant(2))
            .environmentObject(AuthService.shared)
    }
}
