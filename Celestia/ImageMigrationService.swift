//
//  ImageMigrationService.swift
//  Celestia
//
//  Service for migrating existing Firebase Storage images to Cloudinary CDN
//

import Foundation
import Firebase
import FirebaseFunctions
import FirebaseFirestore

@MainActor
class ImageMigrationService: ObservableObject {
    static let shared = ImageMigrationService()

    private let functions = Functions.functions()
    private let db = Firestore.firestore()

    @Published var migrationProgress: [String: MigrationStatus] = [:]
    @Published var totalMigrated = 0
    @Published var totalFailed = 0

    private init() {}

    // MARK: - Single Image Migration

    /// Migrate a single image from Firebase Storage to Cloudinary
    func migrateImage(firebaseUrl: String) async throws -> OptimizedPhotoData {
        let migrateFunction = functions.httpsCallable("migrateImageToCDN")

        do {
            let result = try await migrateFunction.call(["firebaseUrl": firebaseUrl])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let photoData = data["photoData"] as? [String: Any] else {
                throw MigrationError.invalidResponse
            }

            return try parseOptimizedPhotoData(photoData)

        } catch {
            Logger.shared.error("Migration failed for \(firebaseUrl)", category: .storage, error: error)
            throw MigrationError.migrationFailed(error)
        }
    }

    // MARK: - Batch Migration

    /// Migrate all user profile photos
    func migrateAllUserPhotos(batchSize: Int = 10) async throws {
        Logger.shared.info("Starting batch migration", category: .storage)

        // Fetch all users with Firebase Storage URLs
        let snapshot = try await db.collection("users")
            .whereField("profilePhotoURL", isGreaterThan: "")
            .getDocuments()

        let users = snapshot.documents
        Logger.shared.info("Found \(users.count) users to migrate", category: .storage)

        // Process in batches to avoid overwhelming the system
        for batch in users.chunked(into: batchSize) {
            await withTaskGroup(of: MigrationResult.self) { group in
                for userDoc in batch {
                    group.addTask {
                        await self.migrateUserPhotos(userDoc: userDoc)
                    }
                }

                for await result in group {
                    switch result {
                    case .success(let userId):
                        await MainActor.run {
                            self.migrationProgress[userId] = .completed
                            self.totalMigrated += 1
                        }
                        Logger.shared.info("Migrated user \(userId)", category: .storage)

                    case .failure(let userId, let error):
                        await MainActor.run {
                            self.migrationProgress[userId] = .failed(error)
                            self.totalFailed += 1
                        }
                        Logger.shared.error("Failed to migrate user \(userId)", category: .storage, error: error)
                    }
                }
            }

            // Add delay between batches to avoid rate limits
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        Logger.shared.info("Migration complete: \(totalMigrated) succeeded, \(totalFailed) failed", category: .storage)
    }

    private func migrateUserPhotos(userDoc: QueryDocumentSnapshot) async -> MigrationResult {
        let userId = userDoc.documentID
        let data = userDoc.data()

        do {
            // Migrate profile photo
            if let profilePhotoURL = data["profilePhotoURL"] as? String {
                let optimizedPhoto = try await migrateImage(firebaseUrl: profilePhotoURL)

                // Update Firestore with optimized photo data
                try await db.collection("users").document(userId).updateData([
                    "optimizedPhoto": [
                        "urls": optimizedPhoto.urls,
                        "placeholder": optimizedPhoto.placeholder ?? "",
                        "cloudinaryPublicId": optimizedPhoto.cloudinaryPublicId ?? "",
                        "cdnUrl": optimizedPhoto.cdnUrl ?? "",
                        "bytes": optimizedPhoto.bytes ?? 0
                    ],
                    "migratedAt": FieldValue.serverTimestamp()
                ])
            }

            // Migrate additional photos if present
            if let photoUrls = data["photos"] as? [String] {
                var optimizedPhotos: [[String: Any]] = []

                for photoUrl in photoUrls {
                    let optimized = try await migrateImage(firebaseUrl: photoUrl)
                    optimizedPhotos.append([
                        "urls": optimized.urls,
                        "placeholder": optimized.placeholder ?? "",
                        "cloudinaryPublicId": optimized.cloudinaryPublicId ?? "",
                        "cdnUrl": optimized.cdnUrl ?? "",
                        "bytes": optimized.bytes ?? 0
                    ])
                }

                try await db.collection("users").document(userId).updateData([
                    "optimizedPhotos": optimizedPhotos
                ])
            }

            return .success(userId)

        } catch {
            return .failure(userId, error)
        }
    }

    // MARK: - Migration Stats

    /// Get current migration statistics
    func getMigrationStats() async throws -> MigrationStats {
        let totalSnapshot = try await db.collection("users").count.getAggregation(source: .server)
        let total = totalSnapshot.count.intValue

        let migratedSnapshot = try await db.collection("users")
            .whereField("optimizedPhoto", isNotEqualTo: NSNull())
            .count
            .getAggregation(source: .server)
        let migrated = migratedSnapshot.count.intValue

        let percentComplete = total > 0 ? Double(migrated) / Double(total) * 100 : 0

        return MigrationStats(
            total: total,
            migrated: migrated,
            remaining: total - migrated,
            percentComplete: percentComplete
        )
    }

    // MARK: - Rollback

    /// Rollback migration for specific users
    func rollbackMigration(userIds: [String]) async throws {
        for userId in userIds {
            try await db.collection("users").document(userId).updateData([
                "optimizedPhoto": FieldValue.delete(),
                "optimizedPhotos": FieldValue.delete(),
                "migratedAt": FieldValue.delete()
            ])
            Logger.shared.info("Rolled back migration for user \(userId)", category: .storage)
        }
    }

    // MARK: - Helper Methods

    private func parseOptimizedPhotoData(_ data: [String: Any]) throws -> OptimizedPhotoData {
        guard let urlsDict = data["urls"] as? [String: String] else {
            throw MigrationError.invalidResponse
        }

        return OptimizedPhotoData(
            urls: urlsDict,
            placeholder: data["placeholder"] as? String,
            cloudinaryPublicId: data["cloudinaryPublicId"] as? String,
            cdnUrl: data["cdnUrl"] as? String,
            bytes: data["bytes"] as? Int
        )
    }
}

// MARK: - Supporting Types

enum MigrationStatus {
    case pending
    case inProgress
    case completed
    case failed(Error)
}

enum MigrationResult {
    case success(String)
    case failure(String, Error)
}

struct MigrationStats {
    let total: Int
    let migrated: Int
    let remaining: Int
    let percentComplete: Double
}

enum MigrationError: LocalizedError {
    case invalidResponse
    case migrationFailed(Error)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from migration endpoint"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .notAuthorized:
            return "Admin access required for migration"
        }
    }
}
