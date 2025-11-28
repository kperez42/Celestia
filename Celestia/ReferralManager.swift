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

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

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
        guard referrerId != newUserId else {
            Logger.shared.warning("User attempted to refer themselves", category: .referral)
            throw ReferralError.selfReferral
        }

        // Step 2: Check if this user has already been referred (with fallback for missing index)
        var alreadyReferred = false
        do {
            let existingReferralSnapshot = try await db.collection("referrals")
                .whereField("referredUserId", isEqualTo: newUserId)
                .whereField("status", isEqualTo: ReferralStatus.completed.rawValue)
                .limit(to: 1)
                .getDocuments()

            alreadyReferred = !existingReferralSnapshot.documents.isEmpty
        } catch {
            // Fallback: fetch referrals for this user and filter locally
            Logger.shared.warning("Falling back to local filtering for existing referral check", category: .referral)

            let referralsSnapshot = try await db.collection("referrals")
                .whereField("referredUserId", isEqualTo: newUserId)
                .limit(to: 10)
                .getDocuments()

            alreadyReferred = referralsSnapshot.documents.contains { doc in
                let data = doc.data()
                return (data["status"] as? String) == ReferralStatus.completed.rawValue
            }
        }

        if alreadyReferred {
            Logger.shared.warning("User has already been referred", category: .referral)
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

        // Step 4: Create referral record
        let referral = Referral(
            referrerUserId: referrerId,
            referredUserId: newUserId,
            referralCode: referralCode,
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            rewardClaimed: false
        )

        // Save referral
        try await db.collection("referrals").addDocument(from: referral)

        // Step 5: Award bonus days to new user
        try await awardPremiumDays(userId: newUserId, days: ReferralRewards.newUserBonusDays, reason: "referral_signup")

        // Step 6: Award bonus days to referrer
        try await awardPremiumDays(userId: referrerId, days: ReferralRewards.referrerBonusDays, reason: "successful_referral")

        // Step 7: Update referrer stats
        try await updateReferrerStats(userId: referrerId)

        Logger.shared.info("Referral processed successfully: \(referralCode)", category: .referral)
    }

    // MARK: - Award Premium Days

    func awardPremiumDays(userId: String, days: Int, reason: String) async throws {
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()

        guard let data = document.data() else { return }

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

        // Update user
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
            "expiryDate": Timestamp(date: expiryDate)
        ]
        try await db.collection("referralRewards").addDocument(data: rewardData)

        Logger.shared.info("Awarded \(days) premium days to user \(userId) for \(reason)", category: .referral)
    }

    // MARK: - Update Referrer Stats

    private func updateReferrerStats(userId: String) async throws {
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
    }

    // MARK: - Fetch User Referrals

    func fetchUserReferrals(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Try with ordering first (requires composite index)
            let snapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            userReferrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
        } catch {
            // Fallback: fetch without ordering if index doesn't exist
            // This handles the case where composite index is not yet created
            Logger.shared.warning("Falling back to unordered referral query - composite index may be missing", category: .referral)

            let snapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .limit(to: 50)
                .getDocuments()

            // Sort locally instead
            var referrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
            referrals.sort { $0.createdAt > $1.createdAt }
            userReferrals = referrals
        }
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
