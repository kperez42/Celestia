//
//  ReferralAnalytics.swift
//  Celestia
//
//  Advanced analytics for referral ROI tracking
//  Features: LTV calculation, conversion funnels, cohort analysis, cost metrics
//

import Foundation
import FirebaseFirestore

// MARK: - Analytics Models

struct ReferralROIMetrics: Codable {
    let calculatedAt: Date
    let periodStart: Date
    let periodEnd: Date

    // Acquisition Metrics
    let totalReferrals: Int
    let successfulReferrals: Int
    let conversionRate: Double

    // Revenue Metrics
    let totalRevenue: Double
    let referralRevenue: Double              // Revenue from referred users
    let revenuePerReferral: Double
    let revenuePerSuccessfulReferral: Double

    // Cost Metrics
    let totalPremiumDaysAwarded: Int
    let estimatedCostOfPremium: Double       // Value of premium days given away
    let costPerAcquisition: Double           // CPA
    let customerAcquisitionCost: Double      // CAC

    // LTV Metrics
    let averageLTV: Double                   // Lifetime value of referred users
    let averageLTVRatio: Double              // LTV / CAC ratio
    let paybackPeriodDays: Int               // Days to recover CAC

    // Efficiency Metrics
    let viralCoefficient: Double             // K-factor
    let referralROI: Double                  // (Revenue - Cost) / Cost
}

struct ConversionFunnel: Codable {
    let funnelId: String
    let name: String
    let calculatedAt: Date
    let period: AnalyticsPeriod
    let stages: [FunnelStage]

    var overallConversionRate: Double {
        guard let first = stages.first, let last = stages.last, first.count > 0 else { return 0 }
        return Double(last.count) / Double(first.count)
    }
}

struct FunnelStage: Codable {
    let name: String
    let count: Int
    let conversionRate: Double       // From previous stage
    let dropoffRate: Double          // 1 - conversionRate
    let averageTimeToNext: TimeInterval?
}

enum AnalyticsPeriod: String, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    case allTime = "all_time"

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        let start: Date
        switch self {
        case .day:
            start = calendar.startOfDay(for: now)
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .quarter:
            start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            start = calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }

        return (start, now)
    }
}

// MARK: - Cohort Analysis

struct CohortAnalysis: Codable {
    let cohortId: String
    let cohortType: CohortType
    let cohortDate: Date               // When the cohort started
    let totalUsers: Int
    let retention: [RetentionDataPoint]
    let revenue: [RevenueDataPoint]
    let activity: [ActivityDataPoint]
}

enum CohortType: String, Codable {
    case signup = "signup"             // By signup date
    case firstReferral = "first_referral"  // By first referral date
    case firstPurchase = "first_purchase"  // By first purchase date
}

struct RetentionDataPoint: Codable {
    let daysSince: Int
    let activeUsers: Int
    let retentionRate: Double
}

struct RevenueDataPoint: Codable {
    let daysSince: Int
    let cumulativeRevenue: Double
    let revenuePerUser: Double
}

struct ActivityDataPoint: Codable {
    let daysSince: Int
    let averageReferrals: Double
    let averageSessions: Double
}

// MARK: - User LTV

struct UserLTV: Codable {
    let userId: String
    let calculatedAt: Date

    // Revenue components
    let subscriptionRevenue: Double
    let inAppPurchaseRevenue: Double
    let totalRevenue: Double

    // Predicted values
    let predictedLTV: Double
    let confidenceScore: Double

    // Engagement metrics
    let daysSinceSignup: Int
    let totalSessions: Int
    let totalReferrals: Int
    let isPremium: Bool

    // Acquisition source
    let acquisitionSource: String
    let wasReferred: Bool
    let referredByUserId: String?
}

// MARK: - Source Performance

struct SourcePerformance: Codable {
    let source: String
    let period: AnalyticsPeriod

    // Volume metrics
    let totalClicks: Int
    let totalSignups: Int
    let clickToSignupRate: Double

