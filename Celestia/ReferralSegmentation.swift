//
//  ReferralSegmentation.swift
//  Celestia
//
//  User segmentation for targeted referral campaigns
//  Features: Dynamic segments, personalized rewards, targeting rules
//

import Foundation
import FirebaseFirestore

// MARK: - Segment Models

struct UserSegment: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let rules: [SegmentRule]
    let combineOperator: CombineOperator  // AND or OR for rules
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    // Campaign settings
    var referrerBonus: Int?          // Override default bonus
    var referredBonus: Int?          // Override default bonus
    var customMessage: String?       // Custom share message
    var priorityLevel: Int           // Higher = more priority when user matches multiple
}

enum CombineOperator: String, Codable {
    case and = "AND"
    case or = "OR"
}

struct SegmentRule: Codable {
    let field: SegmentField
    let `operator`: SegmentOperator
    let value: SegmentValue

    func evaluate(with context: UserSegmentContext) -> Bool {
        let fieldValue = context.getValue(for: field)
        return `operator`.evaluate(fieldValue: fieldValue, ruleValue: value)
    }
}

enum SegmentField: String, Codable {
    // User attributes
    case accountAgeDays = "account_age_days"
    case isPremium = "is_premium"
    case subscriptionType = "subscription_type"
    case profileCompletion = "profile_completion"

    // Engagement
    case totalReferrals = "total_referrals"
    case successfulReferrals = "successful_referrals"
    case lastActiveDate = "last_active_date"
    case sessionCount = "session_count"
    case averageSessionDuration = "avg_session_duration"

    // Social
    case matchCount = "match_count"
    case messagesSent = "messages_sent"
    case likesReceived = "likes_received"

    // Acquisition
    case acquisitionSource = "acquisition_source"
    case wasReferred = "was_referred"
    case referralCode = "referral_code"

    // Revenue
    case lifetimeValue = "lifetime_value"
    case lastPurchaseDate = "last_purchase_date"
    case purchaseCount = "purchase_count"

    // Location
    case country = "country"
    case city = "city"
    case timezone = "timezone"

    // Demographics
    case ageRange = "age_range"
    case gender = "gender"
}

enum SegmentOperator: String, Codable {
    case equals = "equals"
    case notEquals = "not_equals"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThanOrEqual = "less_than_or_equal"
    case contains = "contains"
    case notContains = "not_contains"
    case `in` = "in"
    case notIn = "not_in"
    case between = "between"
    case isNull = "is_null"
    case isNotNull = "is_not_null"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case withinDays = "within_days"      // For dates
    case olderThanDays = "older_than_days"  // For dates

    func evaluate(fieldValue: Any?, ruleValue: SegmentValue) -> Bool {
        switch self {
        case .equals:
            return areEqual(fieldValue, ruleValue)
        case .notEquals:
            return !areEqual(fieldValue, ruleValue)
        case .greaterThan:
            return compare(fieldValue, ruleValue) > 0
        case .lessThan:
            return compare(fieldValue, ruleValue) < 0
        case .greaterThanOrEqual:
            return compare(fieldValue, ruleValue) >= 0
        case .lessThanOrEqual:
            return compare(fieldValue, ruleValue) <= 0
        case .contains:
            if let str = fieldValue as? String, case .string(let val) = ruleValue {
                return str.localizedCaseInsensitiveContains(val)
            }
            return false
        case .notContains:
            if let str = fieldValue as? String, case .string(let val) = ruleValue {
                return !str.localizedCaseInsensitiveContains(val)
            }
            return true
        case .in:
            if case .array(let arr) = ruleValue {
                return arr.contains { areEqual(fieldValue, $0) }
            }
            return false
        case .notIn:
            if case .array(let arr) = ruleValue {
                return !arr.contains { areEqual(fieldValue, $0) }
            }
            return true
        case .between:
            if case .range(let min, let max) = ruleValue {
                let c1 = compare(fieldValue, .number(min))
                let c2 = compare(fieldValue, .number(max))
                return c1 >= 0 && c2 <= 0
            }
            return false
        case .isNull:
            return fieldValue == nil
        case .isNotNull:
            return fieldValue != nil
        case .startsWith:
            if let str = fieldValue as? String, case .string(let val) = ruleValue {
                return str.lowercased().hasPrefix(val.lowercased())
            }
            return false
        case .endsWith:
            if let str = fieldValue as? String, case .string(let val) = ruleValue {
                return str.lowercased().hasSuffix(val.lowercased())
            }
            return false
        case .withinDays:
            if let date = fieldValue as? Date, case .number(let days) = ruleValue {
                let threshold = Calendar.current.date(byAdding: .day, value: -Int(days), to: Date()) ?? Date()
                return date >= threshold
            }
            return false
        case .olderThanDays:
            if let date = fieldValue as? Date, case .number(let days) = ruleValue {
                let threshold = Calendar.current.date(byAdding: .day, value: -Int(days), to: Date()) ?? Date()
                return date < threshold
            }
            return false
        }
    }

