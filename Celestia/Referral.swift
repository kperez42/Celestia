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
    case selfReferral
    case alreadyReferred
    case emailAlreadyReferred
    case codeGenerationFailed
    case maxReferralsReached

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "This referral code doesn't exist. Please check and try again."
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

    enum CodingKeys: String, CodingKey {
        case id
        case referrerUserId
        case referredUserId
        case referralCode
        case status
        case createdAt
        case completedAt
        case rewardClaimed
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
