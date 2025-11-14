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
        try await db.collection("users").document(userId).updateData([
            "referralStats.referralCode": code
        ])
    }

    // MARK: - Process Referral on Signup

    func processReferralSignup(newUser: User, referralCode: String) async throws {
        // Validate referral code
        guard !referralCode.isEmpty else { return }
        guard let newUserId = newUser.id else {
            throw ReferralError.invalidUser
        }

        // Parallelize all validation queries for better performance
        async let referrerQuery = db.collection("users")
            .whereField("referralStats.referralCode", isEqualTo: referralCode)
            .limit(to: 1)
            .getDocuments()

        async let existingReferralQuery = db.collection("referrals")
            .whereField("referredUserId", isEqualTo: newUserId)
            .whereField("status", isEqualTo: ReferralStatus.completed.rawValue)
            .limit(to: 1)
            .getDocuments()

        async let emailCheckQuery = db.collection("users")
            .whereField("email", isEqualTo: newUser.email)
            .limit(to: 5)
            .getDocuments()

        // Wait for all queries to complete
        let (querySnapshot, existingReferralSnapshot, emailCheckSnapshot) = try await (referrerQuery, existingReferralQuery, emailCheckQuery)

        // Validate referrer exists
        guard let referrerDoc = querySnapshot.documents.first else {
            Logger.shared.warning("Invalid referral code: \(referralCode)", category: .referral)
            throw ReferralError.invalidCode
        }

        let referrerId = referrerDoc.documentID
        guard referrerId != newUserId else {
            Logger.shared.warning("User attempted to refer themselves", category: .referral)
            throw ReferralError.selfReferral
        }

        // Check if this user has already been referred
        if !existingReferralSnapshot.documents.isEmpty {
            Logger.shared.warning("User has already been referred", category: .referral)
            throw ReferralError.alreadyReferred
        }

        // Filter for users with referredByCode
        let usersWithReferral = emailCheckSnapshot.documents.filter { doc in
            let data = doc.data()
            return data["referredByCode"] != nil && !(data["referredByCode"] is NSNull)
        }

        if !usersWithReferral.isEmpty {
            // Email was already used with a referral code
        }
        if emailCheckSnapshot.documents.count > 1 {
            Logger.shared.warning("Email has already been referred with a different account", category: .referral)
            throw ReferralError.emailAlreadyReferred
        }

        // Create referral record
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

        // Award bonus days to new user
        try await awardPremiumDays(userId: newUserId, days: ReferralRewards.newUserBonusDays, reason: "referral_signup")

        // Award bonus days to referrer
        try await awardPremiumDays(userId: referrerId, days: ReferralRewards.referrerBonusDays, reason: "successful_referral")

        // Update referrer stats
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
        try await userRef.updateData([
            "isPremium": true,
            "subscriptionExpiryDate": Timestamp(date: expiryDate)
        ])

        // Log the reward
        try await db.collection("referralRewards").addDocument(data: [
            "userId": userId,
            "days": days,
            "reason": reason,
            "awardedAt": Timestamp(date: Date()),
            "expiryDate": Timestamp(date: expiryDate)
        ])

        Logger.shared.info("Awarded \(days) premium days to user \(userId) for \(reason)", category: .referral)
    }

    // MARK: - Update Referrer Stats

    private func updateReferrerStats(userId: String) async throws {
        // Count successful referrals
        let referralsSnapshot = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: ReferralStatus.completed.rawValue)
            .getDocuments()

        let totalReferrals = referralsSnapshot.documents.count
        let premiumDaysEarned = ReferralRewards.calculateTotalDays(referrals: totalReferrals)

        // Update user stats
        try await db.collection("users").document(userId).updateData([
            "referralStats.totalReferrals": totalReferrals,
            "referralStats.premiumDaysEarned": premiumDaysEarned
        ])
    }

    // MARK: - Fetch User Referrals

    func fetchUserReferrals(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        userReferrals = snapshot.documents.compactMap { doc in
            try? doc.data(as: Referral.self)
        }
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(limit: Int = 20) async throws {
        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection("users")
            .whereField("referralStats.totalReferrals", isGreaterThan: 0)
            .order(by: "referralStats.totalReferrals", descending: true)
            .limit(to: limit)
            .getDocuments()

        var entries: [ReferralLeaderboardEntry] = []
        for (index, doc) in snapshot.documents.enumerated() {
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

        leaderboard = entries
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

        var stats = user.referralStats

        // Parallelize queries for better performance
        async let pendingQuery = db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: ReferralStatus.pending.rawValue)
            .getDocuments()

        // Only fetch leaderboard if user has referrals
        if stats.totalReferrals > 0 {
            async let leaderboardQuery = db.collection("users")
                .whereField("referralStats.totalReferrals", isGreaterThan: stats.totalReferrals)
                .getDocuments()

            // Wait for both queries
            let (pendingSnapshot, leaderboardSnapshot) = try await (pendingQuery, leaderboardQuery)
            stats.pendingReferrals = pendingSnapshot.documents.count
            stats.referralRank = leaderboardSnapshot.documents.count + 1
        } else {
            // Only wait for pending query
            let pendingSnapshot = try await pendingQuery
            stats.pendingReferrals = pendingSnapshot.documents.count
        }

        return stats
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
            try await db.collection("referralShares").addDocument(data: [
                "userId": userId,
                "referralCode": code,
                "shareMethod": shareMethod,
                "timestamp": Timestamp(date: Date()),
                "platform": "iOS"
            ])
            Logger.shared.info("Tracked share for code: \(code) via \(shareMethod)", category: .analytics)
        } catch {
            Logger.shared.error("Failed to track share", category: .analytics, error: error)
        }
    }
}
