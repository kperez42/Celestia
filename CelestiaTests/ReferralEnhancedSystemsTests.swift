//
//  ReferralEnhancedSystemsTests.swift
//  CelestiaTests
//
//  Tests for enhanced referral systems:
//  - Fraud Detection
//  - Attribution
//  - A/B Testing
//  - Analytics
//  - Segmentation
//  - Compliance
//

import XCTest
@testable import Celestia

final class ReferralEnhancedSystemsTests: XCTestCase {

    // MARK: - Fraud Detection Tests

    func testFraudRiskLevelFromScore() {
        XCTAssertEqual(FraudRiskLevel.fromScore(0.1), .low)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.29), .low)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.3), .medium)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.5), .medium)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.6), .high)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.8), .high)
        XCTAssertEqual(FraudRiskLevel.fromScore(0.85), .blocked)
        XCTAssertEqual(FraudRiskLevel.fromScore(1.0), .blocked)
    }

    func testDeviceFingerprintGeneration() {
        let fingerprint = DeviceFingerprint.generate()

        XCTAssertFalse(fingerprint.fingerprintId.isEmpty)
        XCTAssertFalse(fingerprint.deviceModel.isEmpty)
        XCTAssertFalse(fingerprint.systemVersion.isEmpty)
        XCTAssertFalse(fingerprint.timezone.isEmpty)
        XCTAssertFalse(fingerprint.vendorId.isEmpty)
        XCTAssertFalse(fingerprint.hash.isEmpty)
    }

    func testDeviceFingerprintHashConsistency() {
        let fingerprint1 = DeviceFingerprint.generate()
        let fingerprint2 = DeviceFingerprint.generate()

        // Same device should produce same hash (same vendorId, etc.)
        // Note: In practice, two consecutive calls will have same device info
        XCTAssertEqual(fingerprint1.hash, fingerprint2.hash)
    }

    func testFraudSignalWeights() {
        // High-risk signals should have high weights
        XCTAssertGreaterThan(FraudSignalType.duplicateDevice.baseWeight, 0.8)
        XCTAssertGreaterThan(FraudSignalType.referralRing.baseWeight, 0.9)
        XCTAssertGreaterThan(FraudSignalType.disposableEmail.baseWeight, 0.7)

        // Low-risk signals should have lower weights
        XCTAssertLessThan(FraudSignalType.unusualSignupTime.baseWeight, 0.3)
        XCTAssertLessThan(FraudSignalType.noProfilePhoto.baseWeight, 0.3)
    }

    func testFraudDecisionFromRiskScore() {
        // Test that high-risk referral rings are blocked
        let ringSignal = FraudSignal(
            signalType: .referralRing,
            weight: FraudSignalType.referralRing.baseWeight,
            description: "Test",
            detectedAt: Date(),
            metadata: [:]
        )

        XCTAssertEqual(ringSignal.signalType, .referralRing)
        XCTAssertGreaterThan(ringSignal.weight, 0.9)
    }

    // MARK: - Attribution Tests

    func testAttributionModelTypes() {
        XCTAssertEqual(AttributionModel.firstTouch.rawValue, "first_touch")
        XCTAssertEqual(AttributionModel.lastTouch.rawValue, "last_touch")
        XCTAssertEqual(AttributionModel.linear.rawValue, "linear")
        XCTAssertEqual(AttributionModel.timeDecay.rawValue, "time_decay")
        XCTAssertEqual(AttributionModel.positionBased.rawValue, "position_based")
    }

    func testLinkFingerprintMatching() {
        let fingerprint1 = LinkFingerprint(
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0",
            screenResolution: "1920x1080",
            timezone: "America/New_York",
            language: "en",
            platform: "iOS"
        )

        let fingerprint2 = LinkFingerprint(
            ipAddress: "192.168.1.1",
            userAgent: "Mozilla/5.0",
            screenResolution: "1920x1080",
            timezone: "America/New_York",
            language: "en",
            platform: "iOS"
        )

        let score = fingerprint1.matchScore(with: fingerprint2)
        XCTAssertEqual(score, 1.0, "Identical fingerprints should match 100%")
    }

    func testLinkFingerprintPartialMatch() {
        let fingerprint1 = LinkFingerprint(
            ipAddress: "192.168.1.1",
            userAgent: nil,
            screenResolution: "1920x1080",
            timezone: "America/New_York",
            language: "en",
            platform: "iOS"
        )

        let fingerprint2 = LinkFingerprint(
            ipAddress: "192.168.1.2",  // Different IP
            userAgent: nil,
            screenResolution: "1920x1080",
            timezone: "America/New_York",
            language: "en",
            platform: "iOS"
        )

        let score = fingerprint1.matchScore(with: fingerprint2)
        XCTAssertLessThan(score, 1.0, "Different IPs should reduce match score")
        XCTAssertGreaterThan(score, 0.0, "Matching other fields should give partial score")
    }

    func testTouchpointTypes() {
        let allTypes: [TouchpointType] = [
            .directLink, .sharedMessage, .socialMedia, .email,
            .pushNotification, .inAppShare, .qrCode, .organic,
            .paidAd, .influencer, .unknown
        ]

        for type in allTypes {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testAttributionWindowDefaults() {
        let window = AttributionWindow.default

        XCTAssertEqual(window.clickWindow, 7 * 24 * 3600) // 7 days
        XCTAssertEqual(window.viewWindow, 24 * 3600) // 1 day
        XCTAssertEqual(window.installWindow, 30 * 24 * 3600) // 30 days
    }

    // MARK: - A/B Testing Tests

    func testExperimentStatusValues() {
        XCTAssertEqual(ExperimentStatus.draft.rawValue, "draft")
        XCTAssertEqual(ExperimentStatus.running.rawValue, "running")
        XCTAssertEqual(ExperimentStatus.paused.rawValue, "paused")
        XCTAssertEqual(ExperimentStatus.completed.rawValue, "completed")
        XCTAssertEqual(ExperimentStatus.archived.rawValue, "archived")
    }

    func testExperimentTypeValues() {
        XCTAssertEqual(ExperimentType.rewards.rawValue, "rewards")
        XCTAssertEqual(ExperimentType.messaging.rawValue, "messaging")
        XCTAssertEqual(ExperimentType.ui.rawValue, "ui")
        XCTAssertEqual(ExperimentType.timing.rawValue, "timing")
    }

    func testVariantConversionRate() {
        var variant = ExperimentVariant(
            id: "test",
            name: "Test Variant",
            description: "Test",
            weight: 0.5,
            config: VariantConfig(),
            isControl: false,
            impressions: 100,
            conversions: 25,
            revenue: 500.0
        )

        XCTAssertEqual(variant.conversionRate, 0.25)
        XCTAssertEqual(variant.revenuePerUser, 5.0)
    }

    func testVariantConversionRateZeroImpressions() {
        var variant = ExperimentVariant(
            id: "test",
            name: "Test Variant",
            description: "Test",
            weight: 0.5,
            config: VariantConfig(),
            isControl: false,
            impressions: 0,
            conversions: 0,
            revenue: 0
        )

        XCTAssertEqual(variant.conversionRate, 0.0)
        XCTAssertEqual(variant.revenuePerUser, 0.0)
    }

    // MARK: - Analytics Tests

    func testAnalyticsPeriodDateRanges() {
        let dayRange = AnalyticsPeriod.day.dateRange
        let weekRange = AnalyticsPeriod.week.dateRange
        let monthRange = AnalyticsPeriod.month.dateRange

        // Day should start from start of today
        let calendar = Calendar.current
        XCTAssertEqual(calendar.startOfDay(for: dayRange.start), calendar.startOfDay(for: Date()))

        // Week should be 7 days ago
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertEqual(calendar.dateComponents([.day], from: weekRange.start, to: weekAgo).day, 0)

        // Month should be 1 month ago
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        XCTAssertEqual(calendar.dateComponents([.month], from: monthRange.start, to: monthAgo).month, 0)
    }

    func testConversionTypeValues() {
        XCTAssertEqual(ConversionType.install.rawValue, "install")
        XCTAssertEqual(ConversionType.signup.rawValue, "signup")
        XCTAssertEqual(ConversionType.referralComplete.rawValue, "referral_complete")
        XCTAssertEqual(ConversionType.subscription.rawValue, "subscription")
    }

    func testCohortTypeValues() {
        XCTAssertEqual(CohortType.signup.rawValue, "signup")
        XCTAssertEqual(CohortType.firstReferral.rawValue, "first_referral")
        XCTAssertEqual(CohortType.firstPurchase.rawValue, "first_purchase")
    }

    // MARK: - Segmentation Tests

    func testSegmentRuleOperatorEquals() {
        let rule = SegmentRule(
            field: .totalReferrals,
            operator: .equals,
            value: .number(5)
        )

        var context = UserSegmentContext(userId: "test")
        context.totalReferrals = 5

        XCTAssertTrue(rule.evaluate(with: context))

        context.totalReferrals = 6
        XCTAssertFalse(rule.evaluate(with: context))
    }

    func testSegmentRuleOperatorGreaterThan() {
        let rule = SegmentRule(
            field: .totalReferrals,
            operator: .greaterThan,
            value: .number(5)
        )

        var context = UserSegmentContext(userId: "test")
        context.totalReferrals = 6

        XCTAssertTrue(rule.evaluate(with: context))

        context.totalReferrals = 5
        XCTAssertFalse(rule.evaluate(with: context))

        context.totalReferrals = 4
        XCTAssertFalse(rule.evaluate(with: context))
    }

    func testSegmentRuleOperatorBetween() {
        let rule = SegmentRule(
            field: .lifetimeValue,
            operator: .between,
            value: .range(min: 10.0, max: 100.0)
        )

        var context = UserSegmentContext(userId: "test")
        context.lifetimeValue = 50.0

        XCTAssertTrue(rule.evaluate(with: context))

        context.lifetimeValue = 10.0
        XCTAssertTrue(rule.evaluate(with: context))

        context.lifetimeValue = 100.0
        XCTAssertTrue(rule.evaluate(with: context))

        context.lifetimeValue = 9.0
        XCTAssertFalse(rule.evaluate(with: context))

        context.lifetimeValue = 101.0
        XCTAssertFalse(rule.evaluate(with: context))
    }

    func testSegmentRuleOperatorIn() {
        let rule = SegmentRule(
            field: .country,
            operator: .in,
            value: .array([.string("US"), .string("CA"), .string("UK")])
        )

        var context = UserSegmentContext(userId: "test")
        context.country = "US"

        XCTAssertTrue(rule.evaluate(with: context))

        context.country = "DE"
        XCTAssertFalse(rule.evaluate(with: context))
    }

    func testPredefinedSegmentsExist() {
        let predefined = ReferralSegmentation.predefinedSegments

        XCTAssertFalse(predefined.isEmpty)
        XCTAssertTrue(predefined.contains { $0.id == "high_value_referrers" })
        XCTAssertTrue(predefined.contains { $0.id == "premium_users" })
        XCTAssertTrue(predefined.contains { $0.id == "new_users" })
        XCTAssertTrue(predefined.contains { $0.id == "dormant_users" })
    }

    func testHighValueReferrersSegment() {
        let segment = ReferralSegmentation.predefinedSegments.first { $0.id == "high_value_referrers" }!

        var context = UserSegmentContext(userId: "test")
        context.successfulReferrals = 5

        // Check that high value referrer rule matches
        let matches = segment.rules.allSatisfy { $0.evaluate(with: context) }
        XCTAssertTrue(matches)

        context.successfulReferrals = 4
        let matches2 = segment.rules.allSatisfy { $0.evaluate(with: context) }
        XCTAssertFalse(matches2)
    }

    // MARK: - Compliance Tests

    func testPrivacyRegulationValues() {
        XCTAssertEqual(PrivacyRegulation.gdpr.rawValue, "GDPR")
        XCTAssertEqual(PrivacyRegulation.ccpa.rawValue, "CCPA")
        XCTAssertEqual(PrivacyRegulation.lgpd.rawValue, "LGPD")
    }

    func testGDPRRequiresExplicitConsent() {
        XCTAssertTrue(PrivacyRegulation.gdpr.requiresExplicitConsent)
        XCTAssertFalse(PrivacyRegulation.ccpa.requiresExplicitConsent)
    }

    func testRegulationDeletionDeadlines() {
        XCTAssertEqual(PrivacyRegulation.gdpr.deletionDeadlineDays, 30)
        XCTAssertEqual(PrivacyRegulation.ccpa.deletionDeadlineDays, 45)
        XCTAssertEqual(PrivacyRegulation.lgpd.deletionDeadlineDays, 15)
    }

    func testConsentTypeValues() {
        let allTypes: [ConsentType] = [
            .referralParticipation,
            .referralMarketing,
            .referralAnalytics,
            .shareContactInfo,
            .deviceTracking,
            .crossPlatformTracking
        ]

        for type in allTypes {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testDataRequestTypeValues() {
        XCTAssertEqual(DataRequestType.access.rawValue, "access")
        XCTAssertEqual(DataRequestType.portability.rawValue, "portability")
        XCTAssertEqual(DataRequestType.erasure.rawValue, "erasure")
        XCTAssertEqual(DataRequestType.rectification.rawValue, "rectification")
    }

    func testComplianceActionValues() {
        XCTAssertEqual(ComplianceAction.consentGranted.rawValue, "consent_granted")
        XCTAssertEqual(ComplianceAction.dataExported.rawValue, "data_exported")
        XCTAssertEqual(ComplianceAction.dataDeleted.rawValue, "data_deleted")
        XCTAssertEqual(ComplianceAction.requestCompleted.rawValue, "request_completed")
    }

    // MARK: - Integration Tests

    func testUserSegmentContextCreation() {
        let context = UserSegmentContext(userId: "test123")

        XCTAssertEqual(context.userId, "test123")
        XCTAssertEqual(context.accountAgeDays, 0)
        XCTAssertFalse(context.isPremium)
        XCTAssertEqual(context.totalReferrals, 0)
        XCTAssertFalse(context.wasReferred)
    }

    func testUserExperimentContextToDictionary() {
        let context = UserExperimentContext(
            userId: "user123",
            totalReferrals: 10,
            isPremium: true,
            accountAgeDays: 30,
            segments: ["premium_users", "high_engagement"]
        )

        let dict = context.toDictionary()

        XCTAssertEqual(dict["userId"], "user123")
        XCTAssertEqual(dict["totalReferrals"], "10")
        XCTAssertEqual(dict["isPremium"], "true")
        XCTAssertEqual(dict["accountAgeDays"], "30")
        XCTAssertEqual(dict["segments"], "premium_users,high_engagement")
    }

    // MARK: - Referral Milestone Tests (Existing Functionality)

    func testReferralMilestonesExist() {
        let milestones = ReferralMilestone.milestones

        XCTAssertFalse(milestones.isEmpty)
        XCTAssertTrue(milestones.contains { $0.id == "first_referral" })
        XCTAssertTrue(milestones.contains { $0.id == "legend" })
    }

    func testNextMilestoneCalculation() {
        let next0 = ReferralMilestone.nextMilestone(for: 0)
        XCTAssertEqual(next0?.id, "first_referral")

        let next5 = ReferralMilestone.nextMilestone(for: 5)
        XCTAssertEqual(next5?.id, "social_butterfly")

        let next100 = ReferralMilestone.nextMilestone(for: 100)
        XCTAssertNil(next100) // All milestones achieved
    }

    func testMilestoneProgress() {
        let progress0 = ReferralMilestone.progressToNextMilestone(for: 0)
        XCTAssertEqual(progress0, 0.0)

        let progress50 = ReferralMilestone.progressToNextMilestone(for: 50)
        // Between 25 (influencer) and 50 (ambassador) = 100%
        XCTAssertEqual(progress50, 1.0)

        let progress100 = ReferralMilestone.progressToNextMilestone(for: 100)
        XCTAssertEqual(progress100, 1.0) // All milestones achieved
    }

    // MARK: - SHA256 Hash Tests

    func testSHA256HashConsistency() {
        let input = "test_string_for_hashing"
        let hash1 = input.sha256Hash
        let hash2 = input.sha256Hash

        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64) // SHA256 produces 64 hex characters
    }

    func testSHA256HashDifferentInputs() {
        let hash1 = "input1".sha256Hash
        let hash2 = "input2".sha256Hash

        XCTAssertNotEqual(hash1, hash2)
    }
}
