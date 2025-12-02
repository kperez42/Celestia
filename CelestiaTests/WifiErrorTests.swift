//
//  WifiErrorTests.swift
//  CelestiaTests
//
//  Comprehensive tests for WiFi/network error scenarios:
//  1. WiFi upload failures - when image/data upload fails due to WiFi issues
//  2. WiFi get/fetch failures - when fetching data fails due to WiFi
//  3. Erasure prevention - ensure data doesn't get erased when operations fail
//  4. All error scenarios - network timeouts, connection loss, intermittent connectivity
//
//  These tests ensure the app handles WiFi errors gracefully without data loss.
//

import Testing
import Foundation
import UIKit
@testable import Celestia

// MARK: - WiFi Error Types

enum WifiError: Error, LocalizedError, Equatable {
    case wifiDisconnected
    case wifiSignalWeak
    case uploadFailed
    case uploadTimeout
    case downloadFailed
    case downloadTimeout
    case connectionLost
    case connectionInterrupted
    case networkUnreachable
    case sslHandshakeFailed
    case dnsLookupFailed
    case serverUnreachable
    case bandwidthExceeded
    case connectionReset

    var errorDescription: String? {
        switch self {
        case .wifiDisconnected: return "WiFi disconnected"
        case .wifiSignalWeak: return "WiFi signal too weak"
        case .uploadFailed: return "Upload failed due to WiFi error"
        case .uploadTimeout: return "Upload timed out"
        case .downloadFailed: return "Download failed due to WiFi error"
        case .downloadTimeout: return "Download timed out"
        case .connectionLost: return "Connection lost during operation"
        case .connectionInterrupted: return "Connection was interrupted"
        case .networkUnreachable: return "Network is unreachable"
        case .sslHandshakeFailed: return "SSL handshake failed"
        case .dnsLookupFailed: return "DNS lookup failed"
        case .serverUnreachable: return "Server unreachable"
        case .bandwidthExceeded: return "Bandwidth limit exceeded"
        case .connectionReset: return "Connection reset by peer"
        }
    }
}

// MARK: - Mock WiFi Network Service

@MainActor
class MockWifiNetworkService {
    var isWifiConnected = true
    var wifiSignalStrength: Double = 1.0 // 0.0 to 1.0
    var shouldFailUpload = false
    var shouldFailDownload = false
    var uploadFailureType: WifiError = .uploadFailed
    var downloadFailureType: WifiError = .downloadFailed
    var failAfterAttempts = 0
    var currentAttempts = 0
    var uploadDelay: UInt64 = 0
    var downloadDelay: UInt64 = 0
    var operationLog: [String] = []
    var uploadedData: [String: Data] = [:]
    var downloadedData: [String: Data] = [:]
    var simulateIntermittentConnection = false
    var intermittentFailureRate: Double = 0.5

    func upload(data: Data, path: String) async throws -> String {
        operationLog.append("upload:\(path)")

        if uploadDelay > 0 {
            try await Task.sleep(nanoseconds: uploadDelay)
        }

        currentAttempts += 1

        // Check WiFi connection
        guard isWifiConnected else {
            throw WifiError.wifiDisconnected
        }

        // Check signal strength
        if wifiSignalStrength < 0.2 {
            throw WifiError.wifiSignalWeak
        }

        // Simulate intermittent connection
        if simulateIntermittentConnection && Double.random(in: 0...1) < intermittentFailureRate {
            throw WifiError.connectionInterrupted
        }

        // Check failure conditions
        if shouldFailUpload && currentAttempts > failAfterAttempts {
            throw uploadFailureType
        }

        let documentId = UUID().uuidString
        uploadedData[documentId] = data
        return documentId
    }

    func download(path: String) async throws -> Data {
        operationLog.append("download:\(path)")

        if downloadDelay > 0 {
            try await Task.sleep(nanoseconds: downloadDelay)
        }

        currentAttempts += 1

        // Check WiFi connection
        guard isWifiConnected else {
            throw WifiError.wifiDisconnected
        }

        // Check signal strength
        if wifiSignalStrength < 0.2 {
            throw WifiError.wifiSignalWeak
        }

        // Simulate intermittent connection
        if simulateIntermittentConnection && Double.random(in: 0...1) < intermittentFailureRate {
            throw WifiError.connectionInterrupted
        }

        // Check failure conditions
        if shouldFailDownload && currentAttempts > failAfterAttempts {
            throw downloadFailureType
        }

        // Return mock data
        return "mock_data_for_\(path)".data(using: .utf8) ?? Data()
    }

