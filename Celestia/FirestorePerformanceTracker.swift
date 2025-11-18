//
//  FirestorePerformanceTracker.swift
//  Celestia
//
//  Firestore query performance tracking
//  Identifies slow queries and reports to backend
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Firestore query performance tracker
@MainActor
class FirestorePerformanceTracker {
    static let shared = FirestorePerformanceTracker()

    private let slowQueryThreshold: Double = 500 // 500ms
    private let verySlowQueryThreshold: Double = 1000 // 1s

    private init() {}

    /// Track query performance
    /// - Parameters:
    ///   - collection: Collection name
    ///   - operation: Operation type (get, list, query)
    ///   - query: Query description
    ///   - operation: Query closure
    /// - Returns: Query result
    func trackQuery<T>(
        collection: String,
        operation: String,
        description: String = "",
        query: () async throws -> T
    ) async rethrows -> T {
        let start = Date()

        let result = try await query()

        let duration = Date().timeIntervalSince(start) * 1000 // ms

        // Get result count if possible
        var resultCount = 0
        if let snapshot = result as? QuerySnapshot {
            resultCount = snapshot.documents.count
        } else if let _ = result as? DocumentSnapshot {
            resultCount = 1
        }

        // Log performance
        logQueryPerformance(
            collection: collection,
            operation: operation,
            description: description,
            duration: duration,
            resultCount: resultCount
        )

        // Track in PerformanceMonitor
        await PerformanceMonitor.shared.trackQuery(duration: duration)

        return result
    }

    /// Log query performance and report if slow
    private func logQueryPerformance(
        collection: String,
        operation: String,
        description: String,
        duration: Double,
        resultCount: Int
    ) {
        let queryDesc = description.isEmpty ? "" : " (\(description))"

        if duration > verySlowQueryThreshold {
            Logger.shared.warning(
                "🐌 VERY SLOW QUERY: \(collection).\(operation)\(queryDesc) took \(String(format: "%.0f", duration))ms (\(resultCount) docs)",
                category: .performance
            )

            // Report to backend
            Task {
                await reportSlowQuery(
                    collection: collection,
                    operation: operation,
                    duration: duration,
                    resultCount: resultCount
                )
            }

            // Send to analytics
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "type": "very_slow_query",
                "collection": collection,
                "operation": operation,
                "duration_ms": duration,
                "result_count": resultCount,
                "threshold_ms": verySlowQueryThreshold
            ])

        } else if duration > slowQueryThreshold {
            Logger.shared.info(
                "🐌 SLOW QUERY: \(collection).\(operation)\(queryDesc) took \(String(format: "%.0f", duration))ms (\(resultCount) docs)",
                category: .performance
            )

            // Send to analytics
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "type": "slow_query",
                "collection": collection,
                "operation": operation,
                "duration_ms": duration,
                "result_count": resultCount,
                "threshold_ms": slowQueryThreshold
            ])

        } else {
            Logger.shared.debug(
                "⏱️ \(collection).\(operation)\(queryDesc) took \(String(format: "%.0f", duration))ms (\(resultCount) docs)",
                category: .performance
            )
        }
    }

    /// Report slow query to backend
    private func reportSlowQuery(
        collection: String,
        operation: String,
        duration: Double,
        resultCount: Int
    ) async {
        let functions = Functions.functions()
        let callable = functions.httpsCallable("reportSlowQuery")

        do {
            _ = try await callable.call([
                "collection": collection,
                "operation": operation,
                "duration": duration,
                "resultCount": resultCount
            ])

            Logger.shared.debug("Slow query reported to backend", category: .performance)

        } catch {
            Logger.shared.error("Failed to report slow query", category: .performance, error: error)
        }
    }

    /// Get query performance recommendations
    func getRecommendations() -> [String] {
        var recommendations: [String] = []

        let stats = PerformanceMonitor.shared.getCurrentSummary()

        if let avgQueryTime = stats["avgQueryTimeMs"] as? Double, avgQueryTime > slowQueryThreshold {
            recommendations.append("Slow database queries detected. Consider adding indexes or reducing query complexity.")
        }

        return recommendations
    }
}

// MARK: - Firestore Extension

extension Firestore {

    /// Perform tracked query
    /// Automatically tracks performance and reports slow queries
    func trackedQuery<T>(
        collection: String,
        operation: String = "query",
        description: String = "",
        query: () async throws -> T
    ) async rethrows -> T {
        return try await FirestorePerformanceTracker.shared.trackQuery(
            collection: collection,
            operation: operation,
            description: description,
            query: query
        )
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Track collection query
 let users = await Firestore.firestore().trackedQuery(
     collection: "users",
     operation: "list",
     description: "active users"
 ) {
     try await Firestore.firestore()
         .collection("users")
         .whereField("isActive", isEqualTo: true)
         .limit(to: 20)
         .getDocuments()
 }

 // Example 2: Track document fetch
 let user = await Firestore.firestore().trackedQuery(
     collection: "users",
     operation: "get",
     description: "user profile"
 ) {
     try await Firestore.firestore()
         .collection("users")
         .document(userId)
         .getDocument()
 }

 // Example 3: Track complex query
 let matches = await Firestore.firestore().trackedQuery(
     collection: "matches",
     operation: "query",
     description: "active matches with messages"
 ) {
     try await Firestore.firestore()
         .collection("matches")
         .whereField("userId", isEqualTo: currentUserId)
         .whereField("isActive", isEqualTo: true)
         .order(by: "lastMessageTimestamp", descending: true)
         .limit(to: 50)
         .getDocuments()
 }

 // Output examples:
 // ✅ ⏱️ users.list (active users) took 125ms (20 docs)
 // ⚠️  🐌 SLOW QUERY: matches.query (active matches) took 850ms (50 docs)
 // ❌ 🐌 VERY SLOW QUERY: messages.query (unread) took 1520ms (200 docs) - Reported to backend
 */
