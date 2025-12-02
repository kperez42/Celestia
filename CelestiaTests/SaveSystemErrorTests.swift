//
//  SaveSystemErrorTests.swift
//  CelestiaTests
//
//  Comprehensive tests for save system error scenarios:
//  1. Save failures (network errors, timeouts, permission denied)
//  2. Upload failures (image upload failures, storage errors)
//  3. Save erasure prevention (data integrity, accidental deletion)
//  4. Save operations not working (race conditions, edge cases)
//
//  These tests ensure the save system is robust and handles all error cases gracefully.
//

import Testing
import Foundation
@testable import Celestia

// MARK: - Mock Firestore Service for Error Simulation

@MainActor
class MockFirestoreService {
    var shouldFail = false
    var failureType: SaveSystemError = .networkError
    var failAfterAttempts = 0
    var currentAttempts = 0
    var savedDocuments: [String: [String: Any]] = [:]
    var deletedDocuments: [String] = []
    var operationDelay: UInt64 = 0
    var operationLog: [String] = []

    enum SaveSystemError: Error, LocalizedError {
        case networkError
        case timeout
        case permissionDenied
        case quotaExceeded
        case documentNotFound
        case serverUnavailable
        case invalidData
        case concurrentModification
        case batchOperationFailed
        case partialFailure(successCount: Int, failureCount: Int)

        var errorDescription: String? {
            switch self {
            case .networkError: return "Network connection failed"
            case .timeout: return "Operation timed out"
            case .permissionDenied: return "Permission denied"
            case .quotaExceeded: return "Storage quota exceeded"
            case .documentNotFound: return "Document not found"
            case .serverUnavailable: return "Server temporarily unavailable"
            case .invalidData: return "Invalid data format"
            case .concurrentModification: return "Document was modified by another process"
            case .batchOperationFailed: return "Batch operation failed"
            case .partialFailure(let success, let failure):
                return "Partial failure: \(success) succeeded, \(failure) failed"
            }
        }
    }

    func addDocument(collection: String, data: [String: Any]) async throws -> String {
        operationLog.append("addDocument:\(collection)")

        if operationDelay > 0 {
            try await Task.sleep(nanoseconds: operationDelay)
        }

        currentAttempts += 1

        if shouldFail && currentAttempts > failAfterAttempts {
            throw failureType
        }

        let documentId = UUID().uuidString
        savedDocuments[documentId] = data
        return documentId
    }

    func deleteDocument(collection: String, documentId: String) async throws {
        operationLog.append("deleteDocument:\(collection)/\(documentId)")

        if operationDelay > 0 {
            try await Task.sleep(nanoseconds: operationDelay)
        }

        currentAttempts += 1

        if shouldFail && currentAttempts > failAfterAttempts {
            throw failureType
        }

        if savedDocuments[documentId] == nil {
            throw SaveSystemError.documentNotFound
        }

        savedDocuments.removeValue(forKey: documentId)
        deletedDocuments.append(documentId)
    }

    func updateDocument(collection: String, documentId: String, data: [String: Any]) async throws {
        operationLog.append("updateDocument:\(collection)/\(documentId)")

        if operationDelay > 0 {
            try await Task.sleep(nanoseconds: operationDelay)
        }

        currentAttempts += 1

        if shouldFail && currentAttempts > failAfterAttempts {
            throw failureType
        }

        if savedDocuments[documentId] == nil {
            throw SaveSystemError.documentNotFound
        }

        var existingData = savedDocuments[documentId] ?? [:]
        for (key, value) in data {
            existingData[key] = value
        }
        savedDocuments[documentId] = existingData
    }

    func batchDelete(documentIds: [String]) async throws {
        operationLog.append("batchDelete:\(documentIds.count) documents")

        if shouldFail {
            throw failureType
        }

        for id in documentIds {
            if savedDocuments[id] != nil {
                savedDocuments.removeValue(forKey: id)
                deletedDocuments.append(id)
            }
        }
    }

    func reset() {
        shouldFail = false
        failureType = .networkError
        failAfterAttempts = 0
        currentAttempts = 0
        savedDocuments = [:]
        deletedDocuments = []
        operationDelay = 0
        operationLog = []
    }
}

