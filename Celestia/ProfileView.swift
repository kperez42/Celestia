//
//  ProfileView.swift
//  Celestia
//
//  ELITE PROFILE VIEW - Your Digital Identity
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userService = UserService.shared
    
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingPremiumUpgrade = false
    @State private var showingPhotoViewer = false
    @State private var selectedPhotoIndex = 0
    @State private var animateStats = false
    @State private var profileCompletion = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let user = authService.currentUser {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Hero header with profile photo
                            heroSection(user: user)
                            
                            // Content sections
                            VStack(spacing: 20) {
                                // Profile completion
                                if profileCompletion < 100 {
                                    profileCompletionCard(user: user)
                                        .padding(.top, 20)
                                }
                                
                                // Stats row
                                statsRow(user: user)
                                
                                // Edit profile button
                                editButton
                                
                                // Premium badge or upgrade
                                if user.isPremium {
                                    premiumBadgeCard
                                } else {
                                    premiumUpgradeCard
                                }
                                
                                // About section
                                if !user.bio.isEmpty {
                                    aboutSection(bio: user.bio)
                                }
                                
                                // Details grid
                                detailsCard(user: user)
                                
                                // Photo gallery
                                if !user.photos.isEmpty {
                                    photoGallerySection(photos: user.photos)
                                }
                                
                                // Languages
                                if !user.languages.isEmpty {
                                    languagesCard(languages: user.languages)
                                }
                                
                                // Interests
                                if !user.interests.isEmpty {
                                    interestsCard(interests: user.interests)
                                }
                                
                                // Preferences
                                preferencesCard(user: user)
                                
                                // Activity & Achievements
                                achievementsCard(user: user)
                                
                                // Action buttons
                                actionButtons
                            }
                            .padding(.top, -40)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
            }
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let user = authService.currentUser {
                    PhotoViewerView(
                        photos: user.photos.isEmpty ? [user.profileImageURL] : user.photos,
                        selectedIndex: $selectedPhotoIndex
                    )
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animateStats = true
                }
                if let user = authService.currentUser {
                    profileCompletion = userService.profileCompletionPercentage(user)
                }
            }
        }
    }
    
    // MARK: - Hero Section
    
    private func heroSection(user: User) -> some View {
        ZStack(alignment: .bottom) {
            // Gradient background with decorative elements
            ZStack {
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.9),
                        Color.pink.opacity(0.7),
                        Color.blue.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative circles
                GeometryReader { geo in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .offset(x: -80, y: 50)
                    
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 30)
                        .offset(x: geo.size.width - 60, y: 100)
                }
            }
            .frame(height: 380)
            
            // Profile content
            VStack(spacing: 16) {
                Spacer()
                
                // Profile image with tap to expand
                Button {
                    selectedPhotoIndex = 0
                    showingPhotoViewer = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    profileImageView(user: user)
                }
                
                // Name and badges
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.5), radius: 5)
                        }
                        
                        if user.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.7), radius: 8)
                        }
                    }
                    
                    // Location and age
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text("\(user.location), \(user.country)")
                                .font(.subheadline)
                        }
                        
                        Text("•")
                        
                        Text("\(user.age) years old")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.95))
                }
                .padding(.bottom, 40)
            }
            .frame(height: 380)
            
            // Top bar buttons
            VStack {
                HStack {
                    Button {
                        // Share profile
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        showingSettings = true
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(20)
                .padding(.top, 40)
                Spacer()
            }
            .frame(height: 380)
        }
    }
    
    private func profileImageView(user: User) -> some View {
        Group {
            if let url = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderImage(initial: user.fullName.prefix(1))
                    }
                }
            } else {
                placeholderImage(initial: user.fullName.prefix(1))
            }
        }
        .frame(width: 160, height: 160)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color.yellow.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .overlay(alignment: .bottomTrailing) {
            // Edit icon
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "camera.fill")
                    .font(.callout)
                    .foregroundColor(.white)
            }
            .offset(x: 4, y: 4)
        }
    }
    
    private func placeholderImage(initial: Substring) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.8),
                    Color.pink.opacity(0.7),
                    Color.blue.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(initial)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Profile Completion Card
    
    private func profileCompletionCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Completion")
                        .font(.headline)
                    Text("Complete your profile to get more matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(profileCompletion) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.7), value: profileCompletion)
                    
                    Text("\(profileCompletion)%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                .frame(width: 50, height: 50)
            }
            
            // Missing items
            if profileCompletion < 100 {
                VStack(alignment: .leading, spacing: 8) {
                    if user.bio.isEmpty {
                        missingItem(icon: "text.alignleft", text: "Add a bio")
                    }
                    if user.photos.count < 3 {
                        missingItem(icon: "photo.on.rectangle", text: "Add more photos")
                    }
                    if user.interests.count < 3 {
                        missingItem(icon: "star", text: "Add interests")
                    }
                    if user.languages.isEmpty {
                        missingItem(icon: "globe", text: "Add languages")
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    private func missingItem(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Stats Row
    
    private func statsRow(user: User) -> some View {
        HStack(spacing: 0) {
            statCard(
                icon: "heart.fill",
                value: "\(user.matchCount)",
                label: "Matches",
                color: .pink
            )
            
            Divider()
                .frame(height: 40)
            
            statCard(
                icon: "eye.fill",
                value: "\(user.profileViews)",
                label: "Views",
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            statCard(
                icon: "hand.thumbsup.fill",
                value: "\(user.likesReceived)",
                label: "Likes",
                color: .purple
            )
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
        .scaleEffect(animateStats ? 1 : 0.8)
        .opacity(animateStats ? 1 : 0)
    }
    
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Edit Button
    
    private var editButton: some View {
        Button {
            showingEditProfile = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                Text("Edit Profile")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Premium Badge Card
    
    private var premiumBadgeCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Premium Member")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                Text("Enjoying all premium features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Premium Upgrade Card
    
    private var premiumUpgradeCard: some View {
        Button {
            showingPremiumUpgrade = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Upgrade to Premium")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Unlock unlimited likes & see who likes you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .yellow.opacity(0.15), radius: 15, y: 8)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - About Section
    
    private func aboutSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("About")
                    .font(.headline)
            }
            
            Text(bio)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Details Card
    
    private func detailsCard(user: User) -> some View {
        VStack(spacing: 16) {
            detailRow(icon: "person.fill", label: "Gender", value: user.gender)
            Divider()
            detailRow(icon: "heart.circle.fill", label: "Looking for", value: user.lookingFor)
            Divider()
            detailRow(icon: "calendar", label: "Member since", value: formatDate(user.timestamp))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Photo Gallery
    
    private func photoGallerySection(photos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.purple)
                Text("Photo Gallery")
                    .font(.headline)
                
                Spacer()
                
                Text("\(photos.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button {
                            selectedPhotoIndex = index
                            showingPhotoViewer = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            AsyncImage(url: URL(string: photos[index])) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .frame(width: 140, height: 200)
                            .cornerRadius(16)
                            .clipped()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Languages Card
    
    private func languagesCard(languages: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(.purple)
                Text("Languages")
                    .font(.headline)
            }
            
            FlowLayout3(spacing: 8) {
                ForEach(languages, id: \.self) { language in
                    Text(language)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Interests Card
    
    private func interestsCard(interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.purple)
                Text("Interests")
                    .font(.headline)
            }
            
            FlowLayout3(spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Preferences Card
    
    private func preferencesCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                Text("Discovery Preferences")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Age range")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(user.ageRangeMin) - \(user.ageRangeMax)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Text("Max distance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(user.maxDistance) km")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Achievements Card
    
    private func achievementsCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.purple)
                Text("Achievements")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                achievementBadge(
                    icon: "flame.fill",
                    title: "Active",
                    subtitle: "Daily user",
                    color: .orange
                )
                
                if user.matchCount >= 10 {
                    achievementBadge(
                        icon: "heart.fill",
                        title: "Popular",
                        subtitle: "\(user.matchCount) matches",
                        color: .pink
                    )
                }
                
                if user.isVerified {
                    achievementBadge(
                        icon: "checkmark.seal.fill",
                        title: "Verified",
                        subtitle: "Trusted",
                        color: .blue
                    )
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    private func achievementBadge(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            actionButton(
                icon: "questionmark.circle.fill",
                title: "Help & Support",
                color: .blue
            ) {
                if let url = URL(string: "mailto:support@celestia.app") {
                    UIApplication.shared.open(url)
                }
            }
            
            actionButton(
                icon: "shield.checkered",
                title: "Privacy & Safety",
                color: .green
            ) {
                showingSettings = true
            }
            
            actionButton(
                icon: "arrow.right.square.fill",
                title: "Sign Out",
                color: .red
            ) {
                authService.signOut()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Photo Viewer

struct PhotoViewerView: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    AsyncImage(url: URL(string: photos[index])) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout3: Layout {
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
    NavigationStack {
        ProfileView()
            .environmentObject(AuthService.shared)
    }
}