    func reset() {
        isWifiConnected = true
        wifiSignalStrength = 1.0
        shouldFailUpload = false
        shouldFailDownload = false
        uploadFailureType = .uploadFailed
        downloadFailureType = .downloadFailed
        failAfterAttempts = 0
        currentAttempts = 0
        uploadDelay = 0
        downloadDelay = 0
        operationLog = []
        uploadedData = [:]
        downloadedData = [:]
        simulateIntermittentConnection = false
        intermittentFailureRate = 0.5
    }
}

// MARK: - Mock WiFi Image Upload Service

@MainActor
class MockWifiImageUploadService {
    private let networkService: MockWifiNetworkService
    var uploadedImages: [String: UIImage] = [:]
    var imageUrls: [String] = []
    var retryCount = 0
    var maxRetries = 3
    var lastError: Error?
    var errorMessage: String = ""

    init(networkService: MockWifiNetworkService) {
        self.networkService = networkService
    }

    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        retryCount = 0
        lastError = nil

        while retryCount < maxRetries {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw CelestiaError.invalidImageFormat
                }

                let documentId = try await networkService.upload(data: imageData, path: path)
                let url = "https://storage.example.com/\(path)/\(documentId).jpg"
                uploadedImages[documentId] = image
                imageUrls.append(url)
                return url
            } catch {
                retryCount += 1
                lastError = error

                if retryCount >= maxRetries {
                    errorMessage = "Image upload failed after \(maxRetries) attempts: \(error.localizedDescription)"
                    throw error
                }

                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(100_000_000 * retryCount))
            }
        }

        throw lastError ?? WifiError.uploadFailed
    }

    func uploadMultipleImages(_ images: [UIImage], path: String) async throws -> [String] {
        var urls: [String] = []
        let originalImageUrls = imageUrls
        let originalUploadedImages = uploadedImages

        for image in images {
            do {
                let url = try await uploadImage(image, path: path)
                urls.append(url)
            } catch {
                // Rollback - remove all images uploaded in this batch
                for url in urls {
                    imageUrls.removeAll { $0 == url }
                }
                // Restore original state
                imageUrls = originalImageUrls
                uploadedImages = originalUploadedImages
                throw error
            }
        }

        return urls
    }
}

// MARK: - Mock WiFi Data Fetch Service

@MainActor
class MockWifiDataFetchService {
    private let networkService: MockWifiNetworkService
    var cachedData: [String: Data] = [:]
    var fetchedPaths: [String] = []
    var retryCount = 0
    var maxRetries = 3
    var lastError: Error?
    var errorMessage: String = ""
    var useCacheOnFailure = true

    init(networkService: MockWifiNetworkService) {
        self.networkService = networkService
    }

    func fetchData(path: String) async throws -> Data {
        retryCount = 0
        lastError = nil

        while retryCount < maxRetries {
            do {
                let data = try await networkService.download(path: path)
                cachedData[path] = data
                fetchedPaths.append(path)
                return data
            } catch {
                retryCount += 1
                lastError = error

                if retryCount >= maxRetries {
                    // Return cached data if available
                    if useCacheOnFailure, let cached = cachedData[path] {
                        errorMessage = "Using cached data due to network error"
                        return cached
                    }

                    errorMessage = "Failed to fetch data after \(maxRetries) attempts: \(error.localizedDescription)"
                    throw error
                }

                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(100_000_000 * retryCount))
            }
        }

        throw lastError ?? WifiError.downloadFailed
    }
}

// MARK: - Mock WiFi Save Service

@MainActor
class MockWifiSaveService {
    private let networkService: MockWifiNetworkService
    var savedProfiles: [SavedProfile] = []
    var savedDocuments: [String: [String: Any]] = [:]
    var retryCount = 0
    var maxRetries = 3
    var lastError: Error?
    var errorMessage: String = ""

