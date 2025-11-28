//
//  ReferralAttribution.swift
//  Celestia
//
//  Advanced attribution system for referral tracking
//  Features: Multi-touch attribution, deferred deep linking, cross-platform tracking
//

import Foundation
import FirebaseFirestore
import AdSupport
import AppTrackingTransparency
import StoreKit

// MARK: - Attribution Models

enum AttributionModel: String, Codable {
    case firstTouch = "first_touch"     // Credit goes to first touchpoint
    case lastTouch = "last_touch"       // Credit goes to last touchpoint
    case linear = "linear"              // Equal credit across all touchpoints
    case timeDecay = "time_decay"       // More credit to recent touchpoints
    case positionBased = "position_based" // 40% first, 40% last, 20% middle
}

enum TouchpointType: String, Codable {
    case directLink = "direct_link"
    case sharedMessage = "shared_message"
    case socialMedia = "social_media"
    case email = "email"
    case pushNotification = "push_notification"
    case inAppShare = "in_app_share"
    case qrCode = "qr_code"
    case organic = "organic"
    case paidAd = "paid_ad"
    case influencer = "influencer"
    case unknown = "unknown"
}

enum Platform: String, Codable {
    case iOS = "ios"
    case android = "android"
    case web = "web"
    case unknown = "unknown"
}

// MARK: - Touchpoint

struct Touchpoint: Codable, Identifiable {
    let id: String
    let type: TouchpointType
    let source: String           // e.g., "facebook", "instagram", "direct"
    let medium: String           // e.g., "social", "email", "cpc"
    let campaign: String?        // Campaign name if applicable
    let referralCode: String?
    let timestamp: Date
    let platform: Platform
    let deviceId: String?
    let sessionId: String
    let metadata: [String: String]

    var attributionCredit: Double = 0.0

    enum CodingKeys: String, CodingKey {
        case id, type, source, medium, campaign, referralCode
        case timestamp, platform, deviceId, sessionId, metadata
    }
}

// MARK: - Attribution Window

struct AttributionWindow: Codable {
    let clickWindow: TimeInterval    // How long after click to attribute (default: 7 days)
    let viewWindow: TimeInterval     // How long after view to attribute (default: 1 day)
    let installWindow: TimeInterval  // Time to complete install (default: 30 days)

    static let `default` = AttributionWindow(
        clickWindow: 7 * 24 * 3600,      // 7 days
        viewWindow: 24 * 3600,            // 1 day
        installWindow: 30 * 24 * 3600     // 30 days
    )
}

// MARK: - Deferred Deep Link

struct DeferredDeepLink: Codable {
    let linkId: String
    let referralCode: String
    let originalURL: String
    let source: String
    let medium: String
    let campaign: String?
    let createdAt: Date
    let expiresAt: Date
    let fingerprint: LinkFingerprint
    let claimed: Bool
    let claimedBy: String?
    let claimedAt: Date?
}

struct LinkFingerprint: Codable {
    let ipAddress: String?
    let userAgent: String?
    let screenResolution: String?
    let timezone: String?
    let language: String?
    let platform: String?

    /// Match score between two fingerprints (0.0 - 1.0)
    func matchScore(with other: LinkFingerprint) -> Double {
        var matches = 0.0
        var total = 0.0

        if let ip1 = ipAddress, let ip2 = other.ipAddress {
            total += 3.0  // IP is weighted heavily
            if ip1 == ip2 { matches += 3.0 }
        }

        if let tz1 = timezone, let tz2 = other.timezone {
            total += 1.0
            if tz1 == tz2 { matches += 1.0 }
        }

        if let lang1 = language, let lang2 = other.language {
            total += 1.0
            if lang1 == lang2 { matches += 1.0 }
        }

        if let platform1 = platform, let platform2 = other.platform {
            total += 1.5
            if platform1 == platform2 { matches += 1.5 }
        }

        if let screen1 = screenResolution, let screen2 = other.screenResolution {
            total += 0.5
            if screen1 == screen2 { matches += 0.5 }
        }

        return total > 0 ? matches / total : 0.0
    }
}

