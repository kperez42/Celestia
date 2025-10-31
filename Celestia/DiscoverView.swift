//
//  DiscoverView.swift
//  Celestia
//
//  Enhanced discover view with real user integration
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = DiscoverViewModel()
    @StateObject private var userService = UserService.shared
    @StateObject private var interestService = InterestService.shared
    
    @State private var currentIndex = 0
    @State private var showingUserDetail = false
    @State private var selectedUser: User?
    @State private var showingMatchAlert = false
    @State private var matchedUser: User?
    @State private var showingSuccess = false
    @State private var showingSendInterest = false
    @State private var successMessage = ""
    
    // Real users from Firestore
    @State private var users: [User] = []
    @State private var isLoadingUsers = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    if isLoadingUsers {
                        loadingView
                    } else if users.isEmpty || currentIndex >= users.count {
                        emptyStateView
                    } else {
                        cardStackView
                        actionButtonsView
                    }
                }
                
                if showingSuccess {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showingUserDetail) {
                if let user = selectedUser {
                    UserDetailSheet(user: user, onSendInterest: {
                        showingUserDetail = false
                        showingSendInterest = true
                    })
                }
            }
            .sheet(isPresented: $showingSendInterest) {
                if let user = selectedUser {
                    SendInterestView(user: user, showSuccess: $showingSuccess)
                }
            }
            .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
                Button("Send Message") {
                    // Navigate to chat with matched user
                }
                Button("Keep Browsing", role: .cancel) {}
            } message: {
                if let matchedUser = matchedUser {
                    Text("You and \(matchedUser.fullName) liked each other!")
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Finding people near you...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var cardStackView: some View {
        ZStack {
            ForEach(Array(users.enumerated().filter { 
                $0.offset >= currentIndex && $0.offset < currentIndex + 3 
            }), id: \.element.id) { index, user in
                UserCardSwipeView(
                    user: user,
                    onSwipe: { direction in
                        handleSwipe(direction: direction, user: user)
                    },
                    onTap: {
                        selectedUser = user
                        showingUserDetail = true
                    }
                )
                .offset(y: CGFloat((index - currentIndex) * 8))
                .scaleEffect(1.0 - CGFloat(index - currentIndex) * 0.05)
                .zIndex(Double(users.count - index))
                .opacity(index == currentIndex ? 1 : 0.7)
                .allowsHitTesting(index == currentIndex)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 25) {
            ActionButton(
                icon: "xmark",
                color: .red,
                size: 60,
                action: { handleSwipeAction(.pass) }
            )
            
            ActionButton(
                icon: "star.fill",
                gradient: [.blue, .cyan],
                size: 60,
                action: {
                    if currentIndex < users.count {
                        selectedUser = users[currentIndex]
                        showingUserDetail = true
                    }
                }
            )
            
            ActionButton(
                icon: "heart.fill",
                gradient: [.green, .mint],
                size: 70,
                action: { handleSwipeAction(.like) }
            )
        }
        .padding(.bottom, 100)
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
            
            Text("Check back later for new people")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await loadUsers() }
            } label: {
                Text("Reload Profiles")
                    .fontWeight(.semibold)
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
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text(successMessage.isEmpty ? "Liked!" : successMessage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 10)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 60)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSuccess = false
                    successMessage = ""
                }
            }
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task { await loadUsers() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    // MARK: - Actions
    
    private func handleSwipe(direction: SwipeDirection, user: User) {
        let action: SwipeAction = direction == .right ? .like : .pass
        
        if action == .like {
            Task {
                await sendLike(to: user)
            }
        }
        
        advanceToNextUser()
    }
    
    private func handleSwipeAction(_ action: SwipeAction) {
        guard currentIndex < users.count else { return }
        let user = users[currentIndex]
        
        if action == .like {
            Task {
                await sendLike(to: user)
            }
        }
        
        advanceToNextUser()
    }
    
    private func advanceToNextUser() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentIndex < users.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = users.count
            }
        }
    }
    
    private func sendLike(to user: User) async {
        guard let currentUserId = authService.currentUser?.id,
              let targetUserId = user.id else { return }
        
        do {
            // Check for mutual match
            let isMutual = try await interestService.checkForMutualMatch(
                userId1: currentUserId,
                userId2: targetUserId
            )
            
            if isMutual {
                // It's a match!
                await MainActor.run {
                    matchedUser = user
                    successMessage = "It's a Match! 🎉"
                    showingSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingMatchAlert = true
                    }
                }
            } else {
                // Just send interest
                try await interestService.sendInterest(
                    fromUserId: currentUserId,
                    toUserId: targetUserId
                )
                
                await MainActor.run {
                    successMessage = "Interest sent!"
                    showingSuccess = true
                }
            }
        } catch {
            print("Error sending like: \(error)")
        }
    }
    
    private func loadUsers() async {
        guard let currentUser = authService.currentUser else { return }
        
        await MainActor.run {
            isLoadingUsers = true
            currentIndex = 0
        }
        
        do {
            try await userService.fetchUsers(
                excludingUserId: currentUser.id ?? "",
                lookingFor: currentUser.lookingFor == "Everyone" ? nil : currentUser.lookingFor,
                ageRange: currentUser.ageRangeMin...currentUser.ageRangeMax,
                limit: 20,
                reset: true
            )
            
            await MainActor.run {
                users = userService.users
                isLoadingUsers = false
            }
        } catch {
            print("Error loading users: \(error)")
            await MainActor.run {
                isLoadingUsers = false
                // Load test data as fallback
                users = generateTestUsers()
            }
        }
    }
    
    private func generateTestUsers() -> [User] {
        [
            User(
                id: "test1",
                email: "sofia@test.com",
                fullName: "Sofia Martinez",
                age: 24,
                gender: "Female",
                lookingFor: "Male",
                bio: "Adventure seeker 🌍 | Coffee addict ☕ | Love exploring new cultures and trying exotic foods",
                location: "Barcelona",
                country: "Spain",
                languages: ["Spanish", "English", "French"],
                interests: ["Travel", "Photography", "Food", "Music"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test2",
                email: "yuki@test.com",
                fullName: "Yuki Tanaka",
                age: 26,
                gender: "Female",
                lookingFor: "Everyone",
                bio: "Digital artist 🎨 | Anime lover | Creating worlds one pixel at a time",
                location: "Tokyo",
                country: "Japan",
                languages: ["Japanese", "English"],
                interests: ["Art", "Anime", "Gaming", "Design"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test3",
                email: "marco@test.com",
                fullName: "Marco Rossi",
                age: 28,
                gender: "Male",
                lookingFor: "Female",
                bio: "Chef by passion 👨‍🍳 | Wine connoisseur 🍷 | Love making homemade pasta",
                location: "Rome",
                country: "Italy",
                languages: ["Italian", "English", "Spanish"],
                interests: ["Cooking", "Wine", "Food", "Travel"],
                profileImageURL: "",
                isVerified: false
            ),
            User(
                id: "test4",
                email: "marcus@test.com",
                fullName: "Marcus Johnson",
                age: 29,
                gender: "Male",
                lookingFor: "Female",
                bio: "Personal trainer 💪 | Marathon runner | Plant-based lifestyle 🌱",
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
                bio: "Fashion designer ✨ | Wine enthusiast 🍷 | Love art galleries",
                location: "Paris",
                country: "France",
                languages: ["French", "English", "Italian"],
                interests: ["Fashion", "Art", "Wine", "Travel"],
                profileImageURL: "",
                isVerified: false
            ),
            User(
                id: "test6",
                email: "alex@test.com",
                fullName: "Alex Chen",
                age: 27,
                gender: "Male",
                lookingFor: "Female",
                bio: "Software engineer 💻 | Rock climber 🧗 | Coffee enthusiast",
                location: "San Francisco",
                country: "USA",
                languages: ["English", "Chinese"],
                interests: ["Tech", "Climbing", "Coffee", "Travel"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test7",
                email: "luna@test.com",
                fullName: "Luna Silva",
                age: 23,
                gender: "Female",
                lookingFor: "Everyone",
                bio: "Yoga instructor 🧘‍♀️ | Beach lover 🏖️ | Sunset chaser",
                location: "Rio de Janeiro",
                country: "Brazil",
                languages: ["Portuguese", "English", "Spanish"],
                interests: ["Yoga", "Surfing", "Nature", "Music"],
                profileImageURL: "",
                isVerified: true
            ),
            User(
                id: "test8",
                email: "oliver@test.com",
                fullName: "Oliver Schmidt",
                age: 30,
                gender: "Male",
                lookingFor: "Female",
                bio: "Architect 🏛️ | History buff | Love exploring old cities",
                location: "Berlin",
                country: "Germany",
                languages: ["German", "English", "French"],
                interests: ["Architecture", "History", "Travel", "Photography"],
                profileImageURL: "",
                isVerified: false
            )
        ]
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    var color: Color?
    var gradient: [Color]?
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(size > 65 ? .title : .title2)
                .fontWeight(.bold)
                .foregroundColor(color != nil ? color : .white)
                .frame(width: size, height: size)
                .background(
                    Group {
                        if let color = color {
                            Circle().fill(color == .red ? Color.white : color)
                        } else if let gradient = gradient {
                            Circle().fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }
                    }
                )
                .clipShape(Circle())
                .shadow(
                    color: (color ?? gradient?.first ?? .gray).opacity(0.3),
                    radius: 8
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - User Card Swipe View

struct UserCardSwipeView: View {
    let user: User
    let onSwipe: (SwipeDirection) -> Void
    let onTap: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var isDragging = false
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    profileImageView
                        .frame(height: 450)
                    
                    if user.isVerified {
                        verifiedBadge
                    }
                }
                
                profileInfoSection
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1), radius: isDragging ? 20 : 10)
            
            swipeOverlay
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(swipeGesture)
    }
    
    private var profileImageView: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 15) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(user.fullName.prefix(1))
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.white)
                }
            }
    }
    
    private var verifiedBadge: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.title2)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(12)
            .background(Color.white.opacity(0.9))
            .clipShape(Circle())
            .padding(8)
    }
    
    private var profileInfoSection: some View {
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
                
                Button(action: onTap) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if !user.interests.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(user.interests.prefix(4), id: \.self) { interest in
                            InterestTag(text: interest)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    private var swipeOverlay: some View {
        ZStack {
            if offset.width < -30 {
                SwipeLabel(text: "PASS", color: .red, rotation: -20)
                    .opacity(min(Double(-offset.width / 100), 1.0))
                    .offset(x: -100, y: -200)
            }
            
            if offset.width > 30 {
                SwipeLabel(text: "LIKE", color: .green, rotation: 20)
                    .opacity(min(Double(offset.width / 100), 1.0))
                    .offset(x: 100, y: -200)
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                isDragging = true
                offset = gesture.translation
                rotation = Double(gesture.translation.width / 20)
            }
            .onEnded { gesture in
                isDragging = false
                let horizontalMovement = gesture.translation.width
                
                if abs(horizontalMovement) > swipeThreshold {
                    let direction: SwipeDirection = horizontalMovement > 0 ? .right : .left
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        offset = CGSize(
                            width: horizontalMovement > 0 ? 500 : -500,
                            height: gesture.translation.height
                        )
                        rotation = horizontalMovement > 0 ? 20 : -20
                    }
                    
                    onSwipe(direction)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }
}

// MARK: - Supporting Components

struct InterestTag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
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

struct SwipeLabel: View {
    let text: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        Text(text)
            .font(.system(size: 48, weight: .heavy))
            .foregroundColor(color)
            .padding(20)
            .background(Color.white.opacity(0.95))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 5)
            )
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - User Detail Sheet

struct UserDetailSheet: View {
    let user: User
    let onSendInterest: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    profileDetails
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSendInterest()
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 400)
            .overlay {
                VStack(spacing: 15) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(user.fullName.prefix(1))
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white)
                }
            }
    }
    
    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Text(user.fullName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(user.age)")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(user.location), \(user.country)")
                    .foregroundColor(.gray)
            }
            
            if !user.bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text(user.bio)
                        .foregroundColor(.secondary)
                }
            }
            
            if !user.languages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Languages")
                        .font(.headline)
                    FlowLayout2(spacing: 8) {
                        ForEach(user.languages, id: \.self) { language in
                            Text(language)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            if !user.interests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.headline)
                    FlowLayout2(spacing: 8) {
                        ForEach(user.interests, id: \.self) { interest in
                            Text(interest)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Flow Layout

struct FlowLayout2: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.frames[index].minX,
                    y: bounds.minY + result.frames[index].minY
                ),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Enums & Styles

enum SwipeDirection {
    case left, right
}

enum SwipeAction {
    case like, pass
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiscoverView()
            .environmentObject(AuthService.shared)
    }
}
