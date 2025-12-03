//
//  AnalyticsServiceEnhanced.swift
//  Celestia
//
//  Advanced analytics with profile heatmaps, match quality scoring,
//  time-to-match trends, and A/B testing
//

import Foundation
import FirebaseAnalytics
import FirebaseFirestore

@MainActor
class AnalyticsServiceEnhanced: ObservableObject {
    static let shared = AnalyticsServiceEnhanced()

    @Published var profileHeatmap: ProfileHeatmap?
    @Published var matchQualityScore: Double = 0.0
    @Published var timeToMatchTrend: TimeToMatchTrend?
    @Published var userInsights: UserInsights?
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // FIXED: Use lazy to avoid circular dependency crash during singleton initialization
    private lazy var abTesting = ABTestingManager.shared

    // MEMORY FIX: Batch analytics events to reduce Firestore writes and memory pressure
    private var eventBatch: [[String: Any]] = []
    private var batchTimer: Timer?
    private let batchSize = 20 // Write after 20 events
    private let batchInterval: TimeInterval = 30.0 // Or after 30 seconds

    // MEMORY FIX: Track recent events to deduplicate rapid-fire identical events
    private var recentEvents: [(event: String, timestamp: Date)] = []
    private let deduplicationWindow: TimeInterval = 1.0 // 1 second window

