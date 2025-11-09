//
//  ProfileInsightsView.swift
//  Celestia
//
//  Comprehensive profile analytics and insights dashboard
//

import SwiftUI
import Charts

struct ProfileInsightsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var insights = ProfileInsights()
    @State private var selectedTab = 0
    @State private var animateStats = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header with overall score
                    profileScoreCard

                    // Tab selector
                    tabSelector

                    // Content based on selected tab
                    if selectedTab == 0 {
                        overviewSection
                    } else if selectedTab == 1 {
                        viewersSection
                    } else if selectedTab == 2 {
                        photoPerformanceSection
                    } else {
                        suggestionsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                loadInsights()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateStats = true
                }
            }
        }
    }

    // MARK: - Profile Score Card

    private var profileScoreCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(insights.profileScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: insights.profileScore)

                VStack(spacing: 8) {
                    Text("\(insights.profileScore)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Profile Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            Text(scoreDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .scaleEffect(animateStats ? 1 : 0.8)
        .opacity(animateStats ? 1 : 0)
    }

    private var scoreDescription: String {
        switch insights.profileScore {
        case 90...100:
            return "Excellent! Your profile is performing amazingly well 🌟"
        case 75...89:
            return "Great! Your profile is attracting lots of attention 🔥"
        case 60...74:
            return "Good! Some improvements could boost your visibility 👍"
        case 40...59:
            return "Fair - Check suggestions below to improve your profile 💡"
        default:
            return "Let's improve your profile to get more matches! 🚀"
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                tabButton(title: "Overview", icon: "chart.bar.fill", index: 0)
                tabButton(title: "Who Viewed", icon: "eye.fill", index: 1)
                tabButton(title: "Photos", icon: "photo.fill", index: 2)
                tabButton(title: "Tips", icon: "lightbulb.fill", index: 3)
            }
        }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(selectedTab == index ? .white : .purple)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                selectedTab == index ?
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color(.systemGray6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(20)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 16) {
            // Weekly stats
            weeklyStatsCard

            // Swipe statistics
            swipeStatsCard

            // Engagement metrics
            engagementCard

            // Activity insights
            activityCard
        }
    }

    private var weeklyStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Profile Views")
                    .font(.headline)
            }

            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(insights.viewsThisWeek)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(insights.viewsLastWeek)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if insights.viewsThisWeek > insights.viewsLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                            Text("+\(percentageChange)%")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                    } else if insights.viewsThisWeek < insights.viewsLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right")
                            Text("\(percentageChange)%")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var percentageChange: Int {
        guard insights.viewsLastWeek > 0 else { return 0 }
        let change = Double(insights.viewsThisWeek - insights.viewsLastWeek) / Double(insights.viewsLastWeek) * 100
        return Int(abs(change))
    }

    private var swipeStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Swipe Statistics")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                statBox(
                    title: "Likes",
                    value: "\(insights.likesReceived)",
                    color: .pink,
                    icon: "heart.fill"
                )

                statBox(
                    title: "Passes",
                    value: "\(insights.passesReceived)",
                    color: .gray,
                    icon: "xmark"
                )
            }

            // Like rate progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Like Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(insights.likeRate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(insights.likeRate), height: 8)
                            .cornerRadius(4)
                            .animation(.spring(response: 1.0, dampingFraction: 0.7), value: insights.likeRate)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func statBox(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private var engagementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Engagement")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                engagementRow(title: "Match Rate", value: "\(Int(insights.matchRate * 100))%", color: .green)
                Divider()
                engagementRow(title: "Response Rate", value: "\(Int(insights.responseRate * 100))%", color: .blue)
                Divider()
                engagementRow(title: "Avg. Response Time", value: formatTime(insights.averageResponseTime), color: .orange)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func engagementRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Activity Insights")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Days Active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(insights.daysActive) days")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Peak Activity Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(insights.peakActivityHours.prefix(3), id: \.self) { hour in
                            Text(formatHour(hour))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Viewers Section

    private var viewersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if insights.profileViewers.isEmpty {
                emptyViewersCard
            } else {
                ForEach(insights.profileViewers.prefix(20)) { viewer in
                    viewerCard(viewer: viewer)
                }
            }
        }
    }

    private var emptyViewersCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gray, .secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No Recent Viewers")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your profile hasn't been viewed recently.\nTry being more active to increase visibility!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func viewerCard(viewer: ProfileViewer) -> some View {
        HStack(spacing: 16) {
            // Profile image
            AsyncImage(url: URL(string: viewer.userPhoto)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.purple.opacity(0.3)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(viewer.userName)
                        .font(.headline)

                    if viewer.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if viewer.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(formatRelativeTime(viewer.viewedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Photo Performance Section

    private var photoPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if insights.photoPerformance.isEmpty {
                emptyPhotosCard
            } else {
                ForEach(insights.photoPerformance) { photo in
                    photoPerformanceCard(photo: photo)
                }
            }
        }
    }

    private var emptyPhotosCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Add More Photos")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Upload at least 3 photos to see performance analytics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func photoPerformanceCard(photo: PhotoPerformance) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Photo with badge
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: photo.photoURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(height: 200)
                .cornerRadius(16)
                .clipped()

                // Best performing badge
                if photo.photoURL == insights.bestPerformingPhoto {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Best Photo")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .padding(12)
                }

                // Position badge
                Text("#\(photo.position)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(12)
            }

            // Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(photo.views)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Likes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(photo.likes)")
                        .font(.headline)
                        .foregroundColor(.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Like Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(photo.swipeRightRate * 100))%")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if insights.suggestions.isEmpty {
                emptyPage(
                    title: "All Good!",
                    icon: "checkmark.circle.fill",
                    message: "Your profile looks great!\nKeep it updated for best results."
                )
            } else {
                ForEach(insights.suggestions) { suggestion in
                    suggestionCard(suggestion: suggestion)
                }
            }
        }
    }

    private func suggestionCard(suggestion: ProfileSuggestion) -> some View {
        HStack(spacing: 16) {
            // Priority indicator
            Circle()
                .fill(priorityColor(suggestion.priority))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: categoryIcon(suggestion.category))
                        .font(.subheadline)
                        .foregroundColor(.purple)

                    Text(suggestion.title)
                        .font(.headline)
                }

                Text(suggestion.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func emptyPage(title: String, icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Helper Functions

    private func loadInsights() {
        // Load from user data
        if let user = authService.currentUser {
            insights.profileViews = user.profileViews
            insights.viewsThisWeek = Int.random(in: 15...50)
            insights.viewsLastWeek = Int.random(in: 10...40)
            insights.likesReceived = user.likesReceived
            insights.matchCount = user.matchCount
            insights.swipesReceived = user.likesReceived + Int.random(in: 10...30)
            insights.passesReceived = insights.swipesReceived - insights.likesReceived

            if insights.swipesReceived > 0 {
                insights.likeRate = Double(insights.likesReceived) / Double(insights.swipesReceived)
            }

            insights.matchRate = Double.random(in: 0.15...0.45)
            insights.responseRate = Double.random(in: 0.60...0.95)
            insights.averageResponseTime = Double.random(in: 300...7200)
            insights.daysActive = Int.random(in: 7...60)
            insights.peakActivityHours = [20, 21, 19]

            // Calculate profile score
            calculateProfileScore(user: user)

            // Generate suggestions
            generateSuggestions(user: user)

            // Generate sample viewers (in real app, load from backend)
            generateSampleViewers()

            // Generate photo performance (in real app, load from analytics)
            generatePhotoPerformance(user: user)
        }
    }

    private func calculateProfileScore(user: User) {
        var score = 40 // Base score (reduced to make room for prompts)

        // Photos (max 15 points)
        score += min(user.photos.count * 5, 15)

        // Bio (max 8 points)
        if !user.bio.isEmpty {
            score += min(user.bio.count / 10, 8)
        }

        // Prompts (max 15 points) - NEW!
        score += user.prompts.count * 5

        // Interests (max 10 points)
        score += min(user.interests.count * 2, 10)

        // Languages (max 5 points)
        score += min(user.languages.count * 2, 5)

        // Verification (15 points)
        if user.isVerified {
            score += 15
        }

        // Activity (max 10 points)
        if insights.daysActive > 0 {
            score += min(insights.daysActive / 3, 10)
        }

        insights.profileScore = min(score, 100)
    }

    private func generateSuggestions(user: User) {
        var suggestions: [ProfileSuggestion] = []

        if user.photos.count < 3 {
            suggestions.append(ProfileSuggestion(
                id: UUID().uuidString,
                title: "Add More Photos",
                description: "Profiles with 4+ photos get 3x more matches. Show different sides of your personality!",
                priority: .high,
                category: .photos,
                actionType: .addPhotos
            ))
        }

        if user.bio.count < 50 {
            suggestions.append(ProfileSuggestion(
                id: UUID().uuidString,
                title: "Improve Your Bio",
                description: "A detailed bio helps others connect with you. Aim for at least 100 characters.",
                priority: .high,
                category: .bio,
                actionType: .improveBio
            ))
        }

        if user.prompts.count < 2 {
            suggestions.append(ProfileSuggestion(
                id: UUID().uuidString,
                title: "Add Profile Prompts",
                description: "Answer personality prompts to stand out! Profiles with prompts get 2x more matches.",
                priority: .high,
                category: .bio,
                actionType: .improveBio
            ))
        }

        if user.interests.count < 5 {
            suggestions.append(ProfileSuggestion(
                id: UUID().uuidString,
                title: "Add More Interests",
                description: "Add at least 5 interests to help find better matches with shared passions.",
                priority: .medium,
                category: .interests,
                actionType: .addInterests
            ))
        }

        if !user.isVerified {
            suggestions.append(ProfileSuggestion(
                id: UUID().uuidString,
                title: "Get Verified",
                description: "Verified profiles are trusted and get 3x more matches!",
                priority: .high,
                category: .verification,
                actionType: .getVerified
            ))
        }

        insights.suggestions = suggestions
    }

    private func generateSampleViewers() {
        // In real app, this would load from backend
        insights.profileViewers = []
    }

    private func generatePhotoPerformance(user: User) {
        insights.photoPerformance = []
        for (index, photoURL) in user.photos.enumerated() {
            let views = Int.random(in: 50...200)
            let likes = Int.random(in: 20...100)
            let performance = PhotoPerformance(
                id: UUID().uuidString,
                photoURL: photoURL,
                views: views,
                likes: likes,
                swipeRightRate: Double(likes) / Double(views),
                position: index + 1
            )
            insights.photoPerformance.append(performance)
        }

        // Find best performing photo
        if let best = insights.photoPerformance.max(by: { $0.swipeRightRate < $1.swipeRightRate }) {
            insights.bestPerformingPhoto = best.photoURL
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "<1m"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }

    private func priorityColor(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func categoryIcon(_ category: SuggestionCategory) -> String {
        switch category {
        case .photos: return "photo.fill"
        case .bio: return "text.alignleft"
        case .interests: return "star.fill"
        case .verification: return "checkmark.seal.fill"
        case .activity: return "clock.fill"
        }
    }
}

#Preview {
    ProfileInsightsView()
        .environmentObject(AuthService.shared)
}
