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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector - scrollable for more tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["New", "Reports", "Suspicious", "ID Review", "Stats"], id: \.self) { tab in
                            let index = ["New", "Reports", "Suspicious", "ID Review", "Stats"].firstIndex(of: tab) ?? 0
                            Button(action: { selectedTab = index }) {
                                Text(tab)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == index ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedTab == index ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            // Show badge for pending accounts
                            .overlay(alignment: .topTrailing) {
                                if tab == "New" && viewModel.pendingProfiles.count > 0 {
                                    Text("\(viewModel.pendingProfiles.count)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Content
                Group {
                    switch selectedTab {
                    case 0:
                        pendingProfilesView
                    case 1:
                        reportsListView
                    case 2:
                        suspiciousProfilesView
                    case 3:
                        idVerificationReviewView
                    case 4:
                        statsView
                    default:
                        pendingProfilesView
                    }
                }
            }
            .navigationTitle("Moderation")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadQueue()
            }
        }
    }

    // MARK: - Reports List

    private var reportsListView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading reports...")
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
                ProgressView("Loading new accounts...")
            } else if viewModel.pendingProfiles.isEmpty {
                emptyState(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "No Pending Accounts",
                    message: "All new accounts have been reviewed"
                )
            } else {
                List(viewModel.pendingProfiles) { profile in
                    PendingProfileRow(profile: profile, viewModel: viewModel)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Suspicious Profiles

    private var suspiciousProfilesView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading suspicious profiles...")
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
        ScrollView {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
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
                }

                HStack(spacing: 12) {
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

                Divider()

                // Recent activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)

                    if viewModel.reports.isEmpty && viewModel.suspiciousProfiles.isEmpty {
                        Text("No recent activity")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.reports.prefix(5)) { report in
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(report.reason)
                                        .font(.subheadline)
                                    Text(report.timestamp)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // PERFORMANCE: Use CachedAsyncImage
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
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // User info - PERFORMANCE: Use CachedAsyncImage
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
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title3.bold())
                                Text("ID: \(user.id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
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
    @Published var stats: ModerationStats = ModerationStats()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

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

    /// Approve a pending profile
    func approveProfile(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileStatus": "active",
            "profileStatusUpdatedAt": FieldValue.serverTimestamp()
        ])

        // Refresh to update list
        await loadQueue()
        Logger.shared.info("Profile approved: \(userId)", category: .moderation)
    }

    /// Reject a pending profile
    func rejectProfile(userId: String, reason: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileStatus": "rejected",
            "profileStatusReason": reason,
            "profileStatusUpdatedAt": FieldValue.serverTimestamp(),
            "showMeInSearch": false
        ])

        // Refresh to update list
        await loadQueue()
        Logger.shared.info("Profile rejected: \(userId)", category: .moderation)
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

        Logger.shared.info("User suspended for \(days) days: \(userId)", category: .moderation)
    }

    /// Warn user in Firestore
    private func warnUserInFirestore(userId: String, reason: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "warnings": FieldValue.arrayUnion([
                [
                    "reason": reason,
                    "timestamp": Timestamp(date: Date())
                ]
            ]),
            "warningCount": FieldValue.increment(Int64(1))
        ])

        Logger.shared.info("Warning issued to user: \(userId)", category: .moderation)
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

// MARK: - Pending Profile Row View

struct PendingProfileRow: View {
    let profile: PendingProfile
    @ObservedObject var viewModel: ModerationViewModel
    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var showRejectAlert = false
    @State private var rejectReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Profile photo
                if let photoURL = profile.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.headline)

                    Text("\(profile.age) • \(profile.gender) • \(profile.location)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(profile.email)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Joined \(profile.createdAt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Bio preview
            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Photo count
            if profile.photos.count > 1 {
                Text("\(profile.photos.count) photos")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        isApproving = true
                        try? await viewModel.approveProfile(userId: profile.id)
                        isApproving = false
                    }
                }) {
                    HStack {
                        if isApproving {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Approve")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .disabled(isApproving || isRejecting)

                Button(action: {
                    showRejectAlert = true
                }) {
                    HStack {
                        if isRejecting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                        }
                        Text("Reject")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .disabled(isApproving || isRejecting)

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .alert("Reject Profile", isPresented: $showRejectAlert) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Cancel", role: .cancel) { }
            Button("Reject", role: .destructive) {
                Task {
                    isRejecting = true
                    try? await viewModel.rejectProfile(userId: profile.id, reason: rejectReason)
                    isRejecting = false
                }
            }
        } message: {
            Text("Are you sure you want to reject this profile?")
        }
    }
}

#Preview {
    AdminModerationDashboard()
}