    private func areEqual(_ fieldValue: Any?, _ ruleValue: SegmentValue) -> Bool {
        switch ruleValue {
        case .string(let val):
            return (fieldValue as? String)?.lowercased() == val.lowercased()
        case .number(let val):
            if let intVal = fieldValue as? Int { return Double(intVal) == val }
            if let doubleVal = fieldValue as? Double { return doubleVal == val }
            return false
        case .bool(let val):
            return (fieldValue as? Bool) == val
        case .date(let val):
            return (fieldValue as? Date) == val
        default:
            return false
        }
    }

    private func compare(_ fieldValue: Any?, _ ruleValue: SegmentValue) -> Int {
        switch ruleValue {
        case .number(let val):
            var fieldNum: Double?
            if let intVal = fieldValue as? Int { fieldNum = Double(intVal) }
            if let doubleVal = fieldValue as? Double { fieldNum = doubleVal }
            guard let num = fieldNum else { return 0 }
            if num < val { return -1 }
            if num > val { return 1 }
            return 0
        case .date(let val):
            guard let date = fieldValue as? Date else { return 0 }
            if date < val { return -1 }
            if date > val { return 1 }
            return 0
        default:
            return 0
        }
    }
}

enum SegmentValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case date(Date)
    case array([SegmentValue])
    case range(min: Double, max: Double)

    enum CodingKeys: String, CodingKey {
        case type, value, min, max, values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            self = .string(try container.decode(String.self, forKey: .value))
        case "number":
            self = .number(try container.decode(Double.self, forKey: .value))
        case "bool":
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case "date":
            self = .date(try container.decode(Date.self, forKey: .value))
        case "array":
            self = .array(try container.decode([SegmentValue].self, forKey: .values))
        case "range":
            let min = try container.decode(Double.self, forKey: .min)
            let max = try container.decode(Double.self, forKey: .max)
            self = .range(min: min, max: max)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let val):
            try container.encode("string", forKey: .type)
            try container.encode(val, forKey: .value)
        case .number(let val):
            try container.encode("number", forKey: .type)
            try container.encode(val, forKey: .value)
        case .bool(let val):
            try container.encode("bool", forKey: .type)
            try container.encode(val, forKey: .value)
        case .date(let val):
            try container.encode("date", forKey: .type)
            try container.encode(val, forKey: .value)
        case .array(let vals):
            try container.encode("array", forKey: .type)
            try container.encode(vals, forKey: .values)
        case .range(let min, let max):
            try container.encode("range", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        }
    }
}

// MARK: - User Context

struct UserSegmentContext {
    let userId: String

    // User attributes
    var accountAgeDays: Int = 0
    var isPremium: Bool = false
    var subscriptionType: String?
    var profileCompletion: Double = 0

    // Engagement
    var totalReferrals: Int = 0
    var successfulReferrals: Int = 0
    var lastActiveDate: Date?
    var sessionCount: Int = 0
    var averageSessionDuration: Double = 0

    // Social
    var matchCount: Int = 0
    var messagesSent: Int = 0
    var likesReceived: Int = 0

    // Acquisition
    var acquisitionSource: String = "organic"
    var wasReferred: Bool = false
    var referralCode: String?

    // Revenue
    var lifetimeValue: Double = 0
    var lastPurchaseDate: Date?
    var purchaseCount: Int = 0

