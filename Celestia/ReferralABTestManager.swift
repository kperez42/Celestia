//
//  ReferralABTestManager.swift
//  Celestia
//
//  A/B Testing system for referral program optimization
//  Features: Experiment management, variant assignment, statistical analysis
//

import Foundation
import FirebaseFirestore
import FirebaseRemoteConfig

// MARK: - Experiment Models

struct ReferralExperiment: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: ExperimentType
    let status: ExperimentStatus
    let variants: [ExperimentVariant]
    let targetAudience: TargetAudience?
    let startDate: Date
    let endDate: Date?
    let createdAt: Date
    let minSampleSize: Int
    let confidenceLevel: Double  // e.g., 0.95 for 95%

    var isActive: Bool {
        return status == .running && Date() >= startDate && (endDate == nil || Date() <= endDate!)
    }
}

enum ExperimentType: String, Codable {
    case rewards = "rewards"           // Test different reward amounts
    case messaging = "messaging"       // Test different share messages
    case ui = "ui"                     // Test UI variations
    case timing = "timing"             // Test notification timing
    case incentiveStructure = "incentive_structure"  // Test reward structures
}

enum ExperimentStatus: String, Codable {
    case draft = "draft"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case archived = "archived"
}

struct ExperimentVariant: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let weight: Double              // Traffic allocation (0.0 - 1.0)
    let config: VariantConfig
    let isControl: Bool

    // Results (populated after experiment runs)
    var impressions: Int = 0
    var conversions: Int = 0
    var revenue: Double = 0.0

    var conversionRate: Double {
        guard impressions > 0 else { return 0 }
        return Double(conversions) / Double(impressions)
    }

    var revenuePerUser: Double {
        guard impressions > 0 else { return 0 }
        return revenue / Double(impressions)
    }
}

struct VariantConfig: Codable {
    // Reward configuration
    var referrerBonusDays: Int?
    var referredBonusDays: Int?
    var milestoneBonusMultiplier: Double?

    // Messaging configuration
    var shareMessageTemplate: String?
    var ctaText: String?
    var notificationTitle: String?
    var notificationBody: String?

    // UI configuration
    var primaryColor: String?
    var showLeaderboard: Bool?
    var showMilestones: Bool?
    var cardStyle: String?

    // Timing configuration
    var reminderDelayHours: Int?
    var followUpDelayDays: Int?

    init() {}
}

struct TargetAudience: Codable {
    var minReferrals: Int?
    var maxReferrals: Int?
    var isPremium: Bool?
    var minAccountAgeDays: Int?
    var segments: [String]?
    var excludeSegments: [String]?
}

// MARK: - User Assignment

struct UserExperimentAssignment: Codable {
    let experimentId: String
    let variantId: String
    let userId: String
    let assignedAt: Date
    let context: [String: String]
}

// MARK: - Experiment Results

struct ReferralExperimentResults: Codable {
    let experimentId: String
    let calculatedAt: Date
    let variants: [VariantResults]
    let winner: String?
    let confidenceAchieved: Bool
    let statisticalSignificance: Double
    let recommendation: String
}

struct VariantResults: Codable {
    let variantId: String
    let variantName: String
    let impressions: Int
    let conversions: Int
    let conversionRate: Double
    let revenue: Double
    let revenuePerUser: Double
    let confidenceInterval: (lower: Double, upper: Double)
    let relativeImprovement: Double?  // vs control
    let pValue: Double?

