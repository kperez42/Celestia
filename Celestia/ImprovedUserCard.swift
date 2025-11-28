//
//  ImprovedUserCard.swift
//  Celestia
//
//  Enhanced profile card with depth, shadows, and smooth gestures
//  ACCESSIBILITY: Full VoiceOver support, Dynamic Type, Reduce Motion, and WCAG 2.1 AA compliant
//

import SwiftUI

struct ImprovedUserCard: View {
    let user: User
    let onSwipe: (SwipeDirection) -> Void
    let onTap: () -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

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
        .conditionalShadow(enabled: true)
        .scaleEffect(scale)
        .offset(offset)
        .rotationEffect(.degrees(reduceMotion ? 0 : rotation))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.fullName), \(user.age) years old")
        .accessibilityValue(buildAccessibilityValue())
        .accessibilityHint("Swipe right to like, left to pass, or tap for details")
        .accessibilityIdentifier(AccessibilityIdentifier.userCard)
        .accessibilityActions([
            AccessibilityCustomAction(name: "Like") {
                onSwipe(.right)
            },
            AccessibilityCustomAction(name: "Pass") {
                onSwipe(.left)
            },
            AccessibilityCustomAction(name: "View Full Profile") {
                onTap()
            }
        ])
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

                        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)
                        withAnimation(animation) {
                            offset = CGSize(
                                width: horizontalSwipe > 0 ? 500 : -500,
                                height: gesture.translation.height
                            )
                            rotation = reduceMotion ? 0 : (horizontalSwipe > 0 ? 20 : -20)
                        }

                        // Announce action to VoiceOver
                        VoiceOverAnnouncement.announce(direction == .right ? "Liked" : "Passed")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipe(direction)
                            resetCard()
                        }
                        
                        HapticManager.shared.impact(.medium)
                    } else {
                        // Snap back
                        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)
                        withAnimation(animation) {
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
                // Background image or gradient - PERFORMANCE: Use CachedAsyncImage for smooth scrolling
                if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                    CachedAsyncImage(
                        url: imageURL,
                        content: { image in
                            image
                                .resizable()
                                .interpolation(.high)
                                .antialiased(true)
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .crispImageRendering()
                        },
                        placeholder: {
                            placeholderGradient
                        }
                    )
                } else {
                    placeholderGradient
                        .overlay {
                            Text(user.fullName.prefix(1))
                                .font(.system(size: 120, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                }

                // Online Status Indicator - Top Right
                VStack {
                    HStack {
                        Spacer()
                        OnlineStatusIndicator(user: user)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                    Spacer()
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
                    .dynamicTypeSize(min: .large, max: .accessibility2)

                Text("\(user.age)")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .dynamicTypeSize(min: .large, max: .accessibility2)

                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .accessibilityLabel("Verified")
                }

                if user.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                        .accessibilityLabel("Premium member")
                }

                Spacer()
            }
            .accessibilityElement(children: .combine)
            
            // Location
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text("\(user.location), \(user.country)")
                    .font(.subheadline)
                    .dynamicTypeSize(min: .small, max: .accessibility1)
            }
            .foregroundColor(.white.opacity(0.95))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Location: \(user.location), \(user.country)")
            
            // Bio preview
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .padding(.top, 4)
                    .dynamicTypeSize(min: .small, max: .accessibility1)
                    .accessibilityLabel("Bio: \(user.bio)")
            }
            
            // Quick info chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Education
                    if let education = user.educationLevel, education != "Prefer not to say" {
                        InfoChip(icon: "graduationcap.fill", text: education)
                            .accessibilityLabel("Education: \(education)")
                    }

                    // Height
                    if let height = user.height {
                        InfoChip(icon: "ruler", text: "\(height) cm")
                            .accessibilityLabel("Height: \(height) centimeters")
                    }

                    // Relationship Goal
                    if let goal = user.relationshipGoal, goal != "Prefer not to say" {
                        InfoChip(icon: "heart.circle", text: goal)
                            .accessibilityLabel("Looking for: \(goal)")
                    }

                    // Religion
                    if let religion = user.religion, religion != "Prefer not to say" {
                        InfoChip(icon: "sparkles", text: religion)
                            .accessibilityLabel("Religion: \(religion)")
                    }

                    // Smoking
                    if let smoking = user.smoking, smoking != "Prefer not to say" {
                        InfoChip(icon: "smoke", text: smoking)
                            .accessibilityLabel("Smoking: \(smoking)")
                    }

                    // Drinking
                    if let drinking = user.drinking, drinking != "Prefer not to say" {
                        InfoChip(icon: "wineglass", text: drinking)
                            .accessibilityLabel("Drinking: \(drinking)")
                    }

                    // Exercise
                    if let exercise = user.exercise, exercise != "Prefer not to say" {
                        InfoChip(icon: "figure.run", text: exercise)
                            .accessibilityLabel("Exercise: \(exercise)")
                    }

                    // Diet
                    if let diet = user.diet, diet != "Prefer not to say" {
                        InfoChip(icon: "fork.knife", text: diet)
                            .accessibilityLabel("Diet: \(diet)")
                    }

                    // Pets
                    if let pets = user.pets, pets != "Prefer not to say" {
                        InfoChip(icon: "pawprint.fill", text: pets)
                            .accessibilityLabel("Pets: \(pets)")
                    }

                    // Languages
                    if !user.languages.isEmpty {
                        ForEach(user.languages.prefix(3), id: \.self) { language in
                            InfoChip(icon: "globe", text: language)
                                .accessibilityLabel("Speaks \(language)")
                        }
                    }

                    // Interests
                    if !user.interests.isEmpty {
                        ForEach(user.interests.prefix(3), id: \.self) { interest in
                            InfoChip(icon: "star.fill", text: interest)
                                .accessibilityLabel("Interest: \(interest)")
                        }
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Profile details, languages and interests")
            
            // Tap to view more
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Tap to view more")
                        .font(.caption)
                        .fontWeight(.medium)
                        .dynamicTypeSize(min: .xSmall, max: .large)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
                Spacer()
            }
            .padding(.top, 8)
            .accessibilityHidden(true)
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

    /// Builds a comprehensive accessibility value string
    private func buildAccessibilityValue() -> String {
        var components: [String] = []

        if !user.location.isEmpty {
            components.append("from \(user.location)")
        }

        if user.isVerified {
            components.append("verified")
        }

        if user.isPremium {
            components.append("premium member")
        }

        if let education = user.educationLevel, education != "Prefer not to say" {
            components.append("Education: \(education)")
        }

        if let height = user.height {
            components.append("Height: \(height) centimeters")
        }

        if let goal = user.relationshipGoal, goal != "Prefer not to say" {
            components.append("Looking for: \(goal)")
        }

        if let religion = user.religion, religion != "Prefer not to say" {
            components.append("Religion: \(religion)")
        }

        if !user.bio.isEmpty {
            components.append("Bio: \(user.bio)")
        }

        if !user.languages.isEmpty {
            let languages = user.languages.prefix(3).joined(separator: ", ")
            components.append("Speaks: \(languages)")
        }

        if !user.interests.isEmpty {
            let interests = user.interests.prefix(3).joined(separator: ", ")
            components.append("Interests: \(interests)")
        }

        return components.joined(separator: ". ")
    }
}

// MARK: - Info Chip

struct InfoChip: View {
    let icon: String
    let text: String
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .dynamicTypeSize(min: .xSmall, max: .large)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.25))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Swipe Label

struct SwipeLabel: View {
    let text: String
    let color: Color
    let rotation: Double
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

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
            .rotationEffect(.degrees(reduceMotion ? 0 : rotation))
            .shadow(color: color.opacity(0.5), radius: 10)
            .accessibilityHidden(true) // Visual indicator only, redundant with VoiceOver announcements
    }
}

// MARK: - Swipe Direction

enum SwipeDirection {
    case left, right
}

enum CardSwipeAction {
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
