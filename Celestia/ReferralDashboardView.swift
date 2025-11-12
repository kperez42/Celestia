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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section with referral code
                        referralCodeCard

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
                if let user = authService.currentUser {
                    ShareSheet(items: [getReferralMessage(user: user)])
                }
            }
            .task {
                await loadData()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    animateStats = true
                }
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
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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

                if let code = authService.currentUser?.referralStats.referralCode, !code.isEmpty {
                    Text(code)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(2)
                } else {
                    Text("CEL-XXXXXX")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.gray.opacity(0.3))
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
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }

                Button {
                    showShareSheet = true
                    HapticManager.shared.impact(.medium)

                    // Track share event
                    if let user = authService.currentUser {
                        Task {
                            await referralManager.trackShare(
                                userId: user.id ?? "",
                                code: user.referralStats.referralCode,
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
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
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
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 0
                    HapticManager.shared.selection()
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
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 1
                    HapticManager.shared.selection()
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
                ForEach(referralManager.userReferrals) { referral in
                    referralRow(referral: referral)
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
                if let user = authService.currentUser {
                    Task {
                        await referralManager.trackShare(
                            userId: user.id ?? "",
                            code: user.referralStats.referralCode,
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
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .scaleButton()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func referralRow(referral: Referral) -> some View {
        let isNew = referral.status == .completed &&
                    referral.completedAt != nil &&
                    Date().timeIntervalSince(referral.completedAt!) < 86400 // 24 hours

        return HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(referral.status == .completed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: referral.status == .completed ? "checkmark.circle.fill" : "clock.fill")
                    .font(.title3)
                    .foregroundColor(referral.status == .completed ? .green : .orange)

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
                    Text(referral.status == .completed ? "Completed" : "Pending")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if isNew {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                Text(referral.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                ForEach(referralManager.leaderboard) { entry in
                    leaderboardRow(entry: entry)
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

            // Profile image
            AsyncImage(url: URL(string: entry.profileImageURL)) { image in
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

        do {
            // Fetch referral stats
            referralStats = try await referralManager.getReferralStats(for: user)

            // Fetch user's referrals
            if let userId = user.id {
                try await referralManager.fetchUserReferrals(userId: userId)
            }

            // Fetch leaderboard
            try await referralManager.fetchLeaderboard()
        } catch {
            print("Error loading referral data: \(error)")
        }
    }

    private func copyCodeToClipboard() {
        guard let code = authService.currentUser?.referralStats.referralCode else { return }

        UIPasteboard.general.string = code
        HapticManager.shared.notification(.success)

        withAnimation {
            copiedToClipboard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }

    private func getReferralMessage(user: User) -> String {
        return referralManager.getReferralShareMessage(
            code: user.referralStats.referralCode,
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
