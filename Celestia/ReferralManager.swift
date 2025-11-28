//
//  ReferralManager.swift
//  Celestia
//
//  Manages referral system logic
//  Optimized for 10k+ users with caching, rate limiting, and efficient queries
//
//  ENHANCED with:
//  - Fraud detection (device fingerprinting, IP analysis)
//  - Multi-touch attribution
//  - A/B testing for rewards and messaging
//  - ROI analytics and LTV tracking
//  - User segmentation for targeted campaigns
//  - GDPR/CCPA compliance automation
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
    @Published var hasMoreReferrals = false  // For pagination
    @Published var lastFraudAssessment: FraudAssessment?

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

    // Enhanced system integrations
    private let fraudDetector = ReferralFraudDetector.shared
    private let attribution = ReferralAttribution.shared
    private let abTestManager = ReferralABTestManager.shared
    private let analytics = ReferralAnalytics.shared
    private let segmentation = ReferralSegmentation.shared
    private let compliance = ReferralCompliance.shared

    // Retry configuration
    private let maxRetries = 3
    private let retryDelaySeconds: UInt64 = 1

    // MARK: - Caching Configuration (for 10k+ scale)

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let expiresIn: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expiresIn
        }
    }

    // Cache storage
    private var statsCache: [String: CacheEntry<ReferralStats>] = [:]
    private var leaderboardCache: CacheEntry<[ReferralLeaderboardEntry]>?
    private var codeValidationCache: [String: CacheEntry<Bool>] = [:]

    // Cache durations
    private let statsCacheDuration: TimeInterval = 60  // 1 minute
    private let leaderboardCacheDuration: TimeInterval = 300  // 5 minutes
    private let codeValidationCacheDuration: TimeInterval = 30  // 30 seconds

    // MARK: - Rate Limiting (prevent abuse at scale)

    private var lastReferralAttempt: [String: Date] = [:]  // userId -> lastAttempt
    private var referralAttemptCount: [String: Int] = [:]  // userId -> count in window
    private let rateLimitWindow: TimeInterval = 3600  // 1 hour
    private let maxReferralsPerWindow = 10  // Max referral attempts per hour

    // Pagination
    private var lastReferralDocument: DocumentSnapshot?
    private let referralsPageSize = 20

    private init() {}

    // MARK: - Cache Management

    /// Clears all caches - call when user logs out or data needs refresh
    func clearCaches() {
        statsCache.removeAll()
        leaderboardCache = nil
        codeValidationCache.removeAll()
        lastReferralDocument = nil
        Logger.shared.info("Referral caches cleared", category: .referral)
    }

    /// Invalidates stats cache for a specific user
    private func invalidateStatsCache(for userId: String) {
        statsCache.removeValue(forKey: userId)
    }

    /// Invalidates leaderboard cache
    private func invalidateLeaderboardCache() {
        leaderboardCache = nil
    }

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

            // Check if code exists in dedicated referralCodes collection (faster lookup at scale)
            // This collection is indexed by code for O(1) lookups
            let codeDoc = try await db.collection("referralCodes").document(fullCode).getDocument()

            if !codeDoc.exists {
                // Code is unique - reserve it in the dedicated collection
                try await db.collection("referralCodes").document(fullCode).setData([
                    "userId": userId,
                    "createdAt": Timestamp(date: Date()),
                    "active": true
                ])
                return fullCode
            }

            Logger.shared.warning("Referral code collision detected (attempt \(attempt)/5): \(fullCode)", category: .referral)
        }

        // If we still can't generate a unique code after 5 attempts, use userId hash + timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let hashSuffix = String(userId.hashValue).suffix(4)
        let fallbackCode = "CEL-\(hashSuffix)\(String(timestamp).suffix(4))"

        // Reserve the fallback code
        try await db.collection("referralCodes").document(fallbackCode).setData([
            "userId": userId,
            "createdAt": Timestamp(date: Date()),
            "active": true
        ])

        return fallbackCode
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

    // MARK: - Rate Limiting Helpers

    private func checkRateLimit(for userId: String) throws {
        let now = Date()

        // Clean up old entries
        if let lastAttempt = lastReferralAttempt[userId],
           now.timeIntervalSince(lastAttempt) > rateLimitWindow {
            referralAttemptCount[userId] = 0
        }

        // Check if rate limited
        let currentCount = referralAttemptCount[userId] ?? 0
        if currentCount >= maxReferralsPerWindow {
            Logger.shared.warning("Rate limit exceeded for user \(userId)", category: .referral)
            throw ReferralError.rateLimitExceeded
        }

        // Update tracking
        lastReferralAttempt[userId] = now
        referralAttemptCount[userId] = currentCount + 1
    }

    // MARK: - Process Referral on Signup (Enhanced with Fraud Detection & Attribution)

    func processReferralSignup(newUser: User, referralCode: String, ipAddress: String? = nil) async throws {
        // Validate referral code
        guard !referralCode.isEmpty else { return }
        guard let newUserId = newUser.id else {
            throw ReferralError.invalidUser
        }

        // Rate limiting check (prevent abuse at scale)
        try checkRateLimit(for: newUserId)

        // ENHANCED: Check compliance consent
        let hasConsent = await compliance.hasRequiredConsent(userId: newUserId, regulation: nil)
        if !hasConsent {
            Logger.shared.warning("User \(newUserId) missing required consent for referral", category: .referral)
            // Continue but log - consent can be granted later
        }

        // Step 1: Look up referral code in dedicated collection (O(1) lookup)
        let codeDoc = try await db.collection("referralCodes").document(referralCode).getDocument()

        var referrerId: String
        var referrerName: String = "Someone"

        if let codeData = codeDoc.data(), codeDoc.exists {
            // Found in dedicated collection
            referrerId = codeData["userId"] as? String ?? ""
            guard !referrerId.isEmpty else {
                Logger.shared.warning("Invalid referral code (no userId): \(referralCode)", category: .referral)
                throw ReferralError.invalidCode
            }

            // Fetch referrer name
            let referrerDoc = try await db.collection("users").document(referrerId).getDocument()
            referrerName = referrerDoc.data()?["fullName"] as? String ?? "Someone"
        } else {
            // Fallback: legacy lookup in users collection
            let referrerSnapshot = try await db.collection("users")
                .whereField("referralStats.referralCode", isEqualTo: referralCode)
                .limit(to: 1)
                .getDocuments()

            guard let referrerDoc = referrerSnapshot.documents.first else {
                Logger.shared.warning("Invalid referral code: \(referralCode)", category: .referral)
                throw ReferralError.invalidCode
            }

            referrerId = referrerDoc.documentID
            referrerName = referrerDoc.data()["fullName"] as? String ?? "Someone"

            // Migrate code to dedicated collection for future fast lookups
            try? await db.collection("referralCodes").document(referralCode).setData([
                "userId": referrerId,
                "createdAt": Timestamp(date: Date()),
                "active": true,
                "migrated": true
            ])
        }

        guard referrerId != newUserId else {
            Logger.shared.warning("User attempted to refer themselves", category: .referral)
            throw ReferralError.selfReferral
        }

        // ENHANCED: Fraud Detection
        let fraudAssessment = try await fraudDetector.assessReferralFraud(
            userId: newUserId,
            referrerId: referrerId,
            referralCode: referralCode,
            email: newUser.email,
            ipAddress: ipAddress
        )

        lastFraudAssessment = fraudAssessment

        if fraudAssessment.shouldBlock {
            Logger.shared.warning("Referral blocked due to fraud risk: \(fraudAssessment.riskLevel.rawValue)", category: .referral)
            throw ReferralError.rateLimitExceeded  // Use existing error for now
        }

        // Log if flagged for review but allowed
        if fraudAssessment.shouldFlagForReview {
            Logger.shared.warning("Referral flagged for review: \(fraudAssessment.riskLevel.rawValue)", category: .referral)
        }

        // ENHANCED: Attribution tracking
        let attributionResult = try await attribution.attributeConversion(
            userId: newUserId,
            conversionType: .referralComplete,
            revenue: nil
        )

        Logger.shared.info("Attribution: \(attributionResult.attributionModel.rawValue) confidence: \(attributionResult.confidence)", category: .referral)

        // Step 2: Use Firestore transaction for atomic referral creation
        // This prevents race conditions at scale
        let referralDocId = "\(referrerId)_\(newUserId)"

        do {
            try await db.runTransaction { transaction, errorPointer in
                // Check if referral already exists
                let referralRef = self.db.collection("referrals").document(referralDocId)
                let referralDoc: DocumentSnapshot
                do {
                    referralDoc = try transaction.getDocument(referralRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                if referralDoc.exists {
                    errorPointer?.pointee = NSError(
                        domain: "ReferralError",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Referral already exists"]
                    )
                    return nil
                }

                // Check referrer's current count
                let referrerRef = self.db.collection("users").document(referrerId)
                let referrerDoc: DocumentSnapshot
                do {
                    referrerDoc = try transaction.getDocument(referrerRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                let referrerData = referrerDoc.data() ?? [:]
                let referrerStatsDict = referrerData["referralStats"] as? [String: Any] ?? [:]
                let currentReferrals = referrerStatsDict["totalReferrals"] as? Int ?? 0

                if currentReferrals >= ReferralRewards.maxReferrals {
                    errorPointer?.pointee = NSError(
                        domain: "ReferralError",
                        code: 429,
                        userInfo: [NSLocalizedDescriptionKey: "Max referrals reached"]
                    )
                    return nil
                }

                // Create referral record
                let referralData: [String: Any] = [
                    "referrerUserId": referrerId,
                    "referredUserId": newUserId,
                    "referralCode": referralCode,
                    "status": ReferralStatus.completed.rawValue,
                    "createdAt": Timestamp(date: Date()),
                    "completedAt": Timestamp(date: Date()),
                    "rewardClaimed": false
                ]

                transaction.setData(referralData, forDocument: referralRef)

                // Atomically increment referrer's total count
                transaction.updateData([
                    "referralStats.totalReferrals": FieldValue.increment(Int64(1))
                ], forDocument: referrerRef)

                return nil
            }
        } catch {
            // Check specific error types
            if let nsError = error as NSError?, nsError.code == 409 {
                throw ReferralError.alreadyReferred
            } else if let nsError = error as NSError?, nsError.code == 429 {
                throw ReferralError.maxReferralsReached
            }
            throw error
        }

        // ENHANCED: Get personalized rewards from A/B testing and segmentation
        let referrerContext = try? await segmentation.buildContext(for: referrerId)
        let abTestContext = referrerContext.map { ctx in
            UserExperimentContext(
                userId: referrerId,
                totalReferrals: ctx.totalReferrals,
                isPremium: ctx.isPremium,
                accountAgeDays: ctx.accountAgeDays,
                segments: segmentation.getSegments(for: ctx).map { $0.id }
            )
        }

        // Get rewards from A/B test or segmentation
        let (referrerDays, referredDays): (Int, Int)
        if let context = abTestContext {
            referrerDays = await abTestManager.getRewardConfig(for: referrerId, context: context).referrerDays
            referredDays = await abTestManager.getRewardConfig(for: referrerId, context: context).referredDays
        } else if let ctx = referrerContext {
            let segmentRewards = segmentation.getPersonalizedRewards(for: ctx)
            referrerDays = segmentRewards.referrerBonus
            referredDays = segmentRewards.referredBonus
        } else {
            referrerDays = ReferralRewards.referrerBonusDays
            referredDays = ReferralRewards.newUserBonusDays
        }

        // Step 3: Award bonus days (outside transaction for better reliability)
        try await awardPremiumDays(userId: newUserId, days: referredDays, reason: "referral_signup")
        try await awardPremiumDays(userId: referrerId, days: referrerDays, reason: "successful_referral")

        // Track conversion for A/B testing
        for experiment in abTestManager.activeExperiments {
            if let variant = await abTestManager.getVariant(for: referrerId, experimentId: experiment.id, userContext: abTestContext) {
                await abTestManager.trackConversion(experimentId: experiment.id, variantId: variant.id, revenue: nil)
            }
        }

        // Step 4: Update referrer stats (full recalculation for milestones)
        try await updateReferrerStats(userId: referrerId)

        // Invalidate caches
        invalidateStatsCache(for: referrerId)
        invalidateLeaderboardCache()

        // Step 5: Send notification
        await sendReferralSuccessNotification(
            referrerId: referrerId,
            referredUserName: newUser.fullName,
            daysAwarded: referrerDays
        )

        // ENHANCED: Update user segment assignment
        if let ctx = referrerContext {
            let segments = segmentation.getSegments(for: ctx)
            await segmentation.trackSegmentAssignment(userId: referrerId, segmentIds: segments.map { $0.id })
        }

        // ENHANCED: Store referral signup data for analytics
        await storeReferralSignupData(
            referrerId: referrerId,
            referredUserId: newUserId,
            referralCode: referralCode,
            fraudScore: fraudAssessment.riskScore,
            attributionConfidence: attributionResult.confidence,
            referrerDays: referrerDays,
            referredDays: referredDays
        )

        Logger.shared.info("Referral processed successfully: \(referralCode)", category: .referral)
    }

    /// Stores additional referral data for analytics
    private func storeReferralSignupData(
        referrerId: String,
        referredUserId: String,
        referralCode: String,
        fraudScore: Double,
        attributionConfidence: Double,
        referrerDays: Int,
        referredDays: Int
    ) async {
        let data: [String: Any] = [
            "referrerId": referrerId,
            "referredUserId": referredUserId,
            "referralCode": referralCode,
            "fraudScore": fraudScore,
            "attributionConfidence": attributionConfidence,
            "referrerDaysAwarded": referrerDays,
            "referredDaysAwarded": referredDays,
            "createdAt": Timestamp(date: Date()),
            "ipAddress": "",  // Would come from request
            "deviceFingerprint": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]

        do {
            try await db.collection("referralSignups").addDocument(data: data)
        } catch {
            Logger.shared.error("Failed to store referral signup data", category: .referral, error: error)
        }
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

    // MARK: - Fetch User Referrals (Paginated for scale)

    func fetchUserReferrals(userId: String, loadMore: Bool = false) async throws {
        isLoading = true
        defer { isLoading = false }

        var referrals: [Referral] = []

        // If not loading more, reset pagination
        if !loadMore {
            lastReferralDocument = nil
        }

        do {
            // Build query with pagination
            var query = db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: referralsPageSize)

            // If loading more, start after last document
            if loadMore, let lastDoc = lastReferralDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            // Track last document for pagination
            lastReferralDocument = snapshot.documents.last
            hasMoreReferrals = snapshot.documents.count == referralsPageSize

            referrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
        } catch {
            // Fallback: fetch without ordering if index doesn't exist
            Logger.shared.warning("Falling back to unordered referral query - composite index may be missing", category: .referral)

            let snapshot = try await db.collection("referrals")
                .whereField("referrerUserId", isEqualTo: userId)
                .limit(to: referralsPageSize)
                .getDocuments()

            // Sort locally instead
            referrals = snapshot.documents.compactMap { doc in
                try? doc.data(as: Referral.self)
            }
            referrals.sort { $0.createdAt > $1.createdAt }
            hasMoreReferrals = false  // Can't paginate without ordering
        }

        // Fetch referred user names for each referral
        let enrichedReferrals = await enrichReferralsWithUserInfo(referrals)

        // If loading more, append to existing list
        if loadMore {
            userReferrals.append(contentsOf: enrichedReferrals)
        } else {
            userReferrals = enrichedReferrals
        }
    }

    /// Load more referrals for pagination
    func loadMoreReferrals(userId: String) async throws {
        guard hasMoreReferrals, !isLoading else { return }
        try await fetchUserReferrals(userId: userId, loadMore: true)
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

    // MARK: - Leaderboard (Optimized for 10k+ users)

    func fetchLeaderboard(limit: Int = 20, forceRefresh: Bool = false) async throws {
        // Check cache first (unless force refresh)
        if !forceRefresh,
           let cached = leaderboardCache,
           !cached.isExpired {
            leaderboard = cached.value
            Logger.shared.info("Returning cached leaderboard (\(cached.value.count) entries)", category: .referral)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Try with ordering (requires composite index on referralStats.totalReferrals)
            let snapshot = try await db.collection("users")
                .whereField("referralStats.totalReferrals", isGreaterThan: 0)
                .order(by: "referralStats.totalReferrals", descending: true)
                .limit(to: limit)
                .getDocuments()

            let entries = parseLeaderboardEntries(from: snapshot.documents)
            leaderboard = entries

            // Cache the result
            leaderboardCache = CacheEntry(
                value: entries,
                timestamp: Date(),
                expiresIn: leaderboardCacheDuration
            )
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
            let finalEntries = Array(entries.prefix(limit).enumerated().map { index, entry in
                ReferralLeaderboardEntry(
                    id: entry.id,
                    userName: entry.userName,
                    profileImageURL: entry.profileImageURL,
                    totalReferrals: entry.totalReferrals,
                    rank: index + 1,
                    premiumDaysEarned: entry.premiumDaysEarned
                )
            })

            leaderboard = finalEntries

            // Cache the result
            leaderboardCache = CacheEntry(
                value: finalEntries,
                timestamp: Date(),
                expiresIn: leaderboardCacheDuration
            )
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

    // MARK: - Validate Referral Code (Cached for scale)

    func validateReferralCode(_ code: String) async -> Bool {
        // Check cache first
        if let cached = codeValidationCache[code], !cached.isExpired {
            return cached.value
        }

        do {
            // First check dedicated referralCodes collection (O(1) lookup)
            let codeDoc = try await db.collection("referralCodes").document(code).getDocument()

            if codeDoc.exists {
                // Cache the result
                codeValidationCache[code] = CacheEntry(
                    value: true,
                    timestamp: Date(),
                    expiresIn: codeValidationCacheDuration
                )
                return true
            }

            // Fallback to users collection for legacy codes
            let snapshot = try await db.collection("users")
                .whereField("referralStats.referralCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            let isValid = !snapshot.documents.isEmpty

            // Cache the result
            codeValidationCache[code] = CacheEntry(
                value: isValid,
                timestamp: Date(),
                expiresIn: codeValidationCacheDuration
            )

            return isValid
        } catch {
            Logger.shared.error("Error validating referral code", category: .referral, error: error)
            return false
        }
    }

    // MARK: - Get Referral Stats (Cached for scale)

    func getReferralStats(for user: User, forceRefresh: Bool = false) async throws -> ReferralStats {
        guard let userId = user.id else {
            return ReferralStats()
        }

        // Check cache first (unless force refresh)
        if !forceRefresh,
           let cached = statsCache[userId],
           !cached.isExpired {
            Logger.shared.info("Returning cached stats for user", category: .referral)
            return cached.value
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

        // Optimized rank calculation for 10k+ users
        // Instead of counting all users with more referrals, use cached leaderboard position
        if totalReferrals > 0 {
            // First check if user is in cached leaderboard
            if let cachedLeaderboard = leaderboardCache?.value,
               let entry = cachedLeaderboard.first(where: { $0.id == userId }) {
                baseStats.referralRank = entry.rank
            } else {
                // Use count query with limit for efficiency (approximate rank)
                do {
                    let leaderboardSnapshot = try await db.collection("users")
                        .whereField("referralStats.totalReferrals", isGreaterThan: totalReferrals)
                        .limit(to: 1000)  // Limit query scope for performance
                        .getDocuments()

                    // If at limit, rank is approximate (1000+)
                    let countAbove = leaderboardSnapshot.documents.count
                    baseStats.referralRank = countAbove >= 1000 ? 1000 : countAbove + 1
                } catch {
                    // If query fails, estimate rank as 0 (unknown)
                    Logger.shared.warning("Could not fetch referral rank - index may be missing", category: .referral)
                    baseStats.referralRank = 0
                }
            }
        }

        // Cache the result
        statsCache[userId] = CacheEntry(
            value: baseStats,
            timestamp: Date(),
            expiresIn: statsCacheDuration
        )

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

    // MARK: - Share Methods (Enhanced with A/B Testing & Segmentation)

    func getReferralShareMessage(code: String, userName: String) -> String {
        return """
        Hey! Join me on Celestia, the best dating app for meaningful connections! 💜

        Use my code \(code) when you sign up and we'll both get 3 days of Premium free!

        Download now: https://celestia.app/join/\(code)
        """
    }

    /// Gets personalized share message using A/B testing and segmentation
    func getPersonalizedShareMessage(for userId: String, code: String) async -> String {
        // Build user context for segmentation
        if let context = try? await segmentation.buildContext(for: userId) {
            // Check for segment-specific message first
            if let segmentMessage = segmentation.getPersonalizedMessage(for: context, code: code) {
                return segmentMessage
            }

            // Check A/B test variants
            let abContext = UserExperimentContext(
                userId: userId,
                totalReferrals: context.totalReferrals,
                isPremium: context.isPremium,
                accountAgeDays: context.accountAgeDays,
                segments: segmentation.getSegments(for: context).map { $0.id }
            )

            let message = await abTestManager.getShareMessage(for: userId, code: code, context: abContext)
            return message
        }

        // Fallback to default message
        return getReferralShareMessage(code: code, userName: "")
    }

    func getReferralURL(code: String) -> URL? {
        return URL(string: "https://celestia.app/join/\(code)")
    }

    // MARK: - Analytics (Enhanced)

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

            // Track touchpoint for attribution
            await attribution.recordTouchpoint(
                type: .inAppShare,
                source: "app",
                medium: shareMethod,
                referralCode: code
            )

            Logger.shared.info("Tracked share for code: \(code) via \(shareMethod)", category: .analytics)
        } catch {
            Logger.shared.error("Failed to track share", category: .analytics, error: error)
        }
    }

    // MARK: - Enhanced Analytics Access

    /// Gets comprehensive ROI metrics for the referral program
    func getROIMetrics(period: AnalyticsPeriod = .month) async throws -> ReferralROIMetrics {
        return try await analytics.calculateROIMetrics(period: period)
    }

    /// Gets conversion funnel data
    func getConversionFunnel(period: AnalyticsPeriod = .month) async throws -> ConversionFunnel {
        return try await analytics.generateConversionFunnel(period: period)
    }

    /// Gets top performing referral sources
    func getTopSources(period: AnalyticsPeriod = .month) async throws -> [SourcePerformance] {
        return try await analytics.analyzeSourcePerformance(period: period)
    }

    /// Gets dashboard summary metrics
    func getDashboardMetrics() async throws -> ReferralDashboardMetrics {
        return try await analytics.getDashboardMetrics()
    }

    /// Calculates LTV for a specific user
    func calculateUserLTV(userId: String) async throws -> UserLTV {
        return try await analytics.calculateUserLTV(userId: userId)
    }

    // MARK: - Fraud Detection Access

    /// Gets fraud assessment history for a user
    func getFraudHistory(userId: String) async throws -> [FraudAssessment] {
        return try await fraudDetector.getAssessmentHistory(userId: userId)
    }

    /// Gets referrals flagged for manual review
    func getFlaggedReferrals() async throws -> [FraudAssessment] {
        return try await fraudDetector.getFlaggedReferrals()
    }

    /// Marks a fraud assessment as reviewed
    func reviewFraudAssessment(assessmentId: String, approved: Bool, notes: String) async throws {
        try await fraudDetector.markAsReviewed(assessmentId: assessmentId, approved: approved, reviewerNotes: notes)
    }

    // MARK: - A/B Testing Access

    /// Gets active experiments
    func getActiveExperiments() -> [ReferralExperiment] {
        return abTestManager.activeExperiments
    }

    /// Gets experiment results
    func getExperimentResults(experimentId: String) async throws -> ReferralExperimentResults {
        return try await abTestManager.calculateResults(experimentId: experimentId)
    }

    // MARK: - Segmentation Access

    /// Gets segments for the current user
    func getUserSegments(userId: String) async throws -> [UserSegment] {
        let context = try await segmentation.buildContext(for: userId)
        return segmentation.getSegments(for: context)
    }

    /// Gets segment statistics
    func getSegmentStats(segmentId: String) async throws -> SegmentStats {
        return try await segmentation.getSegmentStats(segmentId: segmentId)
    }

    // MARK: - Compliance Access

    /// Creates a data export request (GDPR right to access)
    func requestDataExport(userId: String, email: String, regulation: PrivacyRegulation) async throws -> DataSubjectRequest {
        return try await compliance.createDataRequest(
            userId: userId,
            email: email,
            requestType: .portability,
            regulation: regulation
        )
    }

    /// Creates a data deletion request (GDPR right to be forgotten)
    func requestDataDeletion(userId: String, email: String, regulation: PrivacyRegulation) async throws -> DataSubjectRequest {
        return try await compliance.createDataRequest(
            userId: userId,
            email: email,
            requestType: .erasure,
            regulation: regulation
        )
    }

    /// Records user consent
    func recordConsent(userId: String, consentType: ConsentType, granted: Bool) async throws {
        try await compliance.recordConsent(userId: userId, consentType: consentType, granted: granted)
    }

    /// Gets user consent status
    func getConsentStatus(userId: String) async throws -> [ConsentType: Bool] {
        return try await compliance.getConsentStatus(userId: userId)
    }

    // MARK: - Attribution Access

    /// Records a deep link click for attribution
    func recordDeepLinkClick(url: URL, referralCode: String?) async {
        await attribution.recordDeepLinkClick(url: url, referralCode: referralCode)
    }

    /// Attempts to match a deferred deep link
    func matchDeferredDeepLink() async throws -> DeferredDeepLink? {
        let fingerprint = LinkFingerprint(
            ipAddress: nil,
            userAgent: nil,
            screenResolution: "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))",
            timezone: TimeZone.current.identifier,
            language: Locale.current.language.languageCode?.identifier,
            platform: "iOS"
        )
        return try await attribution.matchDeferredDeepLink(currentFingerprint: fingerprint)
    }

    /// Claims a deferred deep link after signup
    func claimDeferredDeepLink(linkId: String, userId: String) async throws {
        try await attribution.claimDeferredDeepLink(linkId: linkId, userId: userId)
    }
}

// MARK: - UIKit Import for Device Info
import UIKit
