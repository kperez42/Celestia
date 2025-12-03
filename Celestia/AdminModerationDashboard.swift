//
//  AdminModerationDashboard.swift
//  Celestia
//
//  Admin dashboard for viewing and moderating user reports
//

import SwiftUI
import FirebaseFunctions
import FirebaseFirestore

struct AdminModerationDashboard: View {
    @StateObject private var viewModel = ModerationViewModel()
    @State private var selectedTab = 0
    @State private var showingAlerts = false
    @State private var lastRefreshed = Date()
    @State private var isRefreshing = false

    // Tab configuration with icons and colors
    private let tabs: [(name: String, icon: String, color: Color)] = [
        ("New", "person.badge.plus", .blue),
        ("Reports", "exclamationmark.triangle.fill", .orange),
        ("Appeals", "envelope.open.fill", .cyan),
        ("Suspicious", "eye.trianglebadge.exclamationmark", .red),
        ("ID Review", "person.text.rectangle", .purple),
        ("Stats", "chart.bar.fill", .green)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Dashboard Header
                adminHeader

                // Organized Tab Bar - Fixed height, no layout shifts
                adminTabBar

                // Content area with smooth page transitions - horizontal swipe only
                GeometryReader { geometry in
                    TabView(selection: $selectedTab) {
                        pendingProfilesView
                            .tag(0)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        reportsListView
                            .tag(1)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        appealsListView
                            .tag(2)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        suspiciousProfilesView
                            .tag(3)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        idVerificationReviewView
                            .tag(4)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        statsView
                            .tag(5)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.smooth(duration: 0.3), value: selectedTab)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .clipped()
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            // Start all real-time listeners when view appears
            viewModel.startAllListeners()
            lastRefreshed = Date()
        }
        .onDisappear {
            // Clean up all listeners when view disappears
            viewModel.stopAllListeners()
        }
        .sheet(isPresented: $showingAlerts) {
            AdminAlertsSheet(viewModel: viewModel)
        }
        .refreshable {
            isRefreshing = true
            await viewModel.refresh()
            lastRefreshed = Date()
            isRefreshing = false
        }
    }

    // MARK: - Admin Header

