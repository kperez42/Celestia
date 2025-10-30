import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var messageService = MessageService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var unreadCounts: [String: Int] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if matchService.isLoading && matchService.matches.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if matchService.matches.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(matchService.matches) { match in
                                if let otherUserId = getOtherUserId(match: match),
                                   let user = matchedUsers[otherUserId] {
                                    NavigationLink(destination: ChatView(match: match, otherUser: user)) {
                                        MessageRowView(
                                            match: match,
                                            user: user,
                                            unreadCount: unreadCounts[match.id ?? ""] ?? 0
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No messages yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start matching with people to chat")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .padding(.top, 50)
    }
    
    private func loadData() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            // Load matches
            try await matchService.fetchMatches(userId: currentUserId)
            
            // Load user details and unread counts for each match
            for match in matchService.matches {
                if let otherUserId = getOtherUserId(match: match) {
                    // Fetch user
                    if let user = try await userService.fetchUser(userId: otherUserId) {
                        await MainActor.run {
                            matchedUsers[otherUserId] = user
                        }
                    }
                    
                    // Get unread count
                    // FIXED: Changed from getUnreadMessageCount to getUnreadCount
                    if let matchId = match.id {
                        do {
                            let count = try await messageService.getUnreadCount(
                                matchId: matchId,
                                userId: currentUserId
                            )
                            await MainActor.run {
                                unreadCounts[matchId] = count
                            }
                        } catch {
                            print("Error fetching unread count: \(error)")
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
}

struct MessageRowView: View {
    let match: Match
    let user: User
    let unreadCount: Int
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile image
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 65, height: 65)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 65, height: 65)
                    .overlay {
                        Text(user.fullName.prefix(1))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(user.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
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
                    
                    Spacer()
                    
                    if let lastMessageTime = match.lastMessageTimestamp {
                        Text(timeAgo(from: lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    if match.lastMessageTimestamp != nil {
                        Text("Tap to continue conversation")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Say hi!")
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
                        Text("\(unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5)
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
