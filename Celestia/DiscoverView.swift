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
    @StateObject private var viewModel = DiscoverViewModel()
    
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
                    if viewModel.isLoading {
                        // Skeleton loading state
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                CardSkeleton()
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 200)
                                    .offset(y: CGFloat(index * 8))
                                    .scaleEffect(1.0 - CGFloat(index) * 0.05)
                                    .opacity(1.0 - Double(index) * 0.2)
                                    .zIndex(Double(3 - index))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.users.isEmpty || viewModel.currentIndex >= viewModel.users.count {
                        emptyStateView
                    } else {
                        cardStackView
                    }
                }
                
                // Match animation
                if viewModel.showingMatchAnimation {
                    matchCelebrationView
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await viewModel.loadUsers()
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.loadUsers()
                HapticManager.shared.notification(.success)
            }
            .sheet(isPresented: $viewModel.showingUserDetail) {
                if let user = viewModel.selectedUser {
                    UserDetailView(user: user)
                }
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                DiscoverFiltersView()
            }
            .sheet(isPresented: $viewModel.showingUpgradeSheet) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
            .onChange(of: viewModel.hasActiveFilters) { _ in
                viewModel.applyFilters()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Discover")
                    .font(.system(size: 36, weight: .bold))

                if !viewModel.users.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(viewModel.remainingCount) people")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if viewModel.hasActiveFilters {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }

            Spacer()

            // Shuffle button
            Button {
                viewModel.shuffleUsers()
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, 8)

            // Filter button
            Button {
                viewModel.showFilters()
                HapticManager.shared.impact(.light)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.purple)

                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Card Stack

    private var cardStackView: some View {
        ZStack {
            // Card stack layer (lower z-index)
            ZStack {
                ForEach(Array(viewModel.users.enumerated().filter { $0.offset >= viewModel.currentIndex && $0.offset < viewModel.currentIndex + 3 }), id: \.offset) { index, user in
                    let cardIndex = index - viewModel.currentIndex

                    UserCardView(user: user)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 200) // Space for buttons and tab bar
                        .offset(y: CGFloat(cardIndex * 8))
                        .scaleEffect(1.0 - CGFloat(cardIndex) * 0.05)
                        .opacity(1.0 - Double(cardIndex) * 0.2)
                        .zIndex(Double(3 - cardIndex))
                        .offset(cardIndex == 0 ? viewModel.dragOffset : .zero)
                        .rotationEffect(.degrees(cardIndex == 0 ? Double(viewModel.dragOffset.width / 20) : 0))
                        .contentShape(Rectangle()) // Define tappable area
                        .onTapGesture {
                            if cardIndex == 0 {
                                viewModel.showUserDetail(user)
                            }
                        }
                        .gesture(
                            cardIndex == 0 ? DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    viewModel.dragOffset = value.translation
                                }
                                .onEnded { value in
                                    viewModel.handleSwipeEnd(value: value)
                                } : nil
                        )
                }
            }
            .zIndex(0)

            // Action buttons overlay - Separate layer with higher z-index
            VStack {
                Spacer()

                // Button container with explicit hit testing
                HStack(spacing: 24) {
                    // Pass button
                    SwipeActionButton(
                        icon: "xmark",
                        iconSize: .title,
                        iconWeight: .bold,
                        size: 68,
                        colors: [Color.red.opacity(0.9), Color.red],
                        shadowColor: .red.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task { await viewModel.handlePass() }
                    }
                    .disabled(viewModel.isProcessingAction)

                    // Super Like button
                    SwipeActionButton(
                        icon: "star.fill",
                        iconSize: .title2,
                        iconWeight: .semibold,
                        size: 60,
                        colors: [Color.blue, Color.cyan],
                        shadowColor: .blue.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task { await viewModel.handleSuperLike() }
                    }
                    .disabled(viewModel.isProcessingAction)

                    // Like button
                    SwipeActionButton(
                        icon: "heart.fill",
                        iconSize: .title,
                        iconWeight: .bold,
                        size: 68,
                        colors: [Color.green.opacity(0.9), Color.green],
                        shadowColor: .green.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task { await viewModel.handleLike() }
                    }
                    .disabled(viewModel.isProcessingAction)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Stay above tab bar and safe area
                .frame(maxWidth: .infinity)
            }
            .zIndex(100) // Ensure buttons are always on top
            .allowsHitTesting(true) // Explicitly enable hit testing for buttons
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "person.2.slash")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text(viewModel.hasActiveFilters ? "No Matches Found" : "No More Profiles")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.hasActiveFilters ?
                     "Try adjusting your filters to see more people" :
                     "Check back later for new people nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                if viewModel.hasActiveFilters {
                    Button {
                        HapticManager.shared.impact(.medium)
                        viewModel.resetFilters()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body.weight(.semibold))
                            Text("Clear Filters")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleEffect: 0.96))
                    .padding(.horizontal, 40)
                }

                Button {
                    HapticManager.shared.impact(.light)
                    Task {
                        await viewModel.loadUsers()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                        Text("Refresh")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.purple)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scaleEffect: 0.96))
                .padding(.horizontal, 40)
            }

            Spacer()
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

                if let user = viewModel.matchedUser {
                    Text("You and \(user.fullName) liked each other!")
                        .font(.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Button("Send Message") {
                    viewModel.dismissMatchAnimation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                Button("Keep Swiping") {
                    viewModel.dismissMatchAnimation()
                }
                .foregroundColor(.white)
            }
            .padding(40)
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
                AsyncImage(url: URL(string: user.profileImageURL)) { image in
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
                .allowsHitTesting(false) // Allow touches to pass through to buttons below

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

// MARK: - Swipe Action Button Component

/// Reusable button component for swipe actions with improved touch handling
struct SwipeActionButton: View {
    let icon: String
    let iconSize: Font
    let iconWeight: Font.Weight
    let size: CGFloat
    let colors: [Color]
    let shadowColor: Color
    let isProcessing: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            ZStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: icon)
                        .font(iconSize)
                        .fontWeight(iconWeight)
                        .foregroundColor(.white)
                }
            }
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isProcessing ? 0.7 : 1.0)
            )
            .clipShape(Circle())
            .shadow(color: shadowColor, radius: isPressed ? 4 : 8, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .contentShape(Circle()) // Ensure full circle is tappable
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
        .opacity(isProcessing ? 0.6 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        // Ensure minimum tap target size (44x44 points)
        .frame(minWidth: max(size, 44), minHeight: max(size, 44))
    }
}


#Preview {
    DiscoverView()
        .environmentObject(AuthService.shared)
}