    enum CodingKeys: String, CodingKey {
        case variantId, variantName, impressions, conversions
        case conversionRate, revenue, revenuePerUser, relativeImprovement, pValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variantId = try container.decode(String.self, forKey: .variantId)
        variantName = try container.decode(String.self, forKey: .variantName)
        impressions = try container.decode(Int.self, forKey: .impressions)
        conversions = try container.decode(Int.self, forKey: .conversions)
        conversionRate = try container.decode(Double.self, forKey: .conversionRate)
        revenue = try container.decode(Double.self, forKey: .revenue)
        revenuePerUser = try container.decode(Double.self, forKey: .revenuePerUser)
        relativeImprovement = try container.decodeIfPresent(Double.self, forKey: .relativeImprovement)
        pValue = try container.decodeIfPresent(Double.self, forKey: .pValue)
        confidenceInterval = (lower: 0, upper: 0)  // Will be calculated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(variantId, forKey: .variantId)
        try container.encode(variantName, forKey: .variantName)
        try container.encode(impressions, forKey: .impressions)
        try container.encode(conversions, forKey: .conversions)
        try container.encode(conversionRate, forKey: .conversionRate)
        try container.encode(revenue, forKey: .revenue)
        try container.encode(revenuePerUser, forKey: .revenuePerUser)
        try container.encodeIfPresent(relativeImprovement, forKey: .relativeImprovement)
        try container.encodeIfPresent(pValue, forKey: .pValue)
    }

    init(variantId: String, variantName: String, impressions: Int, conversions: Int,
         conversionRate: Double, revenue: Double, revenuePerUser: Double,
         confidenceInterval: (lower: Double, upper: Double),
         relativeImprovement: Double?, pValue: Double?) {
        self.variantId = variantId
        self.variantName = variantName
        self.impressions = impressions
        self.conversions = conversions
        self.conversionRate = conversionRate
        self.revenue = revenue
        self.revenuePerUser = revenuePerUser
        self.confidenceInterval = confidenceInterval
        self.relativeImprovement = relativeImprovement
        self.pValue = pValue
    }
}

// MARK: - A/B Test Manager

@MainActor
class ReferralABTestManager: ObservableObject {
    static let shared = ReferralABTestManager()

    private let db = Firestore.firestore()
    private let remoteConfig = RemoteConfig.remoteConfig()

    // Cache for experiments and assignments
    private var experimentsCache: [ReferralExperiment] = []
    private var userAssignments: [String: UserExperimentAssignment] = [:]
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 300  // 5 minutes

    @Published var activeExperiments: [ReferralExperiment] = []

    private init() {
        Task {
            await loadExperiments()
        }
    }

    // MARK: - Experiment Loading

    func loadExperiments(forceRefresh: Bool = false) async {
        // Check cache
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           !experimentsCache.isEmpty {
            return
        }

        do {
            let snapshot = try await db.collection("referralExperiments")
                .whereField("status", isEqualTo: ExperimentStatus.running.rawValue)
                .getDocuments()

            experimentsCache = snapshot.documents.compactMap { doc -> ReferralExperiment? in
                return parseExperiment(from: doc)
            }

            activeExperiments = experimentsCache.filter { $0.isActive }
            lastFetchTime = Date()

            Logger.shared.info("Loaded \(activeExperiments.count) active experiments", category: .referral)
        } catch {
            Logger.shared.error("Failed to load experiments", category: .referral, error: error)
        }
    }