// MARK: - Attribution Result

struct AttributionResult: Codable {
    let resultId: String
    let userId: String
    let conversionType: ConversionType
    let touchpoints: [Touchpoint]
    let attributedReferralCode: String?
    let attributedReferrerId: String?
    let attributionModel: AttributionModel
    let attributedAt: Date
    let confidence: Double           // 0.0 - 1.0
    let isDeferredDeepLink: Bool
    let revenue: Double?             // If conversion involved payment
    let metadata: [String: String]

    /// Primary touchpoint based on attribution model
    var primaryTouchpoint: Touchpoint? {
        return touchpoints.max(by: { $0.attributionCredit < $1.attributionCredit })
    }
}

enum ConversionType: String, Codable {
    case install = "install"
    case signup = "signup"
    case referralComplete = "referral_complete"
    case subscription = "subscription"
    case inAppPurchase = "in_app_purchase"
    case engagement = "engagement"
}

// MARK: - Attribution Manager

@MainActor
class ReferralAttribution: ObservableObject {
    static let shared = ReferralAttribution()

    private let db = Firestore.firestore()
    private var currentSessionId: String
    private var sessionTouchpoints: [Touchpoint] = []
    private let attributionWindow: AttributionWindow

    // Pending deferred deep link
    @Published var pendingDeferredLink: DeferredDeepLink?

    // Current attribution model (can be changed via A/B testing)
    var currentModel: AttributionModel = .lastTouch

    private init() {
        self.currentSessionId = UUID().uuidString
        self.attributionWindow = .default
        loadPendingDeepLink()
    }

    // MARK: - Session Management

    func startNewSession() {
        currentSessionId = UUID().uuidString
        sessionTouchpoints = []
        Logger.shared.info("Started new attribution session: \(currentSessionId)", category: .referral)
    }

    // MARK: - Touchpoint Recording

    /// Records a touchpoint when user interacts with referral content
    func recordTouchpoint(
        type: TouchpointType,
        source: String,
        medium: String,
        campaign: String? = nil,
        referralCode: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let touchpoint = Touchpoint(
            id: UUID().uuidString,
            type: type,
            source: source,
            medium: medium,
            campaign: campaign,
            referralCode: referralCode,
            timestamp: Date(),
            platform: .iOS,
            deviceId: UIDevice.current.identifierForVendor?.uuidString,
            sessionId: currentSessionId,
            metadata: metadata
        )

        sessionTouchpoints.append(touchpoint)

        // Store touchpoint for later attribution
        await storeTouchpoint(touchpoint)

        Logger.shared.info("Recorded touchpoint: \(type.rawValue) from \(source)", category: .referral)
    }

    /// Records a deep link click
    func recordDeepLinkClick(
        url: URL,
        referralCode: String?,
        source: String = "direct"
    ) async {
        // Parse UTM parameters from URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        let utmSource = queryItems.first(where: { $0.name == "utm_source" })?.value ?? source
        let utmMedium = queryItems.first(where: { $0.name == "utm_medium" })?.value ?? "referral"
        let utmCampaign = queryItems.first(where: { $0.name == "utm_campaign" })?.value

        var metadata: [String: String] = ["url": url.absoluteString]
        for item in queryItems {
            if let value = item.value {
                metadata[item.name] = value
            }
        }

        await recordTouchpoint(
            type: .directLink,
            source: utmSource,
            medium: utmMedium,
            campaign: utmCampaign,
            referralCode: referralCode,
            metadata: metadata
        )
    }

    // MARK: - Deferred Deep Linking

