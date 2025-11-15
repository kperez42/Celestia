//
//  UserDetailView.swift
//  Celestia
//
//  Detailed view of a user's profile
//

import SwiftUI

struct UserDetailView: View {
    let user: User
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var showingInterestSent = false
    @State private var showingMatched = false
    @State private var isProcessing = false

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        let photos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        return photos.filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Photos carousel
                TabView {
                    // Filter out empty photo URLs
                    ForEach(validPhotos, id: \.self) { photoURL in
                        CachedCardImage(url: URL(string: photoURL))
                    }
                }
                .frame(height: 450)
                .tabViewStyle(.page)
                
                // Profile info
                VStack(alignment: .leading, spacing: 20) {
                    // Name and age
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                // FIXED: Changed from user.name to user.fullName
                                Text(user.fullName)
                                    .font(.largeTitle.weight(.bold))

                                Text("\(user.age)")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                
                                if user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.purple)
                                Text("\(user.location), \(user.country)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            // Last active status
                            HStack(spacing: 4) {
                                if user.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active now")
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                } else {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.secondary)
                                    Text("Active \(user.lastActive.timeAgoShort()) ago")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Bio
                    if !user.bio.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("About", systemImage: "text.alignleft")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Text(user.bio)
                                .font(.body)
                        }
                    }
                    
                    // Languages
                    if !user.languages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Languages", systemImage: "globe")
                                .font(.headline)
                                .foregroundColor(.purple)

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
                    
                    // Interests
                    if !user.interests.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Interests", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundColor(.purple)

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
                    
                    // Looking for
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Looking for", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        Text(user.lookingFor)
                            .font(.body)
                    }
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            // Action buttons
            HStack(spacing: 20) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                }
                .accessibilityLabel("Pass")
                .accessibilityHint("Skip this profile and return to browsing")

                Button {
                    sendInterest()
                } label: {
                    ZStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 70, height: 70)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.purple.opacity(0.4), radius: 10)
                }
                .disabled(isProcessing)
                .accessibilityLabel("Like")
                .accessibilityHint("Send interest to \(user.fullName)")
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            // Track profile view
            Task {
                guard let currentUserId = authService.currentUser?.id,
                      let viewedUserId = user.id else { return }

                do {
                    try await AnalyticsManager.shared.trackProfileView(
                        viewedUserId: viewedUserId,
                        viewerUserId: currentUserId
                    )
                } catch {
                    Logger.shared.error("Error tracking profile view", category: .general, error: error)
                }
            }
        }
        .alert("Interest Sent! 💫", isPresented: $showingInterestSent) {
            Button("OK") { dismiss() }
        } message: {
            // FIXED: Changed from user.name to user.fullName
            Text("If \(user.fullName) is interested too, you'll be matched!")
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatched) {
            Button("Send Message") {
                // NOTE: Navigation to chat should be implemented using NavigationPath or coordinator
                // For now, user can access chat from Messages tab
                dismiss()
            }
            Button("Keep Browsing") { dismiss() }
        } message: {
            // FIXED: Changed from user.name to user.fullName
            Text("You and \(user.fullName) liked each other!")
        }
    }
    
    func sendInterest() {
        guard let currentUserID = authService.currentUser?.id,
              let targetUserID = user.id,
              !isProcessing else { return }

        isProcessing = true

        Task {
            do {
                // Use SwipeService for unified matching system
                let isMatch = try await SwipeService.shared.likeUser(
                    fromUserId: currentUserID,
                    toUserId: targetUserID,
                    isSuperLike: false
                )

                await MainActor.run {
                    isProcessing = false

                    if isMatch {
                        // It's a match!
                        showingMatched = true
                        HapticManager.shared.notification(.success)
                        Logger.shared.info("Match created with \(user.fullName) from detail view", category: .matching)
                    } else {
                        // Just a like, waiting for mutual like
                        showingInterestSent = true
                        HapticManager.shared.impact(.medium)
                        Logger.shared.info("Like sent to \(user.fullName) from detail view", category: .matching)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                Logger.shared.error("Error sending like from detail view", category: .matching, error: error)
            }
        }
    }
}

// Simple FlowLayout for tags
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
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
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

#Preview {
    UserDetailView(user: User(
        email: "test@test.com",
        fullName: "Sofia", // FIXED: Changed from 'name' to 'fullName'
        age: 25,
        gender: "Female",
        lookingFor: "Men",
        bio: "Love to travel and learn new languages. Looking for someone to explore the world with!",
        location: "Barcelona",
        country: "Spain",
        languages: ["Spanish", "English", "French"],
        interests: ["Travel", "Photography", "Cooking", "Music"]
        // FIXED: Removed 'isVerified' from initializer - it has default value in User model
    ))
}
