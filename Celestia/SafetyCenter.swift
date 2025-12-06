//
//  SafetyCenter.swift
//  Celestia
//
//  Safety features: reporting and blocking
//

import SwiftUI
import FirebaseFirestore

// MARK: - Safety Center View

struct SafetyCenterView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SafetyCenterViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Safety Tools
                    safetyToolsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Safety Center")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadSafetyData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Your Safety Matters")
                .font(.title2.bold())

            Text("Use these tools to protect yourself and report issues.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Safety Tools Section

    private var safetyToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Safety Tools", icon: "shield.fill")

            VStack(spacing: 12) {
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    SafetyOptionRow(
                        icon: "hand.raised.fill",
                        title: "Blocked Users",
                        subtitle: "Manage blocked accounts",
                        color: .red,
                        badge: viewModel.blockedCount
                    )
                }

                NavigationLink {
                    ReportingCenterView()
                } label: {
                    SafetyOptionRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Report & Support",
                        subtitle: "Report issues or users",
                        color: .orange
                    )
                }
            }
        }
    }
}

// MARK: - Section Header

struct SafetySectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)

            Text(title)
                .font(.title3.bold())

            Spacer()
        }
    }
}

// MARK: - Safety Option Row

struct SafetyOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isCompleted: Bool = false
    var badge: Int?

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            } else if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
class SafetyCenterViewModel: ObservableObject {
    @Published var blockedCount = 0

    private let db = Firestore.firestore()

    func loadSafetyData() async {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = AuthService.shared.currentUser?.effectiveId else { return }

        do {
            // Load blocked users count
            let blockedSnapshot = try await db.collection("blocked_users")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            blockedCount = blockedSnapshot.documents.count
        } catch {
            Logger.shared.error("Error loading safety data", category: .general, error: error)
        }
    }
}

#Preview {
    SafetyCenterView()
        .environmentObject(AuthService.shared)
}