    private func parseExperiment(from doc: DocumentSnapshot) -> ReferralExperiment? {
        guard let data = doc.data() else { return nil }

        let variantsData = data["variants"] as? [[String: Any]] ?? []
        let variants = variantsData.compactMap { parseVariant(from: $0) }

        guard !variants.isEmpty else { return nil }

        var targetAudience: TargetAudience?
        if let audienceData = data["targetAudience"] as? [String: Any] {
            targetAudience = TargetAudience(
                minReferrals: audienceData["minReferrals"] as? Int,
                maxReferrals: audienceData["maxReferrals"] as? Int,
                isPremium: audienceData["isPremium"] as? Bool,
                minAccountAgeDays: audienceData["minAccountAgeDays"] as? Int,
                segments: audienceData["segments"] as? [String],
                excludeSegments: audienceData["excludeSegments"] as? [String]
            )
        }

        return ReferralExperiment(
            id: doc.documentID,
            name: data["name"] as? String ?? "",
            description: data["description"] as? String ?? "",
            type: ExperimentType(rawValue: data["type"] as? String ?? "") ?? .rewards,
            status: ExperimentStatus(rawValue: data["status"] as? String ?? "") ?? .draft,
            variants: variants,
            targetAudience: targetAudience,
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
            endDate: (data["endDate"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            minSampleSize: data["minSampleSize"] as? Int ?? 100,
            confidenceLevel: data["confidenceLevel"] as? Double ?? 0.95
        )
    }

    private func parseVariant(from data: [String: Any]) -> ExperimentVariant? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String else {
            return nil
        }

        var config = VariantConfig()
        if let configData = data["config"] as? [String: Any] {
            config.referrerBonusDays = configData["referrerBonusDays"] as? Int
            config.referredBonusDays = configData["referredBonusDays"] as? Int
            config.milestoneBonusMultiplier = configData["milestoneBonusMultiplier"] as? Double
            config.shareMessageTemplate = configData["shareMessageTemplate"] as? String
            config.ctaText = configData["ctaText"] as? String
            config.notificationTitle = configData["notificationTitle"] as? String
            config.notificationBody = configData["notificationBody"] as? String
            config.primaryColor = configData["primaryColor"] as? String
            config.showLeaderboard = configData["showLeaderboard"] as? Bool
            config.showMilestones = configData["showMilestones"] as? Bool
            config.cardStyle = configData["cardStyle"] as? String
            config.reminderDelayHours = configData["reminderDelayHours"] as? Int
            config.followUpDelayDays = configData["followUpDelayDays"] as? Int
        }

        return ExperimentVariant(
            id: id,
            name: name,
            description: data["description"] as? String ?? "",
            weight: data["weight"] as? Double ?? 0.5,
            config: config,
            isControl: data["isControl"] as? Bool ?? false
        )
    }

    // MARK: - Variant Assignment

    /// Gets the variant for a user in an experiment (assigns if not already assigned)
    func getVariant(
        for userId: String,
        experimentId: String,
        userContext: UserExperimentContext? = nil
    ) async -> ExperimentVariant? {
        // Check cache first
        let cacheKey = "\(userId)_\(experimentId)"
        if let assignment = userAssignments[cacheKey] {
            return getVariantById(assignment.variantId, experimentId: experimentId)
        }

        // Check Firestore for existing assignment
        do {
            let existingAssignment = try await db.collection("experimentAssignments")
                .whereField("userId", isEqualTo: userId)
                .whereField("experimentId", isEqualTo: experimentId)
                .limit(to: 1)
                .getDocuments()

            if let doc = existingAssignment.documents.first,
               let variantId = doc.data()["variantId"] as? String {
                let assignment = UserExperimentAssignment(
                    experimentId: experimentId,
                    variantId: variantId,
                    userId: userId,
                    assignedAt: (doc.data()["assignedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    context: doc.data()["context"] as? [String: String] ?? [:]
                )
                userAssignments[cacheKey] = assignment
                return getVariantById(variantId, experimentId: experimentId)
            }

            // Assign new variant
            guard let experiment = experimentsCache.first(where: { $0.id == experimentId }),
                  experiment.isActive else {
                return nil
            }

            // Check if user qualifies for experiment
            if let context = userContext, !userQualifies(context: context, audience: experiment.targetAudience) {
                return nil
            }

            // Assign variant based on weights
            let variant = assignVariant(experiment: experiment, userId: userId)

            // Store assignment
            let assignment = UserExperimentAssignment(
                experimentId: experimentId,
                variantId: variant.id,
                userId: userId,
                assignedAt: Date(),
                context: userContext?.toDictionary() ?? [:]
            )

            try await storeAssignment(assignment)
            userAssignments[cacheKey] = assignment

            // Track impression
            await trackImpression(experimentId: experimentId, variantId: variant.id)

            Logger.shared.info("Assigned user \(userId) to variant \(variant.name) in experiment \(experiment.name)", category: .referral)

            return variant

        } catch {
            Logger.shared.error("Failed to get/assign variant", category: .referral, error: error)
            return nil
        }
    }

    private func assignVariant(experiment: ReferralExperiment, userId: String) -> ExperimentVariant {
        // Use consistent hashing for deterministic assignment
        let hash = "\(userId)_\(experiment.id)".hashValue
        let normalizedHash = abs(Double(hash) / Double(Int.max))

        var cumulative = 0.0
        for variant in experiment.variants {
            cumulative += variant.weight
            if normalizedHash < cumulative {
                return variant
            }
        }

        // Fallback to last variant
        return experiment.variants.last ?? experiment.variants[0]
    }

    private func userQualifies(context: UserExperimentContext, audience: TargetAudience?) -> Bool {
        guard let audience = audience else { return true }

        if let minReferrals = audience.minReferrals, context.totalReferrals < minReferrals {
            return false
        }

        if let maxReferrals = audience.maxReferrals, context.totalReferrals > maxReferrals {
            return false
        }

        if let isPremium = audience.isPremium, context.isPremium != isPremium {
            return false
        }

        if let minAge = audience.minAccountAgeDays, context.accountAgeDays < minAge {
            return false
        }

        if let segments = audience.segments, !segments.isEmpty {
            let hasMatchingSegment = context.segments.contains { segments.contains($0) }
            if !hasMatchingSegment { return false }
        }

        if let excludeSegments = audience.excludeSegments {
            let hasExcludedSegment = context.segments.contains { excludeSegments.contains($0) }
            if hasExcludedSegment { return false }
        }

        return true
    }

    private func getVariantById(_ variantId: String, experimentId: String) -> ExperimentVariant? {
        return experimentsCache
            .first { $0.id == experimentId }?
            .variants
            .first { $0.id == variantId }
    }

    private func storeAssignment(_ assignment: UserExperimentAssignment) async throws {
        let data: [String: Any] = [
            "experimentId": assignment.experimentId,
            "variantId": assignment.variantId,
            "userId": assignment.userId,
            "assignedAt": Timestamp(date: assignment.assignedAt),
            "context": assignment.context
        ]

        try await db.collection("experimentAssignments").addDocument(data: data)
    }

    // MARK: - Event Tracking

    /// Tracks an impression (user saw the variant)
    func trackImpression(experimentId: String, variantId: String) async {
        await trackEvent(type: "impression", experimentId: experimentId, variantId: variantId, value: nil)
    }

    /// Tracks a conversion (user completed desired action)
    func trackConversion(experimentId: String, variantId: String, revenue: Double? = nil) async {
        await trackEvent(type: "conversion", experimentId: experimentId, variantId: variantId, value: revenue)
    }

    /// Tracks a custom event
    func trackEvent(type: String, experimentId: String, variantId: String, value: Double?) async {
        let data: [String: Any] = [
            "experimentId": experimentId,
            "variantId": variantId,
            "eventType": type,
            "value": value ?? 0.0,
            "timestamp": Timestamp(date: Date())
        ]

        do {
            try await db.collection("experimentEvents").addDocument(data: data)
        } catch {
            Logger.shared.error("Failed to track experiment event", category: .referral, error: error)
        }
    }

    // MARK: - Results Analysis

    /// Calculates experiment results with statistical analysis
    func calculateResults(experimentId: String) async throws -> ReferralExperimentResults {
        guard let experiment = experimentsCache.first(where: { $0.id == experimentId }) else {
            throw NSError(domain: "ExperimentError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Experiment not found"])
        }

        // Fetch all events for this experiment
        let eventsSnapshot = try await db.collection("experimentEvents")
            .whereField("experimentId", isEqualTo: experimentId)
            .getDocuments()

        // Group events by variant
        var variantStats: [String: (impressions: Int, conversions: Int, revenue: Double)] = [:]

        for doc in eventsSnapshot.documents {
            let data = doc.data()
            let variantId = data["variantId"] as? String ?? ""
            let eventType = data["eventType"] as? String ?? ""
            let value = data["value"] as? Double ?? 0.0

            var stats = variantStats[variantId] ?? (impressions: 0, conversions: 0, revenue: 0.0)

            if eventType == "impression" {
                stats.impressions += 1
            } else if eventType == "conversion" {
                stats.conversions += 1
                stats.revenue += value
            }

            variantStats[variantId] = stats
        }

        // Calculate results for each variant
        var variantResults: [VariantResults] = []
        var controlVariant: VariantResults?

        for variant in experiment.variants {
            let stats = variantStats[variant.id] ?? (impressions: 0, conversions: 0, revenue: 0.0)
            let conversionRate = stats.impressions > 0 ? Double(stats.conversions) / Double(stats.impressions) : 0.0
            let revenuePerUser = stats.impressions > 0 ? stats.revenue / Double(stats.impressions) : 0.0

            // Calculate confidence interval (Wilson score interval)
            let ci = wilsonScoreInterval(conversions: stats.conversions, trials: stats.impressions, confidence: experiment.confidenceLevel)

            let result = VariantResults(
                variantId: variant.id,
                variantName: variant.name,
                impressions: stats.impressions,
                conversions: stats.conversions,
                conversionRate: conversionRate,
                revenue: stats.revenue,
                revenuePerUser: revenuePerUser,
                confidenceInterval: ci,
                relativeImprovement: nil,
                pValue: nil
            )

            if variant.isControl {
                controlVariant = result
            }

            variantResults.append(result)
        }

        // Calculate relative improvement and p-values vs control
        if let control = controlVariant {
            variantResults = variantResults.map { result in
                if result.variantId == control.variantId {
                    return result
                }

                let improvement = control.conversionRate > 0
                    ? (result.conversionRate - control.conversionRate) / control.conversionRate
                    : 0.0

                let pValue = calculatePValue(
                    conversionsA: control.conversions,
                    trialsA: control.impressions,
                    conversionsB: result.conversions,
                    trialsB: result.impressions
                )

                return VariantResults(
                    variantId: result.variantId,
                    variantName: result.variantName,
                    impressions: result.impressions,
                    conversions: result.conversions,
                    conversionRate: result.conversionRate,
                    revenue: result.revenue,
                    revenuePerUser: result.revenuePerUser,
                    confidenceInterval: result.confidenceInterval,
                    relativeImprovement: improvement,
                    pValue: pValue
                )
            }
        }

        // Determine winner
        let significanceThreshold = 1.0 - experiment.confidenceLevel  // e.g., 0.05 for 95% confidence
        var winner: String?
        var confidenceAchieved = false

        let sortedByConversion = variantResults.sorted { $0.conversionRate > $1.conversionRate }
        if let best = sortedByConversion.first,
           let pValue = best.pValue,
           pValue < significanceThreshold,
           best.impressions >= experiment.minSampleSize {
            winner = best.variantId
            confidenceAchieved = true
        }

        // Generate recommendation
        let recommendation = generateRecommendation(
            results: variantResults,
            winner: winner,
            confidenceAchieved: confidenceAchieved,
            minSampleSize: experiment.minSampleSize
        )

        let overallSignificance = variantResults.compactMap { $0.pValue }.min() ?? 1.0

        return ReferralExperimentResults(
            experimentId: experimentId,
            calculatedAt: Date(),
            variants: variantResults,
            winner: winner,
            confidenceAchieved: confidenceAchieved,
            statisticalSignificance: 1.0 - overallSignificance,
            recommendation: recommendation
        )
    }

    // MARK: - Statistical Calculations

    /// Wilson score confidence interval
    private func wilsonScoreInterval(conversions: Int, trials: Int, confidence: Double) -> (lower: Double, upper: Double) {
        guard trials > 0 else { return (0, 0) }

        let p = Double(conversions) / Double(trials)
        let n = Double(trials)

        // Z-score for confidence level (approximation)
        let z: Double
        switch confidence {
        case 0.99: z = 2.576
        case 0.95: z = 1.96
        case 0.90: z = 1.645
        default: z = 1.96
        }

        let denominator = 1 + z * z / n
        let center = p + z * z / (2 * n)
        let spread = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n))

        let lower = (center - spread) / denominator
        let upper = (center + spread) / denominator

        return (max(0, lower), min(1, upper))
    }

