//
//  Referral.swift
//  Celestia
//
//  Referral system models
//

import Foundation
import FirebaseFirestore

// MARK: - Referral Errors

enum ReferralError: LocalizedError {
    case invalidCode
    case invalidUser
    case selfReferral
    case alreadyReferred
    case emailAlreadyReferred
    case codeGenerationFailed
    case maxReferralsReached
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "This referral code doesn't exist. Please check and try again."
        case .invalidUser:
            return "Invalid user account."
        case .selfReferral:
            return "You cannot use your own referral code."
        case .alreadyReferred:
            return "This account has already been referred by someone else."
        case .emailAlreadyReferred:
            return "This email has already been used with a referral code."
        case .codeGenerationFailed:
            return "Failed to generate a unique referral code. Please try again."
        case .maxReferralsReached:
            return "You've reached the maximum number of referrals allowed."
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        }
    }
}

// MARK: - Referral Model

struct Referral: Identifiable, Codable {
    @DocumentID var id: String?

    var referrerUserId: String      // User who sent the referral
    var referredUserId: String?     // User who signed up (nil if pending)
    var referralCode: String         // Unique referral code
    var status: ReferralStatus       // Status of the referral
    var createdAt: Date              // When referral was created
    var completedAt: Date?           // When referred user signed up
    var rewardClaimed: Bool = false  // Whether reward was claimed by referrer

    // Transient properties (not stored in Firestore, fetched separately)
    var referredUserName: String?    // Name of referred user (for display)
    var referredUserPhotoURL: String? // Photo URL of referred user

    enum CodingKeys: String, CodingKey {
        case id
        case referrerUserId
        case referredUserId
        case referralCode
        case status
        case createdAt
        case completedAt
        case rewardClaimed
        // Note: referredUserName and referredUserPhotoURL are NOT in CodingKeys
        // They are transient properties fetched separately
    }

    // Custom encoding to handle nil values properly for Firebase
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(referrerUserId, forKey: .referrerUserId)
        try container.encodeIfPresent(referredUserId, forKey: .referredUserId)
        try container.encode(referralCode, forKey: .referralCode)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(rewardClaimed, forKey: .rewardClaimed)
        // Don't encode transient properties
    }

    /// Helper to check if referral is recent (within last 7 days)
    var isRecent: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return createdAt > sevenDaysAgo
    }

    /// Formatted date string for display
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

enum ReferralStatus: String, Codable {
    case pending = "pending"         // Code generated, no signup yet
    case completed = "completed"     // User signed up successfully
    case rewarded = "rewarded"       // Referrer received reward
    case expired = "expired"         // Referral expired (optional)
}

// MARK: - Referral Stats

struct ReferralStats: Codable {
    var totalReferrals: Int = 0           // Total successful referrals
    var pendingReferrals: Int = 0         // Pending signups
    var premiumDaysEarned: Int = 0        // Total premium days earned
    var referralCode: String = ""         // User's unique referral code
    var referralRank: Int = 0             // Leaderboard rank

    init() {}

    init(dictionary: [String: Any]) {
        self.totalReferrals = dictionary["totalReferrals"] as? Int ?? 0
        self.pendingReferrals = dictionary["pendingReferrals"] as? Int ?? 0
        self.premiumDaysEarned = dictionary["premiumDaysEarned"] as? Int ?? 0
        self.referralCode = dictionary["referralCode"] as? String ?? ""
        self.referralRank = dictionary["referralRank"] as? Int ?? 0
    }
}

// MARK: - Referral Rewards

struct ReferralRewards {
    static let referrerBonusDays = 7     // Days for successful referral
    static let newUserBonusDays = 3      // Days for new user signup
    static let maxReferrals = 100        // Max referrals per user

    static func calculateTotalDays(referrals: Int) -> Int {
        return min(referrals * referrerBonusDays, maxReferrals * referrerBonusDays)
    }

    /// Returns the number of referrals remaining until max limit
    static func remainingReferrals(current: Int) -> Int {
        return max(0, maxReferrals - current)
    }
}

// MARK: - Referral Milestones

struct ReferralMilestone: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let requiredReferrals: Int
    let icon: String
    let bonusDays: Int  // Extra bonus days for reaching milestone

    static let milestones: [ReferralMilestone] = [
        ReferralMilestone(
            id: "first_referral",
            name: "First Steps",
            description: "Complete your first referral",
            requiredReferrals: 1,
            icon: "star.fill",
            bonusDays: 0
        ),
        ReferralMilestone(
            id: "rising_star",
            name: "Rising Star",
            description: "Refer 5 friends",
            requiredReferrals: 5,
            icon: "star.circle.fill",
            bonusDays: 3
        ),
        ReferralMilestone(
            id: "social_butterfly",
            name: "Social Butterfly",
            description: "Refer 10 friends",
            requiredReferrals: 10,
            icon: "person.3.fill",
            bonusDays: 7
        ),
        ReferralMilestone(
            id: "influencer",
            name: "Influencer",
            description: "Refer 25 friends",
            requiredReferrals: 25,
            icon: "megaphone.fill",
            bonusDays: 14
        ),
        ReferralMilestone(
            id: "ambassador",
            name: "Ambassador",
            description: "Refer 50 friends",
            requiredReferrals: 50,
            icon: "crown.fill",
            bonusDays: 30
        ),
        ReferralMilestone(
            id: "legend",
            name: "Legend",
            description: "Refer 100 friends",
            requiredReferrals: 100,
            icon: "trophy.fill",
            bonusDays: 60
        )
    ]

    /// Returns the next milestone for a given referral count
    static func nextMilestone(for referralCount: Int) -> ReferralMilestone? {
        return milestones.first { $0.requiredReferrals > referralCount }
    }

    /// Returns the milestone just achieved (if any) when going from oldCount to newCount
    static func newlyAchievedMilestone(oldCount: Int, newCount: Int) -> ReferralMilestone? {
        return milestones.first { milestone in
            oldCount < milestone.requiredReferrals && newCount >= milestone.requiredReferrals
        }
    }

    /// Returns all achieved milestones for a referral count
    static func achievedMilestones(for referralCount: Int) -> [ReferralMilestone] {
        return milestones.filter { $0.requiredReferrals <= referralCount }
    }

    /// Returns progress toward next milestone (0.0 to 1.0)
    static func progressToNextMilestone(for referralCount: Int) -> Double {
        guard let nextMilestone = nextMilestone(for: referralCount) else {
            return 1.0 // All milestones achieved
        }

        let previousMilestone = milestones.last { $0.requiredReferrals <= referralCount }
        let startCount = previousMilestone?.requiredReferrals ?? 0

        let progress = Double(referralCount - startCount) / Double(nextMilestone.requiredReferrals - startCount)
        return min(1.0, max(0.0, progress))
    }
}

// MARK: - Leaderboard Entry

struct ReferralLeaderboardEntry: Identifiable, Codable {
    var id: String                    // User ID
    var userName: String              // User's name
    var profileImageURL: String       // User's photo
    var totalReferrals: Int           // Number of successful referrals
    var rank: Int                     // Current rank
    var premiumDaysEarned: Int        // Total days earned

    init(id: String, userName: String, profileImageURL: String, totalReferrals: Int, rank: Int, premiumDaysEarned: Int) {
        self.id = id
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.totalReferrals = totalReferrals
        self.rank = rank
        self.premiumDaysEarned = premiumDaysEarned
    }
}
