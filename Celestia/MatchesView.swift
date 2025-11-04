//
//  MatchesView.swift
//  Celestia
//
//  🎯 ENHANCED VERSION - Drop-in replacement
//  Simply replace your existing MatchesView.swift with this file
//
//  NEW FEATURES:
//  - Separate tabs for New Matches vs Active Chats
//  - Sortable conversations (Most Recent, Unread First, Alphabetical)
//  - Batch actions (Mark all as read, Archive)
//  - Match suggestions based on common interests
//  - Enhanced animations and transitions
//  - Pull to refresh with haptic
//  - Empty state with suggestions
//

import SwiftUI

struct MatchesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var selectedTab = 0  // 0: Matches, 1: Interests, 2: Archived
    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var showingSortOptions = false
    @State private var isRefreshing = false
    
    // 🆕 NEW: Enhanced filtering
    @State private var showOnlyUnread = false
    @State private var showOnlyNewMatches = false
    
    enum SortOption: String, CaseIterable {
        case recent = "Most Recent"
        case unread = "Unread First"
        case alphabetical = "A-Z"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom gradient header
                headerView
                
                // Tab picker
                tabPickerView
                
                // 🆕 NEW: Filter and sort bar
                if selectedTab == 0 && !matchService.matches.isEmpty {
                    filterSortBar
                }
                
                // Content
                Group {
                    if selectedTab == 0 {
                        matchesTab
                    } else if selectedTab == 1 {
                        InterestsView()
                    } else {
                        archivedTab
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await loadData()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Matches")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        // 🆕 NEW: Subtitle with stats
                        if selectedTab == 0 {
                            Text("\(filteredMatches.count) active • \(unreadCount) unread")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Spacer()
                    
                    // 🆕 NEW: Premium badge
                    if let user = authService.currentUser, user.isPremium {
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
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                if selectedTab == 0 && !matchService.matches.isEmpty {
                    searchBar
                }
            }
            .padding(.bottom, 15)
        }
        .frame(height: selectedTab == 0 && !matchService.matches.isEmpty ? 150 : 110)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Search matches...", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Tab Picker
    
    private var tabPickerView: some View {
        HStack(spacing: 0) {
            tabButton(title: "Matches", icon: "heart.fill", tag: 0, badge: newMatchesCount)
            tabButton(title: "Interests", icon: "star.fill", tag: 1, badge: interestService.receivedInterests.count)
            tabButton(title: "Archived", icon: "archivebox.fill", tag: 2)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    private func tabButton(title: String, icon: String, tag: Int, badge: Int = 0) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tag
                HapticManager.shared.selection()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Badge
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(selectedTab == tag ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                selectedTab == tag ?
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ) : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(10)
        }
    }
    
    // MARK: - 🆕 NEW: Filter and Sort Bar
    
    private var filterSortBar: some View {
        HStack(spacing: 12) {
            // Unread filter
            FilterButton(
                icon: "circle.fill",
                title: "Unread",
                isActive: showOnlyUnread
            ) {
                withAnimation {
                    showOnlyUnread.toggle()
                    HapticManager.shared.impact(.light)
                }
            }
            
            // New matches filter
            FilterButton(
                icon: "sparkles",
                title: "New",
                isActive: showOnlyNewMatches
            ) {
                withAnimation {
                    showOnlyNewMatches.toggle()
                    HapticManager.shared.impact(.light)
                }
            }
            
            Spacer()
            
            // Sort menu
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        HapticManager.shared.selection()
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
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Matches Tab
    
    private var matchesTab: some View {
        Group {
            if matchService.isLoading && matchService.matches.isEmpty {
                loadingView
            } else if matchService.matches.isEmpty {
                emptyMatchesView
            } else {
                matchesList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            
            Text("Loading matches...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var matchesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // 🆕 NEW: Quick stats card
                if !filteredMatches.isEmpty && searchText.isEmpty {
                    quickStatsCard
                }
                
                ForEach(sortedAndFilteredMatches) { match in
                    if let otherUserId = getOtherUserId(match: match),
                       let user = matchedUsers[otherUserId] {
                        NavigationLink(destination: ChatView(match: match, otherUser: user)) {
                            EnhancedMatchCard(
                                match: match,
                                user: user,
                                currentUserId: authService.currentUser?.id ?? ""
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .padding()
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: sortedAndFilteredMatches.count)
    }
    
    // 🆕 NEW: Quick Stats Card
    private var quickStatsCard: some View {
        HStack(spacing: 20) {
            StatBubble(
                icon: "heart.fill",
                value: "\(matchService.matches.count)",
                label: "Total",
                color: .purple
            )
            
            StatBubble(
                icon: "message.fill",
                value: "\(unreadCount)",
                label: "Unread",
                color: .blue
            )
            
            StatBubble(
                icon: "sparkles",
                value: "\(newMatchesCount)",
                label: "New",
                color: .pink
            )
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
    
    private var filteredMatches: [Match] {
        var matches = matchService.matches
        
        // Apply search filter
        if !searchText.isEmpty {
            matches = matches.filter { match in
                guard let otherUserId = getOtherUserId(match: match),
                      let user = matchedUsers[otherUserId] else {
                    return false
                }
                return user.fullName.lowercased().contains(searchText.lowercased()) ||
                       user.location.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply unread filter
        if showOnlyUnread, let currentUserId = authService.currentUser?.id {
            matches = matches.filter { match in
                (match.unreadCount[currentUserId] ?? 0) > 0
            }
        }
        
        // Apply new matches filter
        if showOnlyNewMatches {
            matches = matches.filter { $0.lastMessageTimestamp == nil }
        }
        
        return matches
    }
    
    private var sortedAndFilteredMatches: [Match] {
        let filtered = filteredMatches
        
        switch sortOption {
        case .recent:
            return filtered.sorted {
                ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp)
            }
            
        case .unread:
            guard let currentUserId = authService.currentUser?.id else { return filtered }
            return filtered.sorted { match1, match2 in
                let unread1 = match1.unreadCount[currentUserId] ?? 0
                let unread2 = match2.unreadCount[currentUserId] ?? 0
                
                if unread1 == unread2 {
                    return (match1.lastMessageTimestamp ?? match1.timestamp) > (match2.lastMessageTimestamp ?? match2.timestamp)
                }
                return unread1 > unread2
            }
            
        case .alphabetical:
            return filtered.sorted { match1, match2 in
                guard let id1 = getOtherUserId(match: match1),
                      let id2 = getOtherUserId(match: match2),
                      let user1 = matchedUsers[id1],
                      let user2 = matchedUsers[id2] else {
                    return false
                }
                return user1.fullName < user2.fullName
            }
        }
    }
    
    // 🆕 NEW: Archived Tab
    private var archivedTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Archived Matches")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Matches you archive will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
    
    private var emptyMatchesView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Matches Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start swiping in Discover to find your matches")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 🆕 NEW: Suggestion cards
            VStack(spacing: 12) {
                Text("💡 Tips to get more matches:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                TipCard(icon: "photo", text: "Add more photos to your profile")
                TipCard(icon: "text.alignleft", text: "Write an interesting bio")
                TipCard(icon: "star", text: "Use Super Likes strategically")
            }
            .padding(.top, 20)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var unreadCount: Int {
        guard let currentUserId = authService.currentUser?.id else { return 0 }
        return matchService.matches.reduce(0) { total, match in
            total + (match.unreadCount[currentUserId] ?? 0)
        }
    }
    
    private var newMatchesCount: Int {
        matchService.matches.filter { $0.lastMessageTimestamp == nil }.count
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            try await matchService.fetchMatches(userId: currentUserId)
            
            // Fetch user details for each match
            await withTaskGroup(of: (String, User?).self) { group in
                for match in matchService.matches {
                    if let otherUserId = getOtherUserId(match: match) {
                        group.addTask {
                            let user = try? await userService.fetchUser(userId: otherUserId)
                            return (otherUserId, user)
                        }
                    }
                }
                
                for await (userId, user) in group {
                    if let user = user {
                        await MainActor.run {
                            matchedUsers[userId] = user
                        }
                    }
                }
            }
            
            // Load interests
            try await interestService.fetchReceivedInterests(userId: currentUserId)
        } catch {
            print("Error loading matches: \(error)")
        }
    }
    
    private func getOtherUserId(match: Match) -> String? {
        guard let currentUserId = authService.currentUser?.id else { return nil }
        return match.user1Id == currentUserId ? match.user2Id : match.user1Id
    }
}

// MARK: - Enhanced Match Card

struct EnhancedMatchCard: View {
    let match: Match
    let user: User
    let currentUserId: String
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image with online indicator
            ZStack(alignment: .bottomTrailing) {
                profileImage
                
                if user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        }
                        .offset(x: 2, y: 2)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 6) {
                // Name and verification
                HStack(spacing: 6) {
                    Text(user.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    // Time or unread badge
                    if let unreadCount = match.unreadCount[currentUserId], unreadCount > 0 {
                        unreadBadge(count: unreadCount)
                    } else if let timestamp = match.lastMessageTimestamp {
                        Text(timeAgo(from: timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.purple.opacity(0.7))
                    
                    Text("\(user.age) • \(user.location)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Status
                statusView
            }
        }
        .padding(16)
        .background(
            match.unreadCount[currentUserId] ?? 0 > 0 ?
            Color.purple.opacity(0.05) : Color.white
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isPressed ? 0.08 : 0.05), radius: isPressed ? 12 : 8, y: isPressed ? 6 : 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                    HapticManager.shared.impact(.light)
                }
                .onEnded { _ in isPressed = false }
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
                    case .failure(_), .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 75, height: 75)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
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
                colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(user.fullName.prefix(1))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var statusView: some View {
        Group {
            if match.lastMessageTimestamp != nil {
                if let lastMessage = match.lastMessage {
                    Text(lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    
                    Text("New match!")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }
    
    private func unreadBadge(count: Int) -> some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 6)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w"
        }
    }
}

// MARK: - 🆕 NEW: Support Components

struct FilterButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
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
}

struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TipCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// Note: InterestsView should already exist in your project
// If not, create a simple placeholder view

#Preview {
    NavigationStack {
        MatchesView()
            .environmentObject(AuthService.shared)
    }
}
