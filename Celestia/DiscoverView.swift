//
//  DiscoverView.swift
//  Celestia
//
//  Browse and discover other users with swipe cards
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = DiscoverViewModel()
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var showingFilters = false
    @State private var showingSendInterest = false
    @State private var selectedUser: User?
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if userService.isLoading && userService.users.isEmpty {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else if userService.users.isEmpty {
                        emptyStateView
                    } else {
                        // Card stack
                        ZStack {
                            ForEach(Array(userService.users.prefix(3).enumerated()), id: \.element.id) { index, user in
                                UserCardSwipeView(user: user, index: index) { action in
                                    handleSwipeAction(user: user, action: action)
                                }
                                .zIndex(Double(userService.users.count - index))
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Action buttons
                        HStack(spacing: 30) {
                            // Pass button
                            Button {
                                if let firstUser = userService.users.first {
                                    withAnimation(.spring()) {
                                        userService.users.removeFirst()
                                    }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                            
                            // Send interest with message
                            Button {
                                if let firstUser = userService.users.first {
                                    selectedUser = firstUser
                                    showingSendInterest = true
                                }
                            } label: {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                            
                            // Like button
                            Button {
                                if let firstUser = userService.users.first {
                                    handleSwipeAction(user: firstUser, action: .like)
                                }
                            } label: {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .purple.opacity(0.4), radius: 10)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView()
            }
            .sheet(item: $selectedUser) { user in
                SendInterestView(user: user, showSuccess: $showSuccessMessage)
            }
            .overlay(alignment: .top) {
                if showSuccessMessage {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                guard let currentUser = authService.currentUser else { return }
                do {
                    try await userService.fetchUsers(
                        excludingUserId: currentUser.id ?? "",
                        lookingFor: currentUser.lookingFor == "Everyone" ? nil : currentUser.lookingFor,
                        ageRange: currentUser.ageRangeMin...currentUser.ageRangeMax
                    )
                } catch {
                    print("Error loading users: \(error)")
                }
            }
            .onChange(of: showSuccessMessage) { newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSuccessMessage = false
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No users found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button {
                showingFilters = true
            } label: {
                Text("Open Filters")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Interest sent! 💫")
                .font(.headline)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 10)
        .padding(.top, 10)
    }
    
    private func handleSwipeAction(user: User, action: SwipeAction) {
        guard let currentUserId = authService.currentUser?.id else { return }
        guard let userId = user.id else { return }
        
        switch action {
        case .like:
            Task {
                do {
                    try await interestService.sendInterest(
                        fromUserId: currentUserId,
                        toUserId: userId
                    )
                    
                    await MainActor.run {
                        withAnimation(.spring()) {
                            if let index = userService.users.firstIndex(where: { $0.id == user.id }) {
                                userService.users.remove(at: index)
                            }
                        }
                    }
                } catch {
                    print("Error sending interest: \(error)")
                }
            }
        case .pass:
            withAnimation(.spring()) {
                if let index = userService.users.firstIndex(where: { $0.id == user.id }) {
                    userService.users.remove(at: index)
                }
            }
        }
    }
}

// MARK: - User Card Swipe View
struct UserCardSwipeView: View {
    let user: User
    let index: Int
    let onSwipe: (SwipeAction) -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    var body: some View {
        NavigationLink(destination: UserDetailView(user: user)) {
            ZStack(alignment: .topLeading) {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 10)
                
                VStack(spacing: 0) {
                    // Profile image
                    ZStack(alignment: .topTrailing) {
                        if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        } else {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                        }
                        
                        // Verified badge
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(12)
                        }
                    }
                    .frame(height: 450)
                    .clipped()
                    
                    // User info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(user.fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("\(user.age)")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.purple, Color.blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Text("\(user.location), \(user.country)")
                                        .foregroundColor(.gray)
                                }
                                .font(.subheadline)
                            }
                            
                            Spacer()
                        }
                        
                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // Tags
                        if !user.interests.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(user.interests.prefix(3), id: \.self) { interest in
                                        Text(interest)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.purple, Color.blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                
                // Swipe indicators
                if offset.width > 50 {
                    Text("LIKE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding()
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.green, lineWidth: 3)
                        }
                        .rotationEffect(.degrees(-20))
                        .padding(30)
                } else if offset.width < -50 {
                    Text("PASS")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding()
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.red, lineWidth: 3)
                        }
                        .rotationEffect(.degrees(20))
                        .padding(30)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .cornerRadius(20)
            .offset(x: offset.width, y: offset.height * 0.4)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(index == 0 ? 1.0 : 0.95 - Double(index) * 0.05)
            .opacity(index == 0 ? 1.0 : 0.7)
            .gesture(
                index == 0 ?
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                        rotation = Double(gesture.translation.width / 20)
                    }
                    .onEnded { gesture in
                        if abs(gesture.translation.width) > 100 {
                            let direction: SwipeAction = gesture.translation.width > 0 ? .like : .pass
                            withAnimation(.spring()) {
                                offset = CGSize(width: gesture.translation.width > 0 ? 500 : -500, height: 0)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipe(direction)
                                offset = .zero
                                rotation = 0
                            }
                        } else {
                            withAnimation(.spring()) {
                                offset = .zero
                                rotation = 0
                            }
                        }
                    }
                : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 600)
        .padding(.horizontal)
    }
}

enum SwipeAction {
    case like, pass
}

#Preview {
    NavigationStack {
        DiscoverView()
            .environmentObject(AuthService.shared)
    }
}