    // MEMORY FIX: Monitor system memory pressure
    private var isMemoryPressureHigh = false
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        setupMemoryPressureMonitoring()
        startBatchTimer()
    }

    // MARK: - Profile View Heatmap

    /// Generates a heatmap of when users view your profile
    func generateProfileHeatmap(userId: String, days: Int = 30) async throws -> ProfileHeatmap {
        isLoading = true
        defer { isLoading = false }

        // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            throw AnalyticsError.invalidDateRange
        }

        // Fetch profile views
        let viewsSnapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: startDate)
            .order(by: "timestamp", descending: false)
            .getDocuments()

        var hourlyViews: [Int: Int] = [:] // Hour of day (0-23) -> view count
        var dailyViews: [String: Int] = [:] // Date string -> view count
        var dayOfWeekViews: [Int: Int] = [:] // Day of week (1-7) -> view count

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for doc in viewsSnapshot.documents {
            guard let timestamp = (doc.data()["timestamp"] as? Timestamp)?.dateValue() else {
                continue
            }

            // Hour of day
            let hour = calendar.component(.hour, from: timestamp)
            hourlyViews[hour, default: 0] += 1

            // Day of week
            let dayOfWeek = calendar.component(.weekday, from: timestamp)
            dayOfWeekViews[dayOfWeek, default: 0] += 1

            // Daily views
            let dateString = dateFormatter.string(from: timestamp)
            dailyViews[dateString, default: 0] += 1
        }

        // Find peak times
        let peakHour = hourlyViews.max(by: { $0.value < $1.value })?.key ?? 12
        let peakDay = dayOfWeekViews.max(by: { $0.value < $1.value })?.key ?? 1

        // Calculate trends
        let totalViews = viewsSnapshot.documents.count
        // SAFETY: Avoid division by zero if days is 0
        let averageViewsPerDay = days > 0 ? Double(totalViews) / Double(days) : 0

        // Calculate recent trend (last 7 days vs previous 7 days)
        // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
        guard let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: Date()),
              let previous7Days = Calendar.current.date(byAdding: .day, value: -14, to: Date()) else {
            // If date calculation fails, skip trend calculation
            let heatmap = ProfileHeatmap(
                totalViews: totalViews,
                averageViewsPerDay: averageViewsPerDay,
                hourlyDistribution: hourlyViews,
                dailyDistribution: dailyViews,
                dayOfWeekDistribution: dayOfWeekViews,
                peakHour: peakHour,
                peakDay: String(peakDay),
                trendPercentage: 0,
                viewsBySource: [:]  // Empty since we don't have source data
            )
            return heatmap
        }

        // PERFORMANCE FIX: Single-pass iteration instead of multiple filters
        // Old: O(3n) with multiple filter passes
        // New: O(n) with single iteration
        var recentViews = 0
        var previousViews = 0

        for doc in viewsSnapshot.documents {
            guard let timestamp = (doc.data()["timestamp"] as? Timestamp)?.dateValue() else {
                continue
            }

            if timestamp >= last7Days {
                recentViews += 1
            } else if timestamp >= previous7Days {
                previousViews += 1
            }
        }

        let trendPercentage = previousViews > 0 ? Double(recentViews - previousViews) / Double(previousViews) * 100 : 0

        let heatmap = ProfileHeatmap(
            totalViews: totalViews,
            averageViewsPerDay: averageViewsPerDay,
            hourlyDistribution: hourlyViews,
            dailyDistribution: dailyViews,
            dayOfWeekDistribution: dayOfWeekViews,
            peakHour: peakHour,
            peakDay: getDayName(peakDay),
            trendPercentage: trendPercentage,
            viewsBySource: await getViewsBySource(userId: userId, since: startDate)
        )

        profileHeatmap = heatmap

        // Track analytics
        trackEvent(.profileHeatmapGenerated, properties: [
            "totalViews": totalViews,
            "days": days
        ])

        return heatmap
    }

    private func getViewsBySource(userId: String, since: Date) async -> [String: Int] {
        var sources: [String: Int] = [:]

        let snapshot = try? await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: since)
            .getDocuments()

        for doc in snapshot?.documents ?? [] {
            let source = doc.data()["source"] as? String ?? "discover"
            sources[source, default: 0] += 1
        }

        return sources
    }

    // MARK: - Match Quality Score

    /// Calculates match quality based on conversation depth and engagement
    func calculateMatchQualityScore(matchId: String) async throws -> MatchQualityScore {
        isLoading = true
        defer { isLoading = false }

        // Fetch match details
        let matchDoc = try await db.collection("matches").document(matchId).getDocument()
        guard matchDoc.exists, let matchData = matchDoc.data() else {
            throw AnalyticsError.matchNotFound
        }

        let matchTimestamp = (matchData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let daysSinceMatch = Date().timeIntervalSince(matchTimestamp) / (24 * 3600)

        // Fetch messages for this match
        let messagesSnapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: false)
            .getDocuments()

        let messages = messagesSnapshot.documents

        // Calculate metrics
        let totalMessages = messages.count
        let averageMessageLength = calculateAverageMessageLength(messages)
        let responseTime = calculateAverageResponseTime(messages)
        let conversationDepth = calculateConversationDepth(messages)
        let messageFrequency = Double(totalMessages) / max(daysSinceMatch, 1)

        // Calculate quality score (0-100)
        var score: Double = 0

        // Message count (max 30 points)
        score += min(Double(totalMessages) / 100 * 30, 30)

        // Response time (max 20 points) - faster is better
        if responseTime > 0 {
            let responseScore = max(0, 20 - (responseTime / 60)) // Penalize slow responses
            score += max(0, responseScore)
        } else {
            score += 10 // Some score if we can't calculate
        }

        // Message length (max 15 points) - longer is better
        score += min(averageMessageLength / 50 * 15, 15)

        // Conversation depth (max 20 points)
        score += conversationDepth * 20

        // Frequency (max 15 points)
        score += min(messageFrequency * 15, 15)

        let qualityScore = MatchQualityScore(
            matchId: matchId,
            overallScore: min(score, 100),
            totalMessages: totalMessages,
            averageMessageLength: averageMessageLength,
            averageResponseTime: responseTime,
            conversationDepth: conversationDepth,
            messageFrequency: messageFrequency,
            daysSinceMatch: Int(daysSinceMatch),
            qualityLevel: getQualityLevel(score: score)
        )

        matchQualityScore = qualityScore.overallScore

        // Track analytics
        trackEvent(.matchQualityCalculated, properties: [
            "score": Int(qualityScore.overallScore),
            "messages": totalMessages,
            "level": qualityScore.qualityLevel.rawValue
        ])

        return qualityScore
    }

    private func calculateAverageMessageLength(_ messages: [QueryDocumentSnapshot]) -> Double {
        let totalLength = messages.reduce(0) { sum, doc in
            let text = doc.data()["text"] as? String ?? ""
            return sum + text.count
        }

        return messages.isEmpty ? 0 : Double(totalLength) / Double(messages.count)
    }

    private func calculateAverageResponseTime(_ messages: [QueryDocumentSnapshot]) -> Double {
        guard messages.count > 1 else { return 0 }

        var responseTimes: [TimeInterval] = []

        for i in 1..<messages.count {
            let previousTimestamp = (messages[i - 1].data()["timestamp"] as? Timestamp)?.dateValue()
            let currentTimestamp = (messages[i].data()["timestamp"] as? Timestamp)?.dateValue()

            if let prev = previousTimestamp, let curr = currentTimestamp {
                let diff = curr.timeIntervalSince(prev)
                if diff < 3600 * 24 { // Only count if less than 24 hours
                    responseTimes.append(diff)
                }
            }
        }

        return responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
    }

    private func calculateConversationDepth(_ messages: [QueryDocumentSnapshot]) -> Double {
        guard messages.count >= 4 else { return 0 }

        // Check for back-and-forth conversation
        var switches = 0
        var previousSender: String?

        for doc in messages {
            let sender = doc.data()["senderId"] as? String
            if let prev = previousSender, sender != prev {
                switches += 1
            }
            previousSender = sender
        }

        // Depth = switches / possible switches
        return min(Double(switches) / Double(messages.count - 1), 1.0)
    }

    private func getQualityLevel(score: Double) -> QualityLevel {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .average
        case 20..<40: return .poor
        default: return .veryPoor
        }
    }

    // MARK: - Time to Match Trends

    /// Analyzes time it takes to get matches over time
    func analyzeTimeToMatchTrends(userId: String) async throws -> TimeToMatchTrend {
        isLoading = true
        defer { isLoading = false }

        // Fetch user's likes (sent by user)
        let likesSnapshot = try await db.collection("likes")
            .whereField("fromUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: false)
            .getDocuments()

        // Fetch user's matches
        let matchesSnapshot = try await db.collection("matches")
            .whereField("user1Id", isEqualTo: userId)
            .order(by: "timestamp", descending: false)
            .getDocuments()

        var timeToMatchData: [TimeToMatchData] = []

        // For each match, calculate time from first like to match
        for matchDoc in matchesSnapshot.documents {
            let matchTimestamp = (matchDoc.data()["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let otherUserId = matchDoc.data()["user2Id"] as? String ?? ""

            // Find the like that led to this match
            if let likeDoc = likesSnapshot.documents.first(where: { doc in
                let targetId = doc.data()["toUserId"] as? String
                return targetId == otherUserId
            }) {
                let likeTimestamp = (likeDoc.data()["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let timeToMatch = matchTimestamp.timeIntervalSince(likeTimestamp)

                timeToMatchData.append(TimeToMatchData(
                    matchId: matchDoc.documentID,
                    likeTimestamp: likeTimestamp,
                    matchTimestamp: matchTimestamp,
                    timeToMatch: timeToMatch
                ))
            }
        }

        // Calculate statistics
        let averageTime = timeToMatchData.isEmpty ? 0 : timeToMatchData.map { $0.timeToMatch }.reduce(0, +) / Double(timeToMatchData.count)
        let medianTime = calculateMedian(timeToMatchData.map { $0.timeToMatch })
        let fastestMatch = timeToMatchData.min(by: { $0.timeToMatch < $1.timeToMatch })?.timeToMatch ?? 0
        let slowestMatch = timeToMatchData.max(by: { $0.timeToMatch < $1.timeToMatch })?.timeToMatch ?? 0

        // Calculate trend (recent vs older)
        let recentMatches = timeToMatchData.suffix(10)
        let olderMatches = timeToMatchData.prefix(max(10, timeToMatchData.count - 10))

        let recentAverage = recentMatches.isEmpty ? 0 : recentMatches.map { $0.timeToMatch }.reduce(0, +) / Double(recentMatches.count)
        let olderAverage = olderMatches.isEmpty ? 0 : olderMatches.map { $0.timeToMatch }.reduce(0, +) / Double(olderMatches.count)

        let trendDirection: TrendDirection
        if recentAverage < olderAverage * 0.8 {
            trendDirection = .improving
        } else if recentAverage > olderAverage * 1.2 {
            trendDirection = .declining
        } else {
            trendDirection = .stable
        }

        let trend = TimeToMatchTrend(
            averageTimeToMatch: averageTime,
            medianTimeToMatch: medianTime,
            fastestMatch: fastestMatch,
            slowestMatch: slowestMatch,
            totalMatches: timeToMatchData.count,
            trendDirection: trendDirection,
            historicalData: timeToMatchData
        )

        timeToMatchTrend = trend

        // Track analytics
        trackEvent(.timeToMatchAnalyzed, properties: [
            "averageHours": Int(averageTime / 3600),
            "totalMatches": timeToMatchData.count,
            "trend": trendDirection.rawValue
        ])

        return trend
    }

    private func calculateMedian(_ values: [TimeInterval]) -> TimeInterval {
        let sorted = values.sorted()
        let count = sorted.count

        if count == 0 {
            return 0
        } else if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }

    // MARK: - User Insights

    /// Generates comprehensive insights for a user
    func generateUserInsights(userId: String) async throws -> UserInsights {
        isLoading = true
        defer { isLoading = false }

        async let heatmap = try generateProfileHeatmap(userId: userId, days: 30)
        async let matchStats = try getMatchStatistics(userId: userId)
        async let engagementScore = try calculateEngagementScore(userId: userId)
        async let recommendations = try generateRecommendations(userId: userId)

        let insights = try await UserInsights(
            userId: userId,
            profileHeatmap: heatmap,
            matchStatistics: matchStats,
            engagementScore: engagementScore,
            recommendations: recommendations,
            generatedAt: Date()
        )

        userInsights = insights

        // Track analytics
        trackEvent(.userInsightsGenerated, properties: [
            "engagementScore": Int(insights.engagementScore)
        ])

        return insights
    }

    private func getMatchStatistics(userId: String) async throws -> MatchStatistics {
        let matchesSnapshot = try await db.collection("matches")
            .whereField("user1Id", isEqualTo: userId)
            .getDocuments()

        let totalMatches = matchesSnapshot.documents.count

        // Calculate matches with conversations
        var matchesWithConversations = 0
        var totalMessages = 0

        for matchDoc in matchesSnapshot.documents {
            let messagesSnapshot = try? await db.collection("messages")
                .whereField("matchId", isEqualTo: matchDoc.documentID)
                .getDocuments()

            let messageCount = messagesSnapshot?.documents.count ?? 0
            if messageCount > 0 {
                matchesWithConversations += 1
                totalMessages += messageCount
            }
        }

        let conversionRate = totalMatches > 0 ? Double(matchesWithConversations) / Double(totalMatches) * 100 : 0
        let averageMessagesPerMatch = matchesWithConversations > 0 ? Double(totalMessages) / Double(matchesWithConversations) : 0

        return MatchStatistics(
            totalMatches: totalMatches,
            matchesWithConversations: matchesWithConversations,
            conversionRate: conversionRate,
            averageMessagesPerMatch: averageMessagesPerMatch
        )
    }

    private func calculateEngagementScore(userId: String) async throws -> Double {
        // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
        guard let last30Days = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
            throw AnalyticsError.invalidDateRange
        }

        // Fetch activity data (likes sent by user)
        let likesSnapshot = try? await db.collection("likes")
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: last30Days)
            .getDocuments()

        let messagesSnapshot = try? await db.collection("messages")
            .whereField("senderId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: last30Days)
            .getDocuments()

        let profileViewsSnapshot = try? await db.collection("profileViews")
            .whereField("viewerUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: last30Days)
            .getDocuments()

        let likes = likesSnapshot?.documents.count ?? 0
        let messages = messagesSnapshot?.documents.count ?? 0
        let views = profileViewsSnapshot?.documents.count ?? 0

        // Calculate score (0-100)
        var score: Double = 0
        score += min(Double(likes) / 50 * 40, 40) // Max 40 points for likes
        score += min(Double(messages) / 100 * 40, 40) // Max 40 points for messages
        score += min(Double(views) / 30 * 20, 20) // Max 20 points for views

        return min(score, 100)
    }

    private func generateRecommendations(userId: String) async throws -> [String] {
        var recommendations: [String] = []

        // Get user stats
        let heatmap = try await generateProfileHeatmap(userId: userId, days: 7)
        let engagementScore = try await calculateEngagementScore(userId: userId)

        // Low profile views
        if heatmap.averageViewsPerDay < 5 {
            recommendations.append("📸 Add more photos to your profile to get more views")
            recommendations.append("✏️ Update your bio to stand out")
        }

        // Low engagement
        if engagementScore < 30 {
            recommendations.append("👋 Be more active! Like more profiles to increase your chances")
            recommendations.append("💬 Send more messages to your matches")
        }

        // Peak time suggestion
        recommendations.append("⏰ You get most views at \(heatmap.peakHour):00. Be active then!")

        // Day of week suggestion
        recommendations.append("📅 Most people view your profile on \(heatmap.peakDay). Don't miss out!")

        return recommendations
    }

    // MARK: - Memory Management

    /// Sets up memory pressure monitoring to disable Firestore analytics writes when memory is low
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.mask

            if event.contains(.critical) || event.contains(.warning) {
                self.isMemoryPressureHigh = true
                Logger.shared.warning("Memory pressure high - disabling Firestore analytics writes", category: .performance)
                // Flush existing batch immediately to free memory
                Task { await self.flushEventBatch() }
            } else {
                self.isMemoryPressureHigh = false
                Logger.shared.info("Memory pressure normalized - re-enabling Firestore analytics", category: .performance)
            }
        }

        source.resume()
        self.memoryPressureSource = source
    }

    /// Starts the batch timer to periodically flush analytics events
    private func startBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.flushEventBatch()
            }
        }
    }

    /// Flushes the batched analytics events to Firestore
    private func flushEventBatch() async {
        guard !eventBatch.isEmpty else { return }

        // Don't write to Firestore if memory pressure is high
        guard !isMemoryPressureHigh else {
            Logger.shared.warning("Skipping Firestore analytics write due to memory pressure", category: .performance)
            eventBatch.removeAll(keepingCapacity: true)
            return
        }

        let eventsToWrite = eventBatch
        eventBatch.removeAll(keepingCapacity: true)

        // Write in batch to reduce Firestore operations
        let batch = db.batch()
        for eventData in eventsToWrite {
            let docRef = db.collection("analytics_events").document()
            batch.setData(eventData, forDocument: docRef)
        }

        do {
            try await batch.commit()
            Logger.shared.debug("Flushed \(eventsToWrite.count) analytics events to Firestore", category: .analytics)
        } catch {
            Logger.shared.error("Failed to flush analytics batch", category: .analytics, error: error)
        }
    }

    /// Checks if an event was recently logged (for deduplication)
    private func isDuplicateEvent(_ event: String) -> Bool {
        let now = Date()

        // Clean up old events from deduplication cache
        recentEvents.removeAll { now.timeIntervalSince($0.timestamp) > deduplicationWindow }

        // Check if this event was logged recently
        let isDuplicate = recentEvents.contains { $0.event == event }

        if !isDuplicate {
            recentEvents.append((event, now))
        }

        return isDuplicate
    }

    // MARK: - Analytics Tracking

    func trackEvent(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        // Always log to Firebase Analytics (lightweight, in-memory)
        Analytics.logEvent(event.rawValue, parameters: properties)

        // MEMORY FIX: Deduplicate rapid-fire identical events
        if isDuplicateEvent(event.rawValue) {
            Logger.shared.debug("Skipping duplicate analytics event: \(event.rawValue)", category: .analytics)
            return
        }

        // MEMORY FIX: Batch Firestore writes instead of writing each event individually
        // This reduces network calls, Task allocations, and memory pressure
        let eventData: [String: Any] = [
            "event": event.rawValue,
            "properties": properties,
            "userId": AuthService.shared.currentUser?.id ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "variant": abTesting.getCurrentVariant(for: "main_experiment")
        ]

        eventBatch.append(eventData)

        // Flush if batch size reached
        if eventBatch.count >= batchSize {
            Task {
                await flushEventBatch()
            }
        }
    }

    deinit {
        // Flush remaining events before deallocating
        batchTimer?.invalidate()
        memoryPressureSource?.cancel()

        Task {
            await flushEventBatch()
        }
    }

    // MARK: - Helper Functions

    private func getDayName(_ dayNumber: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[dayNumber - 1]
    }
}