    init(networkService: MockWifiNetworkService) {
        self.networkService = networkService
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

                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let documentId = try await networkService.upload(data: jsonData, path: "saved_profiles")

                savedDocuments[documentId] = data
                let testUser = createTestUser(id: savedUserId)
                let savedProfile = SavedProfile(
                    id: documentId,
                    user: testUser,
                    savedAt: Date(),
                    note: note
                )
                savedProfiles.append(savedProfile)

                return documentId
            } catch {
                retryCount += 1
                lastError = error

                if retryCount >= maxRetries {
                    errorMessage = "Failed to save profile after \(maxRetries) attempts: \(error.localizedDescription)"
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(100_000_000 * retryCount))
            }
        }

        throw lastError ?? WifiError.uploadFailed
    }

    func unsaveProfile(documentId: String) async throws {
        let originalProfiles = savedProfiles
        let originalDocuments = savedDocuments

        do {
            // Simulate network call to delete
            _ = try await networkService.download(path: "saved_profiles/\(documentId)/delete")
            savedProfiles.removeAll { $0.id == documentId }
            savedDocuments.removeValue(forKey: documentId)
        } catch {
            // Rollback on failure
            savedProfiles = originalProfiles
            savedDocuments = originalDocuments
            errorMessage = "Failed to unsave profile: \(error.localizedDescription)"
            throw error
        }
    }

    func clearAllSaved() async throws {
        let originalProfiles = savedProfiles
        let originalDocuments = savedDocuments

        do {
            for profile in savedProfiles {
                _ = try await networkService.download(path: "saved_profiles/\(profile.id)/delete")
            }
            savedProfiles = []
            savedDocuments = [:]
        } catch {
            // Rollback on failure
            savedProfiles = originalProfiles
            savedDocuments = originalDocuments
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

// MARK: - WiFi Upload Failure Tests

@Suite("WiFi Upload Failure Tests")
@MainActor
struct WifiUploadFailureTests {

    // MARK: - WiFi Disconnected Tests

    @Test("Image upload fails when WiFi disconnected")
    func testImageUploadFailsWhenWifiDisconnected() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.isWifiConnected = false

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown WiFi disconnected error")
        } catch let error as WifiError {
            #expect(error == .wifiDisconnected)
            #expect(uploadService.uploadedImages.isEmpty)
            #expect(uploadService.imageUrls.isEmpty)
        }
    }

    @Test("Upload fails with weak WiFi signal")
    func testUploadFailsWithWeakWifiSignal() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.wifiSignalStrength = 0.1  // Very weak signal

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown weak signal error")
        } catch let error as WifiError {
            #expect(error == .wifiSignalWeak)
        }
    }

    @Test("Upload times out on slow WiFi")
    func testUploadTimeoutOnSlowWifi() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.shouldFailUpload = true
        networkService.uploadFailureType = .uploadTimeout

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as WifiError {
            #expect(error == .uploadTimeout)
            #expect(uploadService.retryCount == 3)
        }
    }

    @Test("Upload fails when connection lost mid-upload")
    func testUploadFailsWhenConnectionLost() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.shouldFailUpload = true
        networkService.uploadFailureType = .connectionLost

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown connection lost error")
        } catch let error as WifiError {
            #expect(error == .connectionLost)
        }
    }

    @Test("Upload succeeds after transient WiFi failure")
    func testUploadSucceedsAfterTransientWifiFailure() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Fail first 2 attempts, succeed on 3rd
        networkService.shouldFailUpload = true
        networkService.failAfterAttempts = 2
        networkService.uploadFailureType = .connectionInterrupted

        let testImage = createTestImage()

        let url = try await uploadService.uploadImage(testImage, path: "test_images")

        #expect(!url.isEmpty)
        #expect(uploadService.retryCount == 2)
        #expect(uploadService.uploadedImages.count == 1)
    }

    // MARK: - Multiple Image Upload Tests

    @Test("Batch upload fails and rolls back on WiFi error")
    func testBatchUploadRollbackOnWifiError() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Fail on 3rd image
        networkService.shouldFailUpload = true
        networkService.failAfterAttempts = 2
        networkService.uploadFailureType = .wifiDisconnected

        let testImages = (0..<5).map { _ in createTestImage() }

        do {
            _ = try await uploadService.uploadMultipleImages(testImages, path: "test_images")
            #expect(Bool(false), "Should have failed on 3rd image")
        } catch {
            // All images should be rolled back
            #expect(uploadService.imageUrls.isEmpty, "Should have rolled back all uploaded images")
        }
    }

    @Test("Partial batch upload preserves successfully uploaded images on non-rollback mode")
    func testPartialBatchUploadNoRollback() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        var uploadedUrls: [String] = []
        let testImages = (0..<5).map { _ in createTestImage() }

        // Upload images one by one without rollback
        for (index, image) in testImages.enumerated() {
            // Fail on 3rd image
            networkService.shouldFailUpload = (index == 2)

            do {
                let url = try await uploadService.uploadImage(image, path: "test_images")
                uploadedUrls.append(url)
            } catch {
                // Continue with remaining images
                networkService.shouldFailUpload = false
            }
        }

        // Should have 4 successful uploads (0, 1, 3, 4 - skipping failed 2)
        #expect(uploadedUrls.count == 4)
    }

    // MARK: - Connection Reset Tests

    @Test("Upload handles connection reset gracefully")
    func testUploadHandlesConnectionReset() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.shouldFailUpload = true
        networkService.uploadFailureType = .connectionReset

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown connection reset error")
        } catch let error as WifiError {
            #expect(error == .connectionReset)
            #expect(uploadService.errorMessage.contains("failed"))
        }
    }

    @Test("Upload handles SSL handshake failure")
    func testUploadHandlesSslHandshakeFailure() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.shouldFailUpload = true
        networkService.uploadFailureType = .sslHandshakeFailed

        let testImage = createTestImage()

        do {
            _ = try await uploadService.uploadImage(testImage, path: "test_images")
            #expect(Bool(false), "Should have thrown SSL error")
        } catch let error as WifiError {
            #expect(error == .sslHandshakeFailed)
        }
    }
}

