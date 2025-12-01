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
    @State private var showPhotoGallery = false
    @State private var selectedPhotoIndex = 0

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
                investigationLoadingView
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
                userNotFoundView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Investigation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUserData()
        }
    }

    // MARK: - Loading View

    private var investigationLoadingView: some View {
        VStack(spacing: 20) {
            // Header skeleton
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .skeletonShimmer()

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(width: 140, height: 24)
                    SkeletonShape(width: 100, height: 16)
                    SkeletonShape(width: 160, height: 14)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)

            // Status section skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonShape(width: 120, height: 20)
                ForEach(0..<3) { _ in
                    HStack {
                        SkeletonShape(width: 100, height: 16)
                        Spacer()
                        SkeletonShape(width: 80, height: 16)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)

            // Stats skeleton
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                            .skeletonShimmer()
                        SkeletonShape(width: 40, height: 24)
                        SkeletonShape(width: 60, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }

    // MARK: - User Not Found View

    private var userNotFoundView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.15), Color.red.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("User Not Found")
                .font(.title2.bold())

            Text("This user may have been deleted or the ID is invalid")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Profile Header

    // PERFORMANCE: Use CachedAsyncImage - Tap photo to view full screen
    private func userProfileHeader(_ user: User) -> some View {
        VStack(spacing: 0) {
            // Main header with photo and info
            HStack(spacing: 16) {
                // Profile photo - tappable
                Button {
                    if !user.photos.isEmpty {
                        selectedPhotoIndex = 0
                        showPhotoGallery = true
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        CachedAsyncImage(url: URL(string: user.profileImageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: statusGradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )

                        // Photo count badge
                        if user.photos.count > 1 {
                            Text("\(user.photos.count)")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                                .offset(x: 4, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.title2.bold())

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(user.age) years old")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if !user.email.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()
            }
            .padding()

            // User ID bar
            HStack {
                Text("ID:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(userId)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    UIPasteboard.general.string = userId
                    HapticManager.shared.notification(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray5).opacity(0.5))
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .fullScreenCover(isPresented: $showPhotoGallery) {
            AdminPhotoGalleryView(
                photos: user.photos,
                selectedIndex: $selectedPhotoIndex,
                isPresented: $showPhotoGallery
            )
        }
    }

    private var statusGradientColors: [Color] {
        if isBanned {
            return [.red, .red.opacity(0.7)]
        } else if isSuspended {
            return [.orange, .orange.opacity(0.7)]
        } else {
            return [.green, .green.opacity(0.7)]
        }
    }

    // MARK: - Account Status

    private func accountStatusSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: statusGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Account Status")
                    .font(.headline)
                Spacer()

                // Status badge
                Text(isBanned ? "BANNED" : (isSuspended ? "SUSPENDED" : "ACTIVE"))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: statusGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
            }

            VStack(spacing: 10) {
                EnhancedStatusRow(
                    icon: "person.badge.shield.checkmark.fill",
                    label: "Account Status",
                    value: isBanned ? "Permanently Banned" : (isSuspended ? "Temporarily Suspended" : "Active & Visible"),
                    color: isBanned ? .red : (isSuspended ? .orange : .green)
                )

                if isBanned, let bannedReason = bannedReason {
                    EnhancedStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Ban Reason",
                        value: bannedReason,
                        color: .red
                    )
                }

                if isSuspended, let suspendedUntil = suspendedUntil {
                    EnhancedStatusRow(
                        icon: "clock.fill",
                        label: "Suspended Until",
                        value: suspendedUntil.formatted(date: .abbreviated, time: .shortened),
                        color: .orange
                    )
                }

                EnhancedStatusRow(
                    icon: "exclamationmark.circle.fill",
                    label: "Warning Count",
                    value: warningsCount > 0 ? "\(warningsCount) warning\(warningsCount == 1 ? "" : "s")" : "No warnings",
                    color: warningsCount > 0 ? .orange : .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Verification Section

    private func verificationSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Verification Status")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                AdminVerificationBadgeView(
                    icon: "phone.fill",
                    label: "Phone",
                    isVerified: isPhoneVerified,
                    color: .green
                )

                AdminVerificationBadgeView(
                    icon: "camera.fill",
                    label: "Photo",
                    isVerified: user.isVerified,
                    color: .blue
                )

                AdminVerificationBadgeView(
                    icon: "crown.fill",
                    label: "Premium",
                    isVerified: user.isPremium,
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Activity Stats

    private var activityStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Activity Statistics")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                EnhancedActivityStatBox(
                    value: "\(matchesCount)",
                    label: "Matches",
                    icon: "heart.fill",
                    gradientColors: [.pink, .red]
                )
                EnhancedActivityStatBox(
                    value: "\(messagesCount)",
                    label: "Messages",
                    icon: "message.fill",
                    gradientColors: [.blue, .cyan]
                )
                EnhancedActivityStatBox(
                    value: "\(reportsCount)",
                    label: "Reports",
                    icon: "exclamationmark.triangle.fill",
                    gradientColors: reportsCount > 0 ? [.red, .orange] : [.gray, .gray.opacity(0.7)]
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Account Info

    private func accountInfoSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Account Information")
                    .font(.headline)
            }

            VStack(spacing: 10) {
                EnhancedStatusRow(
                    icon: "calendar.badge.clock",
                    label: "Account Age",
                    value: accountAge.isEmpty ? "Unknown" : accountAge,
                    color: .blue
                )

                EnhancedStatusRow(
                    icon: "mappin.circle.fill",
                    label: "Location",
                    value: user.location.isEmpty ? "Not specified" : user.location,
                    color: .teal
                )

                EnhancedStatusRow(
                    icon: "person.fill",
                    label: "Gender",
                    value: user.gender.isEmpty ? "Not specified" : user.gender,
                    color: .purple
                )
            }

            if !user.bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundColor(.secondary)
                        Text("Bio")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(user.bio)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Admin Actions

    private var adminActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Quick Actions")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                // View full profile
                if let user = user {
                    NavigationLink(destination: UserDetailView(user: user)) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("View Full Profile")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                HStack(spacing: 12) {
                    // View reports against this user
                    Button {
                        // TODO: Navigate to reports view filtered by this user
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Reports")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // View messages (if needed)
                    Button {
                        // TODO: View user's messages
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Messages")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Data Loading

    private func loadUserData() async {
        isLoading = true

        do {
            // Load user document
            let userDoc = try await db.collection("users").document(userId).getDocument()

            if let data = userDoc.data() {
                user = try? Firestore.Decoder().decode(User.self, from: data)

                // Extract moderation data from user document
                isBanned = data["isBanned"] as? Bool ?? false
                isSuspended = data["isSuspended"] as? Bool ?? false
                bannedReason = data["banReason"] as? String
                warningsCount = data["warningCount"] as? Int ?? 0
                isPhoneVerified = data["phoneVerified"] as? Bool ?? false

                // Get suspended until date
                if let suspendedTimestamp = data["suspendedUntil"] as? Timestamp {
                    suspendedUntil = suspendedTimestamp.dateValue()
                    // Check if suspension has expired
                    if let until = suspendedUntil, until < Date() {
                        isSuspended = false
                    }
                }
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
                let components = calendar.dateComponents([.day, .month, .year], from: timestamp, to: Date())
                if let years = components.year, years > 0 {
                    accountAge = "\(years) year\(years == 1 ? "" : "s")"
                } else if let months = components.month, months > 0 {
                    accountAge = "\(months) month\(months == 1 ? "" : "s")"
                } else if let days = components.day {
                    accountAge = "\(days) day\(days == 1 ? "" : "s")"
                }
            }

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

/// Enhanced status row with icon and better styling
struct EnhancedStatusRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
}

/// Verification badge component for admin view
struct AdminVerificationBadgeView: View {
    let icon: String
    let label: String
    let isVerified: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isVerified ? [color.opacity(0.2), color.opacity(0.1)] : [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        isVerified ?
                        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if isVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .background(Color.white.clipShape(Circle()))
                        .offset(x: 4, y: 4)
                }
            }

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isVerified ? color : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isVerified ? color.opacity(0.05) : Color(.systemGray6))
        )
    }
}

/// Enhanced activity stat box with gradients
struct EnhancedActivityStatBox: View {
    let value: String
    let label: String
    let icon: String
    let gradientColors: [Color]

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: gradientColors.first?.opacity(0.15) ?? .clear, radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
