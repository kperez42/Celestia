//
//  MatchesView.swift
//  Celestia
//
//  View showing actual matches and received interests
//

import SwiftUI

struct MatchesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab picker
                Picker("", selection: $selectedTab) {
                    Text("Matches").tag(0)
                    Text("Interests").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    matchesTab
                } else {
                    InterestsView()
                }
            }
            .navigationTitle("Matches")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
        }
    }
    
    private var matchesTab: some View {
        Group {
            if matchService.isLoading && matchService.matches.isEmpty {
                ProgressView()
                    .padding(.top, 100)
            } else if matchService.matches.isEmpty {
                emptyMatchesView
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(matchService.matches) { match in
                            if let otherUserId = getOtherUserId(match: match),
                               let user = matchedUsers[otherUserId] {
                                NavigationLink(destination: ChatView(match: match, otherUser: user)) {
                                    MatchCardView(match: match, user: user)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var emptyMatchesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No matches yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("When you match with someone,\nthey'll appear here")
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
            
            // Load user details for each match
            for match in matchService.matches {
                if let otherUserId = getOtherUserId(match: match) {
                    if let user = try await userService.fetchUser(userId: otherUserId) {
                        await MainActor.run {
                            matchedUsers[otherUserId] = user
                        }
                    }
                }
            }
        } catch {
            print("Error loading matches: \(error)")
        }
    }
    
    private func getOtherUserId(match: Match) -> String? {
        guard let currentUserId = authService.currentUser?.id else { return nil }
        return match.user1Id == currentUserId ? match.user2Id : match.user1Id
    }
}

struct MatchCardView: View {
    let match: Match
    let user: User
    
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
                .frame(width: 70, height: 70)
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
                    .frame(width: 70, height: 70)
                    .overlay {
                        Text(user.fullName.prefix(1))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(user.fullName)
                        .font(.headline)
                    
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
                
                Text("\(user.age) • \(user.location)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let lastMessageTime = match.lastMessageTimestamp {
                    Text(timeAgo(from: lastMessageTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("New match!")
                            .font(.caption)
                    }
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
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    NavigationStack {
        MatchesView()
            .environmentObject(AuthService.shared)
    }
}
