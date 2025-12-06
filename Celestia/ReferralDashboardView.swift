//
//  ReferralDashboardView.swift
//  Celestia
//
//  Referral program dashboard with stats and sharing
//

import SwiftUI

struct ReferralDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var referralManager = ReferralManager.shared

    @State private var showShareSheet = false
    @State private var referralStats: ReferralStats?
    @State private var selectedTab = 0
    @State private var copiedToClipboard = false
    @State private var animateStats = false
    @State private var isInitializingCode = false
    @State private var errorMessage: String?
    @State private var referralCode: String = ""
    @State private var isRefreshing = false
    @State private var showMilestoneAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section with referral code
                        referralCodeCard

                        // Milestone progress
                        milestoneProgressCard

                        // Stats overview
                        statsGrid

                        // Tabs for My Referrals / Leaderboard
                        tabSelector

                        if selectedTab == 0 {
                            // My Referrals
                            myReferralsList
                        } else {
                            // Leaderboard
                            leaderboardList
                        }

                        // How it works
                        howItWorksSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Referral Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let user = authService.currentUser, !referralCode.isEmpty {
                    ShareSheet(items: [getReferralMessage(user: user)])
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
            .alert("Milestone Achieved!", isPresented: $showMilestoneAlert) {
                Button("Awesome!") {
                    referralManager.newMilestoneReached = nil
                }
            } message: {
                if let milestone = referralManager.newMilestoneReached {
                    Text("You've reached \(milestone.name)!\n\(milestone.bonusDays > 0 ? "Bonus: +\(milestone.bonusDays) premium days!" : milestone.description)")
                }
            }
            .onChange(of: referralManager.newMilestoneReached) { _, newMilestone in
                if newMilestone != nil {
                    showMilestoneAlert = true
                    HapticManager.shared.notification(.success)
                }
            }
            .task {
                await loadData()
                withAnimation(.butterSmooth.delay(0.1)) {
                    animateStats = true
                }

                // Start real-time listener for updates
                if let userId = authService.currentUser?.effectiveId {
                    referralManager.startReferralListener(for: userId)
                }
            }
            .onDisappear {
                // Stop listener when view disappears
                referralManager.stopReferralListener()
            }
            .overlay {
                if copiedToClipboard {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Code copied!")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .padding(.bottom, 80)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .animation(.butterSmooth, value: copiedToClipboard)
        }
    }

    // MARK: - Referral Code Card

    private var referralCodeCard: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                Image(systemName: "gift.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Invite Friends, Get Premium")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Earn 7 days of Premium for each friend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Referral Code
            VStack(spacing: 12) {
                Text("Your Code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                if isInitializingCode {
                    ProgressView()
                        .frame(height: 32)
                } else if !referralCode.isEmpty {
                    Text(referralCode)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("CEL-XXXXXX")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.gray.opacity(0.3))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    copyCodeToClipboard()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy Code")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(referralCode.isEmpty ? .gray : .purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(referralCode.isEmpty ? Color.gray.opacity(0.1) : Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.springy)
                .disabled(referralCode.isEmpty || isInitializingCode)

                Button {
                    showShareSheet = true
                    HapticManager.shared.celebration()

                    // Track share event
                    if let user = authService.currentUser {
                        Task {
                            await referralManager.trackShare(
                                userId: user.id ?? "",
                                code: referralCode,
                                shareMethod: "share_button"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: referralCode.isEmpty ? [.gray, .gray] : [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.springy)
                .disabled(referralCode.isEmpty || isInitializingCode)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .gpuAccelerated()
    }

    // MARK: - Milestone Progress

    private var milestoneProgressCard: some View {
        let totalReferrals = referralStats?.totalReferrals ?? 0
        let nextMilestone = ReferralMilestone.nextMilestone(for: totalReferrals)
        let progress = ReferralMilestone.progressToNextMilestone(for: totalReferrals)
        let achievedMilestones = ReferralMilestone.achievedMilestones(for: totalReferrals)

        return VStack(spacing: 16) {
            HStack {
                Text("Milestone Progress")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !achievedMilestones.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(achievedMilestones.suffix(3)) { milestone in
                            Image(systemName: milestone.icon)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                )
                        }
                    }
                }
            }

            if let next = nextMilestone {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: next.icon)
                            .foregroundColor(.purple)

                        Text(next.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("\(totalReferrals)/\(next.requiredReferrals)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 12)
                                .animation(.butterSmooth, value: progress)
                        }
                    }
                    .frame(height: 12)

                    if next.bonusDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Bonus: +\(next.bonusDays) premium days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // All milestones achieved
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Legend Status Achieved!")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("You've completed all milestones!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // Remaining referrals info
            let remaining = ReferralRewards.remainingReferrals(current: totalReferrals)
            if remaining > 0 && remaining < ReferralRewards.maxReferrals {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(remaining) referrals remaining until limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                number: "\(referralStats?.totalReferrals ?? 0)",
                label: "Referrals",
                icon: "person.3.fill",
                color: .purple
            )

            statCard(
                number: "\(referralStats?.premiumDaysEarned ?? 0)",
                label: "Days Earned",
                icon: "crown.fill",
                color: .orange
            )

            statCard(
                number: "#\(referralStats?.referralRank ?? 0)",
                label: "Rank",
                icon: "trophy.fill",
                color: .green
            )
        }
    }

    private func statCard(number: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .scaleEffect(animateStats ? 1 : 0.8)
        .opacity(animateStats ? 1 : 0)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.butterSmooth) {
                    selectedTab = 0
                    HapticManager.shared.tabSwitch()
                }
            } label: {
                Text("My Referrals")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTab == 0 ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == 0 ?
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }

            Button {
                withAnimation(.butterSmooth) {
                    selectedTab = 1
                    HapticManager.shared.tabSwitch()
                }
            } label: {
                Text("Leaderboard")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTab == 1 ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == 1 ?
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }
        }
        .padding(4)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - My Referrals List

    private var myReferralsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if referralManager.userReferrals.isEmpty {
                emptyReferralsCard
            } else {
                ForEach(Array(referralManager.userReferrals.enumerated()), id: \.element.id) { index, referral in
                    referralRow(referral: referral)
                        .smoothRowAppearance(delay: Double(index) * 0.05)
                }
            }
        }
    }

    private var emptyReferralsCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Referrals Yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Start sharing your code to earn premium days!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showShareSheet = true
                HapticManager.shared.impact(.medium)

                // Track share event
                if let user = authService.currentUser, !referralCode.isEmpty {
                    Task {
                        await referralManager.trackShare(
                            userId: user.id ?? "",
                            code: referralCode,
                            shareMethod: "empty_state_share"
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Share Now")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: referralCode.isEmpty ? [.gray, .gray] : [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(referralCode.isEmpty)
            .scaleButton()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func referralRow(referral: Referral) -> some View {
        let isNew = referral.isRecent && referral.status == .completed
        let userName = referral.referredUserName ?? "Friend"

        return HStack(spacing: 16) {
            // User avatar or status icon
            ZStack {
                if let photoURL = referral.referredUserPhotoURL, !photoURL.isEmpty {
                    AsyncImage(url: URL(string: photoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "person.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(referral.status == .completed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: referral.status == .completed ? "person.fill.checkmark" : "clock.fill")
                        .font(.title3)
                        .foregroundColor(referral.status == .completed ? .green : .orange)
                }

                // New badge
                if isNew {
                    Text("NEW")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(8)
                        .offset(x: 20, y: -20)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(userName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if isNew {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: referral.status == .completed ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundColor(referral.status == .completed ? .green : .orange)

                    Text(referral.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if referral.status == .completed {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(ReferralRewards.referrerBonusDays) days")
                        .font(.headline)
                        .foregroundColor(.green)

                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: isNew ? [Color.purple.opacity(0.05), Color.pink.opacity(0.05)] : [Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(isNew ? 0.1 : 0.05), radius: isNew ? 8 : 5, y: isNew ? 4 : 2)
    }

    // MARK: - Leaderboard

    private var leaderboardList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if referralManager.leaderboard.isEmpty {
                emptyLeaderboardCard
            } else {
                ForEach(Array(referralManager.leaderboard.enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(entry: entry)
                        .smoothRowAppearance(delay: Double(index) * 0.05)
                }
            }
        }
    }

    private var emptyLeaderboardCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Leaders Yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Be the first to refer friends and top the leaderboard!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func leaderboardRow(entry: ReferralLeaderboardEntry) -> some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(rank: entry.rank).opacity(0.2))
                    .frame(width: 50, height: 50)

                Text("#\(entry.rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor(rank: entry.rank))
            }

            // Profile image - PERFORMANCE: Use CachedAsyncImage
            CachedAsyncImage(url: URL(string: entry.profileImageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            // Name and stats
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.userName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(entry.totalReferrals) referrals • \(entry.premiumDaysEarned) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if entry.rank <= 3 {
                Image(systemName: entry.rank == 1 ? "crown.fill" : "medal.fill")
                    .foregroundColor(rankColor(rank: entry.rank))
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func rankColor(rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .purple
        }
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.title3)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                howItWorksStep(
                    number: "1",
                    title: "Share Your Code",
                    description: "Send your unique referral code to friends"
                )

                howItWorksStep(
                    number: "2",
                    title: "They Sign Up",
                    description: "Your friend creates an account using your code"
                )

                howItWorksStep(
                    number: "3",
                    title: "Both Get Premium",
                    description: "You get 7 days, they get 3 days free!"
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func howItWorksStep(number: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func loadData() async {
        guard let user = authService.currentUser else { return }

        // First, ensure we have a referral code
        await ensureReferralCodeExists(for: user)

        do {
            // Fetch referral stats
            referralStats = try await referralManager.getReferralStats(for: user)

            // Fetch user's referrals
            if let userId = user.id {
                try await referralManager.fetchUserReferrals(userId: userId)
            }

            // Fetch leaderboard
            try await referralManager.fetchLeaderboard()

            // Clear any previous errors on success
            errorMessage = nil
        } catch {
            Logger.shared.error("Error loading referral data", category: .referral, error: error)
            errorMessage = "Failed to load referral data. Please try again."
        }
    }

    private func refreshData() async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let user = authService.currentUser else { return }

        do {
            // Re-fetch all data
            referralStats = try await referralManager.getReferralStats(for: user)

            if let userId = user.id {
                try await referralManager.fetchUserReferrals(userId: userId)
            }

            try await referralManager.fetchLeaderboard()

            // Haptic feedback on successful refresh
            HapticManager.shared.notification(.success)
            errorMessage = nil
        } catch {
            Logger.shared.error("Error refreshing referral data", category: .referral, error: error)
            errorMessage = "Failed to refresh data. Pull down to try again."
            HapticManager.shared.notification(.error)
        }
    }

    private func ensureReferralCodeExists(for user: User) async {
        // Check if user already has a code
        let existingCode = user.referralStats.referralCode
        if !existingCode.isEmpty {
            referralCode = existingCode
            return
        }

        // Generate a new code
        isInitializingCode = true
        defer { isInitializingCode = false }

        do {
            let newCode = try await referralManager.ensureReferralCode(for: user)
            referralCode = newCode
        } catch {
            Logger.shared.error("Failed to generate referral code", category: .referral, error: error)
            errorMessage = "Failed to generate referral code. Please try again."
        }
    }

    private func copyCodeToClipboard() {
        guard !referralCode.isEmpty else { return }

        UIPasteboard.general.string = referralCode
        HapticManager.shared.notification(.success)

        withAnimation(.butterSmooth) {
            copiedToClipboard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.butterSmooth) {
                copiedToClipboard = false
            }
        }
    }

    private func getReferralMessage(user: User) -> String {
        return referralManager.getReferralShareMessage(
            code: referralCode,
            userName: user.fullName
        )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ReferralDashboardView()
            .environmentObject(AuthService.shared)
    }
}
