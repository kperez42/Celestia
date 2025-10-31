//
//  DiscoverView.swift
//  Celestia
//
//  Standalone discover view - works without external services
//

import SwiftUI

struct DiscoverView: View {
    @State private var testUsers: [User] = []
    @State private var currentIndex = 0
    @State private var showingUserDetail = false
    @State private var selectedUser: User?
    @State private var showingMatchAlert = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if testUsers.isEmpty || currentIndex >= testUsers.count {
                        emptyStateView
                    } else {
                        ZStack {
                            ForEach(Array(testUsers.enumerated().filter { $0.offset >= currentIndex && $0.offset < currentIndex + 3 }), id: \.element.id) { index, user in
                                UserCardSwipeView(
                                    user: user,
                                    onSwipe: { direction in
                                        handleSwipe(direction: direction)
                                    },
                                    onTap: {
                                        selectedUser = user
                                        showingUserDetail = true
                                    }
                                )
                                .offset(y: CGFloat((index - currentIndex) * 8))
                                .scaleEffect(1.0 - CGFloat(index - currentIndex) * 0.05)
                                .zIndex(Double(testUsers.count - index))
                                .opacity(index == currentIndex ? 1 : 0.7)
                                .allowsHitTesting(index == currentIndex)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        
                        HStack(spacing: 25) {
                            Button {
                                handleSwipeAction(.pass)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .red.opacity(0.2), radius: 8)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button {
                                if currentIndex < testUsers.count {
                                    selectedUser = testUsers[currentIndex]
                                    showingUserDetail = true
                                }
                            } label: {
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .blue.opacity(0.3), radius: 8)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button {
                                handleSwipeAction(.like)
                            } label: {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green, Color.mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .green.opacity(0.3), radius: 10)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.bottom, 40)
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
                    Button {
                        currentIndex = 0
                        loadTestUsers()
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
            }
            .sheet(isPresented: $showingUserDetail) {
                if let user = selectedUser {
                    UserDetailSheet(user: user)
                }
            }
            .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
                Button("Awesome!", role: .cancel) {}
            } message: {
                Text("You both liked each other!")
            }
            .onAppear {
                if testUsers.isEmpty {
                    loadTestUsers()
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
            
            Text("Tap refresh to reload")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                currentIndex = 0
                loadTestUsers()
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
                
                Text("Liked!")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showingSuccess = false
                }
            }
        }
    }
    
    private func handleSwipe(direction: SwipeDirection) {
        let action: SwipeAction = direction == .right ? .like : .pass
        
        if action == .like {
            showingSuccess = true
            
            if Int.random(in: 0...2) == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingMatchAlert = true
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if currentIndex < testUsers.count - 1 {
                    currentIndex += 1
                } else {
                    currentIndex = testUsers.count
                }
            }
        }
    }
    
    private func handleSwipeAction(_ action: SwipeAction) {
        guard currentIndex < testUsers.count else { return }
        
        if action == .like {
            handleSwipe(direction: .right)
        } else {
            handleSwipe(direction: .left)
        }
    }
    
    private func loadTestUsers() {
        testUsers = [
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
                    placeholderView
                        .frame(height: 450)
                    
                    if user.isVerified {
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
                }
                
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
                        
                        Button {
                            onTap()
                        } label: {
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
                                    Text(interest)
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
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1), radius: isDragging ? 20 : 10)
            
            swipeOverlay
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
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
        )
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
    
    private var swipeOverlay: some View {
        ZStack {
            if offset.width < -30 {
                Text("PASS")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(.red)
                    .padding(20)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 5)
                    )
                    .rotationEffect(.degrees(-20))
                    .opacity(min(Double(-offset.width / 100), 1.0))
                    .offset(x: -100, y: -200)
            }
            
            if offset.width > 30 {
                Text("LIKE")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(.green)
                    .padding(20)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green, lineWidth: 5)
                    )
                    .rotationEffect(.degrees(20))
                    .opacity(min(Double(offset.width / 100), 1.0))
                    .offset(x: 100, y: -200)
            }
        }
    }
}

struct UserDetailSheet: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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

#Preview {
    NavigationStack {
        DiscoverView()
    }
}