    private var adminHeader: some View {
        VStack(spacing: 0) {
            // Main header row
            HStack(spacing: 14) {
                // Admin badge with glow effect
                ZStack {
                    // Glow effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .indigo.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Admin Panel")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        // LIVE indicator with pulsing animation
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: .green.opacity(0.8), radius: 4)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                    }

                    Text("Real-time updates active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 10) {
                    // Alerts button
                    Button {
                        showingAlerts = true
                        HapticManager.shared.impact(.light)
                    } label: {
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
                                )

                            // Centered bell icon
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .overlay(alignment: .topTrailing) {
                            // Badge positioned at top-right corner
                            if viewModel.unreadAlertCount > 0 {
                                Text("\(min(viewModel.unreadAlertCount, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(
                                        Circle()
                                            .fill(Color.red)
                                            .shadow(color: .red.opacity(0.4), radius: 3, y: 1)
                                    )
                                    .offset(x: 4, y: -2)
                            }
                        }
                        .frame(width: 44, height: 44) // Slightly larger hit area
                    }

                    // Refresh button
                    Button {
                        Task {
                            isRefreshing = true
                            HapticManager.shared.impact(.light)
                            await viewModel.refresh()
                            lastRefreshed = Date()
                            isRefreshing = false
                            HapticManager.shared.notification(.success)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
                                )

                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            // Quick stats cards
            HStack(spacing: 8) {
                AdminQuickStatCard(
                    value: viewModel.pendingProfiles.count,
                    label: "New",
                    icon: "person.badge.plus",
                    color: .blue
                )
                AdminQuickStatCard(
                    value: viewModel.reports.count,
                    label: "Reports",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
                AdminQuickStatCard(
                    value: viewModel.appeals.count,
                    label: "Appeals",
                    icon: "envelope.open.fill",
                    color: .cyan
                )
                AdminQuickStatCard(
                    value: viewModel.suspiciousProfiles.count,
                    label: "Suspicious",
                    icon: "eye.trianglebadge.exclamationmark",
                    color: .red
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
    }

    // MARK: - Admin Tab Bar

    private var adminTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        AdminTabItem(
                            name: tab.name,
                            icon: tab.icon,
                            color: tab.color,
                            badgeCount: getBadgeCount(for: index),
                            isSelected: selectedTab == index
                        )
                        .id(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = index
                            }
                            HapticManager.shared.selection()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: 62)
            .background(
                Color(.systemBackground)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color(.separator).opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 1)
                    }
            )
            .onChange(of: selectedTab) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Badge Count Helper

    private func getBadgeCount(for tabIndex: Int) -> Int {
        switch tabIndex {
        case 0: return viewModel.pendingProfiles.count  // New accounts
        case 1: return viewModel.reports.count          // Reports
        case 2: return viewModel.appeals.count          // Appeals
        case 3: return viewModel.suspiciousProfiles.count // Suspicious
        case 4: return 0  // ID Review count comes from embedded view
        default: return 0
        }
    }

    // MARK: - Reports List

    private var reportsListView: some View {
        Group {
            if viewModel.isLoading {
                AdminLoadingView(message: "Loading reports...")
            } else if let error = viewModel.errorMessage {
                AdminErrorView(
                    title: "Could Not Load Reports",
                    message: error,
                    onRetry: { Task { await viewModel.refresh() } }
                )
            } else if viewModel.reports.isEmpty {
                AdminEmptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No Pending Reports",
                    message: "All reports have been reviewed",
                    color: .green,
                    onRefresh: { Task { await viewModel.refresh() } }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section header
                        AdminSectionHeader(
                            title: "Pending Reports",
                            count: viewModel.reports.count,
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )

                        ForEach(viewModel.reports) { report in
                            NavigationLink {
                                ReportDetailView(report: report, viewModel: viewModel)
                            } label: {
                                ReportRowView(report: report)
                            }
                            .buttonStyle(.plain)

                            if report.id != viewModel.reports.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .background(Color(.systemBackground))
                    }
                    .padding(.bottom, 80) // Account for tab bar
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - Appeals List

    private var appealsListView: some View {
        Group {
            if viewModel.isLoading {
                AdminLoadingView(message: "Loading appeals...")
            } else if viewModel.appeals.isEmpty {
                AdminEmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "No Pending Appeals",
                    message: "All user appeals have been reviewed",
                    color: .cyan,
                    onRefresh: { Task { await viewModel.refresh() } }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section header
                        AdminSectionHeader(
                            title: "User Appeals",
                            count: viewModel.appeals.count,
                            icon: "envelope.open.fill",
                            color: .cyan
                        )

                        ForEach(viewModel.appeals) { appeal in
                            NavigationLink {
                                AppealDetailView(appeal: appeal, viewModel: viewModel)
                            } label: {
                                AppealRowView(appeal: appeal)
                            }
                            .buttonStyle(.plain)

                            if appeal.id != viewModel.appeals.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .background(Color(.systemBackground))
                    }
                    .padding(.bottom, 80) // Account for tab bar
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - Pending Profiles (New Accounts)

    private var pendingProfilesView: some View {
        Group {
            if viewModel.isLoading {
                AdminLoadingView(message: "Loading pending profiles...")
            } else if viewModel.pendingProfiles.isEmpty {
                AdminEmptyStateView(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "All Caught Up!",
                    message: "No new accounts waiting for review",
                    color: .blue,
                    onRefresh: { Task { await viewModel.refresh() } }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Section header
                        AdminSectionHeader(
                            title: "New Accounts",
                            count: viewModel.pendingProfiles.count,
                            icon: "person.badge.plus",
                            color: .blue
                        )
                        .padding(.bottom, 4)

                        ForEach(viewModel.pendingProfiles) { profile in
                            PendingProfileCard(profile: profile, viewModel: viewModel)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 80) // Account for tab bar
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - Suspicious Profiles

    private var suspiciousProfilesView: some View {
        Group {
            if viewModel.isLoading {
                AdminLoadingView(message: "Loading suspicious profiles...")
            } else if viewModel.suspiciousProfiles.isEmpty {
                AdminEmptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "No Suspicious Profiles",
                    message: "Auto-detection found no concerns",
                    color: .green,
                    onRefresh: { Task { await viewModel.refresh() } }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section header
                        AdminSectionHeader(
                            title: "Suspicious Activity",
                            count: viewModel.suspiciousProfiles.count,
                            icon: "eye.trianglebadge.exclamationmark",
                            color: .red
                        )

                        ForEach(viewModel.suspiciousProfiles) { item in
                            NavigationLink {
                                SuspiciousProfileDetailView(item: item, viewModel: viewModel)
                            } label: {
                                SuspiciousProfileRowView(item: item)
                            }
                            .buttonStyle(.plain)

                            if item.id != viewModel.suspiciousProfiles.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .background(Color(.systemBackground))
                    }
                    .padding(.bottom, 80) // Account for tab bar
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - ID Verification Review

    private var idVerificationReviewView: some View {
        IDVerificationReviewEmbeddedView()
    }

    // MARK: - Stats

    private var statsView: some View {
        Group {
            if viewModel.isLoading {
                AdminLoadingView(message: "Loading statistics...")
            } else {
                statsContentView
            }
        }
    }

    private var statsContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsHeaderCard
                statsSummaryGrid
                recentActivitySection
            }
            .padding(.bottom, 80) // Account for tab bar
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Stats Sub-Views

    private var statsHeaderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview")
                    .font(.system(size: 20, weight: .bold))
                Text("Real-time moderation stats")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()

            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Live")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var statsSummaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AdminStatCard(
                title: "Total Reports",
                value: "\(viewModel.stats.totalReports)",
                icon: "exclamationmark.triangle.fill",
                color: .blue
            )

            AdminStatCard(
                title: "Pending",
                value: "\(viewModel.stats.pendingReports)",
                icon: "clock.fill",
                color: .orange
            )

            AdminStatCard(
                title: "Resolved",
                value: "\(viewModel.stats.resolvedReports)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            AdminStatCard(
                title: "Suspicious",
                value: "\(viewModel.stats.suspiciousProfiles)",
                icon: "eye.trianglebadge.exclamationmark.fill",
                color: .red
            )
        }
        .padding(.horizontal, 16)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentActivityHeader
            recentActivityContent
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private var recentActivityHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purple)
            Text("Recent Activity")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var recentActivityContent: some View {
        if viewModel.reports.isEmpty && viewModel.suspiciousProfiles.isEmpty {
            recentActivityEmptyState
        } else {
            recentActivityList
        }
    }

    private var recentActivityEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No recent activity")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var recentActivityList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.reports.prefix(5).enumerated()), id: \.element.id) { index, report in
                RecentActivityRowView(report: report)

                if index < min(viewModel.reports.count - 1, 4) {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
    }
}

// MARK: - Recent Activity Row

private struct RecentActivityRowView: View {
    let report: ModerationReport

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(report.reason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(report.timestamp)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.quaternaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Report Row

struct ReportRowView: View {
    let report: ModerationReport

    var body: some View {
        HStack(spacing: 12) {
            // User photo
            if let user = report.reportedUser, let photoURL = user.photoURL {
                CachedAsyncImage(url: URL(string: photoURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let user = report.reportedUser {
                        Text(user.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(report.timestamp)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Reason badge
                Text(report.reason)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(reasonColor)
                    .cornerRadius(4)

                if let reporter = report.reporter {
                    Text("by \(reporter.name)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.quaternaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var reasonColor: Color {
        switch report.reason.lowercased() {
        case let r where r.contains("harassment"):
            return .red
        case let r where r.contains("inappropriate"):
            return .orange
        case let r where r.contains("spam"):
            return .purple
        case let r where r.contains("fake"):
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - Report Detail

struct ReportDetailView: View {
    let report: ModerationReport
    @ObservedObject var viewModel: ModerationViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedAction: ModerationAction = .dismiss
    @State private var actionReason = ""
    @State private var showingConfirmation = false
    @State private var isProcessing = false
    @State private var showPhotoGallery = false
    @State private var selectedPhotoIndex = 0
    @State private var photosToShow: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Reported user info
                if let user = report.reportedUser {
                    userInfoCard(user)
                }

                // Report details
                reportDetailsCard

                // Reporter info
                if let reporter = report.reporter {
                    reporterInfoCard(reporter)
                }

                // Moderation actions
                moderationActionsCard

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Report Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // PERFORMANCE: Use CachedAsyncImage - Tap photo to view full screen
    private func userInfoCard(_ user: ModerationReport.UserInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reported User")
                .font(.headline)

            HStack(spacing: 12) {
                if let photoURL = user.photoURL {
                    CachedAsyncImage(url: URL(string: photoURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                    .onTapGesture {
                        photosToShow = [photoURL]
                        selectedPhotoIndex = 0
                        showPhotoGallery = true
                        HapticManager.shared.impact(.light)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.title3.bold())
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("ID: \(user.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if user.photoURL != nil {
                        Text("Tap photo to view")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .fullScreenCover(isPresented: $showPhotoGallery) {
            AdminPhotoGalleryView(
                photos: photosToShow,
                selectedIndex: $selectedPhotoIndex,
                isPresented: $showPhotoGallery
            )
        }
    }

    private var reportDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Details")
                .font(.headline)

            HStack {
                Text("Reason:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(report.reason)
                    .bold()
            }

            if let details = report.additionalDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Additional Details:")
                        .foregroundColor(.secondary)
                    Text(details)
                        .font(.subheadline)
                }
            }

            HStack {
                Text("Reported:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(report.timestamp)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func reporterInfoCard(_ reporter: ModerationReport.UserInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reporter")
                .font(.headline)

            HStack {
                Text(reporter.name)
                Spacer()
                Text(reporter.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var moderationActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take Action")
                .font(.headline)

            // Action picker
            Picker("Action", selection: $selectedAction) {
                Text("Dismiss").tag(ModerationAction.dismiss)
                Text("Warn User").tag(ModerationAction.warn)
                Text("Suspend (7 days)").tag(ModerationAction.suspend)
                Text("Ban Permanently").tag(ModerationAction.ban)
            }
            .pickerStyle(.segmented)

            // Reason text field
            TextField("Reason for action (optional)", text: $actionReason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            // Action button
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: selectedAction.icon)
                    Text(selectedAction.buttonTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedAction.color)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
            .confirmationDialog(
                "Confirm Action",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button(selectedAction.confirmTitle, role: selectedAction == .ban || selectedAction == .suspend ? .destructive : .none) {
                    Task {
                        await performAction()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(selectedAction.confirmMessage)
            }

            if isProcessing {
                ProgressView("Processing...")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func performAction() async {
        isProcessing = true

        do {
            try await viewModel.moderateReport(
                reportId: report.id,
                action: selectedAction,
                reason: actionReason.isEmpty ? nil : actionReason
            )

            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessing = false
            }
            Logger.shared.error("Failed to moderate report", category: .general, error: error)
        }
    }
}

// MARK: - Appeal Row View

struct AppealRowView: View {
    let appeal: UserAppeal

    var body: some View {
        HStack(spacing: 12) {
            // User photo
            if let user = appeal.user, let photoURL = user.photoURL {
                CachedAsyncImage(url: URL(string: photoURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let user = appeal.user {
                        Text(user.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(appeal.submittedAt)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Appeal type badge
                Text(appeal.typeDisplayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(appeal.type == "ban" ? Color.red : Color.orange)
                    .cornerRadius(4)

                // Message preview
                Text(appeal.appealMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.quaternaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Appeal Detail View

struct AppealDetailView: View {
    let appeal: UserAppeal
    @ObservedObject var viewModel: ModerationViewModel
    @Environment(\.dismiss) var dismiss

    @State private var adminResponse = ""
    @State private var showingApproveConfirmation = false
    @State private var showingRejectConfirmation = false
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appeal.typeDisplayName)
                            .font(.title2.bold())

                        Spacer()

                        Text(appeal.submittedAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Status badge
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Pending Review")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                Divider()

                // User information
                if let user = appeal.user {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("User Information")
                            .font(.headline)

                        HStack(spacing: 12) {
                            if let photoURL = user.photoURL {
                                CachedAsyncImage(url: URL(string: photoURL)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    if user.isBanned {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                        Text("Banned")
                                            .font(.caption.bold())
                                            .foregroundColor(.red)
                                    } else if user.isSuspended {
                                        Image(systemName: "pause.circle.fill")
                                            .foregroundColor(.orange)
                                        Text("Suspended")
                                            .font(.caption.bold())
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Original action reason
                if let actionReason = appeal.actionReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original \(appeal.type == "ban" ? "Ban" : "Suspension") Reason")
                            .font(.headline)

                        Text(actionReason)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                // Appeal message
                VStack(alignment: .leading, spacing: 8) {
                    Text("User's Appeal")
                        .font(.headline)

                    Text(appeal.appealMessage)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Divider()

                // Admin response
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Response (Optional)")
                        .font(.headline)

                    TextEditor(text: $adminResponse)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                    Text("This message will be sent to the user")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Approve button (lift ban/suspension)
                    Button {
                        showingApproveConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve Appeal")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)

                    // Reject button
                    Button {
                        showingRejectConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject Appeal")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Appeal Review")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Approve Appeal?", isPresented: $showingApproveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Approve") {
                resolveAppeal(approved: true)
            }
        } message: {
            Text("This will lift the user's \(appeal.type == "ban" ? "ban" : "suspension") and restore their account access.")
        }
        .alert("Reject Appeal?", isPresented: $showingRejectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                resolveAppeal(approved: false)
            }
        } message: {
            Text("The user's \(appeal.type == "ban" ? "ban" : "suspension") will remain in effect.")
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    private func resolveAppeal(approved: Bool) {
        isProcessing = true
        Task {
            do {
                try await viewModel.resolveAppeal(
                    appealId: appeal.id,
                    userId: appeal.userId,
                    approved: approved,
                    adminResponse: adminResponse.isEmpty ? (approved ? "Your appeal has been approved." : "Your appeal has been reviewed and denied.") : adminResponse
                )
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                HapticManager.shared.notification(.error)
                isProcessing = false
            }
            Logger.shared.info("Appeal \(approved ? "approved" : "rejected") for user \(appeal.userId)", category: .moderation)
        }
    }
}

// MARK: - Suspicious Profile Row

struct SuspiciousProfileRowView: View {
    let item: SuspiciousProfileItem

    var body: some View {
        HStack(spacing: 12) {
            // User photo with severity ring
            ZStack {
                if let user = item.user, let photoURL = user.photoURL {
                    CachedAsyncImage(url: URL(string: photoURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color(.systemGray4))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                }

                // Severity ring
                Circle()
                    .strokeBorder(severityColor, lineWidth: 2.5)
                    .frame(width: 52, height: 52)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.user?.name ?? "Unknown User")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(item.timestamp)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Risk score badge
                HStack(spacing: 6) {
                    Text("\(Int(item.suspicionScore * 100))% Risk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(severityColor)
                        .cornerRadius(4)

                    if !item.indicators.isEmpty {
                        Text(item.indicators.prefix(1).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.quaternaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var severityColor: Color {
        if item.suspicionScore > 0.9 {
            return .red
        } else if item.suspicionScore > 0.75 {
            return .orange
        } else {
            return .yellow
        }
    }
}

// MARK: - Suspicious Profile Detail

struct SuspiciousProfileDetailView: View {
    let item: SuspiciousProfileItem
    @ObservedObject var viewModel: ModerationViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingBanConfirmation = false
    @State private var banReason = ""
    @State private var isBanning = false
    @State private var showPhotoGallery = false
    @State private var selectedPhotoIndex = 0
    @State private var photosToShow: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // User info - PERFORMANCE: Use CachedAsyncImage - Tap to view full screen
                if let user = item.user {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suspicious Profile")
                            .font(.headline)

                        HStack(spacing: 12) {
                            if let photoURL = user.photoURL {
                                CachedAsyncImage(url: URL(string: photoURL)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                                )
                                .onTapGesture {
                                    photosToShow = [photoURL]
                                    selectedPhotoIndex = 0
                                    showPhotoGallery = true
                                    HapticManager.shared.impact(.light)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title3.bold())
                                Text("ID: \(user.id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if user.photoURL != nil {
                                    Text("Tap photo to view")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .fullScreenCover(isPresented: $showPhotoGallery) {
                        AdminPhotoGalleryView(
                            photos: photosToShow,
                            selectedIndex: $selectedPhotoIndex,
                            isPresented: $showPhotoGallery
                        )
                    }
                }

                // Detection details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detection Details")
                        .font(.headline)

                    HStack {
                        Text("Suspicion Score:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(item.suspicionScore * 100))%")
                            .bold()
                            .foregroundColor(item.suspicionScore > 0.85 ? .red : .orange)
                    }

                    if !item.indicators.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Red Flags:")
                                .foregroundColor(.secondary)

                            ForEach(item.indicators, id: \.self) { indicator in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(indicator.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    Text("Auto-detected: \(item.autoDetected ? "Yes" : "No")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Actions
                VStack(spacing: 12) {
                    // Investigate Profile - shows detailed user information
                    NavigationLink(destination: AdminUserInvestigationView(userId: item.user?.id ?? item.id)) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Investigate Profile")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Ban User - same as moderation flow
                    Button(action: {
                        showingBanConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Ban User")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Suspicious Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ban User", isPresented: $showingBanConfirmation) {
            TextField("Reason for ban", text: $banReason)
            Button("Cancel", role: .cancel) { }
            Button("Ban Permanently", role: .destructive) {
                Task {
                    await banUser()
                }
            }
        } message: {
            Text("This user will be permanently banned and their account will be disabled. This action cannot be undone.")
        }
    }

    private func banUser() async {
        guard let user = item.user else { return }

        isBanning = true

        do {
            // Use the existing moderation function if there's a report, or create a synthetic one
            try await viewModel.banUserDirectly(
                userId: user.id,
                reason: banReason.isEmpty ? "Suspicious profile auto-detected with score \(item.suspicionScore)" : banReason
            )

            dismiss()
        } catch {
            Logger.shared.error("Error banning user from suspicious profile view", category: .moderation, error: error)
        }

        isBanning = false
    }
}

// MARK: - View Model

@MainActor
class ModerationViewModel: ObservableObject {
    @Published var reports: [ModerationReport] = []
    @Published var suspiciousProfiles: [SuspiciousProfileItem] = []
    @Published var pendingProfiles: [PendingProfile] = []
    @Published var appeals: [UserAppeal] = []
    @Published var adminAlerts: [AdminAlert] = []
    @Published var unreadAlertCount: Int = 0
    @Published var stats: ModerationStats = ModerationStats()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // Real-time listeners for all admin data
    private var alertsListener: ListenerRegistration?
    private var pendingProfilesListener: ListenerRegistration?
    private var reportsListener: ListenerRegistration?
    private var appealsListener: ListenerRegistration?
    private var suspiciousProfilesListener: ListenerRegistration?

    // Track previous counts for new item detection
    private var previousPendingCount = 0
    private var previousReportsCount = 0
    private var previousAppealsCount = 0
    private var previousSuspiciousCount = 0

    /// Start all real-time listeners for admin dashboard
    func startAllListeners() {
        startListeningToAlerts()
        startListeningToPendingProfiles()
        startListeningToReports()
        startListeningToAppeals()
        startListeningToSuspiciousProfiles()

        // Initial load for stats
        Task {
            stats = await loadStats()
        }
    }

    /// Stop all real-time listeners
    func stopAllListeners() {
        alertsListener?.remove()
        alertsListener = nil
        pendingProfilesListener?.remove()
        pendingProfilesListener = nil
        reportsListener?.remove()
        reportsListener = nil
        appealsListener?.remove()
        appealsListener = nil
        suspiciousProfilesListener?.remove()
        suspiciousProfilesListener = nil
    }

    /// Start listening to admin alerts in real-time
    func startListeningToAlerts() {
        alertsListener?.remove()

        alertsListener = db.collection("admin_alerts")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                let previousCount = self.adminAlerts.count

                self.adminAlerts = documents.compactMap { doc -> AdminAlert? in
                    let data = doc.data()
                    var createdAtStr = "Just now"
                    if let timestamp = data["createdAt"] as? Timestamp {
                        let formatter = RelativeDateTimeFormatter()
                        formatter.unitsStyle = .abbreviated
                        createdAtStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                    }

                    return AdminAlert(
                        id: doc.documentID,
                        type: data["type"] as? String ?? "",
                        userId: data["userId"] as? String ?? "",
                        userName: data["userName"] as? String ?? "Unknown",
                        userEmail: data["userEmail"] as? String ?? "",
                        userPhoto: data["userPhoto"] as? String,
                        createdAt: createdAtStr,
                        read: data["read"] as? Bool ?? false
                    )
                }

                self.unreadAlertCount = self.adminAlerts.filter { !$0.read }.count

                // Notify admin of new alerts with haptic
                if self.adminAlerts.count > previousCount && previousCount > 0 {
                    HapticManager.shared.notification(.warning)
                }
            }
    }

    /// Start listening to pending profiles in real-time
    func startListeningToPendingProfiles() {
        pendingProfilesListener?.remove()

        pendingProfilesListener = db.collection("users")
            .whereField("profileStatus", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                let newProfiles = documents.compactMap { doc -> PendingProfile? in
                    let data = doc.data()

                    var createdAt = "Unknown"
                    var createdAtDate = Date()
                    if let timestamp = data["timestamp"] as? Timestamp {
                        createdAtDate = timestamp.dateValue()
                        let formatter = RelativeDateTimeFormatter()
                        formatter.unitsStyle = .abbreviated
                        createdAt = formatter.localizedString(for: createdAtDate, relativeTo: Date())
                    }

                    return PendingProfile(
                        id: doc.documentID,
                        name: data["fullName"] as? String ?? "Unknown",
                        email: data["email"] as? String ?? "",
                        age: data["age"] as? Int ?? 0,
                        gender: data["gender"] as? String ?? "",
                        location: data["location"] as? String ?? "",
                        country: data["country"] as? String ?? "",
                        photoURL: data["profileImageURL"] as? String,
                        photos: data["photos"] as? [String] ?? [],
                        bio: data["bio"] as? String ?? "",
                        createdAt: createdAt,
                        createdAtDate: createdAtDate,
                        lookingFor: data["lookingFor"] as? String ?? "",
                        interests: data["interests"] as? [String] ?? [],
                        languages: data["languages"] as? [String] ?? [],
                        height: data["height"] as? Int,
                        educationLevel: data["educationLevel"] as? String,
                        religion: data["religion"] as? String,
                        relationshipGoal: data["relationshipGoal"] as? String,
                        smoking: data["smoking"] as? String,
                        drinking: data["drinking"] as? String,
                        exercise: data["exercise"] as? String,
                        pets: data["pets"] as? String,
                        diet: data["diet"] as? String
                    )
                }

                // Detect new items and notify
                if newProfiles.count > self.previousPendingCount && self.previousPendingCount > 0 {
                    HapticManager.shared.notification(.success)
                }
                self.previousPendingCount = newProfiles.count

                withAnimation(.smooth(duration: 0.3)) {
                    self.pendingProfiles = newProfiles
                }
            }
    }

    /// Start listening to reports in real-time
    func startListeningToReports() {
        reportsListener?.remove()

        reportsListener = db.collection("reports")
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    if let error = error {
                        Logger.shared.error("Reports listener error", category: .moderation, error: error)
                    }
                    return
                }

                // Process reports asynchronously to fetch user details
                Task { @MainActor in
                    var loadedReports: [ModerationReport] = []

                    for doc in documents {
                        let data = doc.data()
                        let reporterId = data["reporterId"] as? String ?? ""
                        let reportedUserId = data["reportedUserId"] as? String ?? ""

                        var reporterInfo: ModerationReport.UserInfo? = nil
                        var reportedUserInfo: ModerationReport.UserInfo? = nil

                        // Fetch user details in parallel
                        async let reporterTask: ModerationReport.UserInfo? = {
                            if !reporterId.isEmpty,
                               let reporterDoc = try? await self.db.collection("users").document(reporterId).getDocument(),
                               reporterDoc.exists,
                               let reporterData = reporterDoc.data() {
                                return ModerationReport.UserInfo(
                                    id: reporterId,
                                    name: reporterData["fullName"] as? String ?? "Unknown",
                                    email: reporterData["email"] as? String ?? "",
                                    photoURL: reporterData["profileImageURL"] as? String
                                )
                            }
                            return nil
                        }()

                        async let reportedTask: ModerationReport.UserInfo? = {
                            if !reportedUserId.isEmpty,
                               let reportedDoc = try? await self.db.collection("users").document(reportedUserId).getDocument(),
                               reportedDoc.exists,
                               let reportedData = reportedDoc.data() {
                                return ModerationReport.UserInfo(
                                    id: reportedUserId,
                                    name: reportedData["fullName"] as? String ?? "Unknown",
                                    email: reportedData["email"] as? String ?? "",
                                    photoURL: reportedData["profileImageURL"] as? String
                                )
                            }
                            return nil
                        }()

                        reporterInfo = await reporterTask
                        reportedUserInfo = await reportedTask

                        var timestampStr = "Unknown"
                        if let timestamp = data["timestamp"] as? Timestamp {
                            let formatter = RelativeDateTimeFormatter()
                            formatter.unitsStyle = .abbreviated
                            timestampStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                        }

                        let report = ModerationReport(
                            id: doc.documentID,
                            reason: data["reason"] as? String ?? "Unknown",
                            timestamp: timestampStr,
                            status: data["status"] as? String ?? "pending",
                            additionalDetails: data["additionalDetails"] as? String,
                            reporter: reporterInfo,
                            reportedUser: reportedUserInfo
                        )
                        loadedReports.append(report)
                    }

                    // Detect new reports and notify
                    if loadedReports.count > self.previousReportsCount && self.previousReportsCount > 0 {
                        HapticManager.shared.notification(.warning)
                    }
                    self.previousReportsCount = loadedReports.count

                    withAnimation(.smooth(duration: 0.3)) {
                        self.reports = loadedReports
                    }
                }
            }
    }

    /// Start listening to appeals in real-time
    func startListeningToAppeals() {
        appealsListener?.remove()

        appealsListener = db.collection("appeals")
            .whereField("status", isEqualTo: "pending")
            .order(by: "submittedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    var loadedAppeals: [UserAppeal] = []

                    for doc in documents {
                        let data = doc.data()
                        let userId = data["userId"] as? String ?? ""

                        var userInfo: UserAppeal.UserInfo? = nil
                        if !userId.isEmpty {
                            if let userDoc = try? await self.db.collection("users").document(userId).getDocument(),
                               userDoc.exists,
                               let userData = userDoc.data() {
                                userInfo = UserAppeal.UserInfo(
                                    id: userId,
                                    name: userData["fullName"] as? String ?? "Unknown",
                                    email: userData["email"] as? String ?? "",
                                    photoURL: userData["profileImageURL"] as? String,
                                    isSuspended: userData["isSuspended"] as? Bool ?? false,
                                    isBanned: userData["isBanned"] as? Bool ?? false,
                                    suspendReason: userData["suspendReason"] as? String,
                                    banReason: userData["banReason"] as? String
                                )
                            }
                        }

                        var submittedAtStr = "Unknown"
                        if let timestamp = data["submittedAt"] as? Timestamp {
                            let formatter = RelativeDateTimeFormatter()
                            formatter.unitsStyle = .abbreviated
                            submittedAtStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                        }

                        let appeal = UserAppeal(
                            id: doc.documentID,
                            userId: userId,
                            type: data["type"] as? String ?? "suspension",
                            appealMessage: data["appealMessage"] as? String ?? "",
                            status: data["status"] as? String ?? "pending",
                            submittedAt: submittedAtStr,
                            user: userInfo
                        )
                        loadedAppeals.append(appeal)
                    }

                    // Detect new appeals and notify
                    if loadedAppeals.count > self.previousAppealsCount && self.previousAppealsCount > 0 {
                        HapticManager.shared.notification(.warning)
                    }
                    self.previousAppealsCount = loadedAppeals.count

                    withAnimation(.smooth(duration: 0.3)) {
                        self.appeals = loadedAppeals
                    }
                }
            }
    }

    /// Start listening to suspicious profiles in real-time
    func startListeningToSuspiciousProfiles() {
        suspiciousProfilesListener?.remove()

        suspiciousProfilesListener = db.collection("moderation_queue")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    var loadedProfiles: [SuspiciousProfileItem] = []

                    for doc in documents {
                        let data = doc.data()
                        let userId = data["reportedUserId"] as? String ?? data["userId"] as? String ?? ""

                        var userInfo: SuspiciousProfileItem.UserInfo? = nil
                        if !userId.isEmpty {
                            if let userDoc = try? await self.db.collection("users").document(userId).getDocument(),
                               userDoc.exists,
                               let userData = userDoc.data() {
                                userInfo = SuspiciousProfileItem.UserInfo(
                                    id: userId,
                                    name: userData["fullName"] as? String ?? "Unknown",
                                    photoURL: userData["profileImageURL"] as? String
                                )
                            }
                        }

                        var timestampStr = "Unknown"
                        if let timestamp = data["timestamp"] as? Timestamp {
                            let formatter = RelativeDateTimeFormatter()
                            formatter.unitsStyle = .abbreviated
                            timestampStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                        }

                        let item = SuspiciousProfileItem(
                            id: doc.documentID,
                            suspicionScore: data["suspicionScore"] as? Double ?? 0.5,
                            indicators: data["indicators"] as? [String] ?? [],
                            autoDetected: data["autoDetected"] as? Bool ?? true,
                            timestamp: timestampStr,
                            user: userInfo
                        )
                        loadedProfiles.append(item)
                    }

                    // Detect new suspicious profiles and notify
                    if loadedProfiles.count > self.previousSuspiciousCount && self.previousSuspiciousCount > 0 {
                        HapticManager.shared.notification(.error)
                    }
                    self.previousSuspiciousCount = loadedProfiles.count

                    withAnimation(.smooth(duration: 0.3)) {
                        self.suspiciousProfiles = loadedProfiles
                    }
                }
            }
    }

    /// Stop listening to alerts (legacy - use stopAllListeners instead)
    func stopListeningToAlerts() {
        stopAllListeners()
    }

    /// Mark an alert as read
    func markAlertAsRead(alertId: String) async {
        do {
            try await db.collection("admin_alerts").document(alertId).updateData([
                "read": true
            ])
        } catch {
            Logger.shared.error("Failed to mark alert as read", category: .moderation, error: error)
        }
    }

    /// Mark all alerts as read
    func markAllAlertsAsRead() async {
        for alert in adminAlerts where !alert.read {
            try? await db.collection("admin_alerts").document(alert.id).updateData([
                "read": true
            ])
        }
    }

    /// Load moderation queue directly from Firestore (no Cloud Function required)
    func loadQueue() async {
        isLoading = true
        errorMessage = nil

        do {
            Logger.shared.info("Admin: Loading moderation data from Firestore...", category: .moderation)

            // Load all data in parallel
            async let reportsTask = loadReports()
            async let suspiciousTask = loadSuspiciousProfiles()
            async let pendingTask = loadPendingProfiles()
            async let appealsTask = loadAppeals()
            async let statsTask = loadStats()

            let (loadedReports, loadedSuspicious, loadedPending, loadedAppeals, loadedStats) = await (reportsTask, suspiciousTask, pendingTask, appealsTask, statsTask)

            reports = loadedReports
            suspiciousProfiles = loadedSuspicious
            pendingProfiles = loadedPending
            appeals = loadedAppeals
            stats = loadedStats

            Logger.shared.info("Admin: Loaded \(reports.count) reports, \(suspiciousProfiles.count) suspicious, \(pendingProfiles.count) pending, \(appeals.count) appeals", category: .moderation)

            isLoading = false
        }
    }

    /// Load pending profiles (new accounts waiting for approval)
    private func loadPendingProfiles() async -> [PendingProfile] {
        do {
            let snapshot = try await db.collection("users")
                .whereField("profileStatus", isEqualTo: "pending")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            var profiles: [PendingProfile] = []

            for doc in snapshot.documents {
                let data = doc.data()

                // Format timestamp
                var createdAt = "Unknown"
                var createdAtDate = Date()
                if let timestamp = data["timestamp"] as? Timestamp {
                    createdAtDate = timestamp.dateValue()
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    createdAt = formatter.localizedString(for: createdAtDate, relativeTo: Date())
                }

                let profile = PendingProfile(
                    id: doc.documentID,
                    name: data["fullName"] as? String ?? "Unknown",
                    email: data["email"] as? String ?? "",
                    age: data["age"] as? Int ?? 0,
                    gender: data["gender"] as? String ?? "",
                    location: data["location"] as? String ?? "",
                    country: data["country"] as? String ?? "",
                    photoURL: data["profileImageURL"] as? String,
                    photos: data["photos"] as? [String] ?? [],
                    bio: data["bio"] as? String ?? "",
                    createdAt: createdAt,
                    createdAtDate: createdAtDate,
                    lookingFor: data["lookingFor"] as? String ?? "",
                    interests: data["interests"] as? [String] ?? [],
                    languages: data["languages"] as? [String] ?? [],
                    height: data["height"] as? Int,
                    educationLevel: data["educationLevel"] as? String,
                    religion: data["religion"] as? String,
                    relationshipGoal: data["relationshipGoal"] as? String,
                    smoking: data["smoking"] as? String,
                    drinking: data["drinking"] as? String,
                    exercise: data["exercise"] as? String,
                    pets: data["pets"] as? String,
                    diet: data["diet"] as? String
                )
                profiles.append(profile)
            }

            return profiles
        } catch {
            Logger.shared.error("Admin: Failed to load pending profiles", category: .moderation, error: error)
            return []
        }
    }

    /// Load pending appeals from Firestore
    private func loadAppeals() async -> [UserAppeal] {
        do {
            let snapshot = try await db.collection("appeals")
                .whereField("status", isEqualTo: "pending")
                .order(by: "submittedAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            var loadedAppeals: [UserAppeal] = []

            for doc in snapshot.documents {
                let data = doc.data()
                let userId = data["userId"] as? String ?? ""

                // Fetch user details
                var userInfo: UserAppeal.UserInfo? = nil
                if !userId.isEmpty {
                    if let userDoc = try? await db.collection("users").document(userId).getDocument(),
                       userDoc.exists,
                       let userData = userDoc.data() {
                        userInfo = UserAppeal.UserInfo(
                            id: userId,
                            name: userData["fullName"] as? String ?? "Unknown",
                            email: userData["email"] as? String ?? "",
                            photoURL: userData["profileImageURL"] as? String,
                            isSuspended: userData["isSuspended"] as? Bool ?? false,
                            isBanned: userData["isBanned"] as? Bool ?? false,
                            suspendReason: userData["suspendReason"] as? String,
                            banReason: userData["banReason"] as? String
                        )
                    }
                }

                // Format timestamp
                var submittedAtStr = "Unknown"
                if let timestamp = data["submittedAt"] as? Timestamp {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    submittedAtStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                }

                let appeal = UserAppeal(
                    id: doc.documentID,
                    userId: userId,
                    type: data["type"] as? String ?? "suspension",
                    appealMessage: data["appealMessage"] as? String ?? "",
                    status: data["status"] as? String ?? "pending",
                    submittedAt: submittedAtStr,
                    user: userInfo
                )
                loadedAppeals.append(appeal)
            }

            return loadedAppeals
        } catch {
            Logger.shared.error("Admin: Failed to load appeals", category: .moderation, error: error)
            return []
        }
    }

    /// Resolve an appeal - approve (lift ban/suspension) or reject
    func resolveAppeal(appealId: String, userId: String, approved: Bool, adminResponse: String) async throws {
        // Update appeal status
        try await db.collection("appeals").document(appealId).updateData([
            "status": approved ? "approved" : "rejected",
            "resolvedAt": FieldValue.serverTimestamp(),
            "adminResponse": adminResponse
        ])

        if approved {
            // Get user data to determine if banned or suspended
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data()
            let isBanned = userData?["isBanned"] as? Bool ?? false

            if isBanned {
                // Lift the ban
                try await db.collection("users").document(userId).updateData([
                    "isBanned": false,
                    "bannedAt": FieldValue.delete(),
                    "banReason": FieldValue.delete(),
                    "profileStatus": "active",
                    "showMeInSearch": true
                ])
                Logger.shared.info("Ban lifted for user \(userId) via appeal", category: .moderation)
            } else {
                // Lift the suspension
                try await db.collection("users").document(userId).updateData([
                    "isSuspended": false,
                    "suspendedAt": FieldValue.delete(),
                    "suspendedUntil": FieldValue.delete(),
                    "suspendReason": FieldValue.delete(),
                    "profileStatus": "active",
                    "showMeInSearch": true
                ])
                Logger.shared.info("Suspension lifted for user \(userId) via appeal", category: .moderation)
            }

            // Send notification to user about approved appeal
            await sendAppealResolvedNotification(userId: userId, approved: true, response: adminResponse)
        } else {
            // Just notify the user that appeal was rejected
            await sendAppealResolvedNotification(userId: userId, approved: false, response: adminResponse)
            Logger.shared.info("Appeal rejected for user \(userId)", category: .moderation)
        }

        // Refresh queue
        await loadQueue()
    }

    /// Send appeal resolution notification via Cloud Function
    private func sendAppealResolvedNotification(userId: String, approved: Bool, response: String) async {
        do {
            let callable = functions.httpsCallable("sendAppealResolvedNotification")
            _ = try await callable.call([
                "userId": userId,
                "approved": approved,
                "response": response
            ])
            Logger.shared.info("Appeal resolution notification sent to \(userId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send appeal resolution notification", category: .moderation, error: error)
        }
    }

    /// Approve a pending profile - makes user visible to others
    func approveProfile(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileStatus": "active",
            "profileStatusUpdatedAt": FieldValue.serverTimestamp(),
            "showMeInSearch": true  // Make user visible to others
        ])

        // Send push notification to user about approval
        await sendProfileStatusNotification(userId: userId, status: "approved", reason: nil, reasonCode: nil)

        // Refresh to update list
        await loadQueue()
        Logger.shared.info("Profile approved: \(userId)", category: .moderation)
    }

    /// Reject a pending profile with detailed reason and fix instructions
    func rejectProfile(userId: String, reasonCode: String, reasonMessage: String, fixInstructions: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileStatus": "rejected",
            "profileStatusReason": reasonMessage,
            "profileStatusReasonCode": reasonCode,
            "profileStatusFixInstructions": fixInstructions,
            "profileStatusUpdatedAt": FieldValue.serverTimestamp(),
            "showMeInSearch": false
        ])

        // Send push notification to user about rejection
        await sendProfileStatusNotification(userId: userId, status: "rejected", reason: reasonMessage, reasonCode: reasonCode)

        // Refresh to update list
        await loadQueue()
        Logger.shared.info("Profile rejected: \(userId) - Reason: \(reasonCode)", category: .moderation)
    }

    /// Flag a profile for extended review - hides user from others while under investigation
    /// The user will see FlaggedAccountView (ContentView.swift routes profileStatus="flagged")
    func flagProfile(userId: String, reason: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileStatus": "flagged",
            "profileStatusReason": reason,
            "profileStatusUpdatedAt": FieldValue.serverTimestamp(),
            "showMeInSearch": false  // Hide from other users during review
        ])

        // Send push notification to user about flagged status
        await sendProfileStatusNotification(userId: userId, status: "flagged", reason: reason, reasonCode: nil)

        // Refresh to update list
        await loadQueue()
        Logger.shared.info("Profile flagged for review: \(userId) - Reason: \(reason)", category: .moderation)
    }

    /// Send profile status notification via Cloud Function
    private func sendProfileStatusNotification(userId: String, status: String, reason: String?, reasonCode: String?) async {
        do {
            let callable = functions.httpsCallable("sendProfileStatusNotification")
            _ = try await callable.call([
                "userId": userId,
                "status": status,
                "reason": reason ?? "",
                "reasonCode": reasonCode ?? ""
            ])
            Logger.shared.info("Profile status notification sent to \(userId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send profile status notification", category: .moderation, error: error)
        }
    }

    /// Load reports from Firestore
    private func loadReports() async -> [ModerationReport] {
        do {
            let snapshot = try await db.collection("reports")
                .whereField("status", isEqualTo: "pending")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            var loadedReports: [ModerationReport] = []

            for doc in snapshot.documents {
                let data = doc.data()
                let reporterId = data["reporterId"] as? String ?? ""
                let reportedUserId = data["reportedUserId"] as? String ?? ""

                // Fetch user details for reporter and reported user
                var reporterInfo: ModerationReport.UserInfo? = nil
                var reportedUserInfo: ModerationReport.UserInfo? = nil

                if !reporterId.isEmpty {
                    if let reporterDoc = try? await db.collection("users").document(reporterId).getDocument(),
                       reporterDoc.exists,
                       let reporterData = reporterDoc.data() {
                        reporterInfo = ModerationReport.UserInfo(
                            id: reporterId,
                            name: reporterData["fullName"] as? String ?? "Unknown",
                            email: reporterData["email"] as? String ?? "",
                            photoURL: reporterData["profileImageURL"] as? String
                        )
                    }
                }

                if !reportedUserId.isEmpty {
                    if let reportedDoc = try? await db.collection("users").document(reportedUserId).getDocument(),
                       reportedDoc.exists,
                       let reportedData = reportedDoc.data() {
                        reportedUserInfo = ModerationReport.UserInfo(
                            id: reportedUserId,
                            name: reportedData["fullName"] as? String ?? "Unknown",
                            email: reportedData["email"] as? String ?? "",
                            photoURL: reportedData["profileImageURL"] as? String
                        )
                    }
                }

                // Format timestamp
                var timestampStr = "Unknown"
                if let timestamp = data["timestamp"] as? Timestamp {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    timestampStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                }

                let report = ModerationReport(
                    id: doc.documentID,
                    reason: data["reason"] as? String ?? "Unknown",
                    timestamp: timestampStr,
                    status: data["status"] as? String ?? "pending",
                    additionalDetails: data["additionalDetails"] as? String,
                    reporter: reporterInfo,
                    reportedUser: reportedUserInfo
                )
                loadedReports.append(report)
            }

            return loadedReports
        } catch {
            Logger.shared.error("Admin: Failed to load reports", category: .moderation, error: error)
            await MainActor.run { errorMessage = "Failed to load reports: \(error.localizedDescription)" }
            return []
        }
    }

    /// Load suspicious profiles from moderation queue
    private func loadSuspiciousProfiles() async -> [SuspiciousProfileItem] {
        do {
            let snapshot = try await db.collection("moderation_queue")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            var loadedProfiles: [SuspiciousProfileItem] = []

            for doc in snapshot.documents {
                let data = doc.data()
                let userId = data["reportedUserId"] as? String ?? data["userId"] as? String ?? ""

                // Fetch user details
                var userInfo: SuspiciousProfileItem.UserInfo? = nil
                if !userId.isEmpty {
                    if let userDoc = try? await db.collection("users").document(userId).getDocument(),
                       userDoc.exists,
                       let userData = userDoc.data() {
                        userInfo = SuspiciousProfileItem.UserInfo(
                            id: userId,
                            name: userData["fullName"] as? String ?? "Unknown",
                            photoURL: userData["profileImageURL"] as? String
                        )
                    }
                }

                // Format timestamp
                var timestampStr = "Unknown"
                if let timestamp = data["timestamp"] as? Timestamp {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    timestampStr = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                }

                let item = SuspiciousProfileItem(
                    id: doc.documentID,
                    suspicionScore: data["suspicionScore"] as? Double ?? 0.5,
                    indicators: data["indicators"] as? [String] ?? [],
                    autoDetected: data["autoDetected"] as? Bool ?? true,
                    timestamp: timestampStr,
                    user: userInfo
                )
                loadedProfiles.append(item)
            }

            return loadedProfiles
        } catch {
            Logger.shared.error("Admin: Failed to load suspicious profiles", category: .moderation, error: error)
            return []
        }
    }

    /// Load stats from Firestore
    private func loadStats() async -> ModerationStats {
        do {
            // Count total reports
            let totalSnapshot = try await db.collection("reports").getDocuments()
            let totalReports = totalSnapshot.documents.count

            // Count pending reports
            let pendingSnapshot = try await db.collection("reports")
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            let pendingReports = pendingSnapshot.documents.count

            // Count resolved reports
            let resolvedReports = totalReports - pendingReports

            // Count suspicious profiles
            let suspiciousSnapshot = try await db.collection("moderation_queue").getDocuments()
            let suspiciousCount = suspiciousSnapshot.documents.count

            return ModerationStats(
                totalReports: totalReports,
                pendingReports: pendingReports,
                resolvedReports: resolvedReports,
                suspiciousProfiles: suspiciousCount
            )
        } catch {
            Logger.shared.error("Admin: Failed to load stats", category: .moderation, error: error)
            return ModerationStats()
        }
    }

    func refresh() async {
        await loadQueue()
    }

    /// Moderate a report - update status in Firestore
    func moderateReport(reportId: String, action: ModerationAction, reason: String?) async throws {
        let reportRef = db.collection("reports").document(reportId)
        let reportDoc = try await reportRef.getDocument()

        guard let data = reportDoc.data(),
              let reportedUserId = data["reportedUserId"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Report not found"])
        }

        // Get reporter ID for notification
        let reporterId = data["reporterId"] as? String

        // Update report status
        try await reportRef.updateData([
            "status": "resolved",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolution": action.rawValue,
            "resolutionReason": reason ?? ""
        ])

        // Take action on user based on moderation decision
        if action == .ban {
            try await banUserInFirestore(userId: reportedUserId, reason: reason ?? "Banned due to report")
        } else if action == .suspend {
            try await suspendUserInFirestore(userId: reportedUserId, days: 7, reason: reason ?? "Suspended due to report")
        } else if action == .warn {
            try await warnUserInFirestore(userId: reportedUserId, reason: reason ?? "Warning issued")
        }

        // Send notification to reporter about the resolution
        if let reporterId = reporterId {
            await sendReportResolvedNotification(reporterId: reporterId, action: action.rawValue, reportId: reportId)
        }

        // Refresh queue
        await loadQueue()
    }

    /// Send report resolved notification to reporter via Cloud Function
    private func sendReportResolvedNotification(reporterId: String, action: String, reportId: String) async {
        do {
            let callable = functions.httpsCallable("sendReportResolvedNotification")
            _ = try await callable.call([
                "reporterId": reporterId,
                "action": action,
                "reportId": reportId
            ])
            Logger.shared.info("Report resolution notification sent to reporter: \(reporterId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send report resolution notification", category: .moderation, error: error)
        }
    }

    /// Ban user directly (without needing a report)
    func banUserDirectly(userId: String, reason: String) async throws {
        try await banUserInFirestore(userId: userId, reason: reason)

        // Remove from moderation queue if present
        let queueSnapshot = try await db.collection("moderation_queue")
            .whereField("reportedUserId", isEqualTo: userId)
            .getDocuments()

        for doc in queueSnapshot.documents {
            try await doc.reference.delete()
        }

        // Refresh queue
        await loadQueue()

        Logger.shared.info("User banned directly from admin panel: \(userId)", category: .moderation)
    }

    /// Ban user in Firestore
    private func banUserInFirestore(userId: String, reason: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "isBanned": true,
            "bannedAt": FieldValue.serverTimestamp(),
            "banReason": reason,
            "profileStatus": "banned",
            "showMeInSearch": false
        ])

        // Send push notification to user about ban
        await sendBanNotification(userId: userId, reason: reason)

        Logger.shared.info("User banned: \(userId)", category: .moderation)
    }

    /// Send ban notification via Cloud Function
    private func sendBanNotification(userId: String, reason: String) async {
        do {
            let callable = functions.httpsCallable("sendBanNotification")
            _ = try await callable.call([
                "userId": userId,
                "reason": reason
            ])
            Logger.shared.info("Ban notification sent to \(userId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send ban notification", category: .moderation, error: error)
        }
    }

    /// Suspend user in Firestore
    private func suspendUserInFirestore(userId: String, days: Int, reason: String) async throws {
        let suspendedUntil = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()

        try await db.collection("users").document(userId).updateData([
            "isSuspended": true,
            "suspendedAt": FieldValue.serverTimestamp(),
            "suspendedUntil": Timestamp(date: suspendedUntil),
            "suspendReason": reason,
            "profileStatus": "suspended",
            "showMeInSearch": false
        ])

        // Send push notification to user about suspension
        await sendSuspensionNotification(userId: userId, reason: reason, days: days, suspendedUntil: suspendedUntil)

        Logger.shared.info("User suspended for \(days) days: \(userId)", category: .moderation)
    }

    /// Send suspension notification via Cloud Function
    private func sendSuspensionNotification(userId: String, reason: String, days: Int, suspendedUntil: Date) async {
        do {
            let callable = functions.httpsCallable("sendSuspensionNotification")
            let formatter = ISO8601DateFormatter()
            _ = try await callable.call([
                "userId": userId,
                "reason": reason,
                "days": days,
                "suspendedUntil": formatter.string(from: suspendedUntil)
            ])
            Logger.shared.info("Suspension notification sent to \(userId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send suspension notification", category: .moderation, error: error)
        }
    }

    /// Warn user in Firestore
    private func warnUserInFirestore(userId: String, reason: String) async throws {
        // Get current warning count first
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let currentCount = userDoc.data()?["warningCount"] as? Int ?? 0

        try await db.collection("users").document(userId).updateData([
            "warnings": FieldValue.arrayUnion([
                [
                    "reason": reason,
                    "timestamp": Timestamp(date: Date())
                ]
            ]),
            "warningCount": FieldValue.increment(Int64(1)),
            "hasUnreadWarning": true,
            "lastWarningReason": reason
        ])

        // Send push notification to user about warning
        await sendWarningNotification(userId: userId, reason: reason, warningCount: currentCount + 1)

        Logger.shared.info("Warning issued to user: \(userId)", category: .moderation)
    }

    /// Send warning notification via Cloud Function
    private func sendWarningNotification(userId: String, reason: String, warningCount: Int) async {
        do {
            let callable = functions.httpsCallable("sendWarningNotification")
            _ = try await callable.call([
                "userId": userId,
                "reason": reason,
                "warningCount": warningCount
            ])
            Logger.shared.info("Warning notification sent to \(userId)", category: .moderation)
        } catch {
            Logger.shared.error("Failed to send warning notification", category: .moderation, error: error)
        }
    }
}

// MARK: - Models

struct ModerationReport: Identifiable {
    let id: String
    let reason: String
    let timestamp: String
    let status: String
    let additionalDetails: String?
    let reporter: UserInfo?
    let reportedUser: UserInfo?

    struct UserInfo {
        let id: String
        let name: String
        let email: String
        let photoURL: String?
    }

    // Direct initializer for Firestore data
    init(id: String, reason: String, timestamp: String, status: String, additionalDetails: String?, reporter: UserInfo?, reportedUser: UserInfo?) {
        self.id = id
        self.reason = reason
        self.timestamp = timestamp
        self.status = status
        self.additionalDetails = additionalDetails
        self.reporter = reporter
        self.reportedUser = reportedUser
    }

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let reason = dict["reason"] as? String,
              let timestamp = dict["timestamp"] as? String,
              let status = dict["status"] as? String else {
            return nil
        }

        self.id = id
        self.reason = reason
        self.timestamp = timestamp
        self.status = status
        self.additionalDetails = dict["additionalDetails"] as? String

        if let reporterData = dict["reporter"] as? [String: Any] {
            self.reporter = UserInfo(
                id: reporterData["id"] as? String ?? "",
                name: reporterData["name"] as? String ?? "",
                email: reporterData["email"] as? String ?? "",
                photoURL: reporterData["photoURL"] as? String
            )
        } else {
            self.reporter = nil
        }

        if let reportedData = dict["reportedUser"] as? [String: Any] {
            self.reportedUser = UserInfo(
                id: reportedData["id"] as? String ?? "",
                name: reportedData["name"] as? String ?? "",
                email: reportedData["email"] as? String ?? "",
                photoURL: reportedData["photoURL"] as? String
            )
        } else {
            self.reportedUser = nil
        }
    }
}

struct UserAppeal: Identifiable {
    let id: String
    let userId: String
    let type: String  // "suspension" or "ban"
    let appealMessage: String
    let status: String  // "pending", "approved", "rejected"
    let submittedAt: String
    let user: UserInfo?

    struct UserInfo {
        let id: String
        let name: String
        let email: String
        let photoURL: String?
        let isSuspended: Bool
        let isBanned: Bool
        let suspendReason: String?
        let banReason: String?
    }

    var typeDisplayName: String {
        type == "ban" ? "Ban Appeal" : "Suspension Appeal"
    }

    var actionReason: String? {
        user?.isBanned == true ? user?.banReason : user?.suspendReason
    }
}

struct SuspiciousProfileItem: Identifiable {
    let id: String
    let suspicionScore: Double
    let indicators: [String]
    let autoDetected: Bool
    let timestamp: String
    let user: UserInfo?

    struct UserInfo {
        let id: String
        let name: String
        let photoURL: String?
    }

    // Direct initializer for Firestore data
    init(id: String, suspicionScore: Double, indicators: [String], autoDetected: Bool, timestamp: String, user: UserInfo?) {
        self.id = id
        self.suspicionScore = suspicionScore
        self.indicators = indicators
        self.autoDetected = autoDetected
        self.timestamp = timestamp
        self.user = user
    }

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let suspicionScore = dict["suspicionScore"] as? Double,
              let indicators = dict["indicators"] as? [String],
              let autoDetected = dict["autoDetected"] as? Bool,
              let timestamp = dict["timestamp"] as? String else {
            return nil
        }

        self.id = id
        self.suspicionScore = suspicionScore
        self.indicators = indicators
        self.autoDetected = autoDetected
        self.timestamp = timestamp

        if let userData = dict["user"] as? [String: Any] {
            self.user = UserInfo(
                id: userData["id"] as? String ?? "",
                name: userData["name"] as? String ?? "",
                photoURL: userData["photoURL"] as? String
            )
        } else {
            self.user = nil
        }
    }
}

struct ModerationStats {
    let totalReports: Int
    let pendingReports: Int
    let resolvedReports: Int
    let suspiciousProfiles: Int

    init() {
        self.totalReports = 0
        self.pendingReports = 0
        self.resolvedReports = 0
        self.suspiciousProfiles = 0
    }

    // Direct initializer for Firestore data
    init(totalReports: Int, pendingReports: Int, resolvedReports: Int, suspiciousProfiles: Int) {
        self.totalReports = totalReports
        self.pendingReports = pendingReports
        self.resolvedReports = resolvedReports
        self.suspiciousProfiles = suspiciousProfiles
    }

    init(dict: [String: Any]) {
        self.totalReports = dict["totalReports"] as? Int ?? 0
        self.pendingReports = dict["pendingReports"] as? Int ?? 0
        self.resolvedReports = dict["resolvedReports"] as? Int ?? 0
        self.suspiciousProfiles = dict["suspiciousProfiles"] as? Int ?? 0
    }
}

enum ModerationAction: String {
    case dismiss
    case warn
    case suspend
    case ban

    var buttonTitle: String {
        switch self {
        case .dismiss: return "Dismiss Report"
        case .warn: return "Warn User"
        case .suspend: return "Suspend 7 Days"
        case .ban: return "Ban Permanently"
        }
    }

    var confirmTitle: String {
        switch self {
        case .dismiss: return "Dismiss"
        case .warn: return "Warn User"
        case .suspend: return "Suspend"
        case .ban: return "Ban"
        }
    }

    var confirmMessage: String {
        switch self {
        case .dismiss: return "Close this report without taking action?"
        case .warn: return "Send a warning to this user?"
        case .suspend: return "Suspend this user for 7 days?"
        case .ban: return "Permanently ban this user? This cannot be undone."
        }
    }

    var icon: String {
        switch self {
        case .dismiss: return "xmark.circle"
        case .warn: return "exclamationmark.triangle"
        case .suspend: return "pause.circle"
        case .ban: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .dismiss: return .gray
        case .warn: return .orange
        case .suspend: return .purple
        case .ban: return .red
        }
    }
}

// MARK: - Pending Profile Model

struct PendingProfile: Identifiable {
    let id: String
    let name: String
    let email: String
    let age: Int
    let gender: String
    let location: String
    let country: String
    let photoURL: String?
    let photos: [String]
    let bio: String
    let createdAt: String
    let createdAtDate: Date

    // Profile preferences
    let lookingFor: String
    let interests: [String]
    let languages: [String]

    // Lifestyle fields
    let height: Int?
    let educationLevel: String?
    let religion: String?
    let relationshipGoal: String?
    let smoking: String?
    let drinking: String?
    let exercise: String?
    let pets: String?
    let diet: String?
}

// MARK: - Admin Alert Model

struct AdminAlert: Identifiable {
    let id: String
    let type: String
    let userId: String
    let userName: String
    let userEmail: String
    let userPhoto: String?
    let createdAt: String
    let read: Bool

    var title: String {
        switch type {
        case "new_pending_account":
            return "New Account Pending"
        case "profile_reported":
            return "Profile Reported"
        case "suspicious_activity":
            return "Suspicious Activity"
        default:
            return "Alert"
        }
    }

    var icon: String {
        switch type {
        case "new_pending_account":
            return "person.badge.plus"
        case "profile_reported":
            return "exclamationmark.triangle"
        case "suspicious_activity":
            return "eye.trianglebadge.exclamationmark"
        default:
            return "bell"
        }
    }

    var iconColor: Color {
        switch type {
        case "new_pending_account":
            return .blue
        case "profile_reported":
            return .orange
        case "suspicious_activity":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Pending Profile Card View (Redesigned)

struct PendingProfileCard: View {
    let profile: PendingProfile
    @ObservedObject var viewModel: ModerationViewModel
    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var isFlagging = false
    @State private var showRejectAlert = false
    @State private var showFlagAlert = false
    @State private var flagReason = ""
    @State private var currentPhotoIndex = 0
    @State private var showPhotoGallery = false
    @State private var showProfileDetail = false

    // Admin comment flow
    @State private var selectedRejectionReason: ProfileRejectionReason?
    @State private var showAdminCommentSheet = false
    @State private var adminComment = ""

    // Fixed height for consistent card sizing
    private let photoHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            // Photo Gallery with overlay info
            ZStack(alignment: .bottom) {
                // Photos
                TabView(selection: $currentPhotoIndex) {
                    ForEach(Array(profile.photos.enumerated()), id: \.offset) { index, photoURL in
                        if let url = URL(string: photoURL) {
                            GeometryReader { geo in
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: photoHeight)
                                            .clipped()
                                    case .failure:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: geo.size.width, height: photoHeight)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 32))
                                                    Text("Failed to load")
                                                        .font(.caption)
                                                }
                                                .foregroundColor(.secondary)
                                            )
                                    case .empty:
                                        Rectangle()
                                            .fill(Color(.systemGray6))
                                            .frame(width: geo.size.width, height: photoHeight)
                                            .overlay(ProgressView())
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    currentPhotoIndex = index
                                    showPhotoGallery = true
                                    HapticManager.shared.impact(.light)
                                }
                            }
                            .frame(height: photoHeight)
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: photoHeight)

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)

                // Bottom overlay with name, age, and info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(profile.age)")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Label(profile.location, systemImage: "mappin.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                        Label(profile.gender, systemImage: "person.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Top badges
                HStack {
                    // Time badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(profile.createdAt)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)

                    Spacer()

                    // Photo count
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 10))
                        Text("\(profile.photos.count)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Photo indicators
                if profile.photos.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<profile.photos.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentPhotoIndex ? 20 : 6, height: 4)
                                .animation(.easeInOut(duration: 0.2), value: currentPhotoIndex)
                        }
                    }
                    .padding(.bottom, 70)
                }
            }
            .frame(height: photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .fullScreenCover(isPresented: $showPhotoGallery) {
                AdminPhotoGalleryView(
                    photos: profile.photos,
                    selectedIndex: $currentPhotoIndex,
                    isPresented: $showPhotoGallery
                )
            }

            // Profile Details Section
            VStack(alignment: .leading, spacing: 14) {
                // Email row
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text(profile.email)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()

                    // View full profile button
                    Button {
                        showProfileDetail = true
                        HapticManager.shared.impact(.light)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Full Profile")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Tags section
                if !profile.interests.isEmpty || !profile.languages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if !profile.lookingFor.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 9))
                                    Text(profile.lookingFor)
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.pink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.pink.opacity(0.1))
                                .cornerRadius(6)
                            }

                            ForEach(profile.interests.prefix(3), id: \.self) { interest in
                                Text(interest)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }

                            ForEach(profile.languages.prefix(2), id: \.self) { language in
                                HStack(spacing: 3) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 9))
                                    Text(language)
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Bio
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Action Buttons
                HStack(spacing: 10) {
                    // Reject Button
                    Button {
                        HapticManager.shared.impact(.light)
                        showRejectAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            if isRejecting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("Reject")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isApproving || isRejecting || isFlagging)

                    // Flag Button
                    Button {
                        HapticManager.shared.impact(.light)
                        showFlagAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            if isFlagging {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("Flag")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isApproving || isRejecting || isFlagging)

                    // Approve Button
                    Button {
                        HapticManager.shared.impact(.medium)
                        Task {
                            isApproving = true
                            do {
                                try await viewModel.approveProfile(userId: profile.id)
                                HapticManager.shared.notification(.success)
                            } catch {
                                HapticManager.shared.notification(.error)
                                Logger.shared.error("Failed to approve profile", category: .moderation, error: error)
                            }
                            isApproving = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isApproving {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("Approve")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isApproving || isRejecting || isFlagging)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .confirmationDialog("Reject Profile", isPresented: $showRejectAlert, titleVisibility: .visible) {
            // Photo Issues
            Button("📸 No Clear Face Photo", role: .destructive) {
                selectReasonAndShowComment(.noFacePhoto)
            }
            Button("📷 Low Quality Photos", role: .destructive) {
                selectReasonAndShowComment(.lowQualityPhotos)
            }
            Button("🔍 Fake/Stock Photos", role: .destructive) {
                selectReasonAndShowComment(.fakePhotos)
            }
            Button("🚫 Inappropriate Content", role: .destructive) {
                selectReasonAndShowComment(.inappropriatePhotos)
            }
            // Bio Issues
            Button("✏️ Incomplete Bio", role: .destructive) {
                selectReasonAndShowComment(.incompleteBio)
            }
            Button("📵 Contact Info in Bio", role: .destructive) {
                selectReasonAndShowComment(.contactInfoInBio)
            }
            // Account Issues
            Button("🔞 Suspected Underage", role: .destructive) {
                selectReasonAndShowComment(.underage)
            }
            Button("📢 Spam/Promotional", role: .destructive) {
                selectReasonAndShowComment(.spam)
            }
            Button("⚠️ Offensive Content", role: .destructive) {
                selectReasonAndShowComment(.offensiveContent)
            }
            Button("👥 Multiple Accounts", role: .destructive) {
                selectReasonAndShowComment(.multipleAccounts)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Select why \(profile.name)'s profile needs changes")
        }
        // Admin Comment Sheet (optional note before rejecting)
        .sheet(isPresented: $showAdminCommentSheet) {
            AdminRejectCommentSheet(
                profileName: profile.name,
                reason: selectedRejectionReason,
                adminComment: $adminComment,
                isRejecting: $isRejecting,
                onSubmit: {
                    submitRejection()
                },
                onCancel: {
                    adminComment = ""
                    selectedRejectionReason = nil
                }
            )
        }
        // Flag for extended review alert
        // User will be shown FlaggedAccountView (ContentView.swift handles routing)
        .alert("Flag for Extended Review", isPresented: $showFlagAlert) {
            TextField("Reason for flagging", text: $flagReason)
            Button("Flag Profile", role: .destructive) {
                submitFlag()
            }
            Button("Cancel", role: .cancel) {
                flagReason = ""
            }
        } message: {
            Text("This will hide the profile from other users and notify them that their profile is under review. Add a reason for the flag.")
        }
        // Full Profile Detail Sheet
        .sheet(isPresented: $showProfileDetail) {
            AdminPendingProfileDetailView(
                profile: profile,
                onApprove: {
                    showProfileDetail = false
                    HapticManager.shared.impact(.medium)
                    Task {
                        isApproving = true
                        do {
                            try await viewModel.approveProfile(userId: profile.id)
                            HapticManager.shared.notification(.success)
                        } catch {
                            HapticManager.shared.notification(.error)
                        }
                        isApproving = false
                    }
                },
                onReject: {
                    showProfileDetail = false
                    showRejectAlert = true
                }
            )
        }
    }

    /// Select a rejection reason and show the optional admin comment sheet
    private func selectReasonAndShowComment(_ reason: ProfileRejectionReason) {
        selectedRejectionReason = reason
        adminComment = ""
        showAdminCommentSheet = true
    }

    /// Submit the rejection with optional admin comment
    private func submitRejection() {
        guard let reason = selectedRejectionReason else { return }
        HapticManager.shared.impact(.medium)
        Task {
            isRejecting = true

            // Build fix instructions - add admin comment if provided
            var finalInstructions = reason.fixInstructions
            if !adminComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalInstructions += "\n\n📝 Additional Note from Admin:\n\(adminComment)"
            }

            do {
                try await viewModel.rejectProfile(
                    userId: profile.id,
                    reasonCode: reason.code,
                    reasonMessage: reason.userMessage,
                    fixInstructions: finalInstructions
                )
                HapticManager.shared.notification(.warning)
            } catch {
                HapticManager.shared.notification(.error)
                Logger.shared.error("Failed to reject profile", category: .moderation, error: error)
            }

            isRejecting = false
            adminComment = ""
            selectedRejectionReason = nil
        }
    }

    /// Submit the flag action
    private func submitFlag() {
        guard !flagReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        HapticManager.shared.impact(.medium)
        Task {
            isFlagging = true
            do {
                try await viewModel.flagProfile(userId: profile.id, reason: flagReason)
                HapticManager.shared.notification(.warning)
            } catch {
                HapticManager.shared.notification(.error)
                Logger.shared.error("Failed to flag profile", category: .moderation, error: error)
            }
            isFlagging = false
            flagReason = ""
        }
    }

}

// MARK: - Admin Reject Comment Sheet

/// Sheet for adding optional admin comment before rejecting a profile
struct AdminRejectCommentSheet: View {
    let profileName: String
    let reason: ProfileRejectionReason?
    @Binding var adminComment: String
    @Binding var isRejecting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Reason summary card
                if let reason = reason {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Rejection Reason")
                                .font(.headline)
                        }

                        Text(reason.userMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }

                // Admin comment input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "pencil.and.scribble")
                            .foregroundColor(.blue)
                        Text("Admin Comment")
                            .font(.headline)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Add a personal note for \(profileName). Leave blank to use only the standard message.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $adminComment)
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if adminComment.isEmpty {
                                Text("e.g., \"Please upload a photo without sunglasses\" or \"Your main photo should be just you, not a group photo\"")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Reject button
                    Button(action: {
                        dismiss()
                        onSubmit()
                    }) {
                        HStack(spacing: 10) {
                            if isRejecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                Text(adminComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reject Profile" : "Reject with Comment")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(isRejecting)

                    // Cancel button
                    Button(action: {
                        dismiss()
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .disabled(isRejecting)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reject \(profileName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                    .disabled(isRejecting)
                }
            }
            .onAppear {
                // Auto-focus the text field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Admin Pending Profile Detail View

/// Full profile detail view for admin review of pending profiles
struct AdminPendingProfileDetailView: View {
    let profile: PendingProfile
    let onApprove: () -> Void
    let onReject: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Photos carousel
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(profile.photos.enumerated()), id: \.offset) { index, photoURL in
                            if let url = URL(string: photoURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray)
                                            )
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.1))
                                            .overlay(ProgressView())
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 400)
                                .clipped()
                                .tag(index)
                            }
                        }
                    }
                    .frame(height: 400)
                    .tabViewStyle(.page)

                    // Profile content
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        profileHeaderSection

                        // Contact
                        contactSection

                        // Bio
                        if !profile.bio.isEmpty {
                            bioSection
                        }

                        // Languages
                        if !profile.languages.isEmpty {
                            languagesSection
                        }

                        // Interests
                        if !profile.interests.isEmpty {
                            interestsSection
                        }

                        // Details
                        if hasDetails {
                            detailsSection
                        }

                        // Lifestyle
                        if hasLifestyle {
                            lifestyleSection
                        }

                        // Looking for
                        lookingForSection
                    }
                    .padding(20)
                    .padding(.bottom, 80)
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) {
                actionButtons
            }
            .navigationTitle("Profile Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var profileHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(profile.name)
                    .font(.system(size: 28, weight: .bold))

                Text("\(profile.age)")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(profile.location)\(profile.country.isEmpty ? "" : ", \(profile.country)")")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            HStack(spacing: 8) {
                Label(profile.gender, systemImage: "person.fill")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)

                Text("Joined \(profile.createdAtDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Contact", systemImage: "envelope.fill")
                .font(.headline)
                .foregroundColor(.blue)

            Text(profile.email)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "text.quote")
                .font(.headline)
                .foregroundColor(.purple)

            Text(profile.bio)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Languages", systemImage: "globe")
                .font(.headline)
                .foregroundColor(.green)

            AdminFlowLayout(spacing: 8) {
                ForEach(profile.languages, id: \.self) { language in
                    Text(language)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Interests", systemImage: "heart.fill")
                .font(.headline)
                .foregroundColor(.pink)

            AdminFlowLayout(spacing: 8) {
                ForEach(profile.interests, id: \.self) { interest in
                    Text(interest)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.1))
                        .foregroundColor(.pink)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Details Section

    private var hasDetails: Bool {
        profile.height != nil ||
        (profile.educationLevel.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.religion.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.relationshipGoal.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundColor(.indigo)

            VStack(spacing: 10) {
                if let height = profile.height {
                    AdminDetailRow(icon: "ruler", label: "Height", value: "\(height) cm")
                }
                if let education = profile.educationLevel, education != "Prefer not to say", !education.isEmpty {
                    AdminDetailRow(icon: "graduationcap.fill", label: "Education", value: education)
                }
                if let religion = profile.religion, religion != "Prefer not to say", !religion.isEmpty {
                    AdminDetailRow(icon: "sparkles", label: "Religion", value: religion)
                }
                if let goal = profile.relationshipGoal, goal != "Prefer not to say", !goal.isEmpty {
                    AdminDetailRow(icon: "heart.circle", label: "Looking for", value: goal)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Lifestyle Section

    private var hasLifestyle: Bool {
        (profile.smoking.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.drinking.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.exercise.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.diet.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false) ||
        (profile.pets.map { $0 != "Prefer not to say" && !$0.isEmpty } ?? false)
    }

    private var lifestyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lifestyle", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundColor(.green)

            VStack(spacing: 10) {
                if let smoking = profile.smoking, smoking != "Prefer not to say", !smoking.isEmpty {
                    AdminDetailRow(icon: "smoke", label: "Smoking", value: smoking)
                }
                if let drinking = profile.drinking, drinking != "Prefer not to say", !drinking.isEmpty {
                    AdminDetailRow(icon: "wineglass", label: "Drinking", value: drinking)
                }
                if let exercise = profile.exercise, exercise != "Prefer not to say", !exercise.isEmpty {
                    AdminDetailRow(icon: "figure.run", label: "Exercise", value: exercise)
                }
                if let diet = profile.diet, diet != "Prefer not to say", !diet.isEmpty {
                    AdminDetailRow(icon: "fork.knife", label: "Diet", value: diet)
                }
                if let pets = profile.pets, pets != "Prefer not to say", !pets.isEmpty {
                    AdminDetailRow(icon: "pawprint.fill", label: "Pets", value: pets)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Looking For Section

    private var lookingForSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Interested In", systemImage: "heart.text.square")
                .font(.headline)
                .foregroundColor(.orange)

            Text(profile.lookingFor.isEmpty ? "Everyone" : profile.lookingFor)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.notification(.error)
                onReject()
            } label: {
                HStack {
                    Image(systemName: "xmark")
                    Text("Reject")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(16)
            }

            Button {
                HapticManager.shared.notification(.success)
                onApprove()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Approve")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(16)
            }
        }
        .padding()
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
    }
}

// MARK: - Admin Detail Row (for pending profile detail)

private struct AdminDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Admin Flow Layout for tags

private struct AdminFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = AdminFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = AdminFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct AdminFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
            self.size = CGSize(width: maxWidth, height: y + maxHeight)
        }
    }
}

// MARK: - Profile Rejection Reasons

/// Structured rejection reasons with user-friendly messages and fix instructions
enum ProfileRejectionReason {
    case noFacePhoto
    case inappropriatePhotos
    case fakePhotos
    case incompleteBio
    case underage
    case spam
    case offensiveContent
    case lowQualityPhotos
    case contactInfoInBio
    case multipleAccounts

    var code: String {
        switch self {
        case .noFacePhoto: return "no_face_photo"
        case .inappropriatePhotos: return "inappropriate_photos"
        case .fakePhotos: return "fake_photos"
        case .incompleteBio: return "incomplete_bio"
        case .underage: return "underage"
        case .spam: return "spam"
        case .offensiveContent: return "offensive_content"
        case .lowQualityPhotos: return "low_quality_photos"
        case .contactInfoInBio: return "contact_info_bio"
        case .multipleAccounts: return "multiple_accounts"
        }
    }

    var userMessage: String {
        switch self {
        case .noFacePhoto:
            return "We need a clear photo showing your face"
        case .inappropriatePhotos:
            return "Some photos contain content that isn't allowed"
        case .fakePhotos:
            return "We detected photos that may not be authentic"
        case .incompleteBio:
            return "Your bio needs more detail about yourself"
        case .underage:
            return "Age verification is required"
        case .spam:
            return "Your profile contains promotional content"
        case .offensiveContent:
            return "Some content violates our community guidelines"
        case .lowQualityPhotos:
            return "Your photos are too blurry or low quality"
        case .contactInfoInBio:
            return "Contact information isn't allowed in bios"
        case .multipleAccounts:
            return "Multiple accounts aren't permitted"
        }
    }

    var fixInstructions: String {
        switch self {
        case .noFacePhoto:
            return """
            📸 Upload a clear, well-lit photo where your face is fully visible

            ✅ Good photos:
            • Face clearly visible and in focus
            • Good lighting (natural light works great!)
            • Just you in the photo

            ❌ Avoid:
            • Sunglasses or hats covering your face
            • Group photos as your main picture
            • Photos from far away
            """
        case .inappropriatePhotos:
            return """
            🚫 Please remove photos that contain:
            • Nudity or sexually suggestive content
            • Violent or graphic imagery
            • Drug or alcohol use

            ✅ Keep it classy! Show your personality through photos of your hobbies, travel, or daily life.
            """
        case .fakePhotos:
            return """
            🔍 We want to see the real you!

            Please upload genuine photos of yourself. Using:
            • Celebrity photos
            • Stock images
            • Someone else's pictures

            ...violates our guidelines and may result in a permanent ban.
            """
        case .incompleteBio:
            return """
            ✏️ Tell people about yourself!

            A good bio includes:
            • Your interests and hobbies
            • What you're looking for
            • Something unique about you

            Aim for at least 2-3 sentences. This helps you get better matches!
            """
        case .underage:
            return """
            🔞 All users must be 18 or older.

            If you believe this is a mistake, please contact support with a valid government-issued ID to verify your age.

            We take age verification seriously to keep our community safe.
            """
        case .spam:
            return """
            🚫 Please remove any:
            • Business promotions or advertisements
            • Links to other websites
            • Social media handles
            • Phone numbers or email addresses

            This app is for genuine connections, not marketing!
            """
        case .offensiveContent:
            return """
            🤝 Our community is built on respect.

            Please remove any content that is:
            • Hateful or discriminatory
            • Threatening or harassing
            • Politically extreme

            Everyone deserves to feel welcome here.
            """
        case .lowQualityPhotos:
            return """
            📷 Your photos need better quality!

            Tips for better photos:
            • Use good lighting (natural daylight is best)
            • Keep the camera steady or use a tripod
            • Clean your camera lens
            • Take photos at a reasonable distance

            Clear photos help you get more matches!
            """
        case .contactInfoInBio:
            return """
            📵 Please remove contact information from your bio

            This includes:
            • Phone numbers
            • Email addresses
            • Social media handles (Instagram, Snapchat, etc.)
            • External links

            For your safety, share contact info through our messaging system after matching!
            """
        case .multipleAccounts:
            return """
            ⚠️ Each person can only have one account.

            If you have another account, please delete it and use only this one.

            If you believe this is a mistake, please contact support to resolve the issue.
            """
        }
    }
}

// MARK: - Admin Alerts Sheet

struct AdminAlertsSheet: View {
    @ObservedObject var viewModel: ModerationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if viewModel.adminAlerts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Alerts")
                            .font(.title2.bold())
                        Text("You'll see notifications here when new accounts need approval")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(viewModel.adminAlerts) { alert in
                            AdminAlertRow(alert: alert, viewModel: viewModel)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.adminAlerts.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAlertsAsRead()
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Admin Alert Row

struct AdminAlertRow: View {
    let alert: AdminAlert
    @ObservedObject var viewModel: ModerationViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: alert.icon)
                .font(.title2)
                .foregroundColor(alert.iconColor)
                .frame(width: 40, height: 40)
                .background(alert.iconColor.opacity(0.1))
                .cornerRadius(8)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title)
                        .font(.subheadline.weight(.semibold))
                    if !alert.read {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(alert.userName)
                    .font(.subheadline)

                Text(alert.userEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(alert.createdAt)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // User photo
            if let photoURL = alert.userPhoto, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !alert.read {
                Task {
                    await viewModel.markAlertAsRead(alertId: alert.id)
                }
            }
        }
    }
}

// MARK: - Admin Photo Gallery View (Clickable Full-Screen with Swipe Navigation)

struct AdminPhotoGalleryView: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    // Swipe-down to dismiss state
    @State private var dismissDragOffset: CGFloat = 0
    @State private var isDismissing = false

    // Threshold for dismissing (150 points down)
    private let dismissThreshold: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background with opacity based on drag
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                // Photo carousel with smooth swiping
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoURL in
                        AdminZoomablePhotoView(
                            url: URL(string: photoURL),
                            isCurrentPhoto: index == selectedIndex
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                // Apply dismiss offset and scale
                .offset(y: dismissDragOffset)
                .scaleEffect(dismissScale)

                // Close button and counter overlay
                VStack {
                    HStack {
                        // Close button
                        Button {
                            HapticManager.shared.impact(.light)
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer()

                        // Photo counter
                        Text("\(selectedIndex + 1) / \(photos.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()

                    // Hint text
                    Text("Swipe left/right to navigate • Pinch to zoom • Swipe down to close")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 40)
                }
                .opacity(controlsOpacity)
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
                            isDismissing = true
                            HapticManager.shared.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) {
                                dismissDragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPresented = false
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
        .statusBarHidden()
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

// MARK: - Admin Zoomable Photo View

struct AdminZoomablePhotoView: View {
    let url: URL?
    let isCurrentPhoto: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(url: URL?, isCurrentPhoto: Bool = true) {
        self.url = url
        self.isCurrentPhoto = isCurrentPhoto
    }

    var body: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 1), 4)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale < 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                scale > 1 ?
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
                : nil
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2
                    }
                }
                HapticManager.shared.impact(.light)
            }
        }
    }
}

// MARK: - Admin Quick Stat Card (Header Bar)

struct AdminQuickStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 6) {
            // Icon with background and pulse effect for items needing attention
            ZStack {
                // Pulse ring for active items
                if value > 0 {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: 36, height: 36)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                }

                Circle()
                    .fill(color.opacity(value > 0 ? 0.15 : 0.08))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(value > 0 ? color : .secondary)
            }

            // Value with animation
            Text("\(value)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(value > 0 ? .primary : .secondary)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: value)

            // Label
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(value > 0 ? color.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .onAppear {
            if value > 0 {
                isPulsing = true
            }
        }
        .onChange(of: value) { _, newValue in
            isPulsing = newValue > 0
        }
    }
}

// MARK: - Admin Section Header

struct AdminSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            // Title
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // Count badge
            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Admin Loading View

struct AdminLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.secondary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Admin Error View

struct AdminErrorView: View {
    let title: String
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Admin Empty State View

struct AdminEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }

            // Refresh button
            if let onRefresh = onRefresh {
                Button {
                    HapticManager.shared.impact(.light)
                    onRefresh()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Refresh")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(color.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Admin Stat Card

struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)
            }

            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Title
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Admin Tab Item (Clean, Stable Design)

struct AdminTabItem: View {
    let name: String
    let icon: String
    let color: Color
    let badgeCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : color)

            // Label
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)

            // Inline badge
            if badgeCount > 0 {
                Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? color : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white : Color.red)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(isSelected ? color : Color(.secondarySystemBackground))
                .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, y: 3)
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.white.opacity(0.2) : Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .contentShape(Capsule())
    }
}

#Preview {
    AdminModerationDashboard()
}