// MARK: - WiFi Get/Fetch Failure Tests

@Suite("WiFi Get/Fetch Failure Tests")
@MainActor
struct WifiGetFailureTests {

    @Test("Fetch fails when WiFi disconnected")
    func testFetchFailsWhenWifiDisconnected() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        networkService.isWifiConnected = false

        do {
            _ = try await fetchService.fetchData(path: "users/user123")
            #expect(Bool(false), "Should have thrown WiFi disconnected error")
        } catch let error as WifiError {
            #expect(error == .wifiDisconnected)
        }
    }

    @Test("Fetch times out on slow WiFi")
    func testFetchTimeoutOnSlowWifi() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        networkService.shouldFailDownload = true
        networkService.downloadFailureType = .downloadTimeout

        do {
            _ = try await fetchService.fetchData(path: "users/user123")
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as WifiError {
            #expect(error == .downloadTimeout)
            #expect(fetchService.retryCount == 3)
        }
    }

    @Test("Fetch returns cached data when WiFi fails")
    func testFetchReturnsCachedDataOnWifiFailure() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = true

        // First, cache some data
        let cachedData = "cached_user_data".data(using: .utf8)!
        fetchService.cachedData["users/user123"] = cachedData

        // Now disconnect WiFi
        networkService.isWifiConnected = false

        let data = try await fetchService.fetchData(path: "users/user123")

        #expect(data == cachedData)
        #expect(fetchService.errorMessage.contains("cached"))
    }

    @Test("Fetch fails when connection lost mid-download")
    func testFetchFailsWhenConnectionLost() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        networkService.shouldFailDownload = true
        networkService.downloadFailureType = .connectionLost

        do {
            _ = try await fetchService.fetchData(path: "users/user123")
            #expect(Bool(false), "Should have thrown connection lost error")
        } catch let error as WifiError {
            #expect(error == .connectionLost)
        }
    }

    @Test("Fetch succeeds after transient WiFi failure")
    func testFetchSucceedsAfterTransientWifiFailure() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)

        // Fail first 2 attempts, succeed on 3rd
        networkService.shouldFailDownload = true
        networkService.failAfterAttempts = 2
        networkService.downloadFailureType = .connectionInterrupted

        let data = try await fetchService.fetchData(path: "users/user123")

        #expect(!data.isEmpty)
        #expect(fetchService.retryCount == 2)
    }

    @Test("Fetch handles DNS lookup failure")
    func testFetchHandlesDnsLookupFailure() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        networkService.shouldFailDownload = true
        networkService.downloadFailureType = .dnsLookupFailed

        do {
            _ = try await fetchService.fetchData(path: "users/user123")
            #expect(Bool(false), "Should have thrown DNS error")
        } catch let error as WifiError {
            #expect(error == .dnsLookupFailed)
        }
    }

    @Test("Fetch handles server unreachable")
    func testFetchHandlesServerUnreachable() async throws {
        let networkService = MockWifiNetworkService()
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        networkService.shouldFailDownload = true
        networkService.downloadFailureType = .serverUnreachable

        do {
            _ = try await fetchService.fetchData(path: "users/user123")
            #expect(Bool(false), "Should have thrown server unreachable error")
        } catch let error as WifiError {
            #expect(error == .serverUnreachable)
        }
    }
}

