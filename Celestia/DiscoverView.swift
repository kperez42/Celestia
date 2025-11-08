//
//  DiscoverView.swift
//  Celestia
//

import SwiftUI

struct SwipeAction {
    let user: User
    let index: Int
    let wasLike: Bool
}

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userService = UserService.shared
    @StateObject private var matchService = MatchService.shared

    @State private var currentIndex = 0
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingMatchAnimation = false
    @State private var matchedUser: User?
    @State private var swipeHistory: [SwipeAction] = []
    @State private var showUndoButton = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Main content
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if users.isEmpty || currentIndex >= users.count {
                        emptyStateView
                    } else {
                        cardStackView
                    }
                }
                
                // Match animation
                if showingMatchAnimation {
                    matchCelebrationView
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadUsers()
            }
            .refreshable {
                await loadUsers()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Discover")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if !users.isEmpty {
                    Text("\(users.count - currentIndex) people nearby")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                // Filters
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Card Stack

    private var cardStackView: some View {
        ZStack {
            ForEach(Array(users.enumerated().filter { $0.offset >= currentIndex && $0.offset < currentIndex + 3 }), id: \.offset) { index, user in
                let cardIndex = index - currentIndex

                UserCardView(user: user)
                    .padding(.horizontal, 16)
                    .padding(.top, 16) // Reduce card height from top
                    .padding(.bottom, 180) // Increased space for buttons and tab bar
                    .offset(y: CGFloat(cardIndex * 8))
                    .scaleEffect(1.0 - CGFloat(cardIndex) * 0.05)
                    .opacity(1.0 - Double(cardIndex) * 0.2)
                    .zIndex(Double(3 - cardIndex))
                    .offset(cardIndex == 0 ? dragOffset : .zero)
                    .rotationEffect(.degrees(cardIndex == 0 ? Double(dragOffset.width / 20) : 0))
                    .gesture(
                        cardIndex == 0 ? DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                handleSwipeEnd(value: value, user: user)
                            } : nil
                    )
            }

            // Action buttons overlay
            VStack {
                Spacer()

                HStack(spacing: 24) {
                    // Undo button (premium feature)
                    if showUndoButton && !swipeHistory.isEmpty {
                        Button {
                            handleUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.yellow)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Pass button
                    Button {
                        handlePass()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.9), Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                    }

                    // Super Like button (premium)
                    Button {
                        handleSuperLike()
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                    }

                    // Like button
                    Button {
                        handleLike()
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.9), Color.green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Increased to stay above tab bar
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 80))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("No More Profiles")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Check back later for new people")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                Task {
                    await loadUsers()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
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
                    showingMatchAnimation = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                
                Button("Keep Swiping") {
                    showingMatchAnimation = false
                }
                .foregroundColor(.white)
            }
            .padding(40)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadUsers() async {
        #if DEBUG
        // Use test data in preview/debug mode
        users = TestData.discoverUsers
        currentIndex = 0
        isLoading = false
        #else
        guard let currentUserId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await userService.fetchUsers(
                excludingUserId: currentUserId,
                limit: 20,
                reset: true
            )
            users = userService.users
            currentIndex = 0
        } catch {
            print("Error loading users: \(error)")
        }
        #endif
    }
    
    private func handleSwipeEnd(value: DragGesture.Value, user: User) {
        let threshold: CGFloat = 100
        
        withAnimation {
            if value.translation.width > threshold {
                // Like
                dragOffset = CGSize(width: 500, height: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleLike()
                    dragOffset = .zero
                }
            } else if value.translation.width < -threshold {
                // Pass
                dragOffset = CGSize(width: -500, height: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handlePass()
                    dragOffset = .zero
                }
            } else {
                dragOffset = .zero
            }
        }
    }
    
    private func handleLike(isSuperLike: Bool = false) {
        guard currentIndex < users.count else { return }
        let user = users[currentIndex]

        // Save to history for undo
        swipeHistory.append(SwipeAction(user: user, index: currentIndex, wasLike: true))
        showUndoButton = true

        // Haptic feedback
        if isSuperLike {
            HapticManager.shared.superLike()
        } else {
            HapticManager.shared.swipeRight()
        }

        Task {
            guard let currentUserId = authService.currentUser?.id,
                  let userId = user.id else { return }

            // Check for match
            let hasMatched = try? await matchService.hasMatched(
                user1Id: currentUserId,
                user2Id: userId
            )

            if hasMatched == true {
                await MainActor.run {
                    matchedUser = user
                    showingMatchAnimation = true
                    HapticManager.shared.match()
                }
            }

            await MainActor.run {
                withAnimation {
                    currentIndex += 1
                }
            }
        }
    }

    private func handlePass() {
        guard currentIndex < users.count else { return }
        let user = users[currentIndex]

        // Save to history for undo
        swipeHistory.append(SwipeAction(user: user, index: currentIndex, wasLike: false))
        showUndoButton = true

        // Haptic feedback
        HapticManager.shared.swipeLeft()

        withAnimation {
            currentIndex += 1
        }
    }

    private func handleSuperLike() {
        guard currentIndex < users.count else { return }

        // Check if user is premium
        if authService.currentUser?.isPremium == true {
            handleLike(isSuperLike: true)
        } else {
            // Show premium upgrade prompt
            // For now, just treat as regular like
            handleLike(isSuperLike: false)
        }
    }

    private func handleUndo() {
        guard !swipeHistory.isEmpty else { return }

        // Check if user has premium for unlimited undo, otherwise allow 1 free undo
        let isPremium = authService.currentUser?.isPremium ?? false
        let freeUndoCount = 1

        if isPremium || swipeHistory.count <= freeUndoCount {
            let lastAction = swipeHistory.removeLast()

            withAnimation(.spring(response: 0.3)) {
                currentIndex = lastAction.index
                showUndoButton = !swipeHistory.isEmpty
            }

            HapticManager.shared.impact(.medium)
        }
    }
}

// MARK: - User Card View

struct UserCardView: View {
    let user: User

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 10)

                // User image with caching
                CachedAsyncImage(url: URL(string: user.profileImageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } placeholder: {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }

                // Gradient overlay for better text readability
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .init(x: 0.5, y: 0.6),
                    endPoint: .bottom
                )

                // User info overlay
                VStack(alignment: .leading, spacing: 12) {
                    // Name and age
                    HStack(alignment: .top, spacing: 8) {
                        Text(user.fullName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(user.age)")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }

                        if user.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Spacer()
                    }

                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline)
                        Text(user.location)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)

                    // Bio
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    // Interests preview
                    if !user.interests.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(user.interests.prefix(4), id: \.self) { interest in
                                    Text(interest)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cornerRadius(20)
        }
        .frame(maxHeight: .infinity) // Fill available space
    }
}


#Preview {
    DiscoverView()
        .environmentObject(AuthService.shared)
}