    /// Creates a deferred deep link for web-to-app attribution
    func createDeferredDeepLink(
        referralCode: String,
        source: String,
        medium: String,
        campaign: String?,
        fingerprint: LinkFingerprint
    ) async throws -> DeferredDeepLink {
        let linkId = UUID().uuidString
        let expiresAt = Date().addingTimeInterval(attributionWindow.installWindow)

        let link = DeferredDeepLink(
            linkId: linkId,
            referralCode: referralCode,
            originalURL: "https://celestia.app/join/\(referralCode)",
            source: source,
            medium: medium,
            campaign: campaign,
            createdAt: Date(),
            expiresAt: expiresAt,
            fingerprint: fingerprint,
            claimed: false,
            claimedBy: nil,
            claimedAt: nil
        )

        // Store in Firestore
        let data: [String: Any] = [
            "linkId": link.linkId,
            "referralCode": link.referralCode,
            "originalURL": link.originalURL,
            "source": link.source,
            "medium": link.medium,
            "campaign": link.campaign ?? "",
            "createdAt": Timestamp(date: link.createdAt),
            "expiresAt": Timestamp(date: link.expiresAt),
            "fingerprint": [
                "ipAddress": fingerprint.ipAddress ?? "",
                "userAgent": fingerprint.userAgent ?? "",
                "screenResolution": fingerprint.screenResolution ?? "",
                "timezone": fingerprint.timezone ?? "",
                "language": fingerprint.language ?? "",
                "platform": fingerprint.platform ?? ""
            ],
            "claimed": false
        ]

        try await db.collection("deferredDeepLinks").document(linkId).setData(data)

        Logger.shared.info("Created deferred deep link: \(linkId)", category: .referral)
        return link
    }

    /// Attempts to match and claim a deferred deep link on app install
    func matchDeferredDeepLink(currentFingerprint: LinkFingerprint) async throws -> DeferredDeepLink? {
        // Query for unclaimed, non-expired links
        let snapshot = try await db.collection("deferredDeepLinks")
            .whereField("claimed", isEqualTo: false)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "expiresAt")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        var bestMatch: (link: DeferredDeepLink, score: Double)?

        for doc in snapshot.documents {
            let data = doc.data()

            guard let fingerprintData = data["fingerprint"] as? [String: String] else { continue }

            let storedFingerprint = LinkFingerprint(
                ipAddress: fingerprintData["ipAddress"],
                userAgent: fingerprintData["userAgent"],
                screenResolution: fingerprintData["screenResolution"],
                timezone: fingerprintData["timezone"],
                language: fingerprintData["language"],
                platform: fingerprintData["platform"]
            )

            let score = currentFingerprint.matchScore(with: storedFingerprint)

            // Only consider matches above threshold
            if score > 0.6 {
                if bestMatch == nil || score > bestMatch!.score {
                    let link = DeferredDeepLink(
                        linkId: data["linkId"] as? String ?? "",
                        referralCode: data["referralCode"] as? String ?? "",
                        originalURL: data["originalURL"] as? String ?? "",
                        source: data["source"] as? String ?? "",
                        medium: data["medium"] as? String ?? "",
                        campaign: data["campaign"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date(),
                        fingerprint: storedFingerprint,
                        claimed: false,
                        claimedBy: nil,
                        claimedAt: nil
                    )
                    bestMatch = (link, score)
                }
            }
        }

        if let match = bestMatch {
            Logger.shared.info("Matched deferred deep link with score: \(match.score)", category: .referral)
            pendingDeferredLink = match.link
            savePendingDeepLink(match.link)
            return match.link
        }

        return nil
    }

    /// Claims a deferred deep link after user signup
    func claimDeferredDeepLink(linkId: String, userId: String) async throws {
        try await db.collection("deferredDeepLinks").document(linkId).updateData([
            "claimed": true,
            "claimedBy": userId,
            "claimedAt": Timestamp(date: Date())
        ])

        pendingDeferredLink = nil
        clearPendingDeepLink()

        Logger.shared.info("Claimed deferred deep link: \(linkId) for user: \(userId)", category: .referral)
    }

    // MARK: - Multi-Touch Attribution