    /// Two-proportion z-test p-value
    private func calculatePValue(conversionsA: Int, trialsA: Int, conversionsB: Int, trialsB: Int) -> Double {
        guard trialsA > 0 && trialsB > 0 else { return 1.0 }

        let pA = Double(conversionsA) / Double(trialsA)
        let pB = Double(conversionsB) / Double(trialsB)
        let pPooled = Double(conversionsA + conversionsB) / Double(trialsA + trialsB)

        let se = sqrt(pPooled * (1 - pPooled) * (1.0 / Double(trialsA) + 1.0 / Double(trialsB)))

        guard se > 0 else { return 1.0 }

        let z = abs(pB - pA) / se

        // Approximate p-value from z-score (two-tailed)
        return 2 * (1 - normalCDF(z))
    }

    /// Standard normal CDF approximation
    private func normalCDF(_ z: Double) -> Double {
        // Approximation using error function
        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let p = 0.3275911

        let sign = z < 0 ? -1.0 : 1.0
        let absZ = abs(z) / sqrt(2.0)

        let t = 1.0 / (1.0 + p * absZ)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absZ * absZ)

        return 0.5 * (1.0 + sign * y)
    }

    private func generateRecommendation(results: [VariantResults], winner: String?, confidenceAchieved: Bool, minSampleSize: Int) -> String {
        let totalImpressions = results.reduce(0) { $0 + $1.impressions }

        if totalImpressions < minSampleSize * results.count {
            return "Insufficient data. Continue running the experiment to reach minimum sample size of \(minSampleSize) per variant."
        }

        if let winnerId = winner, confidenceAchieved {
            let winnerResult = results.first { $0.variantId == winnerId }
            let improvement = (winnerResult?.relativeImprovement ?? 0) * 100
            return "Variant '\(winnerResult?.variantName ?? winnerId)' is the winner with \(String(format: "%.1f", improvement))% improvement. Consider deploying this variant."
        }

        if results.contains(where: { ($0.pValue ?? 1.0) < 0.1 }) {
            return "Approaching statistical significance. Continue running for more conclusive results."
        }

        return "No clear winner yet. Results are inconclusive. Consider running longer or testing more distinct variations."
    }

    // MARK: - Convenience Methods

    /// Gets the current reward configuration for a user
    func getRewardConfig(for userId: String, context: UserExperimentContext?) async -> (referrerDays: Int, referredDays: Int) {
        // Check for active rewards experiment
        for experiment in activeExperiments where experiment.type == .rewards {
            if let variant = await getVariant(for: userId, experimentId: experiment.id, userContext: context) {
                let referrerDays = variant.config.referrerBonusDays ?? 7
                let referredDays = variant.config.referredBonusDays ?? 3
                return (referrerDays, referredDays)
            }
        }

        // Return defaults
        return (7, 3)
    }

    /// Gets the current share message for a user
    func getShareMessage(for userId: String, code: String, context: UserExperimentContext?) async -> String {
        // Check for active messaging experiment
        for experiment in activeExperiments where experiment.type == .messaging {
            if let variant = await getVariant(for: userId, experimentId: experiment.id, userContext: context),
               let template = variant.config.shareMessageTemplate {
                return template
                    .replacingOccurrences(of: "{CODE}", with: code)
                    .replacingOccurrences(of: "{REFERRER_DAYS}", with: String(variant.config.referrerBonusDays ?? 7))
                    .replacingOccurrences(of: "{REFERRED_DAYS}", with: String(variant.config.referredBonusDays ?? 3))
            }
        }

        // Return default message
        return """
        Hey! Join me on Celestia, the best dating app for meaningful connections! 💜

        Use my code \(code) when you sign up and we'll both get 3 days of Premium free!

        Download now: https://celestia.app/join/\(code)
        """
    }

    /// Gets UI config for a user
    func getUIConfig(for userId: String, context: UserExperimentContext?) async -> VariantConfig {
        // Check for active UI experiment
        for experiment in activeExperiments where experiment.type == .ui {
            if let variant = await getVariant(for: userId, experimentId: experiment.id, userContext: context) {
                return variant.config
            }
        }

        // Return default config
        return VariantConfig()
    }
}

// MARK: - User Context

struct UserExperimentContext {
    let userId: String
    let totalReferrals: Int
    let isPremium: Bool
    let accountAgeDays: Int
    let segments: [String]

    func toDictionary() -> [String: String] {
        return [
            "userId": userId,
            "totalReferrals": String(totalReferrals),
            "isPremium": String(isPremium),
            "accountAgeDays": String(accountAgeDays),
            "segments": segments.joined(separator: ",")
        ]
    }
}