// MARK: - Models

struct ProfileHeatmap {
    let totalViews: Int
    let averageViewsPerDay: Double
    let hourlyDistribution: [Int: Int]
    let dailyDistribution: [String: Int]
    let dayOfWeekDistribution: [Int: Int]
    let peakHour: Int
    let peakDay: String
    let trendPercentage: Double
    let viewsBySource: [String: Int]
}

struct MatchQualityScore {
    let matchId: String
    let overallScore: Double
    let totalMessages: Int
    let averageMessageLength: Double
    let averageResponseTime: TimeInterval
    let conversationDepth: Double
    let messageFrequency: Double
    let daysSinceMatch: Int
    let qualityLevel: QualityLevel
}

enum QualityLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case average = "Average"
    case poor = "Poor"
    case veryPoor = "Very Poor"
}

struct TimeToMatchTrend {
    let averageTimeToMatch: TimeInterval
    let medianTimeToMatch: TimeInterval
    let fastestMatch: TimeInterval
    let slowestMatch: TimeInterval
    let totalMatches: Int
    let trendDirection: TrendDirection
    let historicalData: [TimeToMatchData]
}

struct TimeToMatchData {
    let matchId: String
    let likeTimestamp: Date
    let matchTimestamp: Date
    let timeToMatch: TimeInterval
}

enum TrendDirection: String {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

struct UserInsights {
    let userId: String
    let profileHeatmap: ProfileHeatmap
    let matchStatistics: MatchStatistics
    let engagementScore: Double
    let recommendations: [String]
    let generatedAt: Date
}

struct MatchStatistics {
    let totalMatches: Int
    let matchesWithConversations: Int
    let conversionRate: Double
    let averageMessagesPerMatch: Double
}

// MARK: - Analytics Errors

enum AnalyticsError: LocalizedError {
    case matchNotFound
    case insufficientData
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .matchNotFound:
            return "Match not found"
        case .insufficientData:
            return "Insufficient data for analysis"
        case .invalidDateRange:
            return "Invalid date range for analytics"
        }
    }
}
