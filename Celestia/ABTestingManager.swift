//
//  ABTestingManager.swift
//  Celestia
//
//  A/B Testing framework using existing feature flags
//  Enables experimentation and data-driven decision making
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics

@MainActor
class ABTestingManager: ObservableObject {
    static let shared = ABTestingManager()

    @Published var activeExperiments: [Experiment] = []
    @Published var userVariants: [String: String] = [:] // experimentId -> variantId

    private let db = Firestore.firestore()

    // FIXED: Use lazy to avoid circular dependency crash during singleton initialization
    // ABTestingManager <-> AnalyticsServiceEnhanced were causing deadlock
    private lazy var analyticsService = AnalyticsServiceEnhanced.shared

    private init() {
        loadActiveExperiments()
    }

    // MARK: - Experiment Management

    /// Loads all active experiments from Firestore
    func loadActiveExperiments() {
        Task {
            do {
                let snapshot = try await db.collection("experiments")
                    .whereField("status", isEqualTo: "active")
                    .getDocuments()

                activeExperiments = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Experiment.self)
                }

                Logger.shared.info("Loaded \(activeExperiments.count) active experiments", category: .general)

                // Assign user to experiments
                await assignUserToExperiments()

            } catch {
                Logger.shared.error("Failed to load experiments", category: .general, error: error)
            }
        }
    }

    /// Assigns current user to active experiments
    private func assignUserToExperiments() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        for experiment in activeExperiments {
            // Check if user is already assigned
            if userVariants[experiment.id] != nil {
                continue
            }

            // Check if user matches targeting criteria
            if await shouldIncludeUser(in: experiment) {
                // SAFETY: Handle experiments with no variants gracefully
                guard let variant = selectVariant(for: experiment, userId: userId) else {
                    Logger.shared.warning("Skipping experiment '\(experiment.name)' - no variants available", category: .general)
                    continue
                }

                userVariants[experiment.id] = variant.id

                // Save assignment to Firestore
                _ = try? await saveAssignment(experimentId: experiment.id, userId: userId, variantId: variant.id)

                // Track analytics
                analyticsService.trackEvent(.experimentVariantAssigned, properties: [
                    "experimentId": experiment.id,
                    "experimentName": experiment.name,
                    "variantId": variant.id,
                    "variantName": variant.name
                ])

                Logger.shared.info("User assigned to experiment: \(experiment.name), variant: \(variant.name)", category: .general)
            }
        }
    }

    /// Selects a variant for a user based on traffic allocation
    private func selectVariant(for experiment: Experiment, userId: String) -> Variant? {
        // SAFETY: Handle edge case of empty variants array
        guard !experiment.variants.isEmpty else {
            Logger.shared.error("Experiment '\(experiment.name)' has no variants", category: .general)
            CrashlyticsManager.shared.recordError(
                NSError(domain: "ABTestingManager", code: -1, userInfo: [
                    "message": "Empty variants array",
                    "experimentId": experiment.id,
                    "experimentName": experiment.name
                ])
            )
            return nil
        }

        // Use consistent hashing to ensure same user always gets same variant
        let hash = abs(userId.hashValue) % 100
        var cumulativeTraffic = 0

        for variant in experiment.variants {
            cumulativeTraffic += variant.trafficAllocation
            if hash < cumulativeTraffic {
                return variant
            }
        }

        // Fallback to control, or first variant if no control exists
        return experiment.variants.first { $0.isControl } ?? experiment.variants.first
    }

    /// Checks if user should be included in experiment based on targeting
    private func shouldIncludeUser(in experiment: Experiment) async -> Bool {
        guard let user = AuthService.shared.currentUser else { return false }

        // Check if user meets targeting criteria
        if let targeting = experiment.targeting {
            // Premium status
            if let requirePremium = targeting.premiumOnly, requirePremium && !user.isPremium {
                return false
            }

            // Platform
            if let platforms = targeting.platforms, !platforms.contains("ios") {
                return false
            }

            // User age
            if let minAge = targeting.minAge, user.age < minAge {
                return false
            }

            if let maxAge = targeting.maxAge, user.age > maxAge {
                return false
            }

            // Account age
            let accountAgeInDays = Calendar.current.dateComponents([.day], from: user.timestamp, to: Date()).day ?? 0
            if let minAccountAge = targeting.minAccountAgeDays, accountAgeInDays < minAccountAge {
                return false
            }

            // Location
            if let countries = targeting.countries, !countries.isEmpty, !countries.contains(user.country) {
                return false
            }
        }

        return true
    }

    private func saveAssignment(experimentId: String, userId: String, variantId: String) async throws {
        try await db.collection("experiment_assignments").addDocument(data: [
            "experimentId": experimentId,
            "userId": userId,
            "variantId": variantId,
            "assignedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Variant Retrieval

    /// Gets the variant for a specific experiment
    func getCurrentVariant(for experimentId: String) -> String {
        return userVariants[experimentId] ?? "control"
    }

    /// Checks if user is in a specific variant
    func isInVariant(_ variantId: String, forExperiment experimentId: String) -> Bool {
        return userVariants[experimentId] == variantId
    }

    /// Gets the value for a feature flag based on current experiments
    func getFeatureValue<T>(for flagKey: String, defaultValue: T) -> T {
        // Check if any active experiment overrides this feature
        for experiment in activeExperiments {
            guard let variantId = userVariants[experiment.id],
                  let variant = experiment.variants.first(where: { $0.id == variantId }),
                  let overrideValue = variant.featureOverrides?[flagKey] as? T else {
                continue
            }

            return overrideValue
        }

        // Fall back to default value
        return defaultValue
    }

    // MARK: - Event Tracking

    /// Tracks a conversion event for experiments
    func trackConversion(event: String, properties: [String: Any] = [:]) {
        var enhancedProperties = properties

        // Add current experiment variants to properties
        for (experimentId, variantId) in userVariants {
            enhancedProperties["experiment_\(experimentId)"] = variantId
        }

        // MEMORY FIX: Only call analytics service if there are active experiments
        // Reduces unnecessary analytics calls and memory allocations
        if !userVariants.isEmpty {
            analyticsService.trackEvent(.init(rawValue: event) ?? .featureFlagChanged, properties: enhancedProperties)
        }

        // Save conversion to Firestore for experiment analysis
        // Note: AnalyticsServiceEnhanced will batch this write
        Task {
            guard let userId = AuthService.shared.currentUser?.id else { return }

            _ = try? await db.collection("experiment_conversions").addDocument(data: [
                "userId": userId,
                "event": event,
                "properties": enhancedProperties,
                "experiments": userVariants,
                "timestamp": FieldValue.serverTimestamp()
            ])
        }
    }

    /// Records a conversion for a specific experiment
    func recordConversion(experimentId: String) {
        trackConversion(event: "experiment_conversion_\(experimentId)", properties: [
            "experimentId": experimentId,
            "variantId": userVariants[experimentId] ?? "unknown"
        ])

        Logger.shared.info("Conversion recorded for experiment: \(experimentId)", category: .general)
    }

    /// Records a custom metric for an experiment
    func recordMetric(experimentId: String, metricName: String, value: Double) {
        Task {
            guard let userId = AuthService.shared.currentUser?.id else { return }

            _ = try? await db.collection("experiment_metrics").addDocument(data: [
                "experimentId": experimentId,
                "userId": userId,
                "variantId": userVariants[experimentId] ?? "unknown",
                "metricName": metricName,
                "value": value,
                "timestamp": FieldValue.serverTimestamp()
            ])
        }

        // MEMORY FIX: Only track analytics if user is actually in this experiment
        // Reduces unnecessary analytics events
        if userVariants[experimentId] != nil {
            analyticsService.trackEvent(.featureFlagChanged, properties: [
                "experimentId": experimentId,
                "metricName": metricName,
                "value": value
            ])
        }
    }

    // MARK: - Experiment Creation (Admin)

    /// Creates a new A/B test experiment (admin only)
    func createExperiment(
        name: String,
        description: String,
        variants: [Variant],
        targeting: Targeting? = nil
    ) async throws -> Experiment {
        let experiment = Experiment(
            id: UUID().uuidString,
            name: name,
            description: description,
            variants: variants,
            status: .draft,
            createdAt: Date(),
            targeting: targeting
        )

        try await db.collection("experiments").document(experiment.id).setData(from: experiment)

        Logger.shared.info("Experiment created: \(name)", category: .general)

        return experiment
    }

    /// Starts an experiment (admin only)
    func startExperiment(experimentId: String) async throws {
        try await db.collection("experiments").document(experimentId).updateData([
            "status": "active",
            "startedAt": FieldValue.serverTimestamp()
        ])

        Logger.shared.info("Experiment started: \(experimentId)", category: .general)

        // Reload experiments
        loadActiveExperiments()
    }

    /// Stops an experiment (admin only)
    func stopExperiment(experimentId: String, winner: String? = nil) async throws {
        var data: [String: Any] = [
            "status": "completed",
            "endedAt": FieldValue.serverTimestamp()
        ]

        if let winner = winner {
            data["winner"] = winner
        }

        try await db.collection("experiments").document(experimentId).updateData(data)

        Logger.shared.info("Experiment stopped: \(experimentId), winner: \(winner ?? "none")", category: .general)

        // Reload experiments
        loadActiveExperiments()
    }

    // MARK: - Results Analysis (Admin)

    /// Gets experiment results for analysis
    func getExperimentResults(experimentId: String) async throws -> ABTestExperimentResults {
        // Get all assignments
        let assignmentsSnapshot = try await db.collection("experiment_assignments")
            .whereField("experimentId", isEqualTo: experimentId)
            .getDocuments()

        var variantAssignments: [String: Int] = [:]
        var variantConversions: [String: Int] = [:]

        // Count assignments per variant
        for doc in assignmentsSnapshot.documents {
            let variantId = doc.data()["variantId"] as? String ?? ""
            variantAssignments[variantId, default: 0] += 1
        }

        // Get conversions
        let conversionsSnapshot = try await db.collection("experiment_conversions")
            .getDocuments()

        for doc in conversionsSnapshot.documents {
            let experiments = doc.data()["experiments"] as? [String: String] ?? [:]
            if let variantId = experiments[experimentId] {
                variantConversions[variantId, default: 0] += 1
            }
        }

        // Calculate conversion rates
        var variantResults: [VariantResult] = []

        for (variantId, assignments) in variantAssignments {
            let conversions = variantConversions[variantId] ?? 0
            let conversionRate = assignments > 0 ? Double(conversions) / Double(assignments) * 100 : 0

            variantResults.append(VariantResult(
                variantId: variantId,
                assignments: assignments,
                conversions: conversions,
                conversionRate: conversionRate
            ))
        }

        // Determine winner (highest conversion rate)
        let winner = variantResults.max(by: { $0.conversionRate < $1.conversionRate })

        return ABTestExperimentResults(
            experimentId: experimentId,
            totalAssignments: assignmentsSnapshot.documents.count,
            variantResults: variantResults,
            winner: winner,
            generatedAt: Date()
        )
    }
}

// MARK: - Models

struct Experiment: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let variants: [Variant]
    var status: ExperimentStatus
    let createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var winner: String?
    let targeting: Targeting?

    enum ExperimentStatus: String, Codable {
        case draft
        case active
        case paused
        case completed
    }
}

struct Variant: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let isControl: Bool
    let trafficAllocation: Int // Percentage (0-100)
    let featureOverrides: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, isControl, trafficAllocation
    }

    init(id: String, name: String, description: String, isControl: Bool, trafficAllocation: Int, featureOverrides: [String: Any]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isControl = isControl
        self.trafficAllocation = trafficAllocation
        self.featureOverrides = featureOverrides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isControl = try container.decode(Bool.self, forKey: .isControl)
        trafficAllocation = try container.decode(Int.self, forKey: .trafficAllocation)
        featureOverrides = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(isControl, forKey: .isControl)
        try container.encode(trafficAllocation, forKey: .trafficAllocation)
    }
}

