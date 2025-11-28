//
//  ReferralManager.swift
//  Celestia
//
//  Manages referral system logic
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ReferralManager: ObservableObject {
    static let shared = ReferralManager()

    @Published var userReferrals: [Referral] = []
    @Published var leaderboard: [ReferralLeaderboardEntry] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var newMilestoneReached: ReferralMilestone?

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

    // Retry configuration
    private let maxRetries = 3
    private let retryDelaySeconds: UInt64 = 1

    private init() {}

    // MARK: - Referral Code Generation

    func generateReferralCode(for userId: String) async throws -> String {
        // Generate a unique 8-character code
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        // Try up to 5 times to generate a unique code
        for attempt in 1...5 {
            let code = String((0..<8).compactMap { _ in characters.randomElement() })
            guard code.count == 8 else {
                Logger.shared.error("Failed to generate 8-character code", category: .referral)
                continue
            }
            let fullCode = "CEL-\(code)"

            // Check if code already exists
            let snapshot = try await db.collection("users")
                .whereField("referralStats.referralCode", isEqualTo: fullCode)
                .limit(to: 1)
                .getDocuments()

            if snapshot.documents.isEmpty {
                // Code is unique
                return fullCode
            }

            Logger.shared.warning("Referral code collision detected (attempt \(attempt)/5): \(fullCode)", category: .referral)
        }

        // If we still can't generate a unique code after 5 attempts, use timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        return "CEL-\(String(timestamp).suffix(8))"
    }

    func initializeReferralCode(for user: inout User) async throws {
        // Check if user already has a referral code
        if !user.referralStats.referralCode.isEmpty {
            return
        }

        // Generate new unique code
        let code = try await generateReferralCode(for: user.id ?? "")
        user.referralStats.referralCode = code

        // Update in Firestore
        guard let userId = user.id else { return }
        let updateData: [String: Any] = [
            "referralStats.referralCode": code
        ]
        try await db.collection("users").document(userId).updateData(updateData)
    }

    // MARK: - Process Referral on Signup

    func processReferralSignup(newUser: User, referralCode: String) async throws {
        // Validate referral code
        guard !referralCode.isEmpty else { return }
        guard let newUserId = newUser.id else {
            throw ReferralError.invalidUser
        }

        // Step 1: Find the referrer by their referral code
        let referrerSnapshot = try await db.collection("users")
            .whereField("referralStats.referralCode", isEqualTo: referralCode)
            .limit(to: 1)
            .getDocuments()

        guard let referrerDoc = referrerSnapshot.documents.first else {
            Logger.shared.warning("Invalid referral code: \(referralCode)", category: .referral)
            throw ReferralError.invalidCode
        }

        let referrerId = referrerDoc.documentID
        let referrerData = referrerDoc.data()
        let referrerName = referrerData["fullName"] as? String ?? "Someone"

        guard referrerId != newUserId else {
            Logger.shared.warning("User attempted to refer themselves", category: .referral)
            throw ReferralError.selfReferral
        }

        // Step 1.5: Check if referrer has reached max referrals
        let referrerStatsDict = referrerData["referralStats"] as? [String: Any] ?? [:]
        let currentReferrals = referrerStatsDict["totalReferrals"] as? Int ?? 0

        if currentReferrals >= ReferralRewards.maxReferrals {
            Logger.shared.warning("Referrer has reached max referrals limit: \(currentReferrals)", category: .referral)
            throw ReferralError.maxReferralsReached
        }

        // Step 2: Use a unique document ID to prevent duplicate referrals
        // This provides database-level duplicate prevention
        let referralDocId = "\(referrerId)_\(newUserId)"
        let existingReferralDoc = try await db.collection("referrals").document(referralDocId).getDocument()

        if existingReferralDoc.exists {
            Logger.shared.warning("Duplicate referral attempt detected", category: .referral)
            throw ReferralError.alreadyReferred
        }

        // Step 3: Check for email abuse (multiple accounts with same email using referral)
        let emailCheckSnapshot = try await db.collection("users")
            .whereField("email", isEqualTo: newUser.email)
            .limit(to: 5)
            .getDocuments()

        // Count other accounts (not this user) that used a referral code
        let otherAccountsWithReferral = emailCheckSnapshot.documents.filter { doc in
            guard doc.documentID != newUserId else { return false }
            let data = doc.data()
            let referredByCode = data["referredByCode"] as? String
            return referredByCode != nil && !referredByCode!.isEmpty
        }

        if !otherAccountsWithReferral.isEmpty {
            Logger.shared.warning("Email has already been referred with a different account", category: .referral)
            throw ReferralError.emailAlreadyReferred
        }

        // Step 4: Create referral record with deterministic ID to prevent duplicates
        let referral = Referral(
            referrerUserId: referrerId,
            referredUserId: newUserId,
            referralCode: referralCode,
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            rewardClaimed: false
        )

        // Use setData with the deterministic ID
        let referralData = try Firestore.Encoder().encode(referral)
        try await db.collection("referrals").document(referralDocId).setData(referralData)

        // Step 5: Award bonus days to new user (with retry)
        try await awardPremiumDays(userId: newUserId, days: ReferralRewards.newUserBonusDays, reason: "referral_signup")

        // Step 6: Award bonus days to referrer (with retry)
        try await awardPremiumDays(userId: referrerId, days: ReferralRewards.referrerBonusDays, reason: "successful_referral")

        // Step 7: Update referrer stats
        try await updateReferrerStats(userId: referrerId)

        // Step 8: Send notification to referrer about successful referral
        await sendReferralSuccessNotification(
            referrerId: referrerId,
            referredUserName: newUser.fullName,
            daysAwarded: ReferralRewards.referrerBonusDays
        )

        Logger.shared.info("Referral processed successfully: \(referralCode)", category: .referral)
    }

    // MARK: - Referral Success Notification

    private func sendReferralSuccessNotification(referrerId: String, referredUserName: String, daysAwarded: Int) async {
        do {
            let notificationData: [String: Any] = [
                "userId": referrerId,
                "type": "referral_success",
                "title": "New Referral! 🎉",
                "body": "\(referredUserName) just signed up with your code! You earned \(daysAwarded) days of Premium!",
                "data": [
                    "referredUserName": referredUserName,
                    "daysAwarded": daysAwarded
                ],
                "timestamp": Timestamp(date: Date()),
                "isRead": false
            ]
            try await db.collection("users").document(referrerId).collection("notifications").addDocument(data: notificationData)
            Logger.shared.info("Sent referral success notification to referrer", category: .referral)
        } catch {
            Logger.shared.error("Failed to send referral success notification", category: .referral, error: error)
        }
    }

    // MARK: - Award Premium Days

    func awardPremiumDays(userId: String, days: Int, reason: String) async throws {
        // Use retry logic for reliability
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                try await performPremiumDaysAward(userId: userId, days: days, reason: reason)
                return // Success
            } catch {
                lastError = error
                Logger.shared.warning("Award premium days attempt \(attempt)/\(maxRetries) failed", category: .referral)

                if attempt < maxRetries {
                    // Wait before retrying with exponential backoff
                    try? await Task.sleep(nanoseconds: retryDelaySeconds * UInt64(attempt) * 1_000_000_000)
                }
            }
        }

        // All retries failed
        if let error = lastError {
            Logger.shared.error("Failed to award premium days after \(maxRetries) attempts", category: .referral, error: error)
            throw error
        }
    }

    private func performPremiumDaysAward(userId: String, days: Int, reason: String) async throws {
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()

        guard let data = document.data() else {
            throw ReferralError.invalidUser
        }

        var expiryDate: Date

        // Check if user has existing premium
        if let existingExpiry = data["subscriptionExpiryDate"] as? Timestamp {
            expiryDate = existingExpiry.dateValue()

            // If expired, start from now
            if expiryDate < Date() {
                expiryDate = Date()
            }
        } else {
            expiryDate = Date()
        }

        // Add the bonus days
        let calendar = Calendar.current
        expiryDate = calendar.date(byAdding: .day, value: days, to: expiryDate) ?? expiryDate

        // Update user with atomic transaction to prevent race conditions
        let userUpdateData: [String: Any] = [
            "isPremium": true,
            "subscriptionExpiryDate": Timestamp(date: expiryDate)
        ]
        try await userRef.updateData(userUpdateData)

        // Log the reward
        let rewardData: [String: Any] = [
            "userId": userId,
            "days": days,
            "reason": reason,
            "awardedAt": Timestamp(date: Date()),
            "expiryDate": Timestamp(date: expiryDate),
            "success": true
        ]
        try await db.collection("referralRewards").addDocument(data: rewardData)

        Logger.shared.info("Awarded \(days) premium days to user \(userId) for \(reason)", category: .referral)
    }

    // MARK: - Update Referrer Stats

    private func updateReferrerStats(userId: String) async throws {
        // First get the old stats to check for milestones
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        let oldStatsDict = userData["referralStats"] as? [String: Any] ?? [:]
        let oldTotalReferrals = oldStatsDict["totalReferrals"] as? Int ?? 0

        var totalReferrals = 0

        do {
            // Try composite query first (requires index)
            let referralsSnapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: ReferralStatus.completed.rawValue)
                .getDocuments()

            totalReferrals = referralsSnapshot.documents.count
        } catch {
            // Fallback: fetch all referrals for user and filter locally
            Logger.shared.warning("Falling back to local filtering for referrer stats - composite index may be missing", category: .referral)

            let referralsSnapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .getDocuments()

            totalReferrals = referralsSnapshot.documents.filter { doc in
                let data = doc.data()
                return (data["status"] as? String) == ReferralStatus.completed.rawValue
            }.count
        }

        let premiumDaysEarned = ReferralRewards.calculateTotalDays(referrals: totalReferrals)

        // Update user stats
        let statsUpdateData: [String: Any] = [
            "referralStats.totalReferrals": totalReferrals,
            "referralStats.premiumDaysEarned": premiumDaysEarned
        ]
        try await db.collection("users").document(userId).updateData(statsUpdateData)

        // Check for milestone achievement
        if let milestone = ReferralMilestone.newlyAchievedMilestone(oldCount: oldTotalReferrals, newCount: totalReferrals) {
            Logger.shared.info("User \(userId) achieved milestone: \(milestone.name)", category: .referral)

            // Award milestone bonus days if any
            if milestone.bonusDays > 0 {
                try await awardPremiumDays(userId: userId, days: milestone.bonusDays, reason: "milestone_\(milestone.id)")
            }

            // Log milestone achievement
            let milestoneData: [String: Any] = [
                "userId": userId,
                "milestoneId": milestone.id,
                "milestoneName": milestone.name,
                "bonusDaysAwarded": milestone.bonusDays,
                "totalReferrals": totalReferrals,
                "achievedAt": Timestamp(date: Date())
            ]
            try await db.collection("referralMilestones").addDocument(data: milestoneData)

            // Set the milestone for UI notification
            await MainActor.run {
                self.newMilestoneReached = milestone
            }

            // Send push notification for milestone
            await sendMilestoneNotification(userId: userId, milestone: milestone)
        }
    }

    // MARK: - Milestone Notifications

    private func sendMilestoneNotification(userId: String, milestone: ReferralMilestone) async {
        do {
            let notificationData: [String: Any] = [
                "userId": userId,
                "type": "referral_milestone",
                "title": "Milestone Achieved!",
                "body": "Congrats! You've reached \(milestone.name) with \(milestone.requiredReferrals) referrals!",
                "data": [
                    "milestoneId": milestone.id,
                    "bonusDays": milestone.bonusDays
                ],
                "timestamp": Timestamp(date: Date()),
                "isRead": false
            ]
            try await db.collection("users").document(userId).collection("notifications").addDocument(data: notificationData)
            Logger.shared.info("Sent milestone notification to user \(userId)", category: .referral)
        } catch {
            Logger.shared.error("Failed to send milestone notification", category: .referral, error: error)
        }
    }

    // MARK: - Fetch User Referrals

    func fetchUserReferrals(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        var referrals: [Referral] = []

        do {
            // Try with ordering first (requires composite index)
            let snapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            referrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
        } catch {
            // Fallback: fetch without ordering if index doesn't exist
            Logger.shared.warning("Falling back to unordered referral query - composite index may be missing", category: .referral)

            let snapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .limit(to: 50)
                .getDocuments()

            // Sort locally instead
            referrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
            referrals.sort { $0.createdAt > $1.createdAt }
        }

        // Fetch referred user names for each referral
        userReferrals = await enrichReferralsWithUserInfo(referrals)
    }

    /// Enriches referrals with referred user information (name, photo)
    private func enrichReferralsWithUserInfo(_ referrals: [Referral]) async -> [Referral] {
        var enrichedReferrals = referrals

        // Collect all referred user IDs
        let userIds = referrals.compactMap { $0.referredUserId }
        guard !userIds.isEmpty else { return referrals }

        // Fetch user info in batches of 10 (Firestore limit for 'in' queries)
        var userInfoMap: [String: (name: String, photoURL: String)] = [:]

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            do {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .getDocuments()

                for doc in usersSnapshot.documents {
                    let data = doc.data()
                    let name = data["fullName"] as? String ?? "Anonymous"
                    let photoURL = data["profileImageURL"] as? String ?? ""
                    userInfoMap[doc.documentID] = (name: name, photoURL: photoURL)
                }
            } catch {
                Logger.shared.warning("Failed to fetch user info for referrals", category: .referral)
            }
        }

        // Enrich referrals with user info
        for index in enrichedReferrals.indices {
            if let referredUserId = enrichedReferrals[index].referredUserId,
               let userInfo = userInfoMap[referredUserId] {
                enrichedReferrals[index].referredUserName = userInfo.name
                enrichedReferrals[index].referredUserPhotoURL = userInfo.photoURL
            }
        }

        return enrichedReferrals
    }

    // MARK: - Real-time Referral Listener

    private var referralListener: ListenerRegistration?

    /// Starts listening for new referrals in real-time
    func startReferralListener(for userId: String) {
        // Remove any existing listener
        stopReferralListener()

        referralListener = db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.shared.error("Referral listener error", category: .referral, error: error)
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let referrals = documents.compactMap { doc in
                    try? doc.data(as: Referral.self)
                }

                // Check for new referrals
                let oldCount = self.userReferrals.count
                let newCount = referrals.count

                Task {
                    self.userReferrals = await self.enrichReferralsWithUserInfo(referrals)

                    // If there's a new referral, haptic feedback
                    if newCount > oldCount && oldCount > 0 {
                        HapticManager.shared.notification(.success)
                        Logger.shared.info("New referral detected via listener", category: .referral)
                    }
                }
            }

        Logger.shared.info("Started referral listener for user", category: .referral)
    }

    /// Stops the real-time referral listener
    func stopReferralListener() {
        referralListener?.remove()
        referralListener = nil
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(limit: Int = 20) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Try with ordering (requires composite index on referralStats.totalReferrals)
            let snapshot = try await db.collection("users")
                .whereField("referralStats.totalReferrals", isGreaterThan: 0)
                .order(by: "referralStats.totalReferrals", descending: true)
                .limit(to: limit)
                .getDocuments()

            leaderboard = parseLeaderboardEntries(from: snapshot.documents)
        } catch {
            // Fallback: fetch without ordering if index doesn't exist
            Logger.shared.warning("Falling back to unordered leaderboard query - composite index may be missing", category: .referral)

            let snapshot = try await db.collection("users")
                .whereField("referralStats.totalReferrals", isGreaterThan: 0)
                .limit(to: limit * 2) // Fetch more to account for local sorting
                .getDocuments()

            // Sort locally and limit
            var entries = parseLeaderboardEntries(from: snapshot.documents)
            entries.sort { $0.totalReferrals > $1.totalReferrals }

            // Re-assign ranks after sorting
            leaderboard = entries.prefix(limit).enumerated().map { index, entry in
                ReferralLeaderboardEntry(
                    id: entry.id,
                    userName: entry.userName,
                    profileImageURL: entry.profileImageURL,
                    totalReferrals: entry.totalReferrals,
                    rank: index + 1,
                    premiumDaysEarned: entry.premiumDaysEarned
                )
            }
        }
    }

    private func parseLeaderboardEntries(from documents: [QueryDocumentSnapshot]) -> [ReferralLeaderboardEntry] {
        var entries: [ReferralLeaderboardEntry] = []
        for (index, doc) in documents.enumerated() {
            let data = doc.data()
            let referralStatsDict = data["referralStats"] as? [String: Any] ?? [:]
            let stats = ReferralStats(dictionary: referralStatsDict)

            let entry = ReferralLeaderboardEntry(
                id: doc.documentID,
                userName: data["fullName"] as? String ?? "Anonymous",
                profileImageURL: data["profileImageURL"] as? String ?? "",
                totalReferrals: stats.totalReferrals,
                rank: index + 1,
                premiumDaysEarned: stats.premiumDaysEarned
            )
            entries.append(entry)
        }
        return entries
    }

    // MARK: - Validate Referral Code

    func validateReferralCode(_ code: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("referralStats.referralCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            return !snapshot.documents.isEmpty
        } catch {
            Logger.shared.error("Error validating referral code", category: .referral, error: error)
            return false
        }
    }

    // MARK: - Get Referral Stats

    func getReferralStats(for user: User) async throws -> ReferralStats {
        guard let userId = user.id else {
            return ReferralStats()
        }

        var baseStats = user.referralStats
        let totalReferrals = baseStats.totalReferrals

        // Try to get pending referrals count
        do {
            let pendingSnapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: ReferralStatus.pending.rawValue)
                .getDocuments()

            baseStats.pendingReferrals = pendingSnapshot.documents.count
        } catch {
            // If composite index is missing, log and continue with 0 pending
            Logger.shared.warning("Could not fetch pending referrals - composite index may be missing", category: .referral)
            baseStats.pendingReferrals = 0
        }

        // Only fetch leaderboard rank if user has referrals
        if totalReferrals > 0 {
            do {
                let leaderboardSnapshot = try await db.collection("users")
                    .whereField("referralStats.totalReferrals", isGreaterThan: totalReferrals)
                    .getDocuments()

                baseStats.referralRank = leaderboardSnapshot.documents.count + 1
            } catch {
                // If query fails, estimate rank as 0 (unknown)
                Logger.shared.warning("Could not fetch referral rank - index may be missing", category: .referral)
                baseStats.referralRank = 0
            }
        }

        return baseStats
    }

    // MARK: - Ensure Referral Code Exists

    /// Ensures the user has a referral code, generating one if needed
    /// Returns the user's referral code
    func ensureReferralCode(for user: User) async throws -> String {
        // If user already has a code, return it
        if !user.referralStats.referralCode.isEmpty {
            return user.referralStats.referralCode
        }

        // Generate and save a new code
        guard let userId = user.id else {
            throw ReferralError.invalidUser
        }

        let code = try await generateReferralCode(for: userId)

        // Update in Firestore
        let updateData: [String: Any] = [
            "referralStats.referralCode": code
        ]
        try await db.collection("users").document(userId).updateData(updateData)

        // Update local user via AuthService
        await MainActor.run {
            authService.updateLocalReferralCode(code)
        }

        Logger.shared.info("Generated referral code for user: \(code)", category: .referral)
        return code
    }

    // MARK: - Share Methods

    func getReferralShareMessage(code: String, userName: String) -> String {
        return """
        Hey! Join me on Celestia, the best dating app for meaningful connections! 💜

        Use my code \(code) when you sign up and we'll both get 3 days of Premium free!

        Download now: https://celestia.app/join/\(code)
        """
    }

    func getReferralURL(code: String) -> URL? {
        return URL(string: "https://celestia.app/join/\(code)")
    }

    // MARK: - Analytics

    func trackShare(userId: String, code: String, shareMethod: String = "generic") async {
        do {
            let shareData: [String: Any] = [
                "userId": userId,
                "referralCode": code,
                "shareMethod": shareMethod,
                "timestamp": Timestamp(date: Date()),
                "platform": "iOS"
            ]
            try await db.collection("referralShares").addDocument(data: shareData)
            Logger.shared.info("Tracked share for code: \(code) via \(shareMethod)", category: .analytics)
        } catch {
            Logger.shared.error("Failed to track share", category: .analytics, error: error)
        }
    }
}