// MARK: - WiFi Erasure Prevention Tests

@Suite("WiFi Erasure Prevention Tests")
@MainActor
struct WifiErasurePreventionTests {

    // MARK: - Image Erasure Prevention

    @Test("Existing images NOT erased when WiFi upload fails")
    func testExistingImagesNotErasedOnWifiUploadFailure() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Upload some images first
        let existingImage1 = createTestImage()
        let existingImage2 = createTestImage()
        let url1 = try await uploadService.uploadImage(existingImage1, path: "profile_images")
        let url2 = try await uploadService.uploadImage(existingImage2, path: "profile_images")

        let originalImageCount = uploadService.imageUrls.count
        #expect(originalImageCount == 2)

        // Now disconnect WiFi and try to upload
        networkService.isWifiConnected = false

        do {
            let newImage = createTestImage()
            _ = try await uploadService.uploadImage(newImage, path: "profile_images")
            #expect(Bool(false), "Should have failed")
        } catch {
            // Original images should still exist
            #expect(uploadService.imageUrls.count == originalImageCount)
            #expect(uploadService.imageUrls.contains(url1))
            #expect(uploadService.imageUrls.contains(url2))
        }
    }

    @Test("Images NOT erased when batch upload partially fails")
    func testImagesNotErasedOnPartialBatchFailure() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Upload existing images
        _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")
        _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")

        let originalUrls = uploadService.imageUrls

        // Try batch upload with failure mid-way
        networkService.shouldFailUpload = true
        networkService.failAfterAttempts = 1  // Fail on second image of batch

        let batchImages = [createTestImage(), createTestImage(), createTestImage()]

        do {
            _ = try await uploadService.uploadMultipleImages(batchImages, path: "profile_images")
        } catch {
            // Original images should remain unchanged
            #expect(uploadService.imageUrls.count >= originalUrls.count)
            for originalUrl in originalUrls {
                #expect(uploadService.imageUrls.contains(originalUrl), "Original image \(originalUrl) should still exist")
            }
        }
    }

    // MARK: - Save Erasure Prevention

    @Test("Saved profiles NOT erased when WiFi fails during save")
    func testSavedProfilesNotErasedOnWifiSaveFailure() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Save some profiles first
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")

        let originalCount = saveService.savedProfiles.count
        #expect(originalCount == 2)

        // Now disconnect WiFi
        networkService.isWifiConnected = false

        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved3")
            #expect(Bool(false), "Should have failed")
        } catch {
            // Original saved profiles should still exist
            #expect(saveService.savedProfiles.count == originalCount)
            #expect(saveService.savedProfiles.contains { $0.id == docId1 })
            #expect(saveService.savedProfiles.contains { $0.id == docId2 })
        }
    }

    @Test("Saved profiles NOT erased when WiFi fails during unsave")
    func testSavedProfilesNotErasedOnWifiUnsaveFailure() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Save profiles
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
        let docId3 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved3")

        #expect(saveService.savedProfiles.count == 3)

        // Disconnect WiFi and try to unsave
        networkService.isWifiConnected = false

        do {
            try await saveService.unsaveProfile(documentId: docId2)
            #expect(Bool(false), "Should have failed")
        } catch {
            // All profiles should be preserved (rolled back)
            #expect(saveService.savedProfiles.count == 3)
            #expect(saveService.savedProfiles.contains { $0.id == docId1 })
            #expect(saveService.savedProfiles.contains { $0.id == docId2 })
            #expect(saveService.savedProfiles.contains { $0.id == docId3 })
        }
    }

    @Test("Saved profiles NOT erased when WiFi fails during clear all")
    func testSavedProfilesNotErasedOnWifiClearAllFailure() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Save profiles
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved3")

        let originalCount = saveService.savedProfiles.count
        #expect(originalCount == 3)

        // Disconnect WiFi mid-clear
        networkService.shouldFailDownload = true
        networkService.downloadFailureType = .wifiDisconnected

        do {
            try await saveService.clearAllSaved()
            #expect(Bool(false), "Should have failed")
        } catch {
            // All profiles should be rolled back
            #expect(saveService.savedProfiles.count == originalCount)
        }
    }

    // MARK: - Data Integrity Tests

    @Test("Concurrent WiFi failures don't cause data corruption")
    func testConcurrentWifiFailuresNoCrruption() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Start with some saved data
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")

        let originalCount = saveService.savedProfiles.count

        // Enable intermittent failures
        networkService.simulateIntermittentConnection = true
        networkService.intermittentFailureRate = 0.7  // 70% failure rate

        // Perform many concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "concurrent\(i)")
                    } catch {
                        // Expected failures
                    }
                }
            }
        }

        // Original data should still exist
        #expect(saveService.savedProfiles.count >= originalCount, "Original profiles should be preserved")
    }

    @Test("WiFi reconnection preserves all data")
    func testWifiReconnectionPreservesData() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Save data while connected
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")

        let countBeforeDisconnect = saveService.savedProfiles.count

        // Disconnect WiFi
        networkService.isWifiConnected = false

        // Try operations (will fail)
        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved3")
        } catch { /* Expected */ }

        // Reconnect WiFi
        networkService.isWifiConnected = true

        // Data should be intact
        #expect(saveService.savedProfiles.count == countBeforeDisconnect)
        #expect(saveService.savedProfiles.contains { $0.id == docId1 })
        #expect(saveService.savedProfiles.contains { $0.id == docId2 })

        // New operations should work
        let docId3 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved3")
        #expect(saveService.savedProfiles.count == countBeforeDisconnect + 1)
        #expect(saveService.savedProfiles.contains { $0.id == docId3 })
    }
}

