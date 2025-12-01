//
//  ImprovedComponents.swift
//  Celestia
//
//  Reusable improved UI components
//

import SwiftUI

// MARK: - Improved Action Button

struct ImprovedActionButton: View {
    var icon: String
    var color: Color? = nil
    var gradient: [Color]? = nil
    var size: CGFloat = 60
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            ZStack {
                // Shadow circle
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: size + 4, height: size + 4)
                    .blur(radius: 8)
                    .offset(y: 4)
                
                // Main button
                Circle()
                    .fill(
                        {
                            if let gradientColors = gradient {
                                return AnyShapeStyle(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            } else {
                                return AnyShapeStyle(color ?? .gray)
                            }
                        }()
                    )
                    .frame(width: size, height: size)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Improved User Detail Sheet

struct ImprovedUserDetailSheet: View {
    let user: User
    let onSendInterest: () -> Void
    let onPass: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoIndex = 0
    @State private var showAllPhotos = false
    
    var photos: [String] {
        if !user.photos.isEmpty {
            return user.photos
        } else if !user.profileImageURL.isEmpty {
            return [user.profileImageURL]
        } else {
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Photo carousel
                    photoCarousel
                    
                    // Main content
                    VStack(spacing: 24) {
                        // Header info
                        headerInfo
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Bio
                        if !user.bio.isEmpty {
                            bioSection
                        }
                        
                        // Stats
                        statsSection
                        
                        // Details grid
                        detailsSection
                        
                        // Languages
                        if !user.languages.isEmpty {
                            languagesSection
                        }
                        
                        // Interests
                        if !user.interests.isEmpty {
                            interestsSection
                        }
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(.top, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.2), radius: 5)
                            
                            Image(systemName: "xmark")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo Carousel

    // PERFORMANCE: Use CachedAsyncImage for smooth scrolling
    private var photoCarousel: some View {
        TabView(selection: $selectedPhotoIndex) {
            if photos.isEmpty {
                placeholderPhoto
                    .tag(0)
            } else {
                ForEach(photos.indices, id: \.self) { index in
                    GeometryReader { geometry in
                        CachedAsyncImage(
                            url: URL(string: photos[index]),
                            content: { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            },
                            placeholder: {
                                placeholderPhoto
                            }
                        )
                    }
                    .tag(index)
                }
            }
        }
        .frame(height: 500)
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    
    private var placeholderPhoto: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.7),
                    Color.pink.opacity(0.6),
                    Color.blue.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(user.fullName.prefix(1))
                .font(.system(size: 140, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Header Info
    
    private var headerInfo: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(user.fullName)
                    .font(.system(size: 32, weight: .bold))
                
                Text("\(user.age)")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                if user.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
            }
            
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(user.location), \(user.country)")
                    .foregroundColor(.gray)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Bio Section
    
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("About")
                    .font(.headline)
            }
            
            Text(user.bio)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(icon: "heart.fill", value: "\(user.likesReceived)", label: "Likes", color: .pink)
            
            Divider()
                .frame(height: 40)
            
            statItem(icon: "star.fill", value: "\(user.matchCount)", label: "Matches", color: .purple)
            
            Divider()
                .frame(height: 40)
            
            statItem(icon: "eye.fill", value: "\(user.profileViews)", label: "Views", color: .blue)
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.horizontal, 24)
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: 16) {
            detailRow(icon: "person.fill", label: "Gender", value: user.gender)
            detailRow(icon: "heart.circle.fill", label: "Looking for", value: user.lookingFor)
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Languages Section
    
    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.purple)
                Text("Languages")
                    .font(.headline)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(user.languages, id: \.self) { language in
                    TagView(text: language, color: .purple)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Interests Section
    
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.purple)
                Text("Interests")
                    .font(.headline)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(user.interests, id: \.self) { interest in
                    TagView(text: interest, color: .blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Pass button
            Button {
                dismiss()
                onPass()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                    Text("Pass")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red, lineWidth: 2)
                )
            }
            
            // Like button
            Button {
                onSendInterest()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Like")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.pink, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .cornerRadius(20)
    }
}

// MARK: - Flow Layout (Shared Component)

struct FlowLayout: Layout {
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

#Preview {
    ImprovedUserDetailSheet(
        user: User(
            email: "test@example.com",
            fullName: "Sofia Rodriguez",
            age: 25,
            gender: "Female",
            lookingFor: "Male",
            bio: "Love to travel and explore new cultures. Passionate about photography and always looking for the next adventure!",
            location: "Barcelona",
            country: "Spain",
            languages: ["Spanish", "English", "French", "Portuguese"],
            interests: ["Travel", "Photography", "Food", "Music", "Dancing"],
            profileImageURL: ""
        ),
        onSendInterest: {},
        onPass: {}
    )
}
