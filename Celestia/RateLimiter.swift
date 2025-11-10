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

    // Track action timestamps
    private var messageTimes: [Date] = []
    private var likeTimes: [Date] = []
    private var reportTimes: [Date] = []
    private var searchTimes: [Date] = []

    private init() {}

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
    }

    /// Check if user is rate limited for a specific action
    func isRateLimited(for action: RateLimitAction) -> Bool {
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
    func timeUntilReset(for action: RateLimitAction) -> TimeInterval? {
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

enum RateLimitAction {
    case message
    case like
    case report
    case search
}

// MARK: - Rate Limit Error

extension CelestiaError {
    static let rateLimitExceeded = CelestiaError.custom(
        message: "You're doing that too often. Please wait a moment and try again.",
        icon: "clock.fill"
    )

    static func rateLimitExceeded(timeRemaining: TimeInterval) -> CelestiaError {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))

        let timeString = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
        return .custom(
            message: "Rate limit exceeded. Try again in \(timeString).",
            icon: "clock.fill"
        )
    }
}
