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
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaved = false
    @ObservedObject private var savedProfilesVM = SavedProfilesViewModel.shared

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        let photos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        return photos.filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                photosCarousel
                profileContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            actionButtons
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: savedProfilesVM.savedProfiles) { _ in
            isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.id == user.id })
        }
        .alert("Like Sent! 💫", isPresented: $showingInterestSent) {
            Button("OK") { dismiss() }
        } message: {
            Text("If \(user.fullName) likes you back, you'll be matched!")
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatched) {
            Button("Send Message") {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToMessages"),
                    object: nil,
                    userInfo: ["matchedUserId": user.id as Any]
                )
                dismiss()
            }
            Button("Keep Browsing") { dismiss() }
        } message: {
            Text("You and \(user.fullName) liked each other!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.isEmpty ? "Failed to send like. Please try again." : errorMessage)
        }
    }

    // MARK: - Photos Carousel

    private var photosCarousel: some View {
        TabView {
            ForEach(validPhotos, id: \.self) { photoURL in
                CachedCardImage(url: URL(string: photoURL))
            }
        }
        .frame(height: 450)
        .tabViewStyle(.page)
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            bioSection
            languagesSection
            interestsSection
            promptsSection
            detailsSection
            lifestyleSection
            lookingForSection
        }
        .padding(20)
        .padding(.bottom, 100)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(user.fullName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("\(user.age)")
                    .font(.title2)
                    .foregroundColor(.secondary)

                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(user.location), \(user.country)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            lastActiveView
        }
    }

    private var lastActiveView: some View {
        HStack(spacing: 6) {
            let interval = Date().timeIntervalSince(user.lastActive)
            let isActive = user.isOnline || interval < 300

            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(user.isOnline ? "Online" : "Active now")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text("Active \(user.lastActive.timeAgoShort()) ago")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }

    // MARK: - Bio Section

    @ViewBuilder
    private var bioSection: some View {
        if !user.bio.isEmpty {
            ProfileSectionCard(
                icon: "quote.bubble.fill",
                title: "About",
                iconColors: [.purple, .pink],
                borderColor: .purple
            ) {
                Text(user.bio)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Languages Section

    @ViewBuilder
    private var languagesSection: some View {
        if !user.languages.isEmpty {
            ProfileSectionCard(
                icon: "globe",
                title: "Languages",
                iconColors: [.blue, .cyan],
                borderColor: .blue
            ) {
                FlowLayout2(spacing: 10) {
                    ForEach(user.languages, id: \.self) { language in
                        TagView(text: language, colors: [.blue, .cyan], textColor: .blue)
                    }
                }
            }
        }
    }

    // MARK: - Interests Section

    @ViewBuilder
    private var interestsSection: some View {
        if !user.interests.isEmpty {
            ProfileSectionCard(
                icon: "sparkles",
                title: "Interests",
                iconColors: [.orange, .pink],
                borderColor: .orange
            ) {
                FlowLayout2(spacing: 10) {
                    ForEach(user.interests, id: \.self) { interest in
                        TagView(text: interest, colors: [.orange, .pink], textColor: .orange)
                    }
                }
            }
        }
    }

    // MARK: - Prompts Section

    @ViewBuilder
    private var promptsSection: some View {
        if !user.prompts.isEmpty {
            ProfileSectionCard(
                icon: "quote.bubble.fill",
                title: "Get to Know Me",
                iconColors: [.purple, .pink],
                borderColor: .purple
            ) {
                VStack(spacing: 12) {
                    ForEach(user.prompts) { prompt in
                        PromptCard(prompt: prompt)
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        if hasAdvancedDetails {
            ProfileSectionCard(
                icon: "person.text.rectangle",
                title: "Details",
                iconColors: [.indigo, .purple],
                borderColor: .indigo
            ) {
                VStack(spacing: 12) {
                    if let height = user.height {
                        DetailRow(icon: "ruler", label: "Height", value: "\(height) cm (\(heightToFeetInches(height)))")
                    }
                    if let goal = user.relationshipGoal, goal != "Prefer not to say" {
                        DetailRow(icon: "heart.circle", label: "Looking for", value: goal)
                    }
                    if let religion = user.religion, religion != "Prefer not to say" {
                        DetailRow(icon: "sparkles", label: "Religion", value: religion)
                    }
                }
            }
        }
    }

    // MARK: - Lifestyle Section

    @ViewBuilder
    private var lifestyleSection: some View {
        if hasLifestyleDetails {
            ProfileSectionCard(
                icon: "leaf.fill",
                title: "Lifestyle",
                iconColors: [.green, .mint],
                borderColor: .green
            ) {
                VStack(spacing: 12) {
                    if let smoking = user.smoking, smoking != "Prefer not to say" {
                        DetailRow(icon: "smoke", label: "Smoking", value: smoking)
                    }
                    if let drinking = user.drinking, drinking != "Prefer not to say" {
                        DetailRow(icon: "wineglass", label: "Drinking", value: drinking)
                    }
                    if let exercise = user.exercise, exercise != "Prefer not to say" {
                        DetailRow(icon: "figure.run", label: "Exercise", value: exercise)
                    }
                    if let diet = user.diet, diet != "Prefer not to say" {
                        DetailRow(icon: "fork.knife", label: "Diet", value: diet)
                    }
                    if let pets = user.pets, pets != "Prefer not to say" {
                        DetailRow(icon: "pawprint.fill", label: "Pets", value: pets)
                    }
                }
            }
        }
    }

    // MARK: - Looking For Section

    private var lookingForSection: some View {
        ProfileSectionCard(
            icon: "heart.fill",
            title: "Looking for",
            iconColors: [.purple, .pink],
            borderColor: .purple
        ) {
            Text(user.lookingFor)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 20) {
            dismissButton
            saveButton
            likeButton
        }
        .padding(.bottom, 30)
    }

    private var dismissButton: some View {
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
    }

    private var saveButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            isSaved.toggle()
            Task {
                if isSaved {
                    await savedProfilesVM.saveProfile(user: user)
                } else {
                    if let savedProfile = savedProfilesVM.savedProfiles.first(where: { $0.user.id == user.id }) {
                        savedProfilesVM.unsaveProfile(savedProfile)
                    }
                }
            }
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 60, height: 60)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save profile")
        .accessibilityHint("Bookmark this profile for later")
    }

    private var likeButton: some View {
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

    // MARK: - Helper Properties

    private var hasAdvancedDetails: Bool {
        user.height != nil ||
        (user.relationshipGoal != nil && user.relationshipGoal != "Prefer not to say") ||
        (user.religion != nil && user.religion != "Prefer not to say")
    }

    private var hasLifestyleDetails: Bool {
        (user.smoking != nil && user.smoking != "Prefer not to say") ||
        (user.drinking != nil && user.drinking != "Prefer not to say") ||
        (user.exercise != nil && user.exercise != "Prefer not to say") ||
        (user.diet != nil && user.diet != "Prefer not to say") ||
        (user.pets != nil && user.pets != "Prefer not to say")
    }

    // MARK: - Helper Functions

    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    private func handleOnAppear() {
        isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.id == user.id })

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

    // MARK: - Actions

    func sendInterest() {
        guard let currentUserID = authService.currentUser?.id,
              let targetUserID = user.id,
              !isProcessing else { return }

        guard currentUserID != targetUserID else {
            errorMessage = "You can't like your own profile!"
            showingError = true
            return
        }

        isProcessing = true

        Task {
            do {
                let isMatch = try await SwipeService.shared.likeUser(
                    fromUserId: currentUserID,
                    toUserId: targetUserID,
                    isSuperLike: false
                )

                await MainActor.run {
                    isProcessing = false

                    if isMatch {
                        showingMatched = true
                        HapticManager.shared.notification(.success)
                        Logger.shared.info("Match created with \(user.fullName) from detail view", category: .matching)
                    } else {
                        showingInterestSent = true
                        HapticManager.shared.impact(.medium)
                        Logger.shared.info("Like sent to \(user.fullName) from detail view", category: .matching)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                Logger.shared.error("Error sending like from detail view", category: .matching, error: error)
            }
        }
    }
}

// MARK: - Reusable Components

struct ProfileSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let iconColors: [Color]
    let borderColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor.opacity(0.1), lineWidth: 1)
        )
    }
}

struct TagView: View {
    let text: String
    let colors: [Color]
    let textColor: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [colors[0].opacity(0.15), colors[1].opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(textColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(textColor.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PromptCard: View {
    let prompt: ProfilePrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt.question)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            Text(prompt.answer)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
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
        fullName: "Sofia",
        age: 25,
        gender: "Female",
        lookingFor: "Men",
        bio: "Love to travel and learn new languages. Looking for someone to explore the world with!",
        location: "Barcelona",
        country: "Spain",
        languages: ["Spanish", "English", "French"],
        interests: ["Travel", "Photography", "Cooking", "Music"]
    ))
}