struct Targeting: Codable {
    let premiumOnly: Bool?
    let platforms: [String]? // ["ios", "android", "web"]
    let minAge: Int?
    let maxAge: Int?
    let minAccountAgeDays: Int?
    let countries: [String]?
}

struct ABTestExperimentResults {
    let experimentId: String
    let totalAssignments: Int
    let variantResults: [VariantResult]
    let winner: VariantResult?
    let generatedAt: Date
}

struct VariantResult {
    let variantId: String
    let assignments: Int
    let conversions: Int
    let conversionRate: Double
}

// MARK: - Onboarding Helpers

extension ABTestingManager {
    /// Checks if user should see onboarding tutorial
    func shouldShowTutorial() -> Bool {
        let variant = getCurrentVariant(for: "onboarding_tutorial")
        return variant == "with_tutorial" || variant == "control"
    }

    /// Checks if user should see profile quality tips during onboarding
    func shouldShowTips() -> Bool {
        let variant = getCurrentVariant(for: "onboarding_tips")
        return variant == "with_tips" || variant == "control"
    }

    /// Gets the disclosure strategy for onboarding (progressive vs all-at-once)
    func getDisclosureStrategy() -> String {
        let variant = getCurrentVariant(for: "onboarding_disclosure")
        return variant == "progressive" || variant == "control" ? "progressive" : "all_at_once"
    }