    // Location
    var country: String?
    var city: String?
    var timezone: String?

    // Demographics
    var ageRange: String?
    var gender: String?

    func getValue(for field: SegmentField) -> Any? {
        switch field {
        case .accountAgeDays: return accountAgeDays
        case .isPremium: return isPremium
        case .subscriptionType: return subscriptionType
        case .profileCompletion: return profileCompletion
        case .totalReferrals: return totalReferrals
        case .successfulReferrals: return successfulReferrals
        case .lastActiveDate: return lastActiveDate
        case .sessionCount: return sessionCount
        case .averageSessionDuration: return averageSessionDuration
        case .matchCount: return matchCount
        case .messagesSent: return messagesSent
        case .likesReceived: return likesReceived
        case .acquisitionSource: return acquisitionSource
        case .wasReferred: return wasReferred
        case .referralCode: return referralCode
        case .lifetimeValue: return lifetimeValue
        case .lastPurchaseDate: return lastPurchaseDate
        case .purchaseCount: return purchaseCount
        case .country: return country
        case .city: return city
        case .timezone: return timezone
        case .ageRange: return ageRange
        case .gender: return gender
        }
    }
}

// MARK: - Segment Manager

@MainActor
class ReferralSegmentation: ObservableObject {
    static let shared = ReferralSegmentation()

    private let db = Firestore.firestore()

    @Published var activeSegments: [UserSegment] = []
    private var segmentsCache: [UserSegment] = []
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 300  // 5 minutes