    /// Performs multi-touch attribution for a conversion
    func attributeConversion(
        userId: String,
        conversionType: ConversionType,
        revenue: Double? = nil,
        lookbackDays: Int = 7
    ) async throws -> AttributionResult {
        // Get all touchpoints within lookback window
        let lookbackDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()

        let touchpoints = try await fetchTouchpoints(
            deviceId: UIDevice.current.identifierForVendor?.uuidString,
            since: lookbackDate
        )

        // Include session touchpoints
        let allTouchpoints = (touchpoints + sessionTouchpoints)
            .sorted(by: { $0.timestamp < $1.timestamp })

        // Apply attribution model
        let attributedTouchpoints = applyAttributionModel(
            touchpoints: allTouchpoints,
            model: currentModel
        )

        // Determine primary referral code
        let primaryTouchpoint = attributedTouchpoints.max(by: { $0.attributionCredit < $1.attributionCredit })
        let attributedCode = primaryTouchpoint?.referralCode ?? allTouchpoints.last?.referralCode

        // Look up referrer if we have a code
        var referrerId: String?
        if let code = attributedCode {
            referrerId = try await lookupReferrerId(code: code)
        }

        // Calculate confidence
        let confidence = calculateAttributionConfidence(touchpoints: attributedTouchpoints)

        let result = AttributionResult(
            resultId: UUID().uuidString,
            userId: userId,
            conversionType: conversionType,
            touchpoints: attributedTouchpoints,
            attributedReferralCode: attributedCode,
            attributedReferrerId: referrerId,
            attributionModel: currentModel,
            attributedAt: Date(),
            confidence: confidence,
            isDeferredDeepLink: pendingDeferredLink != nil,
            revenue: revenue,
            metadata: [:]
        )

        // Store result
        try await storeAttributionResult(result)

        Logger.shared.info("Attribution complete: \(conversionType.rawValue) -> \(attributedCode ?? "organic")", category: .referral)

        return result
    }

    /// Applies the attribution model to assign credit to touchpoints
    private func applyAttributionModel(touchpoints: [Touchpoint], model: AttributionModel) -> [Touchpoint] {
        guard !touchpoints.isEmpty else { return [] }

        var attributed = touchpoints

        switch model {
        case .firstTouch:
            for i in attributed.indices {
                attributed[i].attributionCredit = i == 0 ? 1.0 : 0.0
            }

        case .lastTouch:
            for i in attributed.indices {
                attributed[i].attributionCredit = i == attributed.count - 1 ? 1.0 : 0.0
            }

        case .linear:
            let credit = 1.0 / Double(attributed.count)
            for i in attributed.indices {
                attributed[i].attributionCredit = credit
            }

        case .timeDecay:
            // Half-life of 7 days
            let halfLife: TimeInterval = 7 * 24 * 3600
            let now = Date()
            var totalWeight = 0.0

            // Calculate weights
            var weights: [Double] = []
            for tp in attributed {
                let age = now.timeIntervalSince(tp.timestamp)
                let weight = pow(0.5, age / halfLife)
                weights.append(weight)
                totalWeight += weight
            }

            // Normalize
            for i in attributed.indices {
                attributed[i].attributionCredit = totalWeight > 0 ? weights[i] / totalWeight : 0.0
            }

        case .positionBased:
            // 40% first, 40% last, 20% distributed among middle
            if attributed.count == 1 {
                attributed[0].attributionCredit = 1.0
            } else if attributed.count == 2 {
                attributed[0].attributionCredit = 0.5
                attributed[1].attributionCredit = 0.5
            } else {
                let middleCount = attributed.count - 2
                let middleCredit = 0.2 / Double(middleCount)

                for i in attributed.indices {
                    if i == 0 {
                        attributed[i].attributionCredit = 0.4
                    } else if i == attributed.count - 1 {
                        attributed[i].attributionCredit = 0.4
                    } else {
                        attributed[i].attributionCredit = middleCredit
                    }
                }
            }
        }

        return attributed
    }

