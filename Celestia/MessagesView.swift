//
//  MessagesView.swift
//  Celestia
//
//  Enhanced messages list with modern design
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var messageService = MessageService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var unreadCounts: [String: Int] = [:]
    @State private var searchText = ""
    
    // Test mode toggle
    @State private var useTestData = true // Set to false for real data
    @State private var testConversations: [(Match, User)] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header
                headerView
                
                // Search bar
                if !conversations.isEmpty {
                    searchBar
                }
                
                // Content
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else if conversations.isEmpty {
                        emptyStateView
                    } else {
                        messagesList
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                if useTestData {
                    loadTestData()
                } else {
                    await loadData()
                }
            }
            .refreshable {
                if useTestData {
                    loadTestData()
                } else {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    if !conversations.isEmpty {
                        Text("\(unreadTotal) unread")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                if !conversations.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Text("\(conversations.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)
            .padding(.bottom, 20)
        }
        .frame(height: 120)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search messages...", text: $searchText)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredConversations, id: \.0.id) { match, user in
                    NavigationLink(destination: ChatView(match: match, otherUser: user)) {
                        EnhancedMessageRow(
                            match: match,
                            user: user,
                            unreadCount: getUnreadCount(for: match)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
    }
    
    private var filteredConversations: [(Match, User)] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { _, user in
                user.fullName.lowercased().contains(searchText.lowercased()) ||
                user.location.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private var conversations: [(Match, User)] {
        if useTestData {
            return testConversations
        } else {
            return matchService.matches.compactMap { match in
                guard let otherUserId = getOtherUserId(match: match),
                      let user = matchedUsers[otherUserId] else {
                    return nil
                }
                return (match, user)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            
            Text("Loading messages...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var isLoading: Bool {
        !useTestData && matchService.isLoading && matchService.matches.isEmpty
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
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
                
                Image(systemName: "message.circle.fill")
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
                Text("No Messages Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start matching with people\nto begin chatting")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: DiscoverView()) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                    Text("Start Discovering")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: Color.purple.opacity(0.3), radius: 8, y: 4)
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var unreadTotal: Int {
        if useTestData {
            return testConversations.reduce(0) { total, conversation in
                total + (conversation.0.unreadCount[authService.currentUser?.id ?? ""] ?? 0)
            }
        } else {
            return matchService.matches.reduce(0) { total, match in
                guard let userId = authService.currentUser?.id else { return total }
                return total + (match.unreadCount[userId] ?? 0)
            }
        }
    }
    
    private func getUnreadCount(for match: Match) -> Int {
        guard let userId = authService.currentUser?.id else { return 0 }
        return match.unreadCount[userId] ?? 0
    }
    
    private func loadData() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            try await matchService.fetchMatches(userId: currentUserId)
            
            for match in matchService.matches {
                if let otherUserId = getOtherUserId(match: match) {
                    if let user = try await userService.fetchUser(userId: otherUserId) {
                        await MainActor.run {
                            matchedUsers[otherUserId] = user
                        }
                    }
                    
                    if let matchId = match.id {
                        let count = try await messageService.getUnreadCount(matchId: matchId, userId: currentUserId)
                        await MainActor.run {
                            unreadCounts[matchId] = count
                        }
                    }
                }
            }
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func getOtherUserId(match: Match) -> String? {
        guard let currentUserId = authService.currentUser?.id else { return nil }
        return match.user1Id == currentUserId ? match.user2Id : match.user1Id
    }
    
    // MARK: - Test Data
    
    private func loadTestData() {
        let currentUserId = "currentUser"
        
        let testUsers = [
            User(
                id: "test1",
                email: "emma@test.com",
                fullName: "Emma Wilson",
                age: 24,
                gender: "Female",
                lookingFor: "Male",
                bio: "Coffee enthusiast ☕️ | Travel blogger",
                location: "Paris",
                country: "France",
                languages: ["French", "English"],
                interests: ["Travel", "Photography", "Coffee"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test2",
                email: "sophia@test.com",
                fullName: "Sophia Martinez",
                age: 26,
                gender: "Female",
                lookingFor: "Male",
                bio: "Yoga instructor 🧘‍♀️ | Nature lover",
                location: "Barcelona",
                country: "Spain",
                languages: ["Spanish", "English", "Catalan"],
                interests: ["Yoga", "Hiking", "Meditation"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test3",
                email: "olivia@test.com",
                fullName: "Olivia Chen",
                age: 25,
                gender: "Female",
                lookingFor: "Everyone",
                bio: "Tech entrepreneur 💻 | Startup founder",
                location: "Tokyo",
                country: "Japan",
                languages: ["Japanese", "English", "Mandarin"],
                interests: ["Technology", "Startups", "Anime"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test4",
                email: "isabella@test.com",
                fullName: "Isabella Rossi",
                age: 23,
                gender: "Female",
                lookingFor: "Male",
                bio: "Fashion designer ✨ | Art enthusiast",
                location: "Milan",
                country: "Italy",
                languages: ["Italian", "English"],
                interests: ["Fashion", "Art", "Design"],
                profileImageURL: "",
                isVerified: false
            ),
            User(
                id: "test5",
                email: "mia@test.com",
                fullName: "Mia Anderson",
                age: 27,
                gender: "Female",
                lookingFor: "Male",
                bio: "Musician 🎸 | Indie rock lover",
                location: "London",
                country: "UK",
                languages: ["English"],
                interests: ["Music", "Concerts", "Guitar"],
                profileImageURL: "",
                isVerified: true
            )
        ]
        
        // Create test conversations with varying states
        testConversations = testUsers.enumerated().map { index, user in
            let hasMessages = index < 3 // First 3 have messages
            let unreadCount = index == 0 ? 3 : (index == 1 ? 1 : 0)
            
            var unreadDict: [String: Int] = [:]
            if unreadCount > 0 {
                unreadDict[currentUserId] = unreadCount
            }
            
            let match = Match(
                id: "match\(index + 1)",
                user1Id: currentUserId,
                user2Id: user.id ?? "",
                timestamp: Date().addingTimeInterval(-Double(index) * 86400), // Days ago
                lastMessageTimestamp: hasMessages ? Date().addingTimeInterval(-Double(index + 1) * 3600) : nil, // Hours ago
                lastMessage: hasMessages ? getTestMessage(for: index) : nil,
                unreadCount: unreadDict,
                isActive: true
            )
            
            return (match, user)
        }
    }
    
    private func getTestMessage(for index: Int) -> String {
        let messages = [
            "Hey! How was your day? 😊",
            "That sounds amazing! Would love to hear more about it",
            "See you tomorrow!",
            "",
            ""
        ]
        return messages[index]
    }
}

// MARK: - Enhanced Message Row

struct EnhancedMessageRow: View {
    let match: Match
    let user: User
    let unreadCount: Int
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            ZStack(alignment: .bottomTrailing) {
                profileImage
                
                // Online indicator
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
            
            // Message Info
            VStack(alignment: .leading, spacing: 6) {
                // Name and time
                HStack {
                    HStack(spacing: 6) {
                        Text(user.fullName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
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
                
                // Last message or status
                HStack {
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
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
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
        .padding(16)
        .background(unreadCount > 0 ? Color.purple.opacity(0.05) : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isPressed ? 0.08 : 0.05), radius: isPressed ? 12 : 8, y: isPressed ? 6 : 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
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
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
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
                colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.5)],
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

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(AuthService.shared)
    }
}
