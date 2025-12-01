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
    @Namespace private var tabAnimation

    // Tab configuration with icons and colors
    private let tabs: [(name: String, icon: String, color: Color)] = [
        ("New", "person.badge.plus", .blue),
        ("Reports", "exclamationmark.triangle.fill", .orange),
        ("Suspicious", "eye.trianglebadge.exclamationmark", .red),
        ("ID Review", "person.text.rectangle", .purple),
        ("Stats", "chart.bar.fill", .green)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Tab selector with icons, badges, and smooth animations
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            AdminTabButton(
                                tab: tab,
                                isSelected: selectedTab == index,
                                badgeCount: getBadgeCount(for: index),
                                namespace: tabAnimation
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = index
                                }
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 12)
                .background(
                    // Frosted glass effect background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(alignment: .bottom) {
                    // Subtle separator line
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: 0.5)
                }

                // Content with smooth transitions
                TabView(selection: $selectedTab) {
                    pendingProfilesView
                        .tag(0)

                    reportsListView
                        .tag(1)

                    suspiciousProfilesView
                        .tag(2)

                    idVerificationReviewView
                        .tag(3)

                    statsView
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
            .navigationTitle("Moderation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .task {
                await viewModel.loadQueue()
            }
            .onAppear {
                viewModel.startListeningToAlerts()
            }
            .onDisappear {
                viewModel.stopListeningToAlerts()
            }
            .sheet(isPresented: $showingAlerts) {
                AdminAlertsSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Badge Count Helper

    private func getBadgeCount(for tabIndex: Int) -> Int {
        switch tabIndex {
        case 0: return viewModel.pendingProfiles.count  // New accounts
        case 1: return viewModel.reports.count          // Reports
        case 2: return viewModel.suspiciousProfiles.count // Suspicious
        case 3: return 0  // ID Review count comes from embedded view
        default: return 0
        }
    }

    // MARK: - Reports List

    private var reportsListView: some View {
        Group {
            if viewModel.isLoading {
                ReportsLoadingView()
            } else if let error = viewModel.errorMessage {
                // Show error state with admin access hint
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Could Not Load Reports")
                        .font(.title2.bold())

                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.reports.isEmpty {
                emptyState(
                    icon: "checkmark.shield.fill",
                    title: "No Pending Reports",
                    message: "All reports have been reviewed"
                )
            } else {
                List(viewModel.reports) { report in
                    NavigationLink {
                        ReportDetailView(report: report, viewModel: viewModel)
                    } label: {
                        ReportRowView(report: report)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Pending Profiles (New Accounts)

    private var pendingProfilesView: some View {
        Group {
            if viewModel.isLoading {
                PendingProfilesLoadingView()
            } else if viewModel.pendingProfiles.isEmpty {
                emptyState(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "All Caught Up!",
                    message: "No new accounts waiting for review"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Header with count
                        HStack {
                            Text("\(viewModel.pendingProfiles.count) accounts pending")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ForEach(viewModel.pendingProfiles) { profile in
                            PendingProfileCard(profile: profile, viewModel: viewModel)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Suspicious Profiles

    private var suspiciousProfilesView: some View {
        Group {
            if viewModel.isLoading {
                SuspiciousProfilesLoadingView()
            } else if viewModel.suspiciousProfiles.isEmpty {
                emptyState(
                    icon: "checkmark.circle.fill",
                    title: "No Suspicious Profiles",
                    message: "Auto-detection found no concerns"
                )
            } else {
                List(viewModel.suspiciousProfiles) { item in
                    NavigationLink {
                        SuspiciousProfileDetailView(item: item, viewModel: viewModel)
                    } label: {
                        SuspiciousProfileRowView(item: item)
                    }
                }
                .listStyle(.plain)
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
                StatsLoadingView()
            } else {
                statsContentView
            }
        }
    }

    private var statsContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.title2.bold())
                        Text("Moderation overview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Last updated indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Summary cards in grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Total Reports",
                        value: "\(viewModel.stats.totalReports)",
                        icon: "exclamationmark.triangle.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Pending",
                        value: "\(viewModel.stats.pendingReports)",
                        icon: "clock.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Resolved",
                        value: "\(viewModel.stats.resolvedReports)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Suspicious",
                        value: "\(viewModel.stats.suspiciousProfiles)",
                        icon: "eye.trianglebadge.exclamationmark.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)

                // Recent activity card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("Recent Activity")
                            .font(.headline)
                        Spacer()
                    }

                    if viewModel.reports.isEmpty && viewModel.suspiciousProfiles.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No recent activity")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.reports.prefix(5)) { report in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(report.reason)
                                            .font(.subheadline.weight(.medium))
                                        Text(report.timestamp)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            // Animated icon container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.15), .green.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 90, height: 90)

                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }

            // Refresh hint
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Report Row

struct ReportRowView: View {
    let report: ModerationReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Reason badge
                Text(report.reason)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(reasonColor)
                    .cornerRadius(6)

                Spacer()

                // Timestamp
                Text(report.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Reported user - PERFORMANCE: Use CachedAsyncImage
            if let user = report.reportedUser {
                HStack(spacing: 8) {
                    if let photoURL = user.photoURL {
                        CachedAsyncImage(url: URL(string: photoURL)) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.subheadline.bold())
                        Text("Reported by: \(report.reporter?.name ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Suspicious Profile Row

struct SuspiciousProfileRowView: View {
    let item: SuspiciousProfileItem

    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(severityColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.user?.name ?? "Unknown User")
                    .font(.subheadline.bold())

                Text("Suspicion: \(Int(item.suspicionScore * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Indicators
                if !item.indicators.isEmpty {
                    Text(item.indicators.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text(item.timestamp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
    @Published var adminAlerts: [AdminAlert] = []
    @Published var unreadAlertCount: Int = 0
    @Published var stats: ModerationStats = ModerationStats()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private var alertsListener: ListenerRegistration?

    /// Start listening to admin alerts in real-time
    func startListeningToAlerts() {
        alertsListener?.remove()

        alertsListener = db.collection("admin_alerts")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

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
            }
    }

    /// Stop listening to alerts
    func stopListeningToAlerts() {
        alertsListener?.remove()
        alertsListener = nil
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
            async let statsTask = loadStats()

            let (loadedReports, loadedSuspicious, loadedPending, loadedStats) = await (reportsTask, suspiciousTask, pendingTask, statsTask)

            reports = loadedReports
            suspiciousProfiles = loadedSuspicious
            pendingProfiles = loadedPending
            stats = loadedStats

            Logger.shared.info("Admin: Loaded \(reports.count) reports, \(suspiciousProfiles.count) suspicious, \(pendingProfiles.count) pending profiles", category: .moderation)

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
                if let timestamp = data["timestamp"] as? Timestamp {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    createdAt = formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
                }

                let profile = PendingProfile(
                    id: doc.documentID,
                    name: data["fullName"] as? String ?? "Unknown",
                    email: data["email"] as? String ?? "",
                    age: data["age"] as? Int ?? 0,
                    gender: data["gender"] as? String ?? "",
                    location: data["location"] as? String ?? "",
                    photoURL: data["profileImageURL"] as? String,
                    photos: data["photos"] as? [String] ?? [],
                    bio: data["bio"] as? String ?? "",
                    createdAt: createdAt
                )
                profiles.append(profile)
            }

            return profiles
        } catch {
            Logger.shared.error("Admin: Failed to load pending profiles", category: .moderation, error: error)
            return []
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

        // Refresh queue
        await loadQueue()
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

        Logger.shared.info("User banned: \(userId)", category: .moderation)
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
    let photoURL: String?
    let photos: [String]
    let bio: String
    let createdAt: String
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
    @State private var showRejectAlert = false
    @State private var currentPhotoIndex = 0
    @State private var showPhotoGallery = false

    // Admin comment flow
    @State private var selectedRejectionReason: ProfileRejectionReason?
    @State private var showAdminCommentSheet = false
    @State private var adminComment = ""

    // Fixed height for consistent card sizing
    private let photoHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            // Photo Gallery - Tap to view full screen (fixed height container)
            ZStack(alignment: .bottom) {
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
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: geo.size.width, height: photoHeight)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray)
                                            )
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.1))
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

                // Photo indicators
                if profile.photos.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<profile.photos.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 12)
                }

                // Photo count badge + tap hint
                HStack {
                    // Tap to view hint
                    Label("Tap to view", systemImage: "hand.tap")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(12)

                    Spacer()

                    Label("\(profile.photos.count)", systemImage: "photo.stack")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .fullScreenCover(isPresented: $showPhotoGallery) {
                AdminPhotoGalleryView(
                    photos: profile.photos,
                    selectedIndex: $currentPhotoIndex,
                    isPresented: $showPhotoGallery
                )
            }

            // Profile Info
            VStack(alignment: .leading, spacing: 12) {
                // Name and Age
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.name)
                        .font(.title2.bold())
                    Text("\(profile.age)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                    // Time badge
                    Text(profile.createdAt)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }

                // Location and Gender
                HStack(spacing: 16) {
                    Label(profile.location, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Label(profile.gender, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Email
                Label(profile.email, systemImage: "envelope.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                // Bio
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }

                Divider()
                    .padding(.vertical, 8)

                // Action Buttons
                HStack(spacing: 16) {
                    // Reject Button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showRejectAlert = true
                    }) {
                        HStack(spacing: 8) {
                            if isRejecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.title3.bold())
                            }
                            Text("Reject")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isApproving || isRejecting)

                    // Approve Button
                    Button(action: {
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
                    }) {
                        HStack(spacing: 8) {
                            if isApproving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.title3.bold())
                            }
                            Text("Approve")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isApproving || isRejecting)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
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

// MARK: - Admin Tab Button Component

struct AdminTabButton: View {
    let tab: (name: String, icon: String, color: Color)
    let isSelected: Bool
    let badgeCount: Int
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)

                Text(tab.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tab.color, tab.color.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: tab.color.opacity(0.4), radius: 8, y: 4)
                        .matchedGeometryEffect(id: "tab_background", in: namespace)
                } else {
                    Capsule()
                        .fill(Color(.systemGray5).opacity(0.8))
                }
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        // Badge overlay
        .overlay(alignment: .topTrailing) {
            if badgeCount > 0 {
                Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
                    )
                    .offset(x: 10, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: badgeCount)
    }
}

#Preview {
    AdminModerationDashboard()
}
