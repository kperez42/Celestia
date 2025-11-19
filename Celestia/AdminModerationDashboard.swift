//
//  AdminModerationDashboard.swift
//  Celestia
//
//  Admin dashboard for viewing and moderating user reports
//

import SwiftUI
import FirebaseFunctions

struct AdminModerationDashboard: View {
    @StateObject private var viewModel = ModerationViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Reports").tag(0)
                    Text("Suspicious").tag(1)
                    Text("Stats").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch selectedTab {
                    case 0:
                        reportsListView
                    case 1:
                        suspiciousProfilesView
                    case 2:
                        statsView
                    default:
                        reportsListView
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

    // MARK: - Stats

    private var statsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
                    StatCard(
                        title: "Total Reports",
                        value: "\(viewModel.stats.totalReports)",
                        color: .blue
                    )

                    StatCard(
                        title: "Pending",
                        value: "\(viewModel.stats.pendingReports)",
                        color: .orange
                    )
                }

                HStack(spacing: 12) {
                    StatCard(
                        title: "Resolved",
                        value: "\(viewModel.stats.resolvedReports)",
                        color: .green
                    )

                    StatCard(
                        title: "Suspicious",
                        value: "\(viewModel.stats.suspiciousProfiles)",
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

            // Reported user
            if let user = report.reportedUser {
                HStack(spacing: 8) {
                    if let photoURL = user.photoURL {
                        AsyncImage(url: URL(string: photoURL)) { image in
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

    private func userInfoCard(_ user: ModerationReport.UserInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reported User")
                .font(.headline)

            HStack(spacing: 12) {
                if let photoURL = user.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
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
                // User info
                if let user = item.user {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suspicious Profile")
                            .font(.headline)

                        HStack(spacing: 12) {
                            if let photoURL = user.photoURL {
                                AsyncImage(url: URL(string: photoURL)) { image in
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
                    NavigationLink(destination: AdminUserInvestigationView(userId: item.reportedUserId)) {
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
        guard let user = item.user, let userId = user.id else { return }

        isBanning = true

        do {
            // Use the existing moderation function if there's a report, or create a synthetic one
            try await viewModel.banUserDirectly(
                userId: userId,
                reason: banReason.isEmpty ? "Suspicious profile auto-detected with score \(item.suspicionScore)" : banReason
            )

            dismiss()
        } catch {
            Logger.shared.error("Error banning user from suspicious profile view", category: .admin, error: error)
        }

        isBanning = false
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
class ModerationViewModel: ObservableObject {
    @Published var reports: [ModerationReport] = []
    @Published var suspiciousProfiles: [SuspiciousProfileItem] = []
    @Published var stats: ModerationStats = ModerationStats()
    @Published var isLoading = false

    private let functions = Functions.functions()

    func loadQueue() async {
        isLoading = true

        do {
            let callable = functions.httpsCallable("getModerationQueue")
            let result = try await callable.call(["status": "pending", "limit": 50])

            guard let data = result.data as? [String: Any] else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            // Parse reports
            if let reportsData = data["reports"] as? [[String: Any]] {
                reports = reportsData.compactMap { ModerationReport(dict: $0) }
            }

            // Parse moderation queue
            if let queueData = data["moderationQueue"] as? [[String: Any]] {
                suspiciousProfiles = queueData.compactMap { SuspiciousProfileItem(dict: $0) }
            }

            // Parse stats
            if let statsData = data["stats"] as? [String: Any] {
                stats = ModerationStats(dict: statsData)
            }

            isLoading = false
        } catch {
            isLoading = false
            Logger.shared.error("Failed to load moderation queue", category: .general, error: error)
        }
    }

    func refresh() async {
        await loadQueue()
    }

    func moderateReport(reportId: String, action: ModerationAction, reason: String?) async throws {
        let callable = functions.httpsCallable("moderateReport")

        let params: [String: Any] = [
            "reportId": reportId,
            "action": action.rawValue,
            "reason": reason ?? "",
            "duration": action == .suspend ? 7 : nil as Any
        ]

        _ = try await callable.call(params)

        // Refresh queue
        await loadQueue()
    }

    /// Ban user directly (without needing a report)
    func banUserDirectly(userId: String, reason: String) async throws {
        let callable = functions.httpsCallable("banUserDirectly")

        let params: [String: Any] = [
            "userId": userId,
            "reason": reason
        ]

        _ = try await callable.call(params)

        // Refresh queue to update suspicious profiles list
        await loadQueue()

        Logger.shared.info("User banned directly from admin panel: \(userId)", category: .admin)
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

#Preview {
    AdminModerationDashboard()
}