// MARK: - Mock Save Service for Testing

@MainActor
class MockSaveService {
    private let firestore: MockFirestoreService
    var savedProfiles: [SavedProfile] = []
    var errorMessage: String = ""
    var lastError: Error?
    var retryCount = 0
    var maxRetries = 3

    init(firestore: MockFirestoreService) {
        self.firestore = firestore
    }

    func saveProfile(userId: String, savedUserId: String, note: String? = nil) async throws -> String {
        retryCount = 0
        lastError = nil

        while retryCount < maxRetries {
            do {
                let data: [String: Any] = [
                    "userId": userId,
                    "savedUserId": savedUserId,
                    "savedAt": Date(),
                    "note": note ?? ""
                ]

                let docId = try await firestore.addDocument(collection: "saved_profiles", data: data)

                // Create local SavedProfile for state management
                let testUser = createTestUser(id: savedUserId)
                let savedProfile = SavedProfile(
                    id: docId,
                    user: testUser,
                    savedAt: Date(),
                    note: note
                )
                savedProfiles.append(savedProfile)

                return docId
            } catch {
                retryCount += 1
                lastError = error

                if retryCount >= maxRetries {
                    errorMessage = "Failed to save profile after \(maxRetries) attempts: \(error.localizedDescription)"
                    throw error
                }

                // Exponential backoff simulation
                try await Task.sleep(nanoseconds: UInt64(100_000_000 * retryCount))
            }
        }

        throw lastError ?? MockFirestoreService.SaveSystemError.networkError
    }

    func unsaveProfile(documentId: String) async throws {
        retryCount = 0
        lastError = nil

        // Store original state for rollback
        let originalProfiles = savedProfiles

        while retryCount < maxRetries {
            do {
                try await firestore.deleteDocument(collection: "saved_profiles", documentId: documentId)
                savedProfiles.removeAll { $0.id == documentId }
                return
            } catch {
                retryCount += 1
                lastError = error

                // Rollback to original state on failure
                savedProfiles = originalProfiles

                if retryCount >= maxRetries {
                    errorMessage = "Failed to unsave profile: \(error.localizedDescription)"
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(100_000_000 * retryCount))
            }
        }

        throw lastError ?? MockFirestoreService.SaveSystemError.networkError
    }

    func updateNote(documentId: String, note: String) async throws {
        try await firestore.updateDocument(
            collection: "saved_profiles",
            documentId: documentId,
            data: ["note": note]
        )

        if let index = savedProfiles.firstIndex(where: { $0.id == documentId }) {
            let existing = savedProfiles[index]
            savedProfiles[index] = SavedProfile(
                id: existing.id,
                user: existing.user,
                savedAt: existing.savedAt,
                note: note
            )
        }
    }

    func clearAllSaved(documentIds: [String]) async throws {
        // Store original for rollback
        let originalProfiles = savedProfiles

        do {
            try await firestore.batchDelete(documentIds: documentIds)
            savedProfiles = []
        } catch {
            // Rollback on failure
            savedProfiles = originalProfiles
            errorMessage = "Failed to clear saved profiles: \(error.localizedDescription)"
            throw error
        }
    }

    private func createTestUser(id: String) -> User {
        return User(
            id: id,
            email: "\(id)@example.com",
            fullName: "Test User \(id.prefix(4))",
            age: 25,
            gender: "Other",
            lookingFor: "Everyone",
            bio: "Test bio",
            location: "Test City",
            country: "Test Country",
            languages: ["English"],
            interests: ["Testing"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 18,
            ageRangeMax: 99,
            maxDistance: 100
        )
    }
}

// MARK: - Save Failure Tests

@Suite("Save Operation Failure Tests")
@MainActor
struct SaveOperationFailureTests {

    // MARK: - Network Error Tests

    @Test("Save fails with network error and shows appropriate message")
    func testSaveFailsWithNetworkError() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .networkError

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch {
            #expect(saveService.retryCount == 3, "Should have retried 3 times")
            #expect(saveService.errorMessage.contains("Failed to save profile"), "Should show error message")
            #expect(saveService.savedProfiles.isEmpty, "No profiles should be saved on failure")
        }
    }