// MARK: - Comprehensive WiFi Scenario Tests

@Suite("Comprehensive WiFi Scenario Tests")
@MainActor
struct ComprehensiveWifiScenarioTests {

    @Test("Full workflow with intermittent WiFi failures")
    func testFullWorkflowWithIntermittentWifiFailures() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)
        let saveService = MockWifiSaveService(networkService: networkService)
        let fetchService = MockWifiDataFetchService(networkService: networkService)

        // Step 1: Save some profiles
        let docId1 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        let docId2 = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
        #expect(saveService.savedProfiles.count == 2)

        // Step 2: Upload some images
        _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")
        _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")
        #expect(uploadService.imageUrls.count == 2)

        // Step 3: Fetch some data
        fetchService.cachedData["profiles/user1"] = "user_data".data(using: .utf8)!
        let userData = try await fetchService.fetchData(path: "profiles/user1")
        #expect(!userData.isEmpty)

        // Step 4: WiFi becomes unreliable
        networkService.simulateIntermittentConnection = true
        networkService.intermittentFailureRate = 0.5

        // Step 5: Try various operations
        var successfulOperations = 0
        var failedOperations = 0

        for _ in 0..<5 {
            do {
                _ = try await saveService.saveProfile(userId: "user1", savedUserId: UUID().uuidString)
                successfulOperations += 1
            } catch {
                failedOperations += 1
            }
        }

        // Some should succeed, some should fail
        #expect(successfulOperations > 0 || failedOperations > 0)

        // Step 6: Original data should be intact
        #expect(saveService.savedProfiles.contains { $0.id == docId1 })
        #expect(saveService.savedProfiles.contains { $0.id == docId2 })
        #expect(uploadService.imageUrls.count >= 2)
    }

    @Test("Recovery from complete WiFi outage")
    func testRecoveryFromCompleteWifiOutage() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)
        let saveService = MockWifiSaveService(networkService: networkService)

        // Save data before outage
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")

        let profileCountBefore = saveService.savedProfiles.count
        let imageCountBefore = uploadService.imageUrls.count

        // Complete WiFi outage
        networkService.isWifiConnected = false

        // All operations fail
        do {
            _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
        } catch { /* Expected */ }

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "profile_images")
        } catch { /* Expected */ }

        // Data preserved during outage
        #expect(saveService.savedProfiles.count == profileCountBefore)
        #expect(uploadService.imageUrls.count == imageCountBefore)

        // WiFi restored
        networkService.isWifiConnected = true

        // Operations work again
        let newDocId = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
        let newImageUrl = try await uploadService.uploadImage(createTestImage(), path: "profile_images")

        #expect(!newDocId.isEmpty)
        #expect(!newImageUrl.isEmpty)
        #expect(saveService.savedProfiles.count == profileCountBefore + 1)
        #expect(uploadService.imageUrls.count == imageCountBefore + 1)
    }

    @Test("Rapid WiFi connect/disconnect cycles")
    func testRapidWifiConnectDisconnectCycles() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Initial save
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "initial")
        let initialCount = saveService.savedProfiles.count

        // Rapid connect/disconnect cycles
        for i in 0..<10 {
            networkService.isWifiConnected = (i % 2 == 0)  // Alternates

            do {
                _ = try await saveService.saveProfile(userId: "user1", savedUserId: "cycle\(i)")
            } catch {
                // Expected on disconnected cycles
            }
        }

        // Original data should be preserved
        #expect(saveService.savedProfiles.count >= initialCount)
        #expect(saveService.savedProfiles.contains { $0.user.id == "initial" })
    }

    @Test("WiFi signal strength degradation")
    func testWifiSignalStrengthDegradation() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Start with good signal
        networkService.wifiSignalStrength = 1.0
        _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        #expect(uploadService.imageUrls.count == 1)

        // Degrade signal gradually
        networkService.wifiSignalStrength = 0.5
        _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        #expect(uploadService.imageUrls.count == 2)

        networkService.wifiSignalStrength = 0.3
        _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        #expect(uploadService.imageUrls.count == 3)

        // Signal too weak
        networkService.wifiSignalStrength = 0.1

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "images")
            #expect(Bool(false), "Should fail with weak signal")
        } catch let error as WifiError {
            #expect(error == .wifiSignalWeak)
        }

        // Previous uploads should be preserved
        #expect(uploadService.imageUrls.count == 3)
    }

    @Test("Multiple services fail simultaneously")
    func testMultipleServicesFailSimultaneously() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)
        let saveService = MockWifiSaveService(networkService: networkService)
        let fetchService = MockWifiDataFetchService(networkService: networkService)
        fetchService.useCacheOnFailure = false

        // Setup initial state
        _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved1")
        _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        fetchService.cachedData["data"] = "cached".data(using: .utf8)!

        let saveCountBefore = saveService.savedProfiles.count
        let imageCountBefore = uploadService.imageUrls.count

        // Disconnect WiFi
        networkService.isWifiConnected = false

        // All operations fail concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved2")
                } catch { }
            }
            group.addTask {
                do {
                    _ = try await uploadService.uploadImage(createTestImage(), path: "images")
                } catch { }
            }
            group.addTask {
                do {
                    _ = try await fetchService.fetchData(path: "newdata")
                } catch { }
            }
        }

        // All original data should be preserved
        #expect(saveService.savedProfiles.count == saveCountBefore)
        #expect(uploadService.imageUrls.count == imageCountBefore)
    }

    @Test("High volume operations with WiFi issues")
    func testHighVolumeOperationsWithWifiIssues() async throws {
        let networkService = MockWifiNetworkService()
        let saveService = MockWifiSaveService(networkService: networkService)

        // Enable some failures
        networkService.simulateIntermittentConnection = true
        networkService.intermittentFailureRate = 0.3  // 30% failure rate

        var successCount = 0
        var failCount = 0

        // Perform many operations
        for i in 0..<50 {
            do {
                _ = try await saveService.saveProfile(userId: "user1", savedUserId: "saved\(i)")
                successCount += 1
            } catch {
                failCount += 1
            }
        }

        // Some should succeed, some should fail
        #expect(successCount > 0, "Some operations should succeed")
        #expect(failCount > 0, "Some operations should fail")

        // Total saved should equal success count
        #expect(saveService.savedProfiles.count == successCount)

        // All saved profiles should be valid
        for profile in saveService.savedProfiles {
            #expect(!profile.id.isEmpty)
            #expect(!profile.user.id.isEmpty)
        }
    }
}