    private func calculateAttributionConfidence(touchpoints: [Touchpoint]) -> Double {
        guard !touchpoints.isEmpty else { return 0.0 }

        var confidence = 0.5  // Base confidence

        // More touchpoints = higher confidence
        confidence += min(Double(touchpoints.count) * 0.1, 0.3)

        // Has referral code = higher confidence
        if touchpoints.contains(where: { $0.referralCode != nil }) {
            confidence += 0.15
        }

        // Recent touchpoints = higher confidence
        let mostRecent = touchpoints.max(by: { $0.timestamp < $1.timestamp })
        if let recent = mostRecent {
            let hoursSince = Date().timeIntervalSince(recent.timestamp) / 3600
            if hoursSince < 24 {
                confidence += 0.1
            }
        }

        return min(confidence, 1.0)
    }

    // MARK: - Storage & Queries

    private func storeTouchpoint(_ touchpoint: Touchpoint) async {
        let data: [String: Any] = [
            "id": touchpoint.id,
            "type": touchpoint.type.rawValue,
            "source": touchpoint.source,
            "medium": touchpoint.medium,
            "campaign": touchpoint.campaign ?? "",
            "referralCode": touchpoint.referralCode ?? "",
            "timestamp": Timestamp(date: touchpoint.timestamp),
            "platform": touchpoint.platform.rawValue,
            "deviceId": touchpoint.deviceId ?? "",
            "sessionId": touchpoint.sessionId,
            "metadata": touchpoint.metadata
        ]

        do {
            try await db.collection("attributionTouchpoints").document(touchpoint.id).setData(data)
        } catch {
            Logger.shared.error("Failed to store touchpoint", category: .referral, error: error)
        }
    }

    private func fetchTouchpoints(deviceId: String?, since: Date) async throws -> [Touchpoint] {
        guard let deviceId = deviceId else { return [] }

        let snapshot = try await db.collection("attributionTouchpoints")
            .whereField("deviceId", isEqualTo: deviceId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: since))
            .order(by: "timestamp")
            .limit(to: 100)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Touchpoint? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let typeStr = data["type"] as? String,
                  let type = TouchpointType(rawValue: typeStr),
                  let source = data["source"] as? String,
                  let medium = data["medium"] as? String,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                  let platformStr = data["platform"] as? String,
                  let platform = Platform(rawValue: platformStr),
                  let sessionId = data["sessionId"] as? String else {
                return nil
            }