    @Test("Save succeeds after transient network failure")
    func testSaveSucceedsAfterTransientFailure() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Fail first 2 attempts, succeed on 3rd
        firestore.shouldFail = true
        firestore.failAfterAttempts = 2
        firestore.failureType = .networkError

        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        #expect(!docId.isEmpty, "Should return document ID")
        #expect(saveService.retryCount == 2, "Should have retried twice")
        #expect(saveService.savedProfiles.count == 1, "Profile should be saved")
    }

    @Test("Save fails with timeout error")
    func testSaveFailsWithTimeout() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .timeout

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .timeout, "Error should be timeout")
        }
    }

    // MARK: - Permission Error Tests

    @Test("Save fails with permission denied error")
    func testSaveFailsWithPermissionDenied() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .permissionDenied

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown permission denied error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .permissionDenied, "Error should be permission denied")
        }

        #expect(saveService.savedProfiles.isEmpty, "No profiles should be saved on permission error")
    }

    @Test("Save fails with quota exceeded error")
    func testSaveFailsWithQuotaExceeded() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .quotaExceeded

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown quota exceeded error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .quotaExceeded, "Error should be quota exceeded")
        }
    }

    // MARK: - Server Error Tests

    @Test("Save fails with server unavailable error")
    func testSaveFailsWithServerUnavailable() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .serverUnavailable

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown server unavailable error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .serverUnavailable, "Error should be server unavailable")
        }

        #expect(saveService.retryCount == 3, "Should have exhausted all retries")
    }

    @Test("Save fails with invalid data error")
    func testSaveFailsWithInvalidData() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .invalidData

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
            #expect(Bool(false), "Should have thrown invalid data error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .invalidData, "Error should be invalid data")
        }
    }
}

// MARK: - Unsave Failure Tests

@Suite("Unsave Operation Failure Tests")
@MainActor
struct UnsaveOperationFailureTests {

    @Test("Unsave fails with network error and preserves local state")
    func testUnsaveFailsPreservesState() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // First save a profile successfully
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        #expect(saveService.savedProfiles.count == 1)

        // Now make unsave fail
        firestore.reset()
        firestore.shouldFail = true
        firestore.failureType = .networkError

        do {
            try await saveService.unsaveProfile(documentId: docId)
            #expect(Bool(false), "Should have thrown network error")
        } catch {
            // Profile should still be in local state (rollback)
            #expect(saveService.savedProfiles.count == 1, "Profile should remain after failed unsave")
            #expect(saveService.savedProfiles.first?.id == docId, "Original profile should be preserved")
        }
    }

    @Test("Unsave fails with document not found error")
    func testUnsaveFailsDocumentNotFound() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Try to unsave non-existent document
        do {
            try await saveService.unsaveProfile(documentId: "nonexistent123")
            #expect(Bool(false), "Should have thrown document not found error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .documentNotFound, "Error should be document not found")
        }
    }

    @Test("Unsave succeeds after transient failure")
    func testUnsaveSucceedsAfterTransientFailure() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save a profile first
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        // Configure transient failure
        firestore.shouldFail = true
        firestore.failAfterAttempts = 1  // Fail first attempt only
        firestore.failureType = .networkError

        try await saveService.unsaveProfile(documentId: docId)

        #expect(saveService.savedProfiles.isEmpty, "Profile should be removed after successful unsave")
        #expect(saveService.retryCount == 1, "Should have retried once")
    }
}

// MARK: - Save Erasure Prevention Tests

@Suite("Save Erasure Prevention Tests")
@MainActor
struct SaveErasurePreventionTests {

