//
//  UserService.swift
//  Celestia
//
//  Service for user-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class UserService: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMoreUsers = true
    
    static let shared = UserService()
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private var searchTask: Task<Void, Never>?

    private init() {}

    /// Fetch users with filters and pagination support
    func fetchUsers(
        excludingUserId: String,
        lookingFor: String? = nil,
        ageRange: ClosedRange<Int>? = nil,
        country: String? = nil,
        limit: Int = 20,
        reset: Bool = true
    ) async throws {
        if reset {
            users = []
            lastDocument = nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var query = db.collection("users")
            .whereField("showMeInSearch", isEqualTo: true)
            .order(by: "lastActive", descending: true)
            .limit(to: limit)
        
        // Apply filters
        if let lookingFor = lookingFor {
            query = query.whereField("gender", isEqualTo: lookingFor)
        }
        
        if let ageRange = ageRange {
            query = query
                .whereField("age", isGreaterThanOrEqualTo: ageRange.lowerBound)
                .whereField("age", isLessThanOrEqualTo: ageRange.upperBound)
        }
        
        if let country = country {
            query = query.whereField("country", isEqualTo: country)
        }
        
        // Pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        do {
            let snapshot = try await query.getDocuments()
            lastDocument = snapshot.documents.last

            let newUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                .filter { $0.id != excludingUserId }

            users.append(contentsOf: newUsers)
            hasMoreUsers = newUsers.count >= limit
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Fetch a single user by ID
    func fetchUser(userId: String) async throws -> User? {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return try? doc.data(as: User.self)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Update user profile
    func updateUser(_ user: User) async throws {
        guard let userId = user.id else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is nil"])
        }
        
        do {
            try db.collection("users").document(userId).setData(from: user, merge: true)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Update specific fields
    func updateUserFields(userId: String, fields: [String: Any]) async throws {
        do {
            try await db.collection("users").document(userId).updateData(fields)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Increment profile view count
    func incrementProfileViews(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "profileViews": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.shared.error("Error incrementing profile views", category: .database, error: error)
        }
    }
    
    /// Update user's last active timestamp
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
    
    /// Set user offline
    func setUserOffline(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "isOnline": false,
                "lastActive": FieldValue.serverTimestamp()
            ])
        } catch {
            Logger.shared.error("Error setting user offline", category: .database, error: error)
        }
    }
    
    /// Search users by name or location with pagination support
    func searchUsers(query: String, currentUserId: String, limit: Int = 20, offset: DocumentSnapshot? = nil) async throws -> [User] {
        // Sanitize search query using centralized utility
        let sanitizedQuery = InputSanitizer.standard(query)
        guard !sanitizedQuery.isEmpty else { return [] }

        var firestoreQuery = db.collection("users")
            .whereField("showMeInSearch", isEqualTo: true)
            .limit(to: limit)

        // Add pagination cursor if provided
        if let offset = offset {
            firestoreQuery = firestoreQuery.start(afterDocument: offset)
        }

        let snapshot = try await firestoreQuery.getDocuments()

        let searchQuery = sanitizedQuery.lowercased()
        return snapshot.documents
            .compactMap { try? $0.data(as: User.self) }
            .filter { user in
                guard user.id != currentUserId else { return false }
                return user.fullName.lowercased().contains(searchQuery) ||
                       user.location.lowercased().contains(searchQuery) ||
                       user.country.lowercased().contains(searchQuery)
            }
    }

    /// Debounced search to prevent excessive API calls while typing
    /// - Parameters:
    ///   - query: Search query string
    ///   - currentUserId: Current user's ID to exclude from results
    ///   - debounceInterval: Time to wait before executing search (default: 0.3 seconds)
    ///   - limit: Maximum number of results
    ///   - completion: Callback with search results or error
    func debouncedSearch(
        query: String,
        currentUserId: String,
        debounceInterval: TimeInterval = 0.3,
        limit: Int = 20,
        completion: @escaping ([User]?, Error?) -> Void
    ) {
        // Cancel previous search task
        searchTask?.cancel()

        // Create new debounced search task
        searchTask = Task {
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchUsers(query: query, currentUserId: currentUserId, limit: limit)
                guard !Task.isCancelled else { return }
                completion(results, nil)
            } catch {
                guard !Task.isCancelled else { return }
                completion(nil, error)
            }
        }
    }
    
    /// Load more users (pagination)
    func loadMoreUsers(excludingUserId: String, lookingFor: String? = nil, ageRange: ClosedRange<Int>? = nil) async throws {
        try await fetchUsers(
            excludingUserId: excludingUserId,
            lookingFor: lookingFor,
            ageRange: ageRange,
            reset: false
        )
    }
    
    /// Check if user has completed profile
    func isProfileComplete(_ user: User) -> Bool {
        return !user.fullName.isEmpty &&
               !user.bio.isEmpty &&
               !user.profileImageURL.isEmpty &&
               user.interests.count >= 3 &&
               user.languages.count >= 1
    }
    
    /// Calculate profile completion percentage
    func profileCompletionPercentage(_ user: User) -> Int {
        var completedSteps = 0
        let totalSteps = 7

        if !user.fullName.isEmpty { completedSteps += 1 }
        if !user.bio.isEmpty { completedSteps += 1 }
        if !user.profileImageURL.isEmpty { completedSteps += 1 }
        if user.interests.count >= 3 { completedSteps += 1 }
        if user.languages.count >= 1 { completedSteps += 1 }
        if user.photos.count >= 2 { completedSteps += 1 }
        if user.age >= 18 { completedSteps += 1 }

        return (completedSteps * 100) / totalSteps
    }

    /// Cancel ongoing search task (useful for cleanup or manual cancellation)
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }

    deinit {
        searchTask?.cancel()
    }
}
