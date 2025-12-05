//
//  ProfileView.swift
//  Celestia
//
//  ELITE PROFILE VIEW - Your Digital Identity
//  ACCESSIBILITY: Full VoiceOver support, Dynamic Type, Reduce Motion, and WCAG 2.1 AA compliant
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    // Tab selection binding to detect when profile tab becomes active
    @Binding var selectedTab: Int

    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingPremiumUpgrade = false
    @State private var showingPhotoViewer = false
    @State private var showingIDVerification = false
    @State private var showingReferral = false
    @State private var selectedPhotoIndex = 0
    @State private var animateStats = false
    @State private var profileCompletion = 0
    @State private var showingLogoutConfirmation = false
    @State private var showingShareSheet = false
    @State private var isRefreshing = false
    @State private var hasAnimatedStats = false
    @State private var showingProfileViewers = false
    @State private var showingSubscriptions = false

    // Accurate stats from database
    @State private var accurateMatchCount = 0
    @State private var accurateLikesReceived = 0
    @State private var accurateProfileViews = 0
    @State private var isLoadingStats = true

    // Static date formatter for performance
    private static let memberSinceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        // No NavigationStack wrapper - this is a standalone tab
        profileContent
            .networkStatusBanner()
    }

    private var profileContent: some View {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let user = authService.currentUser {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Hero header with profile photo
                            heroSection(user: user)

                            // Content sections with professional organization
                            VStack(spacing: 20) {
                                // ===== QUICK STATS & ACTIONS SECTION =====
                                VStack(spacing: 16) {
                                    // Stats row
                                    statsRow(user: user)

                                    // Primary action - Edit Profile
                                    editButton
                                }
                                .padding(.top, 20)

                                // ===== PROFILE STATUS & INSIGHTS SECTION =====
                                VStack(spacing: 16) {
                                    // Profile completion
                                    if profileCompletion < 100 {
                                        profileCompletionCard(user: user)
                                    }

                                    // Verification card (if not verified)
                                    if !user.isVerified {
                                        verificationCard
                                    }

                                    // Subscription - consolidated: upgrade for free users, manage for premium
                                    if user.isPremium {
                                        subscriptionManagementCard
                                    } else {
                                        premiumUpgradeCard
                                    }

                                    // Referral card (same spacing as above cards)
                                    referralCard
                                }

                                // ===== ABOUT ME SECTION =====
                                VStack(spacing: 16) {
                                    sectionDivider()
                                    sectionHeader(title: "About Me", icon: "person.text.rectangle")

                                    // About section
                                    if !user.bio.isEmpty {
                                        aboutSection(bio: user.bio)
                                    }

                                    // Profile prompts
                                    if !user.prompts.isEmpty {
                                        promptsSection(prompts: user.prompts)
                                    }

                                    // Photo Gallery
                                    if !user.photos.isEmpty {
                                        VStack(spacing: 12) {
                                            sectionHeader(title: "Photo Gallery", icon: "photo.stack")
                                                .padding(.top, 8)
                                            photoGallerySection(photos: user.photos)
                                        }
                                    }
                                }
                                .padding(.top, 8)

                                // ===== PROFILE DETAILS SECTION =====
                                VStack(spacing: 16) {
                                    sectionDivider()
                                    sectionHeader(title: "Profile Details", icon: "info.circle.fill")

                                    // Details grid
                                    detailsCard(user: user)

                                    // Lifestyle card
                                    lifestyleCard(user: user)
                                }
                                .padding(.top, 8)

                                // ===== INTERESTS & LANGUAGES SECTION =====
                                VStack(spacing: 16) {
                                    sectionDivider()
                                    sectionHeader(title: "Interests", icon: "sparkles")

                                    // Languages
                                    if !user.languages.isEmpty {
                                        languagesCard(languages: user.languages)
                                    }

                                    // Interests
                                    if !user.interests.isEmpty {
                                        interestsCard(interests: user.interests)
                                    }
                                }
                                .padding(.top, 8)

                                // ===== PREFERENCES & ACTIVITY SECTION =====
                                VStack(spacing: 16) {
                                    sectionDivider()
                                    sectionHeader(title: "Preferences", icon: "slider.horizontal.3")

                                    // Preferences
                                    preferencesCard(user: user)

                                    // Activity & Achievements
                                    achievementsCard(user: user)
                                }
                                .padding(.top, 8)

                                // ===== ACCOUNT SECTION =====
                                VStack(spacing: 16) {
                                    sectionDivider()
                                    sectionHeader(title: "Account", icon: "person.circle.fill")

                                    // Action buttons
                                    actionButtons
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 40)
                            }
                            .padding(.top, -40)
                        }
                    }
                    .refreshable {
                        await refreshProfileData()
                    }
                } else {
                    // Loading state while user data loads
                    profileLoadingView
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifier.profileView)
            .sheet(isPresented: $showingEditProfile, onDismiss: {
                // CACHE FIX: Force refresh profile data when returning from edit
                Task {
                    await refreshProfileData()
                }
            }) {
                EditProfileView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let user = authService.currentUser {
                    PhotoViewerView(
                        photos: user.photos.isEmpty ? [user.profileImageURL] : user.photos,
                        selectedIndex: $selectedPhotoIndex
                    )
                }
            }
            .fullScreenCover(isPresented: $showingIDVerification) {
                ManualIDVerificationView()
            }
            .sheet(isPresented: $showingReferral) {
                ReferralDashboardView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingProfileViewers) {
                ProfileViewersView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingSubscriptions) {
                ProfileSubscriptionsView()
                    .environmentObject(authService)
            }
            .confirmationDialog("Are you sure you want to sign out?", isPresented: $showingLogoutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    authService.signOut()
                }
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.impact(.light)
                }
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
            .onAppear {
                // Only animate stats once
                if !hasAnimatedStats {
                    let animation: Animation? = reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.7)
                    withAnimation(animation) {
                        animateStats = true
                        hasAnimatedStats = true
                    }
                }
                updateProfileCompletion()
                VoiceOverAnnouncement.screenChanged(to: "Profile view")

                // Load accurate stats from database
                Task {
                    await loadAccurateStats()
                }
            }
            .onChange(of: authService.currentUser) { oldValue, newValue in
                updateProfileCompletion()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // Load stats when profile tab (index 4) becomes active
                if newValue == 4 {
                    Task {
                        await loadAccurateStats()
                    }
                }
            }
            .detectScreenshots(
                context: .profile(userId: authService.currentUser?.effectiveId ?? ""),
                userName: authService.currentUser?.fullName ?? "User"
            )
    }

    // MARK: - Tip Action Handler

    private func handleTipAction(_ action: ProfileTip.TipAction) {
        HapticManager.shared.impact(.medium)

        switch action {
        case .addPhotos:
            // Open edit profile to photos section
            showingEditProfile = true

        case .writeBio:
            // Open edit profile to bio section
            showingEditProfile = true

        case .addInterests:
            // Open edit profile to interests section
            showingEditProfile = true

        case .addLanguages:
            // Open edit profile to languages section
            showingEditProfile = true

        case .getVerified:
            // Open photo verification flow
            showingIDVerification = true
        }
    }

    // MARK: - Hero Section

    private func heroSection(user: User) -> some View {
        ZStack(alignment: .bottom) {
            // Vibrant gradient background with decorative elements
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

                // Decorative circles for depth
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
            .frame(height: 340)

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
                .accessibilityElement(
                    label: "Profile photo",
                    hint: "Tap to view full size photo and edit profile picture",
                    traits: .isButton,
                    identifier: AccessibilityIdentifier.profilePhoto
                )

                // Name and badges
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
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
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Text("•")

                        Text("\(user.age) years old")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 40)
            }
            .frame(height: 340)

            // Top bar buttons
            VStack {
                HStack {
                    // Share button - only show if user ID exists and URL is valid
                    if let userId = user.id,
                       !userId.isEmpty,
                       let shareURL = URL(string: "https://celestia.app/profile/\(userId)"),
                       shareURL.scheme == "https" {
                        ShareLink(item: shareURL, subject: Text("Check out \(user.fullName)'s profile"), message: Text("See \(user.fullName) on Celestia!")) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.shared.impact(.light)
                        })
                        .accessibilityLabel("Share profile")
                        .accessibilityHint("Share your Celestia profile with others")
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
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Manage your account and app preferences")
                }
                .padding(20)
                .padding(.top, 40)
                Spacer()
            }
            .frame(height: 340)
        }
    }
    
    private func profileImageView(user: User) -> some View {
        Group {
            if let url = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                CachedProfileImage(url: url, size: 160)
            } else {
                placeholderImage(initial: user.fullName.prefix(1))
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            }
        }
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 4)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .overlay(alignment: .bottomTrailing) {
            // Edit icon
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 4)

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
                .font(.custom("System", size: 64, relativeTo: .largeTitle).weight(.bold))
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
        .cornerRadius(16)
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
            // Liked
            Button {
                showingPremiumUpgrade = true
                HapticManager.shared.impact(.light)
            } label: {
                statCard(
                    icon: "heart.fill",
                    value: isLoadingStats ? "-" : "\(accurateLikesReceived)",
                    label: "Liked",
                    color: .pink
                )
            }

            Divider()
                .frame(height: 50)

            // Viewed
            Button {
                if user.isPremium {
                    showingProfileViewers = true
                } else {
                    showingPremiumUpgrade = true
                }
                HapticManager.shared.impact(.light)
            } label: {
                statCard(
                    icon: "eye.fill",
                    value: isLoadingStats ? "-" : "\(accurateProfileViews)",
                    label: "Viewed",
                    color: .blue
                )
            }

            Divider()
                .frame(height: 50)

            // Saved
            Button {
                showingPremiumUpgrade = true
                HapticManager.shared.impact(.light)
            } label: {
                statCard(
                    icon: "bookmark.fill",
                    value: isLoadingStats ? "-" : "\(accurateMatchCount)",
                    label: "Saved",
                    color: .purple
                )
            }
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
        .scaleEffect(animateStats ? 1 : 0.8)
        .opacity(animateStats ? 1 : 0)
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
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
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Referral Card

    private var referralCard: some View {
        Button {
            showingReferral = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 60, height: 60)

                    Image(systemName: "gift.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Invite Friends")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Earn free premium days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .accessibilityLabel("Invite Friends")
        .accessibilityHint("Open referral dashboard to invite friends and earn free premium days")
        .padding(.horizontal, 20)
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
                    .dynamicTypeSize(min: .small, max: .accessibility1)
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
            .conditionalShadow(enabled: true)
        }
        .accessibilityElement(
            label: "Edit Profile",
            hint: "Modify your profile information, photos, and preferences",
            traits: .isButton,
            identifier: AccessibilityIdentifier.editProfileButton
        )
        .scaleButton()
        .padding(.horizontal, 20)
    }

    // MARK: - Verification Card

    private var verificationCard: some View {
        Button {
            showingIDVerification = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 60, height: 60)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Get Verified")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Stand out with the blue checkmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .accessibilityLabel("Get Verified")
        .accessibilityHint("Complete photo verification to earn the blue checkmark badge")
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
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Unlimited likes & see who likes you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .accessibilityLabel("Upgrade to Premium")
        .accessibilityHint("Unlock unlimited likes, see who likes you, and access all premium features")
        .padding(.horizontal, 20)
    }

    // MARK: - Subscription Management Card

    private var subscriptionManagementCard: some View {
        Button {
            showingSubscriptions = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Premium Member")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Manage your subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .accessibilityLabel("Manage Subscription")
        .accessibilityHint("View subscription plans, features, and account details")
        .padding(.horizontal, 20)
    }

    // MARK: - Section Headers & Dividers

    private func sectionDivider() -> some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    // MARK: - About Section

    private func aboutSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("About")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Text(bio)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Prompts Section

    private func promptsSection(prompts: [ProfilePrompt]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(prompts) { prompt in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.caption)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(prompt.question)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    Text(prompt.answer)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Details Card

    private func detailsCard(user: User) -> some View {
        VStack(spacing: 16) {
            detailRow(icon: "person.fill", label: "Gender", value: user.gender)
            Divider()
            detailRow(icon: "heart.circle.fill", label: "Looking for", value: user.lookingFor)

            // Height
            if let height = user.height {
                Divider()
                detailRow(icon: "ruler", label: "Height", value: "\(height) cm (\(heightToFeetInches(height)))")
            }

            // Education
            if let education = user.educationLevel, education != "Prefer not to say" {
                Divider()
                detailRow(icon: "graduationcap.fill", label: "Education", value: education)
            }

            // Relationship goal
            if let goal = user.relationshipGoal, goal != "Prefer not to say" {
                Divider()
                detailRow(icon: "heart.text.square", label: "Relationship goal", value: goal)
            }

            // Religion
            if let religion = user.religion, religion != "Prefer not to say" {
                Divider()
                detailRow(icon: "sparkles", label: "Religion", value: religion)
            }

            Divider()
            detailRow(icon: "calendar", label: "Member since", value: formatDate(user.timestamp))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }

    // MARK: - Lifestyle Card

    @ViewBuilder
    private func lifestyleCard(user: User) -> some View {
        let hasLifestyle = (user.smoking != nil && user.smoking != "Prefer not to say") ||
                           (user.drinking != nil && user.drinking != "Prefer not to say") ||
                           (user.exercise != nil && user.exercise != "Prefer not to say") ||
                           (user.diet != nil && user.diet != "Prefer not to say") ||
                           (user.pets != nil && user.pets != "Prefer not to say")

        if hasLifestyle {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Lifestyle")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                }

                VStack(spacing: 12) {
                    if let smoking = user.smoking, smoking != "Prefer not to say" {
                        detailRow(icon: "smoke", label: "Smoking", value: smoking)
                    }
                    if let drinking = user.drinking, drinking != "Prefer not to say" {
                        if user.smoking != nil && user.smoking != "Prefer not to say" { Divider() }
                        detailRow(icon: "wineglass", label: "Drinking", value: drinking)
                    }
                    if let exercise = user.exercise, exercise != "Prefer not to say" {
                        if (user.smoking != nil && user.smoking != "Prefer not to say") ||
                           (user.drinking != nil && user.drinking != "Prefer not to say") { Divider() }
                        detailRow(icon: "figure.run", label: "Exercise", value: exercise)
                    }
                    if let diet = user.diet, diet != "Prefer not to say" {
                        if (user.smoking != nil && user.smoking != "Prefer not to say") ||
                           (user.drinking != nil && user.drinking != "Prefer not to say") ||
                           (user.exercise != nil && user.exercise != "Prefer not to say") { Divider() }
                        detailRow(icon: "fork.knife", label: "Diet", value: diet)
                    }
                    if let pets = user.pets, pets != "Prefer not to say" {
                        if (user.smoking != nil && user.smoking != "Prefer not to say") ||
                           (user.drinking != nil && user.drinking != "Prefer not to say") ||
                           (user.exercise != nil && user.exercise != "Prefer not to say") ||
                           (user.diet != nil && user.diet != "Prefer not to say") { Divider() }
                        detailRow(icon: "pawprint.fill", label: "Pets", value: pets)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    // Helper function to convert cm to feet/inches
    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
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

    /// Fixed dimensions for gallery thumbnails - 3:4 aspect ratio for consistency
    private static let galleryThumbnailWidth: CGFloat = 150
    private static let galleryThumbnailHeight: CGFloat = 200

    private func photoGallerySection(photos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Photo count badge
            HStack {
                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .font(.caption2)

                    Text("\(photos.count) photo\(photos.count != 1 ? "s" : "")")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Photo gallery scroll view with high-quality images
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button {
                            selectedPhotoIndex = index
                            showingPhotoViewer = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            // Use HighQualityCardImage for consistent sizing and quality
                            // Fixed dimensions ensure gallery thumbnails are uniform
                            HighQualityCardImage(
                                url: URL(string: photos[index]),
                                targetHeight: Self.galleryThumbnailHeight,
                                cornerRadius: 16,
                                priority: .normal
                            )
                            .frame(width: Self.galleryThumbnailWidth, height: Self.galleryThumbnailHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        }
                        .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
                        .accessibilityHint("Tap to view full size")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            // Prefetch gallery photos for smooth scrolling
            ImageCache.shared.prefetchImages(urls: photos)
        }
    }
    
    // MARK: - Languages Card

    private func languagesCard(languages: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Languages")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }

            FlowLayout3(spacing: 10) {
                ForEach(languages, id: \.self) { language in
                    Text(language)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.purple)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Interests Card

    private func interestsCard(interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Interests")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }

            FlowLayout3(spacing: 10) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.15), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.pink)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pink.opacity(0.1), lineWidth: 1)
        )
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
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }

    // MARK: - Achievements Card

    private func achievementsCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                achievementBadge(
                    icon: "flame.fill",
                    title: "Active",
                    subtitle: "Daily user",
                    colors: [.orange, .red]
                )

                if user.matchCount >= 10 {
                    achievementBadge(
                        icon: "heart.fill",
                        title: "Popular",
                        subtitle: "\(user.matchCount) matches",
                        colors: [.pink, .purple]
                    )
                }

                if user.isVerified {
                    achievementBadge(
                        icon: "checkmark.seal.fill",
                        title: "Verified",
                        subtitle: "Trusted",
                        colors: [.blue, .cyan]
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func achievementBadge(icon: String, title: String, subtitle: String, colors: [Color]) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [colors[0].opacity(0.2), colors[1].opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            actionButton(
                icon: "questionmark.circle.fill",
                title: "Help & Support",
                color: .blue,
                accessibilityHint: "Contact Celestia support team for assistance"
            ) {
                guard let url = URL(string: "mailto:support@celestia.app"),
                      UIApplication.shared.canOpenURL(url) else {
                    Logger.shared.error("Cannot open mail client - email URL invalid or no mail app configured", category: .general)
                    return
                }
                UIApplication.shared.open(url)
            }

            actionButton(
                icon: "shield.checkered",
                title: "Privacy & Safety",
                color: .green,
                accessibilityHint: "Manage privacy settings and safety features"
            ) {
                showingSettings = true
            }

            actionButton(
                icon: "arrow.right.square.fill",
                title: "Sign Out",
                color: .red,
                accessibilityHint: "Sign out of your Celestia account"
            ) {
                showingLogoutConfirmation = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private func actionButton(icon: String, title: String, color: Color, accessibilityHint: String, action: @escaping () -> Void) -> some View {
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
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Loading View

    private var profileLoadingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header skeleton
                ZStack {
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 340)

                    VStack {
                        Spacer()

                        // Profile image skeleton
                        SkeletonView()
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    }
                    .padding(.bottom, 40)
                }

                // Content section skeletons
                VStack(spacing: 20) {
                    // Stats row skeleton
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonView()
                                .frame(height: 80)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, -20)

                    // Card skeletons
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonView()
                                .frame(width: 120, height: 20)
                                .cornerRadius(6)

                            SkeletonView()
                                .frame(height: 16)
                                .cornerRadius(6)

                            SkeletonView()
                                .frame(height: 16)
                                .cornerRadius(6)

                            SkeletonView()
                                .frame(width: 200, height: 16)
                                .cornerRadius(6)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        return Self.memberSinceDateFormatter.string(from: date)
    }

    private func updateProfileCompletion() {
        if let user = authService.currentUser {
            profileCompletion = userService.profileCompletionPercentage(user)
        }
    }

    private func refreshProfileData() async {
        guard let userId = authService.currentUser?.effectiveId else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Reload user data from Firestore
            if let user = try await userService.fetchUser(userId: userId) {
                await MainActor.run {
                    authService.currentUser = user
                    updateProfileCompletion()
                }
                Logger.shared.info("Profile data refreshed successfully", category: .general)
            }

            // Also refresh accurate stats
            await loadAccurateStats()
        } catch {
            Logger.shared.error("Failed to refresh profile data", category: .general, error: error)
        }
    }

    private func loadAccurateStats() async {
        guard let userId = authService.currentUser?.effectiveId else { return }

        isLoadingStats = true

        do {
            let stats = try await ProfileStatsService.shared.getAccurateStats(userId: userId)
            await MainActor.run {
                accurateMatchCount = stats.matchCount
                accurateLikesReceived = stats.likesReceived
                accurateProfileViews = stats.profileViews
                isLoadingStats = false
            }
            Logger.shared.info("Accurate stats loaded - Matches: \(stats.matchCount), Likes: \(stats.likesReceived), Views: \(stats.profileViews)", category: .general)
        } catch {
            Logger.shared.error("Failed to load accurate stats", category: .general, error: error)
            // Fall back to user's stored counts on error
            await MainActor.run {
                if let user = authService.currentUser {
                    accurateMatchCount = user.matchCount
                    accurateLikesReceived = user.likesReceived
                    accurateProfileViews = user.profileViews
                }
                isLoadingStats = false
            }
        }
    }
}

// MARK: - Photo Viewer

struct PhotoViewerView: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss

    // Swipe-down to dismiss state
    @State private var dismissDragOffset: CGFloat = 0
    private let dismissThreshold: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                TabView(selection: $selectedIndex) {
                    ForEach(photos.indices, id: \.self) { index in
                        if let url = URL(string: photos[index]) {
                            GeometryReader { imageGeometry in
                                CachedAsyncImage(
                                    url: url,
                                    content: { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: imageGeometry.size.width, height: imageGeometry.size.height)
                                    },
                                    placeholder: {
                                        ZStack {
                                            Color.clear
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(1.5)
                                        }
                                    }
                                )
                            }
                            .tag(index)
                        } else {
                            Color.gray.opacity(0.3)
                                .overlay {
                                    Text("Image unavailable")
                                        .foregroundColor(.white)
                                }
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                // Apply dismiss offset and scale
                .offset(y: dismissDragOffset)
                .scaleEffect(dismissScale)

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
                        .opacity(controlsOpacity)
                    }
                    Spacer()
                }
            }
            // Swipe-down to dismiss gesture
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag for dismiss
                        if value.translation.height > 0 {
                            dismissDragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            // Dismiss with animation
                            HapticManager.shared.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) {
                                dismissDragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dismissDragOffset = 0
                            }
                        }
                    }
            )
        }
    }

    // Computed properties for smooth dismiss animation
    private var backgroundOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private var dismissScale: CGFloat {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.1)
    }

    private var controlsOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - progress
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
        ProfileView(selectedTab: .constant(4))
            .environmentObject(AuthService.shared)
    }
}