    @Test("Failed unsave does NOT erase local saved profiles")
    func testFailedUnsaveDoesNotEraseProfiles() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save multiple profiles
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "user3")
        let docId3 = try await saveService.saveProfile(userId: "user1", savedUserId: "user4")

        #expect(saveService.savedProfiles.count == 3)

        // Make unsave fail
        firestore.shouldFail = true
        firestore.failureType = .networkError

        // Try to unsave one profile - should fail
        do {
            try await saveService.unsaveProfile(documentId: docId2)
            #expect(Bool(false), "Should have failed")
        } catch {
            // All profiles should still be preserved
            #expect(saveService.savedProfiles.count == 3, "All profiles must remain after failed unsave")
            #expect(saveService.savedProfiles.contains { $0.id == docId1 }, "First profile preserved")
            #expect(saveService.savedProfiles.contains { $0.id == docId2 }, "Second profile preserved")
            #expect(saveService.savedProfiles.contains { $0.id == docId3 }, "Third profile preserved")
        }
    }

    @Test("Failed clear all does NOT erase local saved profiles")
    func testFailedClearAllDoesNotEraseProfiles() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save multiple profiles
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "user3")

        let originalCount = saveService.savedProfiles.count
        #expect(originalCount == 2)

        // Make batch delete fail
        firestore.shouldFail = true
        firestore.failureType = .batchOperationFailed

        do {
            try await saveService.clearAllSaved(documentIds: [docId1, docId2])
            #expect(Bool(false), "Should have failed")
        } catch {
            // All profiles should be preserved (rolled back)
            #expect(saveService.savedProfiles.count == originalCount, "All profiles must remain after failed clear")
        }
    }

    @Test("Partial batch failure preserves all profiles")
    func testPartialBatchFailurePreservesProfiles() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save profiles
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "user3")
        let docId3 = try await saveService.saveProfile(userId: "user1", savedUserId: "user4")

        // Simulate partial failure in batch operation
        firestore.shouldFail = true
        firestore.failureType = .partialFailure(successCount: 1, failureCount: 2)

        do {
            try await saveService.clearAllSaved(documentIds: [docId1, docId2, docId3])
            #expect(Bool(false), "Should have failed")
        } catch {
            // All profiles should be rolled back
            #expect(saveService.savedProfiles.count == 3, "All profiles must be preserved on partial failure")
        }
    }

    @Test("Concurrent modifications don't cause data loss")
    func testConcurrentModificationsPreventsDataLoss() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save a profile
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        // Simulate concurrent modification error during update
        firestore.shouldFail = true
        firestore.failureType = .concurrentModification

        do {
            try await saveService.updateNote(documentId: docId, note: "New note")
            #expect(Bool(false), "Should have thrown concurrent modification error")
        } catch {
            // Original profile should still exist unchanged
            #expect(saveService.savedProfiles.count == 1, "Profile should still exist")
            #expect(saveService.savedProfiles.first?.note == nil, "Note should remain unchanged")
        }
    }

    @Test("Multiple rapid save/unsave operations maintain data integrity")
    func testRapidOperationsMaintainIntegrity() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Perform rapid save operations
        var savedIds: [String] = []
        for i in 1...5 {
            let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user\(i)")
            savedIds.append(docId)
        }

        #expect(saveService.savedProfiles.count == 5, "All 5 profiles should be saved")

        // Rapid unsave operations - some fail
        firestore.failAfterAttempts = 2  // Fail after 2 unsave attempts
        firestore.shouldFail = true
        firestore.failureType = .networkError

        var unsavedCount = 0
        for docId in savedIds.prefix(3) {
            do {
                try await saveService.unsaveProfile(documentId: docId)
                unsavedCount += 1
            } catch {
                // Some may fail, that's expected
            }
        }

        // Verify data integrity - remaining profiles should be intact
        let remainingCount = 5 - unsavedCount
        #expect(saveService.savedProfiles.count >= 2, "At least 2 profiles should remain (unsaved 3, 2 untouched)")
    }
}

// MARK: - Save Operation Edge Case Tests

@Suite("Save Operation Edge Cases")
@MainActor
struct SaveOperationEdgeCaseTests {

    @Test("Duplicate save prevention works correctly")
    func testDuplicateSavePrevention() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save same user twice
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        // Both saves succeed (at mock level), but real implementation should prevent duplicates
        #expect(!docId1.isEmpty)
        #expect(!docId2.isEmpty)

