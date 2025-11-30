//
//  RateLimiter.swift
//  Celestia
//
//  Client-side rate limiting to prevent abuse
//

import Foundation

@MainActor
class RateLimiter: ObservableObject {
    static let shared = RateLimiter()

    // SECURITY FIX: Persist timestamps to prevent bypass by restarting app
    // Track action timestamps
    private var messageTimes: [Date] = [] {
        didSet { saveToDisk(messageTimes, key: "rate_limit_messages") }
    }
    private var likeTimes: [Date] = [] {
        didSet { saveToDisk(likeTimes, key: "rate_limit_likes") }
    }
    private var reportTimes: [Date] = [] {
        didSet { saveToDisk(reportTimes, key: "rate_limit_reports") }
    }
    private var searchTimes: [Date] = [] {
        didSet { saveToDisk(searchTimes, key: "rate_limit_searches") }
    }

    // Daily message tracking for free users (across all conversations)
    private var dailyMessageTimes: [Date] = [] {
        didSet { saveToDisk(dailyMessageTimes, key: "rate_limit_daily_messages") }
    }

    private init() {
        // Load persisted timestamps
        messageTimes = loadFromDisk(key: "rate_limit_messages")
        likeTimes = loadFromDisk(key: "rate_limit_likes")
        reportTimes = loadFromDisk(key: "rate_limit_reports")
        searchTimes = loadFromDisk(key: "rate_limit_searches")
        dailyMessageTimes = loadFromDisk(key: "rate_limit_daily_messages")

        Logger.shared.debug(
            "RateLimiter initialized - Loaded \(messageTimes.count) messages, \(likeTimes.count) likes, \(reportTimes.count) reports, \(searchTimes.count) searches, \(dailyMessageTimes.count) daily messages",
            category: .general
        )
    }

    // MARK: - Message Rate Limiting

    func canSendMessage() -> Bool {
        cleanupOldTimestamps(&messageTimes, window: 60) // 1 minute window

        guard messageTimes.count < AppConstants.RateLimit.maxMessagesPerMinute else {
            return false
        }

        messageTimes.append(Date())
        return true
    }

    func recordMessage() {
        messageTimes.append(Date())
    }

    // MARK: - Daily Message Limit (for free users)

    /// Check if free user can send a message (daily limit across all conversations)
    /// Premium users should bypass this check entirely
    func canSendDailyMessage() -> Bool {
        cleanupOldTimestamps(&dailyMessageTimes, window: 86400) // 24 hour window

        guard dailyMessageTimes.count < AppConstants.RateLimit.maxDailyMessagesForFreeUsers else {
            return false
        }

        return true
    }

    /// Record a daily message (call after successfully sending for free users)
    func recordDailyMessage() {
        dailyMessageTimes.append(Date())
    }

    /// Get remaining daily messages for free users
    func getRemainingDailyMessages() -> Int {
        cleanupOldTimestamps(&dailyMessageTimes, window: 86400)
        return max(0, AppConstants.RateLimit.maxDailyMessagesForFreeUsers - dailyMessageTimes.count)
    }

    /// Check if free user has reached daily message limit
    func hasReachedDailyMessageLimit() -> Bool {
        cleanupOldTimestamps(&dailyMessageTimes, window: 86400)
        return dailyMessageTimes.count >= AppConstants.RateLimit.maxDailyMessagesForFreeUsers
    }

    /// Get time until daily message limit resets
    func timeUntilDailyMessageReset() -> TimeInterval? {
        guard let oldestTime = dailyMessageTimes.first else {
            return nil
        }

        let resetTime = oldestTime.addingTimeInterval(86400) // 24 hours
        let now = Date()

        return resetTime > now ? resetTime.timeIntervalSince(now) : nil
    }

    // MARK: - Like/Interest Rate Limiting

    func canSendLike() -> Bool {
        cleanupOldTimestamps(&likeTimes, window: 86400) // 24 hour window

        guard likeTimes.count < AppConstants.RateLimit.maxLikesPerDay else {
            return false
        }

        likeTimes.append(Date())
        return true
    }

    func recordLike() {
        likeTimes.append(Date())
    }

    func getRemainingLikes() -> Int {
        cleanupOldTimestamps(&likeTimes, window: 86400)
        return max(0, AppConstants.RateLimit.maxLikesPerDay - likeTimes.count)
    }

    // MARK: - Report Rate Limiting

    func canReport() -> Bool {
        cleanupOldTimestamps(&reportTimes, window: 3600) // 1 hour window

        let maxReportsPerHour = 5
        guard reportTimes.count < maxReportsPerHour else {
            return false
        }

        reportTimes.append(Date())
        return true
    }

    // MARK: - Search Rate Limiting

    func canSearch() -> Bool {
        cleanupOldTimestamps(&searchTimes, window: 60) // 1 minute window

        let maxSearchesPerMinute = 30
        guard searchTimes.count < maxSearchesPerMinute else {
            return false
        }

        searchTimes.append(Date())
        return true
    }

    // MARK: - Helper Methods

    private func cleanupOldTimestamps(_ times: inout [Date], window: TimeInterval) {
        let cutoffTime = Date().addingTimeInterval(-window)
        times = times.filter { $0 > cutoffTime }
    }

    /// Reset all rate limits (useful for testing or premium users)
    func resetAll() {
        messageTimes = []
        likeTimes = []
        reportTimes = []
        searchTimes = []
        dailyMessageTimes = []

        Logger.shared.info("All rate limits reset", category: .general)
    }

    // MARK: - Persistence

    /// Save timestamps to UserDefaults for persistence across app restarts
    private func saveToDisk(_ dates: [Date], key: String) {
        if let encoded = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    /// Load timestamps from UserDefaults
    private func loadFromDisk(key: String) -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return []
        }

        // Clean up old timestamps when loading
        let cutoffTime = Date().addingTimeInterval(-86400) // 24 hours
        return dates.filter { $0 > cutoffTime }
    }

    /// Check if user is rate limited for a specific action
    func isRateLimited(for action: RateLimitActionType) -> Bool {
        switch action {
        case .message:
            cleanupOldTimestamps(&messageTimes, window: 60)
            return messageTimes.count >= AppConstants.RateLimit.maxMessagesPerMinute
        case .like:
            cleanupOldTimestamps(&likeTimes, window: 86400)
            return likeTimes.count >= AppConstants.RateLimit.maxLikesPerDay
        case .report:
            cleanupOldTimestamps(&reportTimes, window: 3600)
            return reportTimes.count >= 5
        case .search:
            cleanupOldTimestamps(&searchTimes, window: 60)
            return searchTimes.count >= 30
        }
    }

    /// Get time until rate limit resets
    func timeUntilReset(for action: RateLimitActionType) -> TimeInterval? {
        let times: [Date]
        let window: TimeInterval

        switch action {
        case .message:
            times = messageTimes
            window = 60
        case .like:
            times = likeTimes
            window = 86400
        case .report:
            times = reportTimes
            window = 3600
        case .search:
            times = searchTimes
            window = 60
        }

        guard let oldestTime = times.first else {
            return nil
        }

        let resetTime = oldestTime.addingTimeInterval(window)
        let now = Date()

        return resetTime > now ? resetTime.timeIntervalSince(now) : nil
    }
}

// MARK: - Rate Limit Action Types
// Note: This is different from RateLimitAction in BackendAPIService
// This is for local client-side rate limiting

enum RateLimitActionType {
    case message
    case like
    case report
    case search
}