    /// Determines if user should be offered a completion reward
    func shouldOfferCompletionReward() -> (offered: Bool, type: String?, amount: Int?) {
        let variant = getCurrentVariant(for: "onboarding_incentive")

        switch variant {
        case "super_likes":
            return (true, "super_likes", 3)
        case "boosts":
            return (true, "boosts", 1)
        case "premium_trial":
            return (true, "premium_trial", 7)
        case "control", "no_incentive":
            return (false, nil, nil)
        default:
            return (false, nil, nil)
        }
    }

    /// Creates default onboarding experiments
    func setupDefaultOnboardingExperiments() async {
        // Experiment 1: Onboarding Tutorial
        _ = try? await createExperiment(
            name: "Onboarding Tutorial Test",
            description: "Test if showing interactive tutorials improves activation",
            variants: [
                Variant(
                    id: "control",
                    name: "With Tutorial",
                    description: "Show interactive tutorials during onboarding",
                    isControl: true,
                    trafficAllocation: 50,
                    featureOverrides: ["show_tutorial": true]
                ),
                Variant(
                    id: "no_tutorial",
                    name: "No Tutorial",
                    description: "Skip tutorials, go straight to app",
                    isControl: false,
                    trafficAllocation: 50,
                    featureOverrides: ["show_tutorial": false]
                )
            ]
        )

        // Experiment 2: Profile Quality Tips
        _ = try? await createExperiment(
            name: "Profile Quality Tips",
            description: "Test if showing real-time profile tips improves profile completion",
            variants: [
                Variant(
                    id: "control",
                    name: "With Tips",
                    description: "Show profile quality tips in real-time",
                    isControl: true,
                    trafficAllocation: 50,
                    featureOverrides: ["show_tips": true]
                ),
                Variant(
                    id: "no_tips",
                    name: "No Tips",
                    description: "No profile tips shown",
                    isControl: false,
                    trafficAllocation: 50,
                    featureOverrides: ["show_tips": false]
                )
            ]
        )

        // Experiment 3: Progressive Disclosure
        _ = try? await createExperiment(
            name: "Progressive Disclosure",
            description: "Test if progressive disclosure reduces onboarding abandonment",
            variants: [
                Variant(
                    id: "control",
                    name: "Progressive",
                    description: "Show features progressively",
                    isControl: true,
                    trafficAllocation: 50,
                    featureOverrides: ["disclosure": "progressive"]
                ),
                Variant(
                    id: "all_at_once",
                    name: "All at Once",
                    description: "Show all features upfront",
                    isControl: false,
                    trafficAllocation: 50,
                    featureOverrides: ["disclosure": "all_at_once"]
                )
            ]
        )

        // Experiment 4: Completion Incentives
        _ = try? await createExperiment(
            name: "Completion Incentives",
            description: "Test which incentive increases profile completion rate",
            variants: [
                Variant(
                    id: "control",
                    name: "No Incentive",
                    description: "No completion reward offered",
                    isControl: true,
                    trafficAllocation: 25,
                    featureOverrides: ["incentive": "none"]
                ),
                Variant(
                    id: "super_likes",
                    name: "3 Free Super Likes",
                    description: "Offer 3 free super likes for profile completion",
                    isControl: false,
                    trafficAllocation: 25,
                    featureOverrides: ["incentive": "super_likes", "amount": 3]
                ),
                Variant(
                    id: "boosts",
                    name: "1 Free Boost",
                    description: "Offer 1 free boost for profile completion",
                    isControl: false,
                    trafficAllocation: 25,
                    featureOverrides: ["incentive": "boosts", "amount": 1]
                ),
                Variant(
                    id: "premium_trial",
                    name: "7-Day Premium Trial",
                    description: "Offer 7-day premium trial for profile completion",
                    isControl: false,
                    trafficAllocation: 25,
                    featureOverrides: ["incentive": "premium_trial", "amount": 7]
                )
            ]
        )

        Logger.shared.info("Default onboarding experiments created", category: .general)
    }
}