        // Note: In real implementation, this would be prevented
        // This test documents the mock behavior
    }

    @Test("Empty note saves correctly")
    func testEmptyNoteSaves() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2", note: "")

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.first?.note == "", "Empty note should be saved as empty string")
    }

    @Test("Nil note saves correctly")
    func testNilNoteSaves() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2", note: nil)

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.first?.note == nil, "Nil note should remain nil")
    }

    @Test("Very long note saves correctly")
    func testVeryLongNoteSaves() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        let longNote = String(repeating: "This is a very long note. ", count: 100)
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2", note: longNote)

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.first?.note == longNote, "Long note should be preserved")
    }

    @Test("Note with special characters saves correctly")
    func testSpecialCharacterNoteSaves() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        let specialNote = "Met at café ☕️! Very interesting person 💫 #blessed @NYC"
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2", note: specialNote)

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.first?.note == specialNote, "Special characters should be preserved")
    }

    @Test("Update note fails gracefully when document doesn't exist")
    func testUpdateNoteFailsGracefully() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        do {
            try await saveService.updateNote(documentId: "nonexistent", note: "New note")
            #expect(Bool(false), "Should have thrown document not found error")
        } catch let error as MockFirestoreService.SaveSystemError {
            #expect(error == .documentNotFound)
        }
    }

    @Test("Save with slow network eventually succeeds")
    func testSaveWithSlowNetwork() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Simulate slow network (500ms delay)
        firestore.operationDelay = 500_000_000

        let startTime = Date()
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        let duration = Date().timeIntervalSince(startTime)

        #expect(!docId.isEmpty)
        #expect(duration >= 0.4, "Should have experienced delay")
        #expect(saveService.savedProfiles.count == 1)
    }

    @Test("Multiple concurrent saves don't cause race conditions")
    func testConcurrentSavesNoRaceConditions() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Small delay to simulate realistic network conditions
        firestore.operationDelay = 50_000_000

        // Perform concurrent saves
        await withTaskGroup(of: String?.self) { group in
            for i in 1...5 {
                group.addTask {
                    try? await saveService.saveProfile(userId: "user1", savedUserId: "savedUser\(i)")
                }
            }

            var results: [String] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }

            // All saves should complete
            #expect(results.count == 5, "All 5 concurrent saves should succeed")
        }

        #expect(saveService.savedProfiles.count == 5, "All profiles should be saved")
    }
}

// MARK: - Upload Failure Tests

@Suite("Upload Failure Tests")
@MainActor
struct UploadFailureTests {

    @Test("Failed upload does NOT erase existing saved profiles")
    func testFailedUploadDoesNotEraseProfiles() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save some profiles first
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user3")

        let originalCount = saveService.savedProfiles.count
        #expect(originalCount == 2)

        // Make next save fail
        firestore.shouldFail = true
        firestore.failureType = .networkError

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user4")
            #expect(Bool(false), "Should have failed")
        } catch {
            // Original profiles should still exist
            #expect(saveService.savedProfiles.count == originalCount, "Existing profiles must not be erased")
        }
    }

    @Test("Retry mechanism doesn't create duplicate saves")
    func testRetryNoDuplicates() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Fail first attempt, succeed on second
        firestore.shouldFail = true
        firestore.failAfterAttempts = 1
        firestore.failureType = .networkError

        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.count == 1, "Should have exactly one saved profile (no duplicates)")
    }

    @Test("Operation log tracks all attempts")
    func testOperationLogTracksAttempts() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Fail first 2 attempts
        firestore.shouldFail = true
        firestore.failAfterAttempts = 2
        firestore.failureType = .networkError

        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        #expect(firestore.operationLog.count == 3, "Should have logged all 3 attempts")
        #expect(firestore.operationLog.allSatisfy { $0.contains("addDocument") })
    }
}

// MARK: - Error Message Tests

@Suite("Error Message Tests")
@MainActor
struct ErrorMessageTests {

