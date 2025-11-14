//
//  IntegrationTestBase.swift
//  CelestiaTests
//
//  Base class for integration tests with Firebase Emulator support
//  Provides common setup, teardown, and utilities for integration testing
//

import Testing
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
@testable import Celestia

/// Base configuration and utilities for integration tests
@MainActor
class IntegrationTestBase {

    // MARK: - Properties

    static var isFirebaseConfigured = false
    static var isEmulatorConnected = false

    let db: Firestore
    let auth: Auth
    let storage: Storage

    // Test data cleanup tracking
    var createdUserIds: [String] = []
    var createdMatchIds: [String] = []
    var createdMessageIds: [String] = []

    // MARK: - Firebase Emulator Configuration

    static let emulatorConfig = (
        auth: ("localhost", 9099),
        firestore: ("localhost", 8080),
        storage: ("localhost", 9199)
    )

    // MARK: - Initialization

    init() async throws {
        // Configure Firebase if not already done
        if !Self.isFirebaseConfigured {
            try await Self.configureFirebase()
        }

        // Get Firebase instances
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        self.storage = Storage.storage()

        // Connect to emulators
        try await connectToEmulators()
    }

    // MARK: - Firebase Setup

    static func configureFirebase() async throws {
        guard !isFirebaseConfigured else { return }

        // Configure Firebase (using test GoogleService-Info.plist or test configuration)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        isFirebaseConfigured = true
        Logger.shared.info("Firebase configured for integration tests", category: .testing)
    }

    func connectToEmulators() async throws {
        guard !Self.isEmulatorConnected else { return }

        // Connect to Firebase Auth Emulator
        auth.useEmulator(withHost: Self.emulatorConfig.auth.0, port: Self.emulatorConfig.auth.1)

        // Connect to Firestore Emulator
        let settings = Firestore.firestore().settings
        settings.host = "\(Self.emulatorConfig.firestore.0):\(Self.emulatorConfig.firestore.1)"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        db.settings = settings

        // Connect to Storage Emulator
        storage.useEmulator(withHost: Self.emulatorConfig.storage.0, port: Self.emulatorConfig.storage.1)

        Self.isEmulatorConnected = true
        Logger.shared.info("Connected to Firebase Emulators", category: .testing)
    }

    // MARK: - Test Data Helpers

    /// Create a test user in Firestore
    func createTestUser(
        email: String = "test\(UUID().uuidString.prefix(8))@test.com",
        fullName: String = "Test User",
        age: Int = 25,
        gender: String = "Female",
        lookingFor: String = "Male"
    ) async throws -> User {
        // Create auth user
        let authResult = try await auth.createUser(withEmail: email, password: "TestPass123!")

        // Create Firestore user document
        let user = User(
            id: authResult.user.uid,
            email: email,
            fullName: fullName,
            age: age,
            gender: gender,
            lookingFor: lookingFor,
            location: "Test City",
            country: "Test Country"
        )

        let encodedUser = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(user.id!).setData(encodedUser)

        // Track for cleanup
        createdUserIds.append(user.id!)

        Logger.shared.debug("Created test user: \(user.id!)", category: .testing)
        return user
    }

    /// Create a test match between two users
    func createTestMatch(user1Id: String, user2Id: String) async throws -> Match {
        let match = Match(user1Id: user1Id, user2Id: user2Id)

        let docRef = try db.collection("matches").addDocument(from: match)

        var matchWithId = match
        matchWithId.id = docRef.documentID

        // Track for cleanup
        createdMatchIds.append(docRef.documentID)

        Logger.shared.debug("Created test match: \(docRef.documentID)", category: .testing)
        return matchWithId
    }

    /// Create a test message
    func createTestMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String = "Test message"
    ) async throws -> Message {
        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text
        )

        let docRef = try db.collection("messages").addDocument(from: message)

        var messageWithId = message
        messageWithId.id = docRef.documentID

        // Track for cleanup
        createdMessageIds.append(docRef.documentID)

        Logger.shared.debug("Created test message: \(docRef.documentID)", category: .testing)
        return messageWithId
    }

    // MARK: - Cleanup

    /// Clean up all test data created during test
    func cleanup() async {
        Logger.shared.info("Starting integration test cleanup", category: .testing)

        // Delete created messages
        for messageId in createdMessageIds {
            try? await db.collection("messages").document(messageId).delete()
        }

        // Delete created matches
        for matchId in createdMatchIds {
            try? await db.collection("matches").document(matchId).delete()
        }

        // Delete created users
        for userId in createdUserIds {
            // Delete Firestore document
            try? await db.collection("users").document(userId).delete()

            // Delete auth user (requires signing in first)
            // Note: In emulator, this is simplified
        }

        // Sign out
        try? auth.signOut()

        // Clear tracking arrays
        createdMessageIds.removeAll()
        createdMatchIds.removeAll()
        createdUserIds.removeAll()

        Logger.shared.info("Integration test cleanup completed", category: .testing)
    }

    // MARK: - Utilities

    /// Wait for a condition to be true with timeout
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollingInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }

        throw IntegrationTestError.timeoutWaitingForCondition
    }

    /// Simulate network delay
    func simulateNetworkDelay(milliseconds: Int = 100) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    }

    /// Get collection document count
    func getDocumentCount(collection: String) async throws -> Int {
        let snapshot = try await db.collection(collection).getDocuments()
        return snapshot.documents.count
    }
}

// MARK: - Integration Test Error

enum IntegrationTestError: Error, LocalizedError {
    case timeoutWaitingForCondition
    case emulatorNotRunning
    case testDataSetupFailed
    case assertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeoutWaitingForCondition:
            return "Timeout waiting for condition to be met"
        case .emulatorNotRunning:
            return "Firebase Emulator is not running. Start it with: firebase emulators:start"
        case .testDataSetupFailed:
            return "Failed to set up test data"
        case .assertionFailed(let message):
            return "Assertion failed: \(message)"
        }
    }
}

// MARK: - Test Helpers

extension IntegrationTestBase {
    /// Create multiple test users
    func createTestUsers(count: Int) async throws -> [User] {
        var users: [User] = []

        for i in 0..<count {
            let user = try await createTestUser(
                fullName: "Test User \(i + 1)",
                age: 20 + i,
                gender: i % 2 == 0 ? "Female" : "Male"
            )
            users.append(user)
        }

        return users
    }

    /// Create a conversation with messages
    func createTestConversation(
        user1: User,
        user2: User,
        messageCount: Int
    ) async throws -> (match: Match, messages: [Message]) {
        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let match = try await createTestMatch(user1Id: user1Id, user2Id: user2Id)

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        var messages: [Message] = []
        for i in 0..<messageCount {
            let sender = i % 2 == 0 ? user1Id : user2Id
            let receiver = i % 2 == 0 ? user2Id : user1Id

            let message = try await createTestMessage(
                matchId: matchId,
                senderId: sender,
                receiverId: receiver,
                text: "Test message \(i + 1)"
            )
            messages.append(message)

            // Small delay between messages
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        return (match, messages)
    }
}

// MARK: - Performance Measurement

extension IntegrationTestBase {
    /// Measure execution time of a block
    func measureTime(
        operation: String,
        block: () async throws -> Void
    ) async rethrows -> TimeInterval {
        let start = Date()
        try await block()
        let duration = Date().timeIntervalSince(start)

        Logger.shared.info("Performance: \(operation) took \(String(format: "%.2f", duration * 1000))ms", category: .testing)

        return duration
    }

    /// Measure memory usage
    func measureMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        }

        return 0
    }
}