            return Touchpoint(
                id: id,
                type: type,
                source: source,
                medium: medium,
                campaign: data["campaign"] as? String,
                referralCode: data["referralCode"] as? String,
                timestamp: timestamp,
                platform: platform,
                deviceId: data["deviceId"] as? String,
                sessionId: sessionId,
                metadata: data["metadata"] as? [String: String] ?? [:]
            )
        }
    }

    private func storeAttributionResult(_ result: AttributionResult) async throws {
        let touchpointData = result.touchpoints.map { tp -> [String: Any] in
            return [
                "id": tp.id,
                "type": tp.type.rawValue,
                "source": tp.source,
                "medium": tp.medium,
                "referralCode": tp.referralCode ?? "",
                "timestamp": Timestamp(date: tp.timestamp),
                "attributionCredit": tp.attributionCredit
            ]
        }

        let data: [String: Any] = [
            "resultId": result.resultId,
            "userId": result.userId,
            "conversionType": result.conversionType.rawValue,
            "touchpoints": touchpointData,
            "attributedReferralCode": result.attributedReferralCode ?? "",
            "attributedReferrerId": result.attributedReferrerId ?? "",
            "attributionModel": result.attributionModel.rawValue,
            "attributedAt": Timestamp(date: result.attributedAt),
            "confidence": result.confidence,
            "isDeferredDeepLink": result.isDeferredDeepLink,
            "revenue": result.revenue ?? 0.0,
            "metadata": result.metadata
        ]

        try await db.collection("attributionResults").document(result.resultId).setData(data)
    }

    private func lookupReferrerId(code: String) async throws -> String? {
        // First check dedicated referralCodes collection
        let codeDoc = try await db.collection("referralCodes").document(code).getDocument()
        if let data = codeDoc.data(), codeDoc.exists {
            return data["userId"] as? String
        }

        // Fallback to users collection
        let userSnapshot = try await db.collection("users")
            .whereField("referralStats.referralCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        return userSnapshot.documents.first?.documentID
    }

    // MARK: - Local Storage for Pending Deep Links

    private let pendingDeepLinkKey = "pendingDeferredDeepLink"

    private func savePendingDeepLink(_ link: DeferredDeepLink) {
        if let data = try? JSONEncoder().encode(link) {
            UserDefaults.standard.set(data, forKey: pendingDeepLinkKey)
        }
    }

    private func loadPendingDeepLink() {
        if let data = UserDefaults.standard.data(forKey: pendingDeepLinkKey),
           let link = try? JSONDecoder().decode(DeferredDeepLink.self, from: data) {
            // Check if still valid
            if link.expiresAt > Date() && !link.claimed {
                pendingDeferredLink = link
            } else {
                clearPendingDeepLink()
            }
        }
    }

    private func clearPendingDeepLink() {
        UserDefaults.standard.removeObject(forKey: pendingDeepLinkKey)
    }

    // MARK: - Analytics Queries

    /// Gets attribution results for analytics
    func getAttributionResults(
        startDate: Date,
        endDate: Date,
        conversionType: ConversionType? = nil
    ) async throws -> [AttributionResult] {
        var query = db.collection("attributionResults")
            .whereField("attributedAt", isGreaterThan: Timestamp(date: startDate))
            .whereField("attributedAt", isLessThan: Timestamp(date: endDate))

        if let type = conversionType {
            query = query.whereField("conversionType", isEqualTo: type.rawValue)
        }

        let snapshot = try await query.limit(to: 500).getDocuments()

        return snapshot.documents.compactMap { doc -> AttributionResult? in
            let data = doc.data()
            guard let resultId = data["resultId"] as? String,
                  let userId = data["userId"] as? String,
                  let typeStr = data["conversionType"] as? String,
                  let conversionType = ConversionType(rawValue: typeStr),
                  let modelStr = data["attributionModel"] as? String,
                  let model = AttributionModel(rawValue: modelStr),
                  let attributedAt = (data["attributedAt"] as? Timestamp)?.dateValue(),
                  let confidence = data["confidence"] as? Double else {
                return nil
            }

            return AttributionResult(
                resultId: resultId,
                userId: userId,
                conversionType: conversionType,
                touchpoints: [],
                attributedReferralCode: data["attributedReferralCode"] as? String,
                attributedReferrerId: data["attributedReferrerId"] as? String,
                attributionModel: model,
                attributedAt: attributedAt,
                confidence: confidence,
                isDeferredDeepLink: data["isDeferredDeepLink"] as? Bool ?? false,
                revenue: data["revenue"] as? Double,
                metadata: data["metadata"] as? [String: String] ?? [:]
            )
        }
    }

    /// Gets top referral sources
    func getTopSources(limit: Int = 10) async throws -> [(source: String, count: Int, revenue: Double)] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let snapshot = try await db.collection("attributionTouchpoints")
            .whereField("timestamp", isGreaterThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()

        var sourceStats: [String: (count: Int, revenue: Double)] = [:]

        for doc in snapshot.documents {
            let data = doc.data()
            let source = data["source"] as? String ?? "unknown"

            var stats = sourceStats[source] ?? (count: 0, revenue: 0.0)
            stats.count += 1
            sourceStats[source] = stats
        }

        return sourceStats
            .map { (source: $0.key, count: $0.value.count, revenue: $0.value.revenue) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - App Tracking Transparency

extension ReferralAttribution {
    /// Requests app tracking authorization
    func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        return await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Gets current tracking authorization status
    var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }

    /// Whether we can use IDFA for attribution
    var canUseIDFA: Bool {
        return trackingAuthorizationStatus == .authorized
    }

    /// Gets IDFA if authorized
    var advertisingIdentifier: String? {
        guard canUseIDFA else { return nil }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return idfa == "00000000-0000-0000-0000-000000000000" ? nil : idfa
    }
}