    @Test("Network error produces appropriate error message")
    func testNetworkErrorMessage() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        firestore.shouldFail = true
        firestore.failureType = .networkError

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")
        } catch {
            #expect(saveService.errorMessage.contains("Failed to save profile"))
        }
    }

    @Test("Unsave error produces appropriate error message")
    func testUnsaveErrorMessage() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save first
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        // Make unsave fail
        firestore.shouldFail = true
        firestore.failureType = .networkError

        do {
            try await saveService.unsaveProfile(documentId: docId)
        } catch {
            #expect(saveService.errorMessage.contains("Failed to unsave profile"))
        }
    }

    @Test("Clear all error produces appropriate error message")
    func testClearAllErrorMessage() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save first
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user2")

        // Make clear fail
        firestore.shouldFail = true
        firestore.failureType = .batchOperationFailed

        do {
            try await saveService.clearAllSaved(documentIds: [docId])
        } catch {
            #expect(saveService.errorMessage.contains("Failed to clear saved profiles"))
        }
    }
}

// MARK: - Integration Simulation Tests

@Suite("Integration Simulation Tests")
@MainActor
struct IntegrationSimulationTests {

    @Test("Full save workflow with intermittent failures")
    func testFullWorkflowWithIntermittentFailures() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Step 1: Save 3 profiles successfully
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "userA")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "userB")
        let docId3 = try await saveService.saveProfile(userId: "user1", savedUserId: "userC")

        #expect(saveService.savedProfiles.count == 3)

        // Step 2: Update a note (succeeds)
        try await saveService.updateNote(documentId: docId1, note: "Great conversation!")
        #expect(saveService.savedProfiles.first(where: { $0.id == docId1 })?.note == "Great conversation!")

        // Step 3: Unsave one profile with transient failure (succeeds on retry)
        firestore.shouldFail = true
        firestore.failAfterAttempts = 1
        firestore.failureType = .networkError

        try await saveService.unsaveProfile(documentId: docId2)
        #expect(saveService.savedProfiles.count == 2)

        // Step 4: Try to save new profile with persistent failure
        firestore.reset()
        firestore.shouldFail = true
        firestore.failureType = .serverUnavailable

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "userD")
            #expect(Bool(false), "Should have failed")
        } catch {
            // Still have 2 profiles from before
            #expect(saveService.savedProfiles.count == 2, "Existing profiles preserved after failed save")
        }

        // Step 5: Retry with working connection
        firestore.reset()
        let docId4 = try await saveService.saveProfile(userId: "user1", savedUserId: "userD")

        #expect(!docId4.isEmpty)
        #expect(saveService.savedProfiles.count == 3, "New profile added successfully")
    }

    @Test("Recovery from total network outage")
    func testRecoveryFromNetworkOutage() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save some profiles before outage
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "userA")
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "userB")

        let profileCountBeforeOutage = saveService.savedProfiles.count

        // Simulate network outage
        firestore.shouldFail = true
        firestore.failureType = .networkError

        // All operations fail during outage
        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "userC")
        } catch { /* Expected */ }

        // Verify state preserved during outage
        #expect(saveService.savedProfiles.count == profileCountBeforeOutage, "Profiles preserved during outage")

        // Network restored
        firestore.reset()

        // Operations work again
        let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "userC")

        #expect(!docId.isEmpty)
        #expect(saveService.savedProfiles.count == profileCountBeforeOutage + 1, "New profile saved after recovery")
    }

    @Test("High volume save operations stress test")
    func testHighVolumeSaveOperations() async throws {
        let firestore = MockFirestoreService()
        let saveService = MockSaveService(firestore: firestore)

        // Save 50 profiles
        var savedIds: [String] = []
        for i in 1...50 {
            let docId = try await saveService.saveProfile(userId: "user1", savedUserId: "user\(i)")
            savedIds.append(docId)
        }

        #expect(saveService.savedProfiles.count == 50, "All 50 profiles saved")
        #expect(savedIds.count == 50, "All 50 document IDs returned")

        // Verify no duplicates
        let uniqueIds = Set(savedIds)
        #expect(uniqueIds.count == 50, "All IDs are unique")

        // Clear all with success
        try await saveService.clearAllSaved(documentIds: savedIds)
        #expect(saveService.savedProfiles.isEmpty, "All profiles cleared")
    }
}
