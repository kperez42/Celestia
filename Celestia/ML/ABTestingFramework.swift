//
//  ABTestingFramework.swift
//  Celestia
//
//  Framework for A/B testing matching algorithm variants
//  Enables data-driven optimization of recommendation engine
//

import Foundation
import FirebaseFirestore

@MainActor
class ABTestingFramework: ObservableObject {
    static let shared = ABTestingFramework()

    @Published var currentExperiment: Experiment?
    @Published var assignedVariant: String?

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    private init() {
        // Load persisted variant assignment
        assignedVariant = userDefaults.string(forKey: "ab_test_variant")
    }

    // MARK: - Experiment Definition

    struct Experiment: Codable {
        let id: String
        let name: String
        let description: String
        let variants: [Variant]
        let startDate: Date
        let endDate: Date
        let isActive: Bool
        let targetMetric: String // e.g., "match_rate", "engagement", "session_length"

        struct Variant: Codable {
            let name: String
            let algorithmVariant: String // Maps to RecommendationEngine.AlgorithmVariant
            let trafficPercentage: Double // 0.0 to 1.0
        }
    }

    // MARK: - Variant Assignment

    /// Assign user to an experiment variant
    /// Uses consistent hashing to ensure stable assignments
    func assignVariant(userId: String, experimentId: String = "matching_algorithm_v1") async {
        do {
            // Check if user already has a variant assigned
            if let existing = assignedVariant {
                Logger.shared.info("User already assigned to variant: \(existing)", category: .matching)
                return
            }

            // Fetch experiment configuration
            let experimentDoc = try await db.collection("experiments")
                .document(experimentId)
                .getDocument()

            guard experimentDoc.exists,
                  let experimentData = experimentDoc.data(),
                  let experiment = try? JSONDecoder().decode(Experiment.self, from: JSONSerialization.data(withJSONObject: experimentData)) else {
                Logger.shared.warning("Experiment not found: \(experimentId)", category: .matching)
                // Default to standard variant
                await assignDefaultVariant(userId: userId)
                return
            }

            guard experiment.isActive else {
                Logger.shared.info("Experiment is not active: \(experimentId)", category: .matching)
                await assignDefaultVariant(userId: userId)
                return
            }

            // Use consistent hashing to assign variant
            let variant = selectVariantByHash(userId: userId, variants: experiment.variants)

            // Persist assignment
            assignedVariant = variant.name
            userDefaults.set(variant.name, forKey: "ab_test_variant")

            // Apply algorithm variant
            if let algorithmVariant = RecommendationEngine.AlgorithmVariant(rawValue: variant.algorithmVariant) {
                RecommendationEngine.shared.setAlgorithmVariant(algorithmVariant)
            }

            // Record assignment in Firebase
            try await recordVariantAssignment(
                userId: userId,
                experimentId: experimentId,
                variantName: variant.name
            )

            Logger.shared.info("User assigned to variant: \(variant.name) for experiment: \(experimentId)", category: .matching)

        } catch {
            Logger.shared.error("Error assigning variant", category: .matching, error: error)
            await assignDefaultVariant(userId: userId)
        }
    }

    /// Assign default (control) variant
    private func assignDefaultVariant(userId: String) async {
        assignedVariant = "control"
        userDefaults.set("control", forKey: "ab_test_variant")
        RecommendationEngine.shared.setAlgorithmVariant(.standard)

        Logger.shared.info("User assigned to default variant: control", category: .matching)
    }

    /// Use consistent hashing to select variant
    /// Ensures same user always gets same variant
    private func selectVariantByHash(userId: String, variants: [Experiment.Variant]) -> Experiment.Variant {
        // Generate hash from userId
        let hash = abs(userId.hashValue)
        let normalizedHash = Double(hash % 10000) / 10000.0 // 0.0 to 1.0

        // Select variant based on traffic allocation
        var cumulativePercentage = 0.0
        for variant in variants {
            cumulativePercentage += variant.trafficPercentage
            if normalizedHash < cumulativePercentage {
                return variant
            }
        }

        // Fallback to first variant (shouldn't happen if percentages sum to 1.0)
        return variants.first ?? Experiment.Variant(name: "control", algorithmVariant: "standard", trafficPercentage: 1.0)
    }

    /// Record variant assignment in Firestore
    private func recordVariantAssignment(userId: String, experimentId: String, variantName: String) async throws {
        let assignment: [String: Any] = [
            "userId": userId,
            "experimentId": experimentId,
            "variantName": variantName,
            "assignedAt": Timestamp(date: Date())
        ]

        try await db.collection("experiment_assignments")
            .document("\(experimentId)_\(userId)")
            .setData(assignment)

        // Track analytics event
        AnalyticsManager.shared.logEvent(.customEvent("ab_test_assigned"), parameters: [
            "experiment_id": experimentId,
            "variant": variantName,
            "user_id": userId
        ])
    }