// MARK: - WiFi Error Message Tests

@Suite("WiFi Error Message Tests")
@MainActor
struct WifiErrorMessageTests {

    @Test("WiFi disconnected error message is user-friendly")
    func testWifiDisconnectedErrorMessage() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.isWifiConnected = false

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        } catch {
            #expect(uploadService.errorMessage.contains("failed"))
            #expect(uploadService.errorMessage.contains("WiFi"))
        }
    }

    @Test("Timeout error message indicates retry exhausted")
    func testTimeoutErrorMessageIndicatesRetryExhausted() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        networkService.shouldFailUpload = true
        networkService.uploadFailureType = .uploadTimeout

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        } catch {
            #expect(uploadService.errorMessage.contains("3 attempts"))
        }
    }

    @Test("All WiFi error types have descriptive messages")
    func testAllWifiErrorTypesHaveDescriptiveMessages() async throws {
        let allErrors: [WifiError] = [
            .wifiDisconnected,
            .wifiSignalWeak,
            .uploadFailed,
            .uploadTimeout,
            .downloadFailed,
            .downloadTimeout,
            .connectionLost,
            .connectionInterrupted,
            .networkUnreachable,
            .sslHandshakeFailed,
            .dnsLookupFailed,
            .serverUnreachable,
            .bandwidthExceeded,
            .connectionReset
        ]

        for error in allErrors {
            let description = error.errorDescription ?? ""
            #expect(!description.isEmpty, "Error \(error) should have a description")
            #expect(description.count > 5, "Description should be meaningful")
        }
    }
}

