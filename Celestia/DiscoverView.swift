//
//  DiscoverView.swift
//  Celestia
//
//  Enhanced discovery view with swipe cards and test dummies
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var showingFilters = false
    @State private var showingUserDetail = false
    @State private var selectedUser: User?
    @State private var showingSendInterest = false
    @State private var showingMatchAlert = false
    @State private var showingInterestSent = false
    
    // For testing - remove these when connecting to real Firebase
    @State private var testUsers: [User] = []
    @State private var useTestData = true // Set to false when using real data
    
    var displayUsers: [User] {
        useTestData ? testUsers : userService.users
    }
    
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
                    if displayUsers.isEmpty {
                        emptyStateView
                    } else {
                        // Card stack
                        ZStack {
                            ForEach(Array(displayUsers.prefix(3).enumerated()), id: \.element.id) { index, user in
                                UserCardSwipeView(user: user)
                                    .offset(y: CGFloat(index * 8))
                                    .scaleEffect(1.0 - CGFloat(index) * 0.05)
                                    .zIndex(Double(displayUsers.count - index))
                                    .opacity(index == 0 ? 1 : 0.8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        
                        // Action buttons
                        HStack(spacing: 25) {
                            // Pass button
                            Button {
                                handleSwipeAction(user: displayUsers.first!, action: .pass)
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
                                if let firstUser = displayUsers.first {
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
                                if let firstUser = displayUsers.first {
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
                        .padding(.bottom, 40)
                    }
                }
                
                // Success banner
                if showingInterestSent {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                if showingSendInterest {
                    SendInterestView(user: user, showSuccess: $showingInterestSent)
                } else {
                    UserDetailView(user: user)
                }
            }
            .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
                Button("Send Message") {
                    // Navigate to messages
                }
                Button("Keep Browsing", role: .cancel) { }
            } message: {
                Text("You both liked each other!")
            }
            .onAppear {
                if useTestData {
                    loadTestUsers()
                } else {
                    loadRealUsers()
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
            
            Text("No more profiles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters to see more people")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
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
        .padding(.top, 50)
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Interest Sent!")
                    .font(.headline)
                Text("We'll let you know if they're interested")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 10)
        .padding()
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showingInterestSent = false
                }
            }
        }
    }
    
    private func handleSwipeAction(user: User, action: SwipeAction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if useTestData {
                testUsers.removeFirst()
            } else {
                userService.users.removeFirst()
            }
        }
        
        if action == .like {
            // Send interest
            guard let currentUserId = authService.currentUser?.id,
                  let targetUserId = user.id else { return }
            
            Task {
                do {
                    try await interestService.sendInterest(
                        fromUserId: currentUserId,
                        toUserId: targetUserId
                    )
                    
                    // Check if it's a match
                    if let match = try? await interestService.checkForMutualMatch(
                        userId1: currentUserId,
                        userId2: targetUserId
                    ), match {
                        await MainActor.run {
                            showingMatchAlert = true
                        }
                    } else {
                        await MainActor.run {
                            showingInterestSent = true
                        }
                    }
                } catch {
                    print("Error sending interest: \(error)")
                }
            }
        }
    }
    
    private func loadRealUsers() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                // Create proper age range from optional values
                let minAge = authService.currentUser?.ageRangeMin ?? 18
                let maxAge = authService.currentUser?.ageRangeMax ?? 99
                let ageRange = minAge...maxAge
                
                try await userService.fetchUsers(
                    excludingUserId: currentUserId,
                    lookingFor: authService.currentUser?.lookingFor,
                    ageRange: ageRange
                )
            } catch {
                print("Error loading users: \(error)")
            }
        }
    }
    
    // MARK: - Test Data
    private func loadTestUsers() {
        testUsers = [
            User(
                id: "test1",
                email: "sofia@test.com",
                fullName: "Sofia Martinez",
                age: 24,
                gender: "Female",
                lookingFor: "Male",
                bio: "Adventure seeker 🌍 | Love trying new cuisines | Fluent in Spanish & English | Looking for someone to explore the world with!",
                location: "Barcelona",
                country: "Spain",
                languages: ["Spanish", "English", "Catalan"],
                interests: ["Travel", "Cooking", "Yoga", "Photography"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test2",
                email: "liam@test.com",
                fullName: "Liam O'Connor",
                age: 27,
                gender: "Male",
                lookingFor: "Female",
                bio: "Software engineer by day, guitarist by night 🎸 | Coffee enthusiast ☕️ | Love hiking and indie music",
                location: "Dublin",
                country: "Ireland",
                languages: ["English", "Irish"],
                interests: ["Music", "Hiking", "Technology", "Coffee"],
                profileImageURL: "",
                isVerified: false
            ),
            User(
                id: "test3",
                email: "yuki@test.com",
                fullName: "Yuki Tanaka",
                age: 26,
                gender: "Female",
                lookingFor: "Everyone",
                bio: "Anime lover 🎌 | Digital artist | Foodie who loves ramen & sushi 🍜 | Let's explore Tokyo together!",
                location: "Tokyo",
                country: "Japan",
                languages: ["Japanese", "English"],
                interests: ["Art", "Anime", "Food", "Design"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test4",
                email: "marcus@test.com",
                fullName: "Marcus Johnson",
                age: 29,
                gender: "Male",
                lookingFor: "Female",
                bio: "Personal trainer 💪 | Marathon runner | Plant-based lifestyle 🌱 | Looking for someone who shares my passion for fitness",
                location: "Los Angeles",
                country: "USA",
                languages: ["English"],
                interests: ["Fitness", "Running", "Nutrition", "Cooking"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test5",
                email: "emma@test.com",
                fullName: "Emma Dubois",
                age: 25,
                gender: "Female",
                lookingFor: "Male",
                bio: "Fashion designer ✨ | Wine enthusiast 🍷 | Love art galleries and weekend getaways | Seeking someone cultured and fun",
                location: "Paris",
                country: "France",
                languages: ["French", "English", "Italian"],
                interests: ["Fashion", "Art", "Wine", "Travel"],
                profileImageURL: "",
                isVerified: false
            )
        ]
    }
}

// MARK: - User Card Swipe View
struct UserCardSwipeView: View {
    let user: User
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Card content
            VStack(spacing: 0) {
                // Image
                ZStack(alignment: .topTrailing) {
                    if !user.profileImageURL.isEmpty, let imageURL = URL(string: user.profileImageURL) {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 450)
                        .clipped()
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
                            .frame(height: 450)
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
                
                // Info section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
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
                    
                    // Bio
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
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
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                    rotation = Double(gesture.translation.width / 20)
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        offset = .zero
                        rotation = 0
                    }
                }
        )
    }
}

enum SwipeAction {
    case like
    case pass
}

#Preview {
    NavigationStack {
        DiscoverView()
            .environmentObject(AuthService.shared)
    }
}