    // MARK: - Metric Tracking

    /// Track experiment metric (e.g., match rate, engagement)
    func trackMetric(
        userId: String,
        experimentId: String,
        metricName: String,
        value: Double
    ) async {
        guard let variant = assignedVariant else {
            Logger.shared.warning("Cannot track metric: No variant assigned", category: .matching)
            return
        }

        do {
            let metric: [String: Any] = [
                "userId": userId,
                "experimentId": experimentId,
                "variantName": variant,
                "metricName": metricName,
                "value": value,
                "timestamp": Timestamp(date: Date())
            ]

            try await db.collection("experiment_metrics")
                .document()
                .setData(metric)

            // Track analytics event
            AnalyticsManager.shared.logEvent(.customEvent("ab_test_metric"), parameters: [
                "experiment_id": experimentId,
                "variant": variant,
                "metric_name": metricName,
                "value": value
            ])

            Logger.shared.debug("Tracked metric: \(metricName) = \(value) for variant: \(variant)", category: .matching)

        } catch {
            Logger.shared.error("Error tracking experiment metric", category: .matching, error: error)
        }
    }

    /// Track conversion event (e.g., match created, message sent)
    func trackConversion(
        userId: String,
        experimentId: String,
        conversionType: String
    ) async {
        await trackMetric(
            userId: userId,
            experimentId: experimentId,
            metricName: "conversion_\(conversionType)",
            value: 1.0
        )
    }

    // MARK: - Experiment Management

    /// Create a new experiment
    func createExperiment(
        id: String,
        name: String,
        description: String,
        variants: [Experiment.Variant],
        startDate: Date,
        endDate: Date,
        targetMetric: String
    ) async throws {
        let experiment = Experiment(
            id: id,
            name: name,
            description: description,
            variants: variants,
            startDate: startDate,
            endDate: endDate,
            isActive: true,
            targetMetric: targetMetric
        )

        let experimentData = try JSONEncoder().encode(experiment)
        let experimentDict = try JSONSerialization.jsonObject(with: experimentData) as! [String: Any]

        try await db.collection("experiments")
            .document(id)
            .setData(experimentDict)

        Logger.shared.info("Created experiment: \(name) (\(id))", category: .matching)
    }

    /// Get experiment results summary
    func getExperimentResults(experimentId: String) async throws -> ExperimentResults {
        let metricsSnapshot = try await db.collection("experiment_metrics")
            .whereField("experimentId", isEqualTo: experimentId)
            .getDocuments()

        var variantMetrics: [String: [Double]] = [:]

        for doc in metricsSnapshot.documents {
            let data = doc.data()
            guard let variant = data["variantName"] as? String,
                  let value = data["value"] as? Double else {
                continue
            }

            if variantMetrics[variant] == nil {
                variantMetrics[variant] = []
            }
            variantMetrics[variant]?.append(value)
        }

        // Calculate statistics for each variant
        var results = ExperimentResults(experimentId: experimentId)

        for (variant, values) in variantMetrics {
            let stats = VariantStatistics(
                variantName: variant,
                sampleSize: values.count,
                mean: values.reduce(0, +) / Double(values.count),
                median: values.sorted()[values.count / 2],
                min: values.min() ?? 0,
                max: values.max() ?? 0
            )
            results.variantStats[variant] = stats
        }

        return results
    }
}

// MARK: - Experiment Results

struct ExperimentResults {
    let experimentId: String
    var variantStats: [String: VariantStatistics] = [:]
}

struct VariantStatistics {
    let variantName: String
    let sampleSize: Int
    let mean: Double
    let median: Double
    let min: Double
    let max: Double

    var description: String {
        return """
        Variant: \(variantName)
        Sample Size: \(sampleSize)
        Mean: \(String(format: "%.3f", mean))
        Median: \(String(format: "%.3f", median))
        Range: \(String(format: "%.3f", min)) - \(String(format: "%.3f", max))
        """
    }
}

// MARK: - Predefined Experiments

extension ABTestingFramework {
    /// Create default matching algorithm experiment
    func createDefaultMatchingExperiment() async throws {
        try await createExperiment(
            id: "matching_algorithm_v1",
            name: "Matching Algorithm Optimization",
            description: "Test different weighting schemes for matching algorithm",
            variants: [
                Experiment.Variant(
                    name: "control",
                    algorithmVariant: "standard",
                    trafficPercentage: 0.25
                ),
                Experiment.Variant(
                    name: "aggressive",
                    algorithmVariant: "aggressive",
                    trafficPercentage: 0.25
                ),
                Experiment.Variant(
                    name: "conservative",
                    algorithmVariant: "conservative",
                    trafficPercentage: 0.25
                ),
                Experiment.Variant(
                    name: "experimental",
                    algorithmVariant: "experimental",
                    trafficPercentage: 0.25
                )
            ],
            startDate: Date(),
            endDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days
            targetMetric: "match_rate"
        )
    }
}
