//
//  InterestsView.swift
//  Celestia
//

import SwiftUI

struct InterestsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var interestService = InterestService.shared
    @StateObject private var userService = UserService.shared
    
    @State private var users: [String: User] = [:]
    @State private var showMatchAnimation = false
    @State private var matchedUser: User?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Content
                    if interestService.isLoading {
                        loadingView
                    } else if interestService.receivedInterests.isEmpty {
                        emptyStateView
                    } else {
                        interestsGrid
                    }
                }
                
                // Match animation
                if showMatchAnimation {
                    matchCelebrationView
                }
            }
            .navigationTitle("Interests")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("People Who Liked You")
                    .font(.headline)
                
                Text("\(interestService.receivedInterests.count) interested")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !(authService.currentUser?.isPremium ?? false) {
                Text("👑 Premium")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Interests Grid
    
    private var interestsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(interestService.receivedInterests) { interest in
                    if let user = users[interest.fromUserId] {
                        InterestCard(
                            interest: interest,
                            user: user,
                            isBlurred: !(authService.currentUser?.isPremium ?? false),
                            onAccept: {
                                acceptInterest(interest)
                            },
                            onReject: {
                                rejectInterest(interest)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Loading interests...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)

                // Show skeleton grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        MatchCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("No Interests Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("People who like you will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Match Animation
    
    private var matchCelebrationView: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                
                Text("It's a Match! 🎉")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let user = matchedUser {
                    Text("You and \(user.fullName) liked each other!")
                        .font(.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                
                Button("Send Message") {
                    showMatchAnimation = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                
                Button("Keep Browsing") {
                    showMatchAnimation = false
                }
                .foregroundColor(.white)
            }
            .padding(40)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadData() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await interestService.fetchReceivedInterests(userId: userId)
            
            for interest in interestService.receivedInterests {
                if users[interest.fromUserId] == nil {
                    if let user = try await userService.fetchUser(userId: interest.fromUserId) {
                        await MainActor.run {
                            users[interest.fromUserId] = user
                        }
                    }
                }
            }
        } catch {
            print("Error loading interests: \(error)")
        }
    }
    
    private func acceptInterest(_ interest: Interest) {
        guard let interestId = interest.id else { return }
        
        Task {
            do {
                try await interestService.acceptInterest(
                    interestId: interestId,
                    fromUserId: interest.fromUserId,
                    toUserId: interest.toUserId
                )
                
                await MainActor.run {
                    matchedUser = users[interest.fromUserId]
                    showMatchAnimation = true
                }
                
                await loadData()
            } catch {
                print("Error accepting interest: \(error)")
            }
        }
    }
    
    private func rejectInterest(_ interest: Interest) {
        guard let interestId = interest.id else { return }
        
        Task {
            do {
                try await interestService.rejectInterest(interestId: interestId)
                await loadData()
            } catch {
                print("Error rejecting interest: \(error)")
            }
        }
    }
}

// MARK: - Interest Card

struct InterestCard: View {
    let interest: Interest
    let user: User
    let isBlurred: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // User image
            AsyncImage(url: URL(string: user.profileImageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_), .empty:
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                @unknown default:
                    Color.gray
                }
            }
            .frame(height: 180)
            .clipped()
            .blur(radius: isBlurred ? 20 : 0)
            
            // User info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isBlurred ? "Premium User" : user.fullName)
                        .font(.headline)
                    
                    if !isBlurred {
                        Text("\(user.age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if !isBlurred {
                    Text("\(user.location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let message = interest.message {
                        Text("💬 \(message)")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .lineLimit(2)
                    }
                }
                
                // Action buttons
                if !isBlurred {
                    HStack(spacing: 8) {
                        Button(action: onReject) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button(action: onAccept) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
    }
}

#Preview {
    InterestsView()
        .environmentObject(AuthService.shared)
}
