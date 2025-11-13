//
//  MessagesView.swift
//  Celestia
//
//  ELITE MESSAGES VIEW - Premium Chat Experience
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var messageService = MessageService.shared

    @Binding var selectedTab: Int

    @State private var matchedUsers: [String: User] = [:]
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var selectedMatch: (Match, User)?
    @State private var showingChat = false
    
    var conversations: [(Match, User)] {
        matchService.matches.compactMap { match in
            guard let user = getMatchedUser(match) else { return nil }
            return (match, user)
        }
    }
    
    var filteredConversations: [(Match, User)] {
        guard !searchText.isEmpty else { return conversations }
        return conversations.filter { _, user in
            user.fullName.localizedCaseInsensitiveContains(searchText) ||
            user.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var totalUnread: Int {
        #if DEBUG
        let userId = authService.currentUser?.id ?? "current_user"
        #else
        guard let userId = authService.currentUser?.id else { return 0 }
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
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Content
                    if matchService.isLoading && conversations.isEmpty {
                        loadingView
                    } else if conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsListView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await loadData()
                HapticManager.shared.notification(.success)
            }
            .sheet(isPresented: $showingChat) {
                if let selectedMatch = selectedMatch {
                    NavigationStack {
                        ChatView(match: selectedMatch.0, otherUser: selectedMatch.1)
                            .environmentObject(authService)
                    }
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
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            if !conversations.isEmpty {
                                HStack(spacing: 6) {
                                    Text("\(conversations.count)")
                                        .fontWeight(.semibold)
                                    Text("chats")
                                    
                                    if totalUnread > 0 {
                                        Text("•")
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 6, height: 6)
                                            Text("\(totalUnread) unread")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.95))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    HStack(spacing: 12) {
                        // Search toggle
                        Button {
                            withAnimation(.spring(response: 0.3)) {
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
            
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
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
                ForEach(Array(filteredConversations.enumerated()), id: \.element.0.id) { index, conversation in
                    let (match, user) = conversation
                    
                    ConversationRow(
                        match: match,
                        user: user,
                        currentUserId: authService.currentUser?.id ?? "current_user",
                        index: index
                    )
                    .onTapGesture {
                        HapticManager.shared.impact(.medium)
                        selectedMatch = (match, user)
                        showingChat = true
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 100)
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
    
    // MARK: - Helper Functions
    
    private func loadData() async {
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

            // Load users for all matches
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
            Logger.shared.error("Error loading messages", category: .messaging, error: error)
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

// MARK: - Conversation Row

struct ConversationRow: View {
    let match: Match
    let user: User
    let currentUserId: String
    let index: Int
    
    @State private var appeared = false
    
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
                
                if user.isOnline {
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
        .offset(x: appeared ? 0 : 300)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
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
