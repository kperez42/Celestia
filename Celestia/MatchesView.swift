//
//  MatchesView.swift
//  Celestia
//
//  ELITE MATCHES VIEW - Premium Dating Experience
//

import SwiftUI

struct MatchesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var messageService = MessageService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var showingSortMenu = false
    @State private var showOnlyUnread = false
    @State private var selectedMatch: Match?
    @State private var showMatchDetail = false
    
    enum SortOption: String, CaseIterable {
        case recent = "Most Recent"
        case unread = "Unread First"
        case alphabetical = "A-Z"
        case newMatches = "New Matches"
    }
    
    var filteredAndSortedMatches: [Match] {
        var matches = matchService.matches
        
        // Apply search filter
        if !searchText.isEmpty {
            matches = matches.filter { match in
                guard let user = getMatchedUser(match) else { return false }
                return user.fullName.localizedCaseInsensitiveContains(searchText) ||
                       user.location.localizedCaseInsensitiveContains(searchText)
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
                    if matchService.isLoading && matchService.matches.isEmpty {
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
            .task {
                await loadMatches()
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await loadMatches()
                HapticManager.shared.notification(.success)
            }
            .sheet(item: $selectedMatch) { match in
                if let user = getMatchedUser(match) {
                    UserDetailView(user: user)
                        .environmentObject(authService)
                }
            }
        }
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
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
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
            
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
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
    }
    
    // MARK: - Matches List
    
    private var matchesListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredAndSortedMatches) { match in
                    if let user = getMatchedUser(match) {
                        MatchProfileCard(
                            match: match,
                            user: user,
                            currentUserId: authService.currentUser?.id ?? "current_user"
                        )
                        .onTapGesture {
                            HapticManager.shared.impact(.medium)
                            selectedMatch = match
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
                
                Text("Start swiping to find your perfect match!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
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

        #if DEBUG
        // Use test data in debug mode even with authenticated user
        await MainActor.run {
            matchService.matches = TestData.testMatches.map { $0.match }
            for (user, match) in TestData.testMatches {
                let otherUserId = match.user2Id
                matchedUsers[otherUserId] = user
            }
        }
        return
        #endif

        do {
            try await matchService.fetchMatches(userId: userId)

            // Load user data for each match
            for match in matchService.matches {
                let otherUserId = match.user1Id == userId ? match.user2Id : match.user1Id
                if matchedUsers[otherUserId] == nil {
                    if let user = try? await userService.fetchUser(userId: otherUserId) {
                        await MainActor.run {
                            matchedUsers[otherUserId] = user
                        }
                    }
                }
            }
        } catch {
            Logger.shared.error("Error loading matches", category: .matching, error: error)
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
}

// MARK: - Match Card Row

// MARK: - Match Profile Card

struct MatchProfileCard: View {
    let match: Match
    let user: User
    let currentUserId: String

    private var isNewMatch: Bool {
        match.lastMessage == nil
    }

    private var unreadCount: Int {
        match.unreadCount[currentUserId] ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile image with badges
            ZStack(alignment: .topTrailing) {
                profileImage
                    .frame(height: 220)

                // New match or unread badge
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
    }
    
    private var profileImage: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderImage
                    }
                }
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
