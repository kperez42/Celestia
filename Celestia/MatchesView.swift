//
//  MatchesView.swift
//  Celestia
//
//  Enhanced matches view with improved design
//

import SwiftUI

struct MatchesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var matchedUsers: [String: User] = [:]
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom gradient header
                headerView
                
                // Tab picker
                tabPickerView
                
                // Content
                if selectedTab == 0 {
                    matchesTab
                } else {
                    InterestsView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
            .refreshable {
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
                    Text("Matches")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !matchService.matches.isEmpty {
                        Text("\(matchService.matches.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Capsule())
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
            tabButton(title: "Matches", icon: "heart.fill", tag: 0)
            tabButton(title: "Interests", icon: "star.fill", tag: 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tag
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
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
                ForEach(filteredMatches) { match in
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
                    }
                }
            }
            .padding()
            .padding(.top, 8)
        }
    }
    
    private var filteredMatches: [Match] {
        if searchText.isEmpty {
            return matchService.matches
        } else {
            return matchService.matches.filter { match in
                guard let otherUserId = getOtherUserId(match: match),
                      let user = matchedUsers[otherUserId] else {
                    return false
                }
                return user.fullName.lowercased().contains(searchText.lowercased()) ||
                       user.location.lowercased().contains(searchText.lowercased())
            }
        }
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
                
                Text("When you match with someone,\nthey'll appear here")
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

// MARK: - Enhanced Match Card

struct EnhancedMatchCard: View {
    let match: Match
    let user: User
    let currentUserId: String
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            profileImage
            
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
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
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
        .background(Color.white)
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text(timeAgo(from: match.lastMessageTimestamp!))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let unreadCount = match.unreadCount[currentUserId], unreadCount > 0 {
                        unreadBadge(count: unreadCount)
                    }
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
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }
}

#Preview {
    NavigationStack {
        MatchesView()
            .environmentObject(AuthService.shared)
    }
}
