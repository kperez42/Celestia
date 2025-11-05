//
//  ImprovedUserCard.swift
//  Celestia
//
//  Enhanced profile card with depth, shadows, and smooth gestures
//

import SwiftUI

struct ImprovedUserCard: View {
    let user: User
    let onSwipe: (SwipeDirection) -> Void
    let onTap: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main card
            cardContent
            
            // Swipe indicators
            swipeIndicators
            
            // Bottom gradient info overlay
            bottomInfoOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .scaleEffect(scale)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                    rotation = Double(gesture.translation.width / 20)
                    
                    // Slight scale down when dragging
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 0.95
                    }
                }
                .onEnded { gesture in
                    let horizontalSwipe = gesture.translation.width
                    
                    if abs(horizontalSwipe) > swipeThreshold {
                        // Complete the swipe
                        let direction: SwipeDirection = horizontalSwipe > 0 ? .right : .left
                        
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            offset = CGSize(
                                width: horizontalSwipe > 0 ? 500 : -500,
                                height: gesture.translation.height
                            )
                            rotation = horizontalSwipe > 0 ? 20 : -20
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipe(direction)
                            resetCard()
                        }
                        
                        HapticManager.shared.impact(.medium)
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            offset = .zero
                            rotation = 0
                            scale = 1.0
                        }
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image or gradient
                if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        default:
                            placeholderGradient
                        }
                    }
                } else {
                    placeholderGradient
                        .overlay {
                            Text(user.fullName.prefix(1))
                                .font(.system(size: 120, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                }
            }
        }
    }
    
    private var placeholderGradient: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.7),
                Color.pink.opacity(0.6),
                Color.blue.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Swipe Indicators
    
    private var swipeIndicators: some View {
        ZStack {
            // LIKE indicator (right swipe)
            if offset.width > 20 {
                SwipeLabel(
                    text: "LIKE",
                    color: .green,
                    rotation: -15
                )
                .opacity(min(Double(offset.width / swipeThreshold), 1.0))
                .offset(x: -100, y: -200)
            }
            
            // NOPE indicator (left swipe)
            if offset.width < -20 {
                SwipeLabel(
                    text: "NOPE",
                    color: .red,
                    rotation: 15
                )
                .opacity(min(Double(-offset.width / swipeThreshold), 1.0))
                .offset(x: 100, y: -200)
            }
        }
    }
    
    // MARK: - Bottom Info Overlay
    
    private var bottomInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name, age, and badges
            HStack(alignment: .center, spacing: 8) {
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
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
            }
            
            // Location
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.subheadline)
                Text("\(user.location), \(user.country)")
                    .font(.subheadline)
            }
            .foregroundColor(.white.opacity(0.95))
            
            // Bio preview
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            
            // Quick info chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Languages
                    if !user.languages.isEmpty {
                        ForEach(user.languages.prefix(3), id: \.self) { language in
                            InfoChip(icon: "globe", text: language)
                        }
                    }
                    
                    // Interests
                    if !user.interests.isEmpty {
                        ForEach(user.interests.prefix(3), id: \.self) { interest in
                            InfoChip(icon: "star.fill", text: interest)
                        }
                    }
                }
            }
            .padding(.top, 8)
            
            // Tap to view more
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Tap to view more")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Functions
    
    private func resetCard() {
        offset = .zero
        rotation = 0
        scale = 1.0
    }
}

// MARK: - Info Chip

struct InfoChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.25))
        .cornerRadius(12)
    }
}

// MARK: - Swipe Label

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
            .shadow(color: color.opacity(0.5), radius: 10)
    }
}

// MARK: - Swipe Direction

enum SwipeDirection {
    case left, right
}

enum SwipeAction {
    case like, pass
}

#Preview {
    ImprovedUserCard(
        user: User(
            email: "test@example.com",
            fullName: "Sofia Rodriguez",
            age: 25,
            gender: "Female",
            lookingFor: "Male",
            bio: "Love to travel and explore new cultures. Speak 4 languages and always looking for adventure! 🌍✈️",
            location: "Barcelona",
            country: "Spain",
            languages: ["Spanish", "English", "French"],
            interests: ["Travel", "Photography", "Food"],
            profileImageURL: ""
        ),
        onSwipe: { _ in },
        onTap: {}
    )
    .frame(height: 600)
    .padding()
}