    // Predefined segments
    static let predefinedSegments: [UserSegment] = [
        // High-value referrers
        UserSegment(
            id: "high_value_referrers",
            name: "High-Value Referrers",
            description: "Users with 5+ successful referrals",
            rules: [
                SegmentRule(field: .successfulReferrals, operator: .greaterThanOrEqual, value: .number(5))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 10,
            referredBonus: 5,
            customMessage: nil,
            priorityLevel: 10
        ),
        // Premium users
        UserSegment(
            id: "premium_users",
            name: "Premium Users",
            description: "Active premium subscribers",
            rules: [
                SegmentRule(field: .isPremium, operator: .equals, value: .bool(true))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 10,
            referredBonus: 5,
            customMessage: nil,
            priorityLevel: 8
        ),
        // Dormant users
        UserSegment(
            id: "dormant_users",
            name: "Dormant Users",
            description: "Users inactive for 30+ days",
            rules: [
                SegmentRule(field: .lastActiveDate, operator: .olderThanDays, value: .number(30))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 14,
            referredBonus: 7,
            customMessage: "We miss you! Come back and get extra rewards for inviting friends!",
            priorityLevel: 5
        ),
        // New users
        UserSegment(
            id: "new_users",
            name: "New Users",
            description: "Users who signed up in the last 7 days",
            rules: [
                SegmentRule(field: .accountAgeDays, operator: .lessThanOrEqual, value: .number(7))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 7,
            referredBonus: 7,
            customMessage: nil,
            priorityLevel: 6
        ),
        // High engagement
        UserSegment(
            id: "high_engagement",
            name: "High Engagement",
            description: "Very active users (50+ sessions, 10+ matches)",
            rules: [
                SegmentRule(field: .sessionCount, operator: .greaterThanOrEqual, value: .number(50)),
                SegmentRule(field: .matchCount, operator: .greaterThanOrEqual, value: .number(10))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 10,
            referredBonus: 5,
            customMessage: nil,
            priorityLevel: 7
        ),
        // Referred users
        UserSegment(
            id: "referred_users",
            name: "Referred Users",
            description: "Users who were referred by someone else",
            rules: [
                SegmentRule(field: .wasReferred, operator: .equals, value: .bool(true))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 7,
            referredBonus: 3,
            customMessage: nil,
            priorityLevel: 4
        ),
        // Whale users
        UserSegment(
            id: "whale_users",
            name: "Whale Users",
            description: "High LTV users ($100+)",
            rules: [
                SegmentRule(field: .lifetimeValue, operator: .greaterThanOrEqual, value: .number(100))
            ],
            combineOperator: .and,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            referrerBonus: 14,
            referredBonus: 7,
            customMessage: nil,
            priorityLevel: 9
        )
    ]

    private init() {
        Task {
            await loadSegments()
        }
    }

    // MARK: - Segment Loading

    func loadSegments(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           !segmentsCache.isEmpty {
            return
        }

        do {
            let snapshot = try await db.collection("referralSegments")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            var segments = snapshot.documents.compactMap { doc -> UserSegment? in
                return parseSegment(from: doc)
            }

            // Add predefined segments that aren't overridden
            let customIds = Set(segments.map { $0.id })
            for predefined in Self.predefinedSegments {
                if !customIds.contains(predefined.id) {
                    segments.append(predefined)
                }
            }

            // Sort by priority
            segments.sort { $0.priorityLevel > $1.priorityLevel }

            segmentsCache = segments
            activeSegments = segments
            lastFetchTime = Date()

            Logger.shared.info("Loaded \(segments.count) segments", category: .referral)
        } catch {
            Logger.shared.error("Failed to load segments", category: .referral, error: error)
            // Use predefined as fallback
            segmentsCache = Self.predefinedSegments
            activeSegments = Self.predefinedSegments
        }
    }

    private func parseSegment(from doc: DocumentSnapshot) -> UserSegment? {
        guard let data = doc.data() else { return nil }

        let rulesData = data["rules"] as? [[String: Any]] ?? []
        let rules = rulesData.compactMap { parseRule(from: $0) }

        guard !rules.isEmpty else { return nil }

        return UserSegment(
            id: doc.documentID,
            name: data["name"] as? String ?? "",
            description: data["description"] as? String ?? "",
            rules: rules,
            combineOperator: CombineOperator(rawValue: data["combineOperator"] as? String ?? "AND") ?? .and,
            isActive: data["isActive"] as? Bool ?? true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            referrerBonus: data["referrerBonus"] as? Int,
            referredBonus: data["referredBonus"] as? Int,
            customMessage: data["customMessage"] as? String,
            priorityLevel: data["priorityLevel"] as? Int ?? 0
        )
    }

    private func parseRule(from data: [String: Any]) -> SegmentRule? {
        guard let fieldStr = data["field"] as? String,
              let field = SegmentField(rawValue: fieldStr),
              let operatorStr = data["operator"] as? String,
              let op = SegmentOperator(rawValue: operatorStr) else {
            return nil
        }

        let value: SegmentValue
        if let strVal = data["value"] as? String {
            value = .string(strVal)
        } else if let numVal = data["value"] as? Double {
            value = .number(numVal)
        } else if let numVal = data["value"] as? Int {
            value = .number(Double(numVal))
        } else if let boolVal = data["value"] as? Bool {
            value = .bool(boolVal)
        } else if let dateVal = (data["value"] as? Timestamp)?.dateValue() {
            value = .date(dateVal)
        } else if let arrVal = data["values"] as? [String] {
            value = .array(arrVal.map { .string($0) })
        } else if let minVal = data["min"] as? Double, let maxVal = data["max"] as? Double {
            value = .range(min: minVal, max: maxVal)
        } else {
            return nil
        }

        return SegmentRule(field: field, operator: op, value: value)
    }

    // MARK: - User Segmentation

    /// Gets all segments a user belongs to
    func getSegments(for context: UserSegmentContext) -> [UserSegment] {
        return segmentsCache.filter { segment in
            evaluateSegment(segment, with: context)
        }
    }

    /// Gets the highest priority segment for a user
    func getPrimarySegment(for context: UserSegmentContext) -> UserSegment? {
        return getSegments(for: context).first
    }

    /// Evaluates if a user matches a segment
    func evaluateSegment(_ segment: UserSegment, with context: UserSegmentContext) -> Bool {
        guard segment.isActive else { return false }

        switch segment.combineOperator {
        case .and:
            return segment.rules.allSatisfy { $0.evaluate(with: context) }
        case .or:
            return segment.rules.contains { $0.evaluate(with: context) }
        }
    }

    // MARK: - Build Context

    /// Builds a segment context for a user
    func buildContext(for userId: String) async throws -> UserSegmentContext {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]

        var context = UserSegmentContext(userId: userId)

        // Account age
        if let createdAt = (userData["createdAt"] as? Timestamp)?.dateValue() {
            context.accountAgeDays = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        }

        // Premium status
        context.isPremium = userData["isPremium"] as? Bool ?? false
        context.subscriptionType = userData["subscriptionType"] as? String

        // Profile completion
        context.profileCompletion = calculateProfileCompletion(userData: userData)

        // Referral stats
        if let referralStats = userData["referralStats"] as? [String: Any] {
            context.totalReferrals = referralStats["totalReferrals"] as? Int ?? 0
        }

        // Count successful referrals
        let referralsSnapshot = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "completed")
            .getDocuments()
        context.successfulReferrals = referralsSnapshot.documents.count

        // Last active
        context.lastActiveDate = (userData["lastActiveAt"] as? Timestamp)?.dateValue()

        // Session count
        let sessionsSnapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        context.sessionCount = sessionsSnapshot.documents.count

        // Social stats
        context.matchCount = userData["matchCount"] as? Int ?? 0
        context.messagesSent = userData["messagesSent"] as? Int ?? 0
        context.likesReceived = userData["likesReceived"] as? Int ?? 0

        // Acquisition
        context.acquisitionSource = userData["acquisitionSource"] as? String ?? "organic"

        // Check if was referred
        let referredSnapshot = try await db.collection("referrals")
            .whereField("referredUserId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        context.wasReferred = !referredSnapshot.documents.isEmpty

        // Revenue
        let purchasesSnapshot = try await db.collection("purchases")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        context.lifetimeValue = purchasesSnapshot.documents.reduce(0.0) { sum, doc in
            sum + (doc.data()["amount"] as? Double ?? 0)
        }
        context.purchaseCount = purchasesSnapshot.documents.count

        if let lastPurchase = purchasesSnapshot.documents.max(by: {
            let date1 = ($0.data()["purchaseDate"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = ($1.data()["purchaseDate"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 < date2
        }) {
            context.lastPurchaseDate = (lastPurchase.data()["purchaseDate"] as? Timestamp)?.dateValue()
        }

        // Location
        context.country = userData["country"] as? String
        context.city = userData["city"] as? String
        context.timezone = TimeZone.current.identifier

        // Demographics
        context.gender = userData["gender"] as? String
        if let birthDate = (userData["birthDate"] as? Timestamp)?.dateValue() {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
            context.ageRange = getAgeRange(age)
        }

        return context
    }

    private func calculateProfileCompletion(userData: [String: Any]) -> Double {
        var completed = 0
        let total = 8

        if (userData["fullName"] as? String)?.isEmpty == false { completed += 1 }
        if (userData["bio"] as? String)?.isEmpty == false { completed += 1 }
        if (userData["profileImageURL"] as? String)?.isEmpty == false { completed += 1 }
        if let photos = userData["photos"] as? [String], !photos.isEmpty { completed += 1 }
        if userData["gender"] != nil { completed += 1 }
        if userData["birthDate"] != nil { completed += 1 }
        if let interests = userData["interests"] as? [String], !interests.isEmpty { completed += 1 }
        if (userData["occupation"] as? String)?.isEmpty == false { completed += 1 }

        return Double(completed) / Double(total)
    }

    private func getAgeRange(_ age: Int) -> String {
        switch age {
        case 18..<25: return "18-24"
        case 25..<35: return "25-34"
        case 35..<45: return "35-44"
        case 45..<55: return "45-54"
        case 55..<65: return "55-64"
        default: return "65+"
        }
    }

    // MARK: - Personalized Rewards

    /// Gets personalized referral rewards for a user
    func getPersonalizedRewards(for context: UserSegmentContext) -> (referrerBonus: Int, referredBonus: Int) {
        guard let segment = getPrimarySegment(for: context) else {
            return (7, 3)  // Default
        }

        let referrerBonus = segment.referrerBonus ?? 7
        let referredBonus = segment.referredBonus ?? 3

        return (referrerBonus, referredBonus)
    }

    /// Gets personalized share message for a user
    func getPersonalizedMessage(for context: UserSegmentContext, code: String) -> String? {
        guard let segment = getPrimarySegment(for: context),
              let customMessage = segment.customMessage else {
            return nil
        }

        // Replace placeholders
        return customMessage
            .replacingOccurrences(of: "{CODE}", with: code)
            .replacingOccurrences(of: "{REFERRER_BONUS}", with: String(segment.referrerBonus ?? 7))
            .replacingOccurrences(of: "{REFERRED_BONUS}", with: String(segment.referredBonus ?? 3))
    }

    // MARK: - Segment Management

    /// Creates a new segment
    func createSegment(_ segment: UserSegment) async throws {
        let rulesData = segment.rules.map { rule -> [String: Any] in
            var data: [String: Any] = [
                "field": rule.field.rawValue,
                "operator": rule.operator.rawValue
            ]

            switch rule.value {
            case .string(let val):
                data["value"] = val
            case .number(let val):
                data["value"] = val
            case .bool(let val):
                data["value"] = val
            case .date(let val):
                data["value"] = Timestamp(date: val)
            case .array(let vals):
                data["values"] = vals.compactMap { v -> String? in
                    if case .string(let s) = v { return s }
                    return nil
                }
            case .range(let min, let max):
                data["min"] = min
                data["max"] = max
            }

            return data
        }

        let data: [String: Any] = [
            "name": segment.name,
            "description": segment.description,
            "rules": rulesData,
            "combineOperator": segment.combineOperator.rawValue,
            "isActive": segment.isActive,
            "createdAt": Timestamp(date: segment.createdAt),
            "updatedAt": Timestamp(date: Date()),
            "referrerBonus": segment.referrerBonus as Any,
            "referredBonus": segment.referredBonus as Any,
            "customMessage": segment.customMessage as Any,
            "priorityLevel": segment.priorityLevel
        ]

        try await db.collection("referralSegments").document(segment.id).setData(data)

        // Refresh cache
        await loadSegments(forceRefresh: true)
    }

    /// Updates segment assignment for analytics
    func trackSegmentAssignment(userId: String, segmentIds: [String]) async {
        let data: [String: Any] = [
            "userId": userId,
            "segmentIds": segmentIds,
            "assignedAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("userSegmentAssignments").document(userId).setData(data)
        } catch {
            Logger.shared.error("Failed to track segment assignment", category: .referral, error: error)
        }
    }

    // MARK: - Segment Analytics

    /// Gets segment statistics
    func getSegmentStats(segmentId: String) async throws -> SegmentStats {
        // Count users in segment
        let assignmentsSnapshot = try await db.collection("userSegmentAssignments")
            .whereField("segmentIds", arrayContains: segmentId)
            .getDocuments()

        let userCount = assignmentsSnapshot.documents.count

        // Get referral performance for segment
        let userIds = assignmentsSnapshot.documents.map { $0.documentID }

        var totalReferrals = 0
        var successfulReferrals = 0
        var totalRevenue = 0.0

        for batch in stride(from: 0, to: userIds.count, by: 10) {
            let endIndex = min(batch + 10, userIds.count)
            let batchIds = Array(userIds[batch..<endIndex])

            let referralsSnapshot = try await db.collection("referrals")
                .whereField("referrerUserId", in: batchIds)
                .getDocuments()

            totalReferrals += referralsSnapshot.documents.count
            successfulReferrals += referralsSnapshot.documents.filter {
                ($0.data()["status"] as? String) == "completed"
            }.count
        }

        return SegmentStats(
            segmentId: segmentId,
            userCount: userCount,
            totalReferrals: totalReferrals,
            successfulReferrals: successfulReferrals,
            conversionRate: totalReferrals > 0 ? Double(successfulReferrals) / Double(totalReferrals) : 0,
            averageReferralsPerUser: userCount > 0 ? Double(totalReferrals) / Double(userCount) : 0,
            totalRevenue: totalRevenue
        )
    }
}

// MARK: - Segment Stats

struct SegmentStats {
    let segmentId: String
    let userCount: Int
    let totalReferrals: Int
    let successfulReferrals: Int
    let conversionRate: Double
    let averageReferralsPerUser: Double
    let totalRevenue: Double
}
