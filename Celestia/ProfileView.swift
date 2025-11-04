//
//  ProfileView.swift
//  Celestia
//
//  Enhanced user profile with modern design
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingPremiumUpgrade = false
    @State private var selectedPhoto = 0
    @State private var showingPhotoViewer = false
    @State private var showingShareSheet = false
    @State private var profileCompletionPercentage: Int = 0
    @State private var animateStats = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let user = authService.currentUser {
                    VStack(spacing: 0) {
                        heroHeader(user: user)
                        
                        VStack(spacing: 20) {
                            profileCompletionCard(user: user)
                                .padding(.top, 20)
                            
                            quickStats(user: user)
                            
                            editProfileButton
                            
                            if user.isPremium {
                                premiumBadgeCard(user: user)
                            }
                            
                            if !user.bio.isEmpty {
                                aboutSection(bio: user.bio)
                            }
                            
                            detailsGrid(user: user)
                            
                            photoGallery(user: user)
                            
                            if !user.languages.isEmpty {
                                languagesSection(languages: user.languages)
                            }
                            
                            if !user.interests.isEmpty {
                                interestsSection(interests: user.interests)
                            }
                            
                            preferencesCard(user: user)
                            
                            achievementsSection(user: user)
                            
                            activitySection(user: user)
                            
                            if !user.isPremium {
                                premiumCard
                            }
                            
                            actionButtons
                        }
                        .padding(.top, -30)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
            }
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let user = authService.currentUser {
                    PhotoViewerView(photos: user.photos.isEmpty ? [user.profileImageURL] : user.photos, selectedIndex: $selectedPhoto)
                }
            }
            .onAppear {
                animateStats = true
                if let user = authService.currentUser {
                    calculateProfileCompletion(user: user)
                }
            }
        }
    }
    
    // MARK: - Hero Header
    
    private func heroHeader(user: User) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 360)
            .overlay {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -100, y: -80)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 150, height: 150)
                    .offset(x: 120, y: -50)
                
                Circle()
                    .fill(Color.yellow.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: 0, y: -120)
            }
            
            VStack(spacing: 16) {
                Spacer()
                
                Button {
                    showingPhotoViewer = true
                } label: {
                    profileImage(user: user)
                }
                
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        if user.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.5), radius: 4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text("\(user.location), \(user.country)")
                                .font(.subheadline)
                        }
                        
                        if user.age >= 18 {
                            Text("•")
                            Text("\(user.age)")
                                .font(.subheadline)
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 30)
            }
            .frame(height: 360)
            
            VStack {
                HStack {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }
            .frame(height: 360)
        }
    }
    
    private func profileImage(user: User) -> some View {
        Group {
            if !user.profileImageURL.isEmpty, let url = URL(string: user.profileImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderProfileImage(initial: user.fullName.prefix(1))
                    }
                }
            } else {
                placeholderProfileImage(initial: user.fullName.prefix(1))
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white, lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        .overlay(alignment: .bottomTrailing) {
            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    }
                    .offset(x: -8, y: -8)
            }
        }
    }
    
    private func placeholderProfileImage(initial: String.SubSequence) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
            
            Text(String(initial))
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Profile Completion
    
    private func profileCompletionCard(user: User) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                
                Text("Profile Strength")
                    .font(.headline)
                
                Spacer()
                
                Text("\(profileCompletionPercentage)%")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(profileCompletionPercentage) / 100, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: profileCompletionPercentage)
                }
            }
            .frame(height: 8)
            
            if profileCompletionPercentage < 100 {
                Text(getProfileTip(percentage: profileCompletionPercentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal)
    }
    
    private func calculateProfileCompletion(user: User) {
        var completion = 0
        let totalSteps = 8
        
        if !user.fullName.isEmpty { completion += 1 }
        if !user.bio.isEmpty { completion += 1 }
        if !user.profileImageURL.isEmpty { completion += 1 }
        if user.interests.count >= 3 { completion += 1 }
        if user.languages.count >= 1 { completion += 1 }
        if user.photos.count >= 2 { completion += 1 }
        if user.age >= 18 { completion += 1 }
        if !user.location.isEmpty && !user.country.isEmpty { completion += 1 }
        
        profileCompletionPercentage = (completion * 100) / totalSteps
    }
    
    private func getProfileTip(percentage: Int) -> String {
        if percentage < 40 {
            return "💡 Add a bio and interests to stand out!"
        } else if percentage < 70 {
            return "📸 Upload more photos to get 3x more matches!"
        } else if percentage < 100 {
            return "🎯 Almost there! Complete your profile for maximum visibility"
        } else {
            return "✨ Perfect! Your profile is complete"
        }
    }
    
    // MARK: - Quick Stats
    
    private func quickStats(user: User) -> some View {
        HStack(spacing: 0) {
            statItem(title: "Matches", value: "\(user.matchCount)", icon: "heart.fill", color: .pink)
            
            Divider()
                .frame(height: 50)
            
            statItem(title: "Likes", value: "\(user.likesReceived)", icon: "star.fill", color: .yellow)
            
            Divider()
                .frame(height: 50)
            
            statItem(title: "Views", value: "\(user.profileViews)", icon: "eye.fill", color: .blue)
        }
        .padding(.vertical, 24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal)
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .opacity(animateStats ? 1 : 0)
                .scaleEffect(animateStats ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animateStats)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Premium Badge
    
    private func premiumBadgeCard(user: User) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Premium Member")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let expiryDate = user.subscriptionExpiryDate {
                    Text("Active until \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unlimited access to all features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.yellow.opacity(0.1), .orange.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.yellow.opacity(0.4), .orange.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Edit Profile Button
    
    private var editProfileButton: some View {
        Button {
            showingEditProfile = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                
                Text("Edit Profile")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - About Section
    
    private func aboutSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.purple)
                
                Text("About Me")
                    .font(.headline)
                
                Spacer()
            }
            
            Text(bio)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Details Grid
    
    private func detailsGrid(user: User) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.purple)
                
                Text("Details")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                detailCard(icon: "person.fill", title: "Gender", value: user.gender, color: .purple)
                detailCard(icon: "heart.circle.fill", title: "Looking For", value: user.lookingFor, color: .pink)
                detailCard(icon: "calendar", title: "Age", value: "\(user.age)", color: .blue)
                detailCard(icon: "globe", title: "Country", value: user.country, color: .green)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private func detailCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Photo Gallery
    
    private func photoGallery(user: User) -> some View {
        let photos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(.purple)
                
                Text("Photos")
                    .font(.headline)
                
                Spacer()
                
                Text("\(photos.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button {
                            selectedPhoto = index
                            showingPhotoViewer = true
                        } label: {
                            AsyncImage(url: URL(string: photos[index])) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure(_):
                                    placeholderPhoto
                                default:
                                    ProgressView()
                                }
                            }
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private var placeholderPhoto: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
            
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Languages Section
    
    private func languagesSection(languages: [String]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.purple)
                
                Text("Languages I Speak")
                    .font(.headline)
                
                Spacer()
            }
            
            FlowLayout3(spacing: 10) {
                ForEach(languages, id: \.self) { language in
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.caption)
                        Text(language)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.purple)
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Interests Section
    
    private func interestsSection(interests: [String]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.purple)
                
                Text("My Interests")
                    .font(.headline)
                
                Spacer()
            }
            
            FlowLayout3(spacing: 10) {
                ForEach(interests, id: \.self) { interest in
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text(interest)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.15), Color.orange.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.pink)
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Preferences Card
    
    private func preferencesCard(user: User) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                
                Text("My Preferences")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                preferenceRow(icon: "calendar", title: "Age Range", value: "\(user.ageRangeMin) - \(user.ageRangeMax)")
                preferenceRow(icon: "location.circle", title: "Max Distance", value: "\(user.maxDistance) km")
                preferenceRow(icon: "eye", title: "Show in Search", value: user.showMeInSearch ? "Yes" : "No")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private func preferenceRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.purple)
                .frame(width: 28)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Achievements
    
    private func achievementsSection(user: User) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                
                Text("Achievements")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                achievementBadge(
                    icon: "flame.fill",
                    title: "Active User",
                    description: "7 day streak",
                    isUnlocked: true,
                    color: .orange
                )
                
                achievementBadge(
                    icon: "heart.fill",
                    title: "First Match",
                    description: "Got your first match",
                    isUnlocked: user.matchCount > 0,
                    color: .pink
                )
                
                achievementBadge(
                    icon: "star.fill",
                    title: "Popular",
                    description: "100+ profile views",
                    isUnlocked: user.profileViews >= 100,
                    color: .yellow
                )
                
                achievementBadge(
                    icon: "checkmark.seal.fill",
                    title: "Complete Profile",
                    description: "100% profile strength",
                    isUnlocked: profileCompletionPercentage == 100,
                    color: .blue
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private func achievementBadge(icon: String, title: String, description: String, isUnlocked: Bool, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isUnlocked ? color : .gray)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isUnlocked ? .primary : .gray)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isUnlocked ? 1 : 0.5)
    }
    
    // MARK: - Activity Section
    
    private func activitySection(user: User) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                activityRow(icon: "clock.fill", title: "Last Active", value: user.lastActive.timeAgo(), color: .green)
                activityRow(icon: "calendar", title: "Member Since", value: user.timestamp.formatted(date: .abbreviated, time: .omitted), color: .blue)
                activityRow(icon: "heart.fill", title: "Likes Given", value: "\(user.likesGiven)", color: .pink)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private func activityRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Premium Card
    
    private var premiumCard: some View {
        Button {
            showingPremiumUpgrade = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
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
                    HStack {
                        Text("Upgrade to Premium")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Unlock unlimited features & boost visibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            }
            .shadow(color: .yellow.opacity(0.2), radius: 10, y: 5)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            actionButton(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) {
                if let url = URL(string: "mailto:support@celestia.app") {
                    UIApplication.shared.open(url)
                }
            }
            
            actionButton(icon: "shield.checkered", title: "Privacy & Safety", color: .green) {
                showingSettings = true
            }
            
            actionButton(icon: "arrow.right.square.fill", title: "Sign Out", color: .red) {
                authService.signOut()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
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
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
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
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
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
