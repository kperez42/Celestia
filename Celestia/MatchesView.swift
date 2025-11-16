//
//  MatchesView.swift
//  Celestia
//
//  ELITE MATCHES VIEW - Premium Dating Experience
//  ACCESSIBILITY: Full VoiceOver support, Dynamic Type, Reduce Motion, and WCAG 2.1 AA compliant
//

import SwiftUI
import FirebaseFirestore

struct MatchesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var matchService = MatchService.shared
    @ObservedObject private var userService = UserService.shared
    @ObservedObject private var messageService = MessageService.shared
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var matchedUsers: [String: User] = [:]
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var showingSortMenu = false
    @State private var showOnlyUnread = false
    @State private var selectedMatch: Match?
    @State private var selectedUserForProfile: User?
    @State private var showMatchDetail = false
    @State private var errorMessage: String = ""

    enum SortOption: String, CaseIterable {
        case recent = "Most Recent"
        case unread = "Unread First"
        case alphabetical = "A-Z"
        case newMatches = "New Matches"
    }
    
    var filteredAndSortedMatches: [Match] {
        var matches = matchService.matches

        // Apply search filter using debounced text
        if !searchDebouncer.debouncedText.isEmpty {
            matches = matches.filter { match in
                guard let user = getMatchedUser(match) else { return false }
                return user.fullName.localizedCaseInsensitiveContains(searchDebouncer.debouncedText) ||
                       user.location.localizedCaseInsensitiveContains(searchDebouncer.debouncedText)
            }
        }
        
        // Apply unread filter
        if showOnlyUnread {
            #if DEBUG
            let userId = authService.currentUser?.id ?? "current_user"
            matches = matches.filter { ($0.unreadCount[userId] ?? 0) > 0 }
            #else
            if let userId = authService.currentUser?.id {
                matches = matches.filter { ($0.unreadCount[userId] ?? 0) > 0 }
            }
            #endif
        }

        // Apply sorting
        #if DEBUG
        let currentUserId = authService.currentUser?.id ?? "current_user"
        #else
        let currentUserId = authService.currentUser?.id ?? ""
        #endif
        return matches.sorted { match1, match2 in
            switch sortOption {
            case .recent:
                let time1 = match1.lastMessageTimestamp ?? match1.timestamp
                let time2 = match2.lastMessageTimestamp ?? match2.timestamp
                return time1 > time2
            case .unread:
                let unread1 = match1.unreadCount[currentUserId] ?? 0
                let unread2 = match2.unreadCount[currentUserId] ?? 0
                if unread1 != unread2 {
                    return unread1 > unread2
                }
                return (match1.lastMessageTimestamp ?? match1.timestamp) > (match2.lastMessageTimestamp ?? match2.timestamp)
            case .alphabetical:
                let name1 = getMatchedUser(match1)?.fullName ?? ""
                let name2 = getMatchedUser(match2)?.fullName ?? ""
                return name1 < name2
            case .newMatches:
                let hasMessage1 = match1.lastMessage != nil
                let hasMessage2 = match2.lastMessage != nil
                if hasMessage1 != hasMessage2 {
                    return !hasMessage1
                }
                return match1.timestamp > match2.timestamp
            }
        }
    }
    
    var unreadCount: Int {
        #if DEBUG
        let userId = authService.currentUser?.id ?? "current_user"
        #else
        guard let userId = authService.currentUser?.id else { return 0 }
        #endif
        return matchService.matches.reduce(0) { $0 + ($1.unreadCount[userId] ?? 0) }
    }
    
    var newMatchesCount: Int {
        matchService.matches.filter { $0.lastMessage == nil }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Tabs
                    if !matchService.matches.isEmpty {
                        tabsView
                    }
                    
                    // Content
                    if !errorMessage.isEmpty {
                        errorStateView
                    } else if matchService.isLoading && matchService.matches.isEmpty {
                        loadingView
                    } else if matchService.matches.isEmpty {
                        emptyStateView
                    } else {
                        matchesListView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .accessibilityIdentifier(AccessibilityIdentifier.matchesView)
            .task {
                await loadMatches()
                VoiceOverAnnouncement.screenChanged(to: "Matches view. \(matchService.matches.count) matches available.")
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await loadMatches()
                HapticManager.shared.notification(.success)
                VoiceOverAnnouncement.announce("Matches refreshed. \(matchService.matches.count) matches available.")
            }
            .sheet(isPresented: Binding(
                get: { selectedMatch != nil },
                set: { if !$0 { selectedMatch = nil } }
            )) {
                if let match = selectedMatch, let user = getMatchedUser(match) {
                    ChatView(match: match, otherUser: user)
                        .environmentObject(authService)
                }
            }
            .sheet(item: $selectedUserForProfile) { user in
                UserDetailView(user: user)
                    .environmentObject(authService)
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
                    Color.purple.opacity(0.7),
                    Color.blue.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Matches")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                            .dynamicTypeSize(min: .large, max: .accessibility2)
                            .accessibilityAddTraits(.isHeader)
                        
                        if !matchService.matches.isEmpty {
                            HStack(spacing: 8) {
                                // Match count
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                    Text("\(matchService.matches.count)")
                                        .fontWeight(.semibold)
                                }
                                
                                // Separator
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 4, height: 4)
                                
                                // Unread count
                                if unreadCount > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "message.fill")
                                            .font(.caption)
                                        Text("\(unreadCount) unread")
                                            .fontWeight(.semibold)
                                    }
                                }
                                
                                // New matches
                                if newMatchesCount > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 4, height: 4)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                        Text("\(newMatchesCount) new")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.95))
                        }
                    }
                    
                    Spacer()
                    
                    // Premium badge
                    if authService.currentUser?.isPremium == true {
                        premiumBadge
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                
                // Search bar (only show when there are matches)
                if !matchService.matches.isEmpty {
                    searchBar
                }
            }
            .padding(.bottom, 16)
        }
        .frame(height: matchService.matches.isEmpty ? 110 : 160)
    }
    
    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.caption)
            Text("Premium")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
            
            TextField("Search matches...", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
                .placeholder(when: searchText.isEmpty) {
                    Text("Search matches...")
                        .foregroundColor(.white.opacity(0.6))
                }
                .onChange(of: searchText) { _, newValue in
                    searchDebouncer.search(newValue)
                }
                .accessibilityElement(
                    label: "Search matches",
                    hint: "Type to search your matches by name or location",
                    identifier: AccessibilityIdentifier.searchField
                )
            
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                        searchDebouncer.clear()
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tabs
    
    private var tabsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Unread filter
                filterChip(
                    icon: unreadCount > 0 ? "circle.fill" : "circle",
                    title: "Unread",
                    count: unreadCount,
                    isActive: showOnlyUnread
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        showOnlyUnread.toggle()
                        HapticManager.shared.selection()
                    }
                }
                
                Spacer()
                
                // Sort menu
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation {
                                sortOption = option
                                HapticManager.shared.selection()
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        Text(sortOption.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(20)
                }
                .accessibilityLabel("Sort matches by \(sortOption.rawValue)")
                .accessibilityHint("Choose how to sort your matches")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            
            Divider()
        }
    }
    
    private func filterChip(icon: String, title: String, count: Int = 0, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isActive ? Color.white.opacity(0.3) : Color.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isActive ? .white : .purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isActive ?
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(colors: [Color.purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
        }
        .accessibilityLabel("\(title) filter, \(count) matches")
        .accessibilityHint(isActive ? "Active. Tap to deactivate" : "Tap to activate")
    }
    
    // MARK: - Matches List
    
    private var matchesListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(filteredAndSortedMatches.enumerated()), id: \.offset) { index, match in
                    if let user = getMatchedUser(match) {
                        MatchProfileCard(
                            match: match,
                            user: user,
                            currentUserId: authService.currentUser?.id ?? "current_user",
                            onInfoTap: {
                                selectedUserForProfile = user
                            }
                        )
                        .accessibilityElement(
                            label: "\(user.fullName), \(user.age) years old, from \(user.location)",
                            hint: "Tap to open chat and send a message",
                            traits: .isButton,
                            identifier: AccessibilityIdentifier.matchCard
                        )
                        .onTapGesture {
                            HapticManager.shared.impact(.medium)
                            selectedMatch = match
                            VoiceOverAnnouncement.announce("Opening chat with \(user.fullName)")
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    MatchCardSkeleton()
                }
            }
            .padding(16)
            .padding(.bottom, 100)
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
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Matches Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .dynamicTypeSize(min: .large, max: .accessibility2)
                    .accessibilityAddTraits(.isHeader)

                Text("Head to the Discover tab to start swiping and finding your perfect match!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .dynamicTypeSize(min: .small, max: .accessibility1)
            }
            .accessibilityElement(children: .combine)

            // CTA to encourage discovery
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.body)
                    Text("Go to Discover Tab")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .contentShape(RoundedRectangle(cornerRadius: 16))

                Text("Tap the first tab to start swiping")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            // Tips
            VStack(spacing: 12) {
                tipRow(icon: "photo.fill", text: "Add more photos to your profile")
                tipRow(icon: "text.alignleft", text: "Write an interesting bio")
                tipRow(icon: "heart.fill", text: "Be active and swipe regularly")
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.7), .orange.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Oops! Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                errorMessage = ""  // Clear error
                Task {
                    await loadMatches()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helper Functions

    private func loadMatches() async {
        // Check if we should use test data (no user ID or DEBUG mode)
        guard let userId = authService.currentUser?.id else {
            // Load test data when no authenticated user
            #if DEBUG
            await MainActor.run {
                matchService.matches = TestData.testMatches.map { $0.match }
                for (user, match) in TestData.testMatches {
                    let otherUserId = match.user2Id
                    matchedUsers[otherUserId] = user
                }
            }
            #endif
            return
        }

        // Removed test data blocking - use production code in debug builds with authenticated users

        do {
            try await matchService.fetchMatches(userId: userId)

            // Clear any previous errors on successful load
            await MainActor.run {
                errorMessage = ""
            }

            // PERFORMANCE FIX: Batch fetch all user data instead of N+1 queries
            // IMPORTANT: Always fetch fresh user data to ensure status is up-to-date
            let userIdsToFetch = matchService.matches
                .map { match in
                    match.user1Id == userId ? match.user2Id : match.user1Id
                }

            if !userIdsToFetch.isEmpty {
                // Batch fetch users in chunks of 10 (Firestore 'in' query limit)
                let fetchedUsers = try await batchFetchUsers(userIds: userIdsToFetch)

                await MainActor.run {
                    // Update cache with fresh user data (including current online status)
                    for user in fetchedUsers {
                        if let userId = user.id {
                            matchedUsers[userId] = user
                        }
                    }
                }
            }
        } catch {
            Logger.shared.error("Error loading matches", category: .matching, error: error)
            await MainActor.run {
                errorMessage = "Failed to load matches. Please check your connection and try again."
            }
        }
    }
    
    private func getMatchedUser(_ match: Match) -> User? {
        #if DEBUG
        // In debug mode, use "current_user" as default if not authenticated
        let currentUserId = authService.currentUser?.id ?? "current_user"
        #else
        guard let currentUserId = authService.currentUser?.id else { return nil }
        #endif

        let otherUserId = match.user1Id == currentUserId ? match.user2Id : match.user1Id
        return matchedUsers[otherUserId]
    }

    /// PERFORMANCE: Batch fetch users to prevent N+1 queries
    /// Firestore 'in' queries support up to 10 values, so we chunk the requests
    private func batchFetchUsers(userIds: [String]) async throws -> [User] {
        guard !userIds.isEmpty else { return [] }

        let db = Firestore.firestore()
        var allUsers: [User] = []

        // Firestore 'in' query limit is 10, so chunk the user IDs
        let chunks = userIds.chunked(into: 10)

        for chunk in chunks {
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                let users = snapshot.documents.compactMap { doc -> User? in
                    try? doc.data(as: User.self)
                }

                allUsers.append(contentsOf: users)

                Logger.shared.debug(
                    "Batch fetched \(users.count) users from chunk of \(chunk.count) IDs",
                    category: .matching
                )
            } catch {
                Logger.shared.error(
                    "Failed to batch fetch user chunk",
                    category: .matching,
                    error: error
                )
                // Continue with other chunks even if one fails
            }
        }

        return allUsers
    }
}

