//
//  AdminUserInvestigationView.swift
//  Celestia
//
//  Admin tool for investigating user profiles
//

import SwiftUI
import FirebaseFirestore

struct AdminUserInvestigationView: View {
    let userId: String

    @State private var user: User?
    @State private var isLoading = true
    @State private var reportsCount = 0
    @State private var matchesCount = 0
    @State private var messagesCount = 0
    @State private var accountAge = ""

    // Moderation state (fetched separately from user document)
    @State private var isBanned = false
    @State private var isSuspended = false
    @State private var bannedReason: String?
    @State private var suspendedUntil: Date?
    @State private var warningsCount = 0
    @State private var isPhoneVerified = false

    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if let user = user {
                VStack(alignment: .leading, spacing: 20) {
                    // User Profile Header
                    userProfileHeader(user)

                    // Account Status
                    accountStatusSection(user)

                    // Verification Status
                    verificationSection(user)

                    // Activity Stats
                    activityStatsSection

                    // Account Info
                    accountInfoSection(user)

                    // Admin Actions
                    adminActionsSection
                }
                .padding()
            } else {
                Text("User not found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Investigation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUserData()
        }
    }

    // MARK: - Profile Header

    private func userProfileHeader(_ user: User) -> some View {
        HStack(spacing: 16) {
            // Profile photo
            AsyncImage(url: URL(string: user.profileImageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.title2.bold())

                Text("\(user.age) years old")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Account Status

    private func accountStatusSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Status")
                .font(.headline)

            VStack(spacing: 8) {
                StatusRow(
                    label: "Account Status",
                    value: isBanned ? "Banned" : (isSuspended ? "Suspended" : "Active"),
                    color: isBanned ? .red : (isSuspended ? .orange : .green)
                )

                if isBanned, let bannedReason = bannedReason {
                    StatusRow(label: "Ban Reason", value: bannedReason, color: .red)
                }

                if isSuspended, let suspendedUntil = suspendedUntil {
                    StatusRow(
                        label: "Suspended Until",
                        value: suspendedUntil.formatted(date: .abbreviated, time: .shortened),
                        color: .orange
                    )
                }

                StatusRow(
                    label: "Warnings",
                    value: "\(warningsCount)",
                    color: warningsCount > 0 ? .orange : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Verification Section

    private func verificationSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification Status")
                .font(.headline)

            VStack(spacing: 8) {
                StatusRow(
                    label: "Phone Verified",
                    value: isPhoneVerified ? "✓ Yes" : "✗ No",
                    color: isPhoneVerified ? .green : .gray
                )

                StatusRow(
                    label: "Photo Verified",
                    value: user.isVerified ? "✓ Yes" : "✗ No",
                    color: user.isVerified ? .green : .gray
                )

                StatusRow(
                    label: "Premium Status",
                    value: user.isPremium ? "Premium" : "Free",
                    color: user.isPremium ? .purple : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Activity Stats

    private var activityStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                ActivityStatBox(value: "\(matchesCount)", label: "Matches", icon: "heart.fill", color: .pink)
                ActivityStatBox(value: "\(messagesCount)", label: "Messages", icon: "message.fill", color: .blue)
                ActivityStatBox(value: "\(reportsCount)", label: "Reports", icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Account Info

    private func accountInfoSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Information")
                .font(.headline)

            VStack(spacing: 8) {
                StatusRow(label: "Account Age", value: accountAge, color: .gray)
                StatusRow(label: "Location", value: user.location, color: .gray)

                if !user.bio.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bio:")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        Text(user.bio)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Admin Actions

    private var adminActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // View full profile
                if let user = user {
                    NavigationLink(destination: UserDetailView(user: user)) {
                        Label("View Profile", systemImage: "person.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }

                // View reports against this user
                Button {
                    // TODO: Navigate to reports view filtered by this user
                } label: {
                    Label("View Reports", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadUserData() async {
        isLoading = true

        do {
            // Load user document
            let userDoc = try await db.collection("users").document(userId).getDocument()

            if let data = userDoc.data() {
                user = try? Firestore.Decoder().decode(User.self, from: data)
            }

            // Load report count
            let reportsSnapshot = try await db.collection("reports")
                .whereField("reportedUserId", isEqualTo: userId)
                .getDocuments()
            reportsCount = reportsSnapshot.documents.count

            // Load matches count
            let matchesSnapshot = try await db.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userId),
                    Filter.whereField("user2Id", isEqualTo: userId)
                ]))
                .getDocuments()
            matchesCount = matchesSnapshot.documents.count

            // Load messages count (approximate - just count sent messages)
            let messagesSnapshot = try await db.collectionGroup("messages")
                .whereField("senderId", isEqualTo: userId)
                .limit(to: 100) // Sample for performance
                .getDocuments()
            messagesCount = messagesSnapshot.documents.count

            // Calculate account age
            if let timestamp = user?.timestamp {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: timestamp, to: Date())
                if let days = components.day {
                    accountAge = "\(days) days"
                }
            }

            // TODO: Load moderation data from separate collection if it exists
            // For now, moderation fields remain at default values

        } catch {
            Logger.shared.error("Error loading user investigation data", category: .moderation, error: error)
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }
}

struct ActivityStatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    NavigationStack {
        AdminUserInvestigationView(userId: "test_user_id")
    }
}