    // Quality metrics
    let averageLTV: Double
    let averageReferrals: Double
    let premiumConversionRate: Double

    // Cost metrics
    let totalCost: Double
    let costPerClick: Double
    let costPerSignup: Double
    let roi: Double
}

// MARK: - Analytics Manager

@MainActor
class ReferralAnalytics: ObservableObject {
    static let shared = ReferralAnalytics()

    private let db = Firestore.firestore()

    // Cached metrics
    @Published var currentROI: ReferralROIMetrics?
    @Published var currentFunnel: ConversionFunnel?
    @Published var topSources: [SourcePerformance] = []

    // Configuration
    private let premiumDayValue: Double = 2.99 / 30  // Value per premium day (based on monthly subscription)

    private init() {}

    // MARK: - ROI Calculation

    /// Calculates comprehensive ROI metrics for the referral program
    func calculateROIMetrics(period: AnalyticsPeriod = .month) async throws -> ReferralROIMetrics {
        let dateRange = period.dateRange

        // Fetch referral data
        let referralsSnapshot = try await db.collection("referrals")
            .whereField("createdAt", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("createdAt", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        let totalReferrals = referralsSnapshot.documents.count
        let successfulReferrals = referralsSnapshot.documents.filter {
            ($0.data()["status"] as? String) == "completed"
        }.count

        // Fetch reward data
        let rewardsSnapshot = try await db.collection("referralRewards")
            .whereField("awardedAt", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("awardedAt", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        let totalPremiumDaysAwarded = rewardsSnapshot.documents.reduce(0) { sum, doc in
            sum + (doc.data()["days"] as? Int ?? 0)
        }

        // Fetch revenue data from referred users
        let referredUserIds = referralsSnapshot.documents.compactMap {
            $0.data()["referredUserId"] as? String
        }

        var referralRevenue = 0.0
        if !referredUserIds.isEmpty {
            // Batch fetch in groups of 10
            for batch in stride(from: 0, to: referredUserIds.count, by: 10) {
                let endIndex = min(batch + 10, referredUserIds.count)
                let batchIds = Array(referredUserIds[batch..<endIndex])

                let purchasesSnapshot = try await db.collection("purchases")
                    .whereField("userId", in: batchIds)
                    .whereField("purchaseDate", isGreaterThan: Timestamp(date: dateRange.start))
                    .getDocuments()

                referralRevenue += purchasesSnapshot.documents.reduce(0.0) { sum, doc in
                    sum + (doc.data()["amount"] as? Double ?? 0)
                }
            }
        }

        // Fetch total revenue for comparison
        let totalRevenueSnapshot = try await db.collection("purchases")
            .whereField("purchaseDate", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("purchaseDate", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        let totalRevenue = totalRevenueSnapshot.documents.reduce(0.0) { sum, doc in
            sum + (doc.data()["amount"] as? Double ?? 0)
        }

        // Calculate LTV for referred users
        let averageLTV = await calculateAverageLTV(userIds: referredUserIds)

        // Calculate metrics
        let conversionRate = totalReferrals > 0 ? Double(successfulReferrals) / Double(totalReferrals) : 0
        let revenuePerReferral = totalReferrals > 0 ? referralRevenue / Double(totalReferrals) : 0
        let revenuePerSuccessfulReferral = successfulReferrals > 0 ? referralRevenue / Double(successfulReferrals) : 0

        let estimatedCostOfPremium = Double(totalPremiumDaysAwarded) * premiumDayValue
        let costPerAcquisition = successfulReferrals > 0 ? estimatedCostOfPremium / Double(successfulReferrals) : 0
        let customerAcquisitionCost = costPerAcquisition  // Same in this context

        let ltvRatio = customerAcquisitionCost > 0 ? averageLTV / customerAcquisitionCost : 0

        // Calculate payback period (days to recover CAC)
        let dailyRevenue = averageLTV / 365  // Assume 1 year average lifetime
        let paybackPeriodDays = dailyRevenue > 0 ? Int(customerAcquisitionCost / dailyRevenue) : 0

        // Calculate viral coefficient
        let viralCoefficient = await calculateViralCoefficient(period: period)

        // Calculate ROI
        let referralROI = estimatedCostOfPremium > 0 ? (referralRevenue - estimatedCostOfPremium) / estimatedCostOfPremium : 0

        let metrics = ReferralROIMetrics(
            calculatedAt: Date(),
            periodStart: dateRange.start,
            periodEnd: dateRange.end,
            totalReferrals: totalReferrals,
            successfulReferrals: successfulReferrals,
            conversionRate: conversionRate,
            totalRevenue: totalRevenue,
            referralRevenue: referralRevenue,
            revenuePerReferral: revenuePerReferral,
            revenuePerSuccessfulReferral: revenuePerSuccessfulReferral,
            totalPremiumDaysAwarded: totalPremiumDaysAwarded,
            estimatedCostOfPremium: estimatedCostOfPremium,
            costPerAcquisition: costPerAcquisition,
            customerAcquisitionCost: customerAcquisitionCost,
            averageLTV: averageLTV,
            averageLTVRatio: ltvRatio,
            paybackPeriodDays: paybackPeriodDays,
            viralCoefficient: viralCoefficient,
            referralROI: referralROI
        )

        currentROI = metrics

        // Store for historical tracking
        try await storeROIMetrics(metrics)

        return metrics
    }

    // MARK: - LTV Calculation

    /// Calculates average LTV for a set of users
    func calculateAverageLTV(userIds: [String]) async -> Double {
        guard !userIds.isEmpty else { return 0 }

        var totalLTV = 0.0
        var userCount = 0

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            do {
                let purchasesSnapshot = try await db.collection("purchases")
                    .whereField("userId", in: batchIds)
                    .getDocuments()

                // Sum revenue per user
                var userRevenue: [String: Double] = [:]
                for doc in purchasesSnapshot.documents {
                    let userId = doc.data()["userId"] as? String ?? ""
                    let amount = doc.data()["amount"] as? Double ?? 0
                    userRevenue[userId, default: 0] += amount
                }

                totalLTV += userRevenue.values.reduce(0, +)
                userCount += batchIds.count
            } catch {
                Logger.shared.error("Failed to fetch user LTV", category: .referral, error: error)
            }
        }

        return userCount > 0 ? totalLTV / Double(userCount) : 0
    }

    /// Calculates predicted LTV for a single user
    func calculateUserLTV(userId: String) async throws -> UserLTV {
        // Fetch user data
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]

        // Fetch purchase history
        let purchasesSnapshot = try await db.collection("purchases")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        var subscriptionRevenue = 0.0
        var inAppPurchaseRevenue = 0.0

        for doc in purchasesSnapshot.documents {
            let data = doc.data()
            let amount = data["amount"] as? Double ?? 0
            let type = data["type"] as? String ?? ""

            if type == "subscription" {
                subscriptionRevenue += amount
            } else {
                inAppPurchaseRevenue += amount
            }
        }

        let totalRevenue = subscriptionRevenue + inAppPurchaseRevenue

        // Calculate days since signup
        let createdAt = (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let daysSinceSignup = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0

        // Fetch session count
        let sessionsSnapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let totalSessions = sessionsSnapshot.documents.count

        // Get referral stats
        let referralStats = userData["referralStats"] as? [String: Any] ?? [:]
        let totalReferrals = referralStats["totalReferrals"] as? Int ?? 0

        // Check if user was referred
        let referralSnapshot = try await db.collection("referrals")
            .whereField("referredUserId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()

        let wasReferred = !referralSnapshot.documents.isEmpty
        let referredByUserId = referralSnapshot.documents.first?.data()["referrerUserId"] as? String

        // Predict future LTV
        let predictedLTV = predictLTV(
            currentRevenue: totalRevenue,
            daysSinceSignup: daysSinceSignup,
            totalSessions: totalSessions,
            isPremium: userData["isPremium"] as? Bool ?? false,
            totalReferrals: totalReferrals
        )

        return UserLTV(
            userId: userId,
            calculatedAt: Date(),
            subscriptionRevenue: subscriptionRevenue,
            inAppPurchaseRevenue: inAppPurchaseRevenue,
            totalRevenue: totalRevenue,
            predictedLTV: predictedLTV.value,
            confidenceScore: predictedLTV.confidence,
            daysSinceSignup: daysSinceSignup,
            totalSessions: totalSessions,
            totalReferrals: totalReferrals,
            isPremium: userData["isPremium"] as? Bool ?? false,
            acquisitionSource: userData["acquisitionSource"] as? String ?? "organic",
            wasReferred: wasReferred,
            referredByUserId: referredByUserId
        )
    }

    private func predictLTV(currentRevenue: Double, daysSinceSignup: Int, totalSessions: Int, isPremium: Bool, totalReferrals: Int) -> (value: Double, confidence: Double) {
        // Simple prediction model - in production, use ML
        var predictedLTV = currentRevenue

        // If user is new, project based on engagement
        if daysSinceSignup < 90 {
            let sessionsPerDay = daysSinceSignup > 0 ? Double(totalSessions) / Double(daysSinceSignup) : 0
            let engagementMultiplier = min(sessionsPerDay * 0.5, 2.0)

            // Base prediction on premium status
            let baseLTV = isPremium ? 150.0 : 30.0
            predictedLTV = max(currentRevenue, baseLTV * engagementMultiplier)
        }

        // Add referral bonus prediction
        if totalReferrals > 0 {
            // Referrers tend to have 30% higher LTV
            predictedLTV *= 1.3
        }

        // Calculate confidence based on data availability
        var confidence = 0.5
        if daysSinceSignup > 30 { confidence += 0.15 }
        if daysSinceSignup > 90 { confidence += 0.15 }
        if totalSessions > 10 { confidence += 0.1 }
        if currentRevenue > 0 { confidence += 0.1 }

        return (predictedLTV, min(confidence, 0.95))
    }

    // MARK: - Conversion Funnel

    /// Generates conversion funnel analysis
    func generateConversionFunnel(period: AnalyticsPeriod = .month) async throws -> ConversionFunnel {
        let dateRange = period.dateRange

        // Stage 1: Referral link clicks
        let clicksSnapshot = try await db.collection("attributionTouchpoints")
            .whereField("type", isEqualTo: "direct_link")
            .whereField("timestamp", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("timestamp", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        let totalClicks = clicksSnapshot.documents.count

        // Stage 2: App installs (from referral)
        let installsSnapshot = try await db.collection("attributionResults")
            .whereField("conversionType", isEqualTo: "install")
            .whereField("attributedAt", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("attributedAt", isLessThan: Timestamp(date: dateRange.end))
            .whereField("attributedReferralCode", isNotEqualTo: "")
            .getDocuments()

        let totalInstalls = installsSnapshot.documents.count

        // Stage 3: Signups with referral code
        let signupsSnapshot = try await db.collection("referrals")
            .whereField("createdAt", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("createdAt", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        let totalSignups = signupsSnapshot.documents.count

        // Stage 4: Completed referrals
        let completedReferrals = signupsSnapshot.documents.filter {
            ($0.data()["status"] as? String) == "completed"
        }.count

        // Stage 5: Premium conversions from referred users
        let referredUserIds = signupsSnapshot.documents.compactMap {
            $0.data()["referredUserId"] as? String
        }

        var premiumConversions = 0
        if !referredUserIds.isEmpty {
            for batch in stride(from: 0, to: referredUserIds.count, by: 10) {
                let endIndex = min(batch + 10, referredUserIds.count)
                let batchIds = Array(referredUserIds[batch..<endIndex])

                let premiumSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .whereField("isPremium", isEqualTo: true)
                    .getDocuments()

                premiumConversions += premiumSnapshot.documents.count
            }
        }

        // Calculate average time between stages
        let avgTimeToInstall = await calculateAverageTimeBetweenStages(from: "click", to: "install", period: period)
        let avgTimeToSignup = await calculateAverageTimeBetweenStages(from: "install", to: "signup", period: period)
        let avgTimeToPremium = await calculateAverageTimeBetweenStages(from: "signup", to: "premium", period: period)

        // Build funnel stages
        let stages = [
            FunnelStage(
                name: "Referral Link Click",
                count: totalClicks,
                conversionRate: 1.0,
                dropoffRate: 0.0,
                averageTimeToNext: avgTimeToInstall
            ),
            FunnelStage(
                name: "App Install",
                count: totalInstalls,
                conversionRate: totalClicks > 0 ? Double(totalInstalls) / Double(totalClicks) : 0,
                dropoffRate: totalClicks > 0 ? 1.0 - Double(totalInstalls) / Double(totalClicks) : 1.0,
                averageTimeToNext: avgTimeToSignup
            ),
            FunnelStage(
                name: "Account Signup",
                count: totalSignups,
                conversionRate: totalInstalls > 0 ? Double(totalSignups) / Double(totalInstalls) : 0,
                dropoffRate: totalInstalls > 0 ? 1.0 - Double(totalSignups) / Double(totalInstalls) : 1.0,
                averageTimeToNext: nil
            ),
            FunnelStage(
                name: "Referral Completed",
                count: completedReferrals,
                conversionRate: totalSignups > 0 ? Double(completedReferrals) / Double(totalSignups) : 0,
                dropoffRate: totalSignups > 0 ? 1.0 - Double(completedReferrals) / Double(totalSignups) : 1.0,
                averageTimeToNext: avgTimeToPremium
            ),
            FunnelStage(
                name: "Premium Conversion",
                count: premiumConversions,
                conversionRate: completedReferrals > 0 ? Double(premiumConversions) / Double(completedReferrals) : 0,
                dropoffRate: completedReferrals > 0 ? 1.0 - Double(premiumConversions) / Double(completedReferrals) : 1.0,
                averageTimeToNext: nil
            )
        ]

        let funnel = ConversionFunnel(
            funnelId: UUID().uuidString,
            name: "Referral Conversion Funnel",
            calculatedAt: Date(),
            period: period,
            stages: stages
        )

        currentFunnel = funnel

        return funnel
    }

    private func calculateAverageTimeBetweenStages(from: String, to: String, period: AnalyticsPeriod) async -> TimeInterval? {
        // Simplified - in production, calculate actual average from event timestamps
        switch (from, to) {
        case ("click", "install"):
            return 24 * 3600  // 1 day average
        case ("install", "signup"):
            return 0.5 * 3600  // 30 minutes
        case ("signup", "premium"):
            return 7 * 24 * 3600  // 7 days
        default:
            return nil
        }
    }

    // MARK: - Viral Coefficient

    /// Calculates the viral coefficient (K-factor)
    func calculateViralCoefficient(period: AnalyticsPeriod = .month) async -> Double {
        let dateRange = period.dateRange

        do {
            // Get users who signed up in the period
            let usersSnapshot = try await db.collection("users")
                .whereField("createdAt", isGreaterThan: Timestamp(date: dateRange.start))
                .whereField("createdAt", isLessThan: Timestamp(date: dateRange.end))
                .getDocuments()

            let totalNewUsers = usersSnapshot.documents.count
            guard totalNewUsers > 0 else { return 0 }

            // Get referrals made by those users
            let userIds = usersSnapshot.documents.map { $0.documentID }

            var totalReferralsSent = 0
            var totalReferralsConverted = 0

            for batch in stride(from: 0, to: userIds.count, by: 10) {
                let endIndex = min(batch + 10, userIds.count)
                let batchIds = Array(userIds[batch..<endIndex])

                let referralsSnapshot = try await db.collection("referrals")
                    .whereField("referrerUserId", in: batchIds)
                    .getDocuments()

                totalReferralsSent += referralsSnapshot.documents.count
                totalReferralsConverted += referralsSnapshot.documents.filter {
                    ($0.data()["status"] as? String) == "completed"
                }.count
            }

            // K = invites per user × conversion rate
            let invitesPerUser = Double(totalReferralsSent) / Double(totalNewUsers)
            let conversionRate = totalReferralsSent > 0 ? Double(totalReferralsConverted) / Double(totalReferralsSent) : 0

            return invitesPerUser * conversionRate
        } catch {
            Logger.shared.error("Failed to calculate viral coefficient", category: .referral, error: error)
            return 0
        }
    }

    // MARK: - Source Performance

    /// Analyzes performance by referral source
    func analyzeSourcePerformance(period: AnalyticsPeriod = .month) async throws -> [SourcePerformance] {
        let dateRange = period.dateRange

        // Fetch touchpoints grouped by source
        let touchpointsSnapshot = try await db.collection("attributionTouchpoints")
            .whereField("timestamp", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("timestamp", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        var sourceStats: [String: (clicks: Int, signups: Int, revenue: Double, referrals: Int, premiumUsers: Int)] = [:]

        // Group by source
        for doc in touchpointsSnapshot.documents {
            let source = doc.data()["source"] as? String ?? "unknown"
            var stats = sourceStats[source] ?? (clicks: 0, signups: 0, revenue: 0, referrals: 0, premiumUsers: 0)
            stats.clicks += 1
            sourceStats[source] = stats
        }

        // Fetch attribution results to get signups and revenue per source
        let resultsSnapshot = try await db.collection("attributionResults")
            .whereField("attributedAt", isGreaterThan: Timestamp(date: dateRange.start))
            .whereField("attributedAt", isLessThan: Timestamp(date: dateRange.end))
            .getDocuments()

        for doc in resultsSnapshot.documents {
            let data = doc.data()
            // Get source from touchpoints in result
            let touchpoints = data["touchpoints"] as? [[String: Any]] ?? []
            let source = touchpoints.first?["source"] as? String ?? "unknown"

            var stats = sourceStats[source] ?? (clicks: 0, signups: 0, revenue: 0, referrals: 0, premiumUsers: 0)

            if data["conversionType"] as? String == "signup" {
                stats.signups += 1
            }

            stats.revenue += data["revenue"] as? Double ?? 0

            sourceStats[source] = stats
        }

        // Build performance metrics
        var performances: [SourcePerformance] = []

        for (source, stats) in sourceStats {
            let clickToSignupRate = stats.clicks > 0 ? Double(stats.signups) / Double(stats.clicks) : 0
            let averageLTV = stats.signups > 0 ? stats.revenue / Double(stats.signups) : 0
            let averageReferrals = stats.signups > 0 ? Double(stats.referrals) / Double(stats.signups) : 0
            let premiumConversionRate = stats.signups > 0 ? Double(stats.premiumUsers) / Double(stats.signups) : 0

            performances.append(SourcePerformance(
                source: source,
                period: period,
                totalClicks: stats.clicks,
                totalSignups: stats.signups,
                clickToSignupRate: clickToSignupRate,
                averageLTV: averageLTV,
                averageReferrals: averageReferrals,
                premiumConversionRate: premiumConversionRate,
                totalCost: 0,  // Would come from ad spend data
                costPerClick: 0,
                costPerSignup: 0,
                roi: stats.revenue > 0 ? stats.revenue : 0  // Simplified
            ))
        }

        topSources = performances.sorted { $0.totalSignups > $1.totalSignups }

        return topSources
    }

    // MARK: - Cohort Analysis

    /// Performs cohort analysis for referred users
    func analyzeCohort(type: CohortType, cohortDate: Date) async throws -> CohortAnalysis {
        let calendar = Calendar.current
        let cohortStart = calendar.startOfDay(for: cohortDate)
        let cohortEnd = calendar.date(byAdding: .day, value: 1, to: cohortStart) ?? cohortStart

        // Get users in the cohort
        var userIds: [String] = []

        switch type {
        case .signup:
            let snapshot = try await db.collection("users")
                .whereField("createdAt", isGreaterThan: Timestamp(date: cohortStart))
                .whereField("createdAt", isLessThan: Timestamp(date: cohortEnd))
                .getDocuments()
            userIds = snapshot.documents.map { $0.documentID }

        case .firstReferral:
            let snapshot = try await db.collection("referrals")
                .whereField("createdAt", isGreaterThan: Timestamp(date: cohortStart))
                .whereField("createdAt", isLessThan: Timestamp(date: cohortEnd))
                .getDocuments()

            let referrerIds = Set(snapshot.documents.compactMap { $0.data()["referrerUserId"] as? String })
            userIds = Array(referrerIds)

        case .firstPurchase:
            let snapshot = try await db.collection("purchases")
                .whereField("purchaseDate", isGreaterThan: Timestamp(date: cohortStart))
                .whereField("purchaseDate", isLessThan: Timestamp(date: cohortEnd))
                .getDocuments()

            let purchaserIds = Set(snapshot.documents.compactMap { $0.data()["userId"] as? String })
            userIds = Array(purchaserIds)
        }

        guard !userIds.isEmpty else {
            return CohortAnalysis(
                cohortId: UUID().uuidString,
                cohortType: type,
                cohortDate: cohortDate,
                totalUsers: 0,
                retention: [],
                revenue: [],
                activity: []
            )
        }

        // Calculate retention, revenue, and activity over time
        let daysSinceCohort = calendar.dateComponents([.day], from: cohortDate, to: Date()).day ?? 0
        let maxDays = min(daysSinceCohort, 90)  // Track up to 90 days

        var retention: [RetentionDataPoint] = []
        var revenue: [RevenueDataPoint] = []
        var activity: [ActivityDataPoint] = []

        // Sample days: 1, 7, 14, 30, 60, 90
        let sampleDays = [1, 7, 14, 30, 60, 90].filter { $0 <= maxDays }

        for day in sampleDays {
            let dayDate = calendar.date(byAdding: .day, value: day, to: cohortDate) ?? cohortDate

            // Retention: users with session on that day
            let activeUsers = await countActiveUsers(userIds: userIds, on: dayDate)
            retention.append(RetentionDataPoint(
                daysSince: day,
                activeUsers: activeUsers,
                retentionRate: Double(activeUsers) / Double(userIds.count)
            ))

            // Revenue: cumulative by that day
            let cumulativeRevenue = await calculateCumulativeRevenue(userIds: userIds, until: dayDate)
            revenue.append(RevenueDataPoint(
                daysSince: day,
                cumulativeRevenue: cumulativeRevenue,
                revenuePerUser: cumulativeRevenue / Double(userIds.count)
            ))

            // Activity: average referrals and sessions
            let avgReferrals = await calculateAverageReferrals(userIds: userIds, until: dayDate)
            activity.append(ActivityDataPoint(
                daysSince: day,
                averageReferrals: avgReferrals,
                averageSessions: Double(activeUsers) / Double(userIds.count) * Double(day)  // Simplified
            ))
        }

        return CohortAnalysis(
            cohortId: UUID().uuidString,
            cohortType: type,
            cohortDate: cohortDate,
            totalUsers: userIds.count,
            retention: retention,
            revenue: revenue,
            activity: activity
        )
    }

    // MARK: - Helper Methods

    private func countActiveUsers(userIds: [String], on date: Date) async -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        var activeCount = 0

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            do {
                let snapshot = try await db.collection("sessions")
                    .whereField("userId", in: batchIds)
                    .whereField("startTime", isGreaterThan: Timestamp(date: dayStart))
                    .whereField("startTime", isLessThan: Timestamp(date: dayEnd))
                    .getDocuments()

                let activeUserIds = Set(snapshot.documents.compactMap { $0.data()["userId"] as? String })
                activeCount += activeUserIds.count
            } catch {
                continue
            }
        }

        return activeCount
    }

    private func calculateCumulativeRevenue(userIds: [String], until date: Date) async -> Double {
        var totalRevenue = 0.0

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            do {
                let snapshot = try await db.collection("purchases")
                    .whereField("userId", in: batchIds)
                    .whereField("purchaseDate", isLessThan: Timestamp(date: date))
                    .getDocuments()

                totalRevenue += snapshot.documents.reduce(0.0) { sum, doc in
                    sum + (doc.data()["amount"] as? Double ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalRevenue
    }

    private func calculateAverageReferrals(userIds: [String], until date: Date) async -> Double {
        var totalReferrals = 0

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            do {
                let snapshot = try await db.collection("referrals")
                    .whereField("referrerUserId", in: batchIds)
                    .whereField("createdAt", isLessThan: Timestamp(date: date))
                    .getDocuments()

                totalReferrals += snapshot.documents.count
            } catch {
                continue
            }
        }

        return userIds.count > 0 ? Double(totalReferrals) / Double(userIds.count) : 0
    }

    private func storeROIMetrics(_ metrics: ReferralROIMetrics) async throws {
        let data: [String: Any] = [
            "calculatedAt": Timestamp(date: metrics.calculatedAt),
            "periodStart": Timestamp(date: metrics.periodStart),
            "periodEnd": Timestamp(date: metrics.periodEnd),
            "totalReferrals": metrics.totalReferrals,
            "successfulReferrals": metrics.successfulReferrals,
            "conversionRate": metrics.conversionRate,
            "totalRevenue": metrics.totalRevenue,
            "referralRevenue": metrics.referralRevenue,
            "costPerAcquisition": metrics.costPerAcquisition,
            "averageLTV": metrics.averageLTV,
            "viralCoefficient": metrics.viralCoefficient,
            "referralROI": metrics.referralROI
        ]

        try await db.collection("referralROIHistory").addDocument(data: data)
    }

    // MARK: - Dashboard Data

    /// Gets summary metrics for dashboard display
    func getDashboardMetrics() async throws -> ReferralDashboardMetrics {
        let weeklyROI = try await calculateROIMetrics(period: .week)
        let monthlyROI = try await calculateROIMetrics(period: .month)
        let funnel = try await generateConversionFunnel(period: .month)
        let sources = try await analyzeSourcePerformance(period: .month)
        let viralK = await calculateViralCoefficient(period: .month)

        return ReferralDashboardMetrics(
            weeklyReferrals: weeklyROI.successfulReferrals,
            monthlyReferrals: monthlyROI.successfulReferrals,
            monthlyRevenue: monthlyROI.referralRevenue,
            conversionRate: monthlyROI.conversionRate,
            costPerAcquisition: monthlyROI.costPerAcquisition,
            averageLTV: monthlyROI.averageLTV,
            ltvRatio: monthlyROI.averageLTVRatio,
            viralCoefficient: viralK,
            roi: monthlyROI.referralROI,
            topSource: sources.first?.source ?? "organic",
            funnelConversionRate: funnel.overallConversionRate
        )
    }
}

// MARK: - Dashboard Metrics

struct ReferralDashboardMetrics {
    let weeklyReferrals: Int
    let monthlyReferrals: Int
    let monthlyRevenue: Double
    let conversionRate: Double
    let costPerAcquisition: Double
    let averageLTV: Double
    let ltvRatio: Double
    let viralCoefficient: Double
    let roi: Double
    let topSource: String
    let funnelConversionRate: Double
}