// MARK: - Match Card Row

// MARK: - Match Profile Card

struct MatchProfileCard: View {
    let match: Match
    let user: User
    let currentUserId: String
    var onInfoTap: (() -> Void)? = nil

    private var isNewMatch: Bool {
        match.lastMessage == nil
    }

    private var unreadCount: Int {
        match.unreadCount[currentUserId] ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile image with badges
            ZStack {
                profileImage
                    .frame(height: 220)

                // Online Status Indicator - Top Left
                VStack {
                    HStack {
                        OnlineStatusIndicator(user: user)
                            .padding(.top, 8)
                            .padding(.leading, 8)
                        Spacer()
                    }
                    Spacer()
                }

                // New match or unread badge - Top Right
                VStack {
                    HStack {
                        Spacer()
                        if isNewMatch {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("NEW")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .padding(8)
                        } else if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 24, minHeight: 24)
                                .background(Circle().fill(Color.red))
                                .padding(8)
                        }
                    }
                    Spacer()
                }
            }

            // User info section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("\(user.age)")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)

                    Spacer()

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text(user.location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // First interest or bio preview
                if let firstInterest = user.interests.first {
                    Text(firstInterest)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isNewMatch ?
                    LinearGradient(
                        colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2
                )
        )
        .overlay(alignment: .bottomTrailing) {
            // Info button to view full profile
            if let onInfoTap = onInfoTap {
                Button {
                    HapticManager.shared.impact(.light)
                    onInfoTap()
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(12)
                .accessibilityLabel("View \(user.fullName)'s profile")
                .accessibilityHint("Opens full profile details")
            }
        }
    }
    
    private var profileImage: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                CachedCardImage(url: imageURL)
            } else {
                placeholderImage
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(user.fullName.prefix(1))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
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

#Preview {
    NavigationStack {
        MatchesView()
            .environmentObject(AuthService.shared)
    }
}