// MARK: - Example Experiments

extension ABTestingManager {
    /// Creates example experiments for testing
    func createExampleExperiments() async {
        // Experiment 1: Swipe Button Colors
        let colorExperiment = Experiment(
            id: "swipe_button_colors",
            name: "Swipe Button Colors",
            description: "Test different color schemes for swipe buttons",
            variants: [
                Variant(
                    id: "control",
                    name: "Control",
                    description: "Current purple/pink gradient",
                    isControl: true,
                    trafficAllocation: 50,
                    featureOverrides: [:]
                ),
                Variant(
                    id: "variant_a",
                    name: "Blue Gradient",
                    description: "Blue gradient buttons",
                    isControl: false,
                    trafficAllocation: 50,
                    featureOverrides: ["swipe_button_color": "blue"]
                )
            ],
            status: .draft,
            createdAt: Date(),
            targeting: nil
        )

        _ = try? await createExperiment(
            name: colorExperiment.name,
            description: colorExperiment.description,
            variants: colorExperiment.variants
        )

        // Experiment 2: Match Notification Timing
        let notificationExperiment = Experiment(
            id: "notification_timing",
            name: "Match Notification Timing",
            description: "Test immediate vs delayed match notifications",
            variants: [
                Variant(
                    id: "control",
                    name: "Immediate",
                    description: "Send notification immediately",
                    isControl: true,
                    trafficAllocation: 50,
                    featureOverrides: ["notification_delay": 0]
                ),
                Variant(
                    id: "variant_a",
                    name: "Delayed 5min",
                    description: "Delay notification by 5 minutes",
                    isControl: false,
                    trafficAllocation: 50,
                    featureOverrides: ["notification_delay": 300]
                )
            ],
            status: .draft,
            createdAt: Date(),
            targeting: Targeting(
                premiumOnly: nil,
                platforms: ["ios"],
                minAge: nil,
                maxAge: nil,
                minAccountAgeDays: 7,
                countries: nil
            )
        )

        _ = try? await createExperiment(
            name: notificationExperiment.name,
            description: notificationExperiment.description,
            variants: notificationExperiment.variants,
            targeting: notificationExperiment.targeting
        )
    }
}
