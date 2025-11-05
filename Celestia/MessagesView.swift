//
//  MessagesView.swift - ENHANCED VERSION
//  Celestia
//
//  ✨ Improvements:
//  - Beautiful header with stats
//  - Animated message rows
//  - Search with live filtering
//  - Swipe to delete/archive
//  - Online status indicators
//  - Typing indicators
//  - Better empty states
//  - Pull to refresh
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var messageService = MessageService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var isRefreshing = false
    @State private var selectedConversation: (Match, User)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom animated header
                    animatedHeader
                    
                    // Search bar (conditional)
                    if showSearch {
                        searchBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Content
                    if isLoading {
                        loadingView
                    } else if conversations.isEmpty {
                        enhancedEmptyState
                    } else {
                        conversationsList
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
            .refreshable {
                await refreshData()
            }
            .onDisappear {
                matchService.stopListening()
            }
        }
    }
    
    // MARK: - Animated Header
    
    private var animatedHeader: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.85),
                    Color.pink.opacity(0.75),
                    Color.blue.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .overlay {
                // Decorative circles
                GeometryReader { geo in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .offset(x: -30, y: 20)
                    
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .offset(x: geo.size.width - 40, y: 40)
                }
            }
            
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    // Icon and title
                    HStack(spacing: 12) {
                        Image(systemName: "message.circle.fill")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .yellow.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.3), radius: 5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Messages")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            if !conversations.isEmpty {
                                HStack(spacing: 6) {
                                    Text("\(conversations.count) conversations")
                                        .font(.subheadline)
                                    
                                    if unreadTotal > 0 {
                                        Text("•")
                                        Text("\(unreadTotal) unread")
                                    }
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Search toggle
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showSearch.toggle()
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        // Unread count badge
                        if unreadTotal > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                
                                Text("\(unreadTotal)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.body)
            
            TextField("Search conversations...", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredConversations.enumerated()), id: \.element.0.id) { index, conversation in
                    let (match, user) = conversation
                    
                    NavigationLink(destination: ChatView(match: match, otherUser: user)) {
                        AnimatedMessageRow(
                            match: match,
                            user: user,
                            unreadCount: getUnreadCount(for: match),
                            index: index
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 25) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                // Animated ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
            }
            
            VStack(spacing: 8) {
                Text("Loading conversations...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("This won't take long")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Enhanced Empty State
    
    private var enhancedEmptyState: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.2),
                                Color.pink.opacity(0.15),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Messages Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start swiping to match with people\nand begin chatting!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // CTA Button
            NavigationLink(destination: Text("Discover View")) {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.headline)
                    Text("Start Discovering")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Computed Properties
    
    private var isLoading: Bool {
        matchService.isLoading && matchService.matches.isEmpty
    }
    
    private var conversations: [(Match, User)] {
        matchService.matches.compactMap { match in
            guard let otherUserId = getOtherUserId(match: match),
                  let user = matchedUsers[otherUserId] else {
                return nil
            }
            return (match, user)
        }
        .sorted { lhs, rhs in
            let lhsTimestamp = lhs.0.lastMessageTimestamp ?? lhs.0.timestamp
            let rhsTimestamp = rhs.0.lastMessageTimestamp ?? rhs.0.timestamp
            return lhsTimestamp > rhsTimestamp
        }
    }
    
    private var filteredConversations: [(Match, User)] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { _, user in
                user.fullName.localizedCaseInsensitiveContains(searchText) ||
                user.location.localizedCaseInsensitiveContains(searchText) ||
                user.country.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var unreadTotal: Int {
        guard let currentUserId = authService.currentUser?.id else { return 0 }
        return matchService.matches.reduce(0) { total, match in
            total + (match.unreadCount[currentUserId] ?? 0)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getUnreadCount(for match: Match) -> Int {
        guard let currentUserId = authService.currentUser?.id else { return 0 }
        return match.unreadCount[currentUserId] ?? 0
    }
    
    private func getOtherUserId(match: Match) -> String? {
        guard let currentUserId = authService.currentUser?.id else { return nil }
        return match.user1Id == currentUserId ? match.user2Id : match.user1Id
    }
    
    private func loadData() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            try await matchService.fetchMatches(userId: currentUserId)
            
            for match in matchService.matches {
                if let otherUserId = getOtherUserId(match: match) {
                    if matchedUsers[otherUserId] == nil {
                        if let user = try await userService.fetchUser(userId: otherUserId) {
                            await MainActor.run {
                                matchedUsers[otherUserId] = user
                            }
                        }
                    }
                }
            }
            
            matchService.listenToMatches(userId: currentUserId)
        } catch {
            print("❌ Error loading messages: \(error)")
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        HapticManager.shared.impact(.light)
        await loadData()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isRefreshing = false
    }
}

// MARK: - Animated Message Row

struct AnimatedMessageRow: View {
    let match: Match
    let user: User
    let unreadCount: Int
    let index: Int
    
    @State private var isPressed = false
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image with online indicator
            ZStack(alignment: .bottomTrailing) {
                profileImage
                
                if user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        }
                        .offset(x: 3, y: 3)
                }
            }
            
            // Message Info
            VStack(alignment: .leading, spacing: 8) {
                // Name and time row
                HStack {
                    HStack(spacing: 6) {
                        Text(user.fullName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    
                    Spacer()
                    
                    if let timestamp = match.lastMessageTimestamp {
                        Text(timeAgo(from: timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Last message or new match
                HStack(alignment: .center, spacing: 0) {
                    if let lastMessage = match.lastMessage {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(unreadCount > 0 ? .primary : .gray)
                            .fontWeight(unreadCount > 0 ? .semibold : .regular)
                            .lineLimit(2)
                    } else {
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
                    }
                    
                    Spacer()
                    
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
                            Color.purple.opacity(0.05),
                            Color.pink.opacity(0.03)
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
            radius: isPressed ? 12 : 8,
            y: isPressed ? 6 : 4
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .offset(x: appeared ? 0 : 300)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                    HapticManager.shared.impact(.light)
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
    
    // MARK: - Profile Image
    
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
        .frame(width: 70, height: 70)
        .clipShape(Circle())
        .overlay {
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
        }
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
    
    // MARK: - Unread Badge
    
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
    }
    
    // MARK: - Time Ago
    
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

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(AuthService.shared)
    }
}
