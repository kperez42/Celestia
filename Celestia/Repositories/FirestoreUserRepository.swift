//
//  FirestoreUserRepository.swift
//  Celestia
//
//  Concrete implementation of UserRepository using Firestore
//  Separates data access logic from business logic
//

import Foundation
import FirebaseFirestore

class FirestoreUserRepository: UserRepository {
    private let db = Firestore.firestore()
    private let userCache = QueryCache<User>(ttl: 300, maxSize: 100) // 5 min cache, 100 users

    // MARK: - UserRepository Protocol Implementation

    func fetchUser(id: String) async throws -> User? {
        // Check cache first
        if let cached = await userCache.get(id) {
            Logger.shared.debug("Cache hit for user \(id)", category: .database)
            return cached
        }

        // Cache miss - fetch from Firestore
        Logger.shared.debug("Cache miss for user \(id), fetching from database", category: .database)

        let doc = try await db.collection("users").document(id).getDocument()
        guard let user = try? doc.data(as: User.self) else {
            return nil
        }

        // Store in cache
        await userCache.set(id, value: user)

        return user
    }

    func updateUser(_ user: User) async throws {
        guard let userId = user.id else {
            throw NSError(domain: "FirestoreUserRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is nil"])
        }

        try db.collection("users").document(userId).setData(from: user, merge: true)

        // Invalidate cache after update
        await userCache.remove(userId)
        Logger.shared.debug("User cache invalidated for \(userId)", category: .database)
    }

    func updateUserFields(userId: String, fields: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(fields)

        // Invalidate cache after update
        await userCache.remove(userId)
        Logger.shared.debug("User cache invalidated for \(userId)", category: .database)
    }

    func searchUsers(query: String, currentUserId: String, limit: Int, offset: DocumentSnapshot?) async throws -> [User] {
        // Sanitize search query using centralized utility
        let sanitizedQuery = InputSanitizer.standard(query)
        guard !sanitizedQuery.isEmpty else { return [] }

        let searchQuery = sanitizedQuery.lowercased()
        let prefixEnd = searchQuery + "\u{f8ff}" // Unicode max character for range query

        var results: [User] = []

        // Approach 1: Try prefix matching on fullName
        do {
            let nameQuery = db.collection("users")
                .whereField("showMeInSearch", isEqualTo: true)
                .whereField("fullNameLowercase", isGreaterThanOrEqualTo: searchQuery)
                .whereField("fullNameLowercase", isLessThan: prefixEnd)
                .limit(to: limit)

            let nameSnapshot = try await nameQuery.getDocuments()
            let nameResults = nameSnapshot.documents
                .compactMap { try? $0.data(as: User.self) }
                .filter { user in
                    // Exclude current user and non-active profiles
                    // BUGFIX: Use effectiveId for reliable comparison
                    guard user.effectiveId != currentUserId else { return false }
                    let status = user.profileStatus.lowercased()
                    return status == "active" || status.isEmpty
                }

            results.append(contentsOf: nameResults)

            // If we have enough results, return early
            if results.count >= limit {
                return Array(results.prefix(limit))
            }
        } catch {
            Logger.shared.warning("Name prefix query failed: \(error.localizedDescription)", category: .database)
        }

        // Approach 2: Try country prefix match
        do {
            let remainingLimit = limit - results.count
            if remainingLimit > 0 {
                let countryQuery = db.collection("users")
                    .whereField("showMeInSearch", isEqualTo: true)
                    .whereField("countryLowercase", isGreaterThanOrEqualTo: searchQuery)
                    .whereField("countryLowercase", isLessThan: prefixEnd)
                    .limit(to: remainingLimit)

                let countrySnapshot = try await countryQuery.getDocuments()
                let countryResults = countrySnapshot.documents
                    .compactMap { try? $0.data(as: User.self) }
                    .filter { user in
                        // Exclude current user, duplicates, and non-active profiles
                        // BUGFIX: Use effectiveId for reliable comparison
                        guard user.effectiveId != currentUserId else { return false }
                        guard let userId = user.effectiveId,
                              !results.contains(where: { $0.effectiveId == userId }) else { return false }
                        let status = user.profileStatus.lowercased()
                        return status == "active" || status.isEmpty
                    }

                results.append(contentsOf: countryResults)
            }
        } catch {
            Logger.shared.warning("Country prefix query failed: \(error.localizedDescription)", category: .database)
        }

        return Array(results.prefix(limit))
    }

    func incrementProfileViews(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "profileViews": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.shared.error("Error incrementing profile views", category: .database, error: error)
        }
    }

    func updateLastActive(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "lastActive": FieldValue.serverTimestamp(),
                "isOnline": true
            ])
        } catch {
            Logger.shared.error("Error updating last active", category: .database, error: error)
        }
    }

    // MARK: - Consumables and Boosts

    func updateDailySwiperUsage(userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "usedDailySwipers": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.shared.error("Error updating daily swiper usage", category: .database, error: error)
            throw error
        }
    }

    func updateRewindUsage(userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "rewinds": FieldValue.increment(Int64(-1))
            ])
        } catch {
            Logger.shared.error("Error updating rewind usage", category: .database, error: error)
            throw error
        }
    }

    func updateBoostUsage(userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "boosts": FieldValue.increment(Int64(-1)),
                "lastBoostDate": FieldValue.serverTimestamp()
            ])
        } catch {
            Logger.shared.error("Error updating boost usage", category: .database, error: error)
            throw error
        }
    }

    func updateSuperLikeUsage(userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "superLikes": FieldValue.increment(Int64(-1))
            ])
        } catch {
            Logger.shared.error("Error updating super like usage", category: .database, error: error)
            throw error
        }
    }

    func getDailySwiperCount(userId: String) async throws -> Int {
        let document = try await db.collection("users").document(userId).getDocument()

        guard let data = document.data(),
              let count = data["usedDailySwipers"] as? Int else {
            return 0
        }

        return count
    }

    // MARK: - Additional Helper Methods

    func clearCache() async {
        await userCache.clear()
        Logger.shared.info("User cache cleared", category: .database)
    }

    func getCacheSize() async -> Int {
        return await userCache.size()
    }
}