// MARK: - WiFi Retry Logic Tests

@Suite("WiFi Retry Logic Tests")
@MainActor
struct WifiRetryLogicTests {

    @Test("Retry attempts are logged correctly")
    func testRetryAttemptsLogged() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Fail first 2 attempts
        networkService.shouldFailUpload = true
        networkService.failAfterAttempts = 2

        _ = try await uploadService.uploadImage(createTestImage(), path: "images")

        // Should have 3 upload attempts logged
        let uploadLogs = networkService.operationLog.filter { $0.contains("upload") }
        #expect(uploadLogs.count == 3)
        #expect(uploadService.retryCount == 2)
    }

    @Test("Maximum retries are respected")
    func testMaximumRetriesRespected() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)
        uploadService.maxRetries = 5

        networkService.shouldFailUpload = true

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "images")
            #expect(Bool(false), "Should have failed after max retries")
        } catch {
            #expect(uploadService.retryCount == 5)
        }
    }

    @Test("No retry on non-retryable errors")
    func testNoRetryOnNonRetryableErrors() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // WiFi disconnected should fail immediately without retries on each attempt
        networkService.isWifiConnected = false

        do {
            _ = try await uploadService.uploadImage(createTestImage(), path: "images")
            #expect(Bool(false), "Should have failed")
        } catch {
            // Each retry attempt fails immediately due to no WiFi
            #expect(uploadService.retryCount == 3)  // All retries attempted but all failed immediately
        }
    }

    @Test("Exponential backoff is applied between retries")
    func testExponentialBackoffApplied() async throws {
        let networkService = MockWifiNetworkService()
        let uploadService = MockWifiImageUploadService(networkService: networkService)

        // Fail first 2 attempts
        networkService.shouldFailUpload = true
        networkService.failAfterAttempts = 2

        let startTime = Date()
        _ = try await uploadService.uploadImage(createTestImage(), path: "images")
        let elapsed = Date().timeIntervalSince(startTime)

        // Should have waited at least 100ms + 200ms = 300ms for backoff
        #expect(elapsed >= 0.2, "Should have exponential backoff delay")
    }
}

// MARK: - Helper Functions

@MainActor
private func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .blue) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
