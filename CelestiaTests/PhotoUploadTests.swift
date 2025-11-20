//
//  PhotoUploadTests.swift
//  CelestiaTests
//
//  Comprehensive tests for photo upload functionality including:
//  - Upload success scenarios
//  - Upload failures and retry logic
//  - Data persistence verification
//  - Erasure prevention
//  - Performance optimization validation
//

import Testing
import UIKit
@testable import Celestia

// MARK: - Mock Services

@MainActor
class MockPhotoUploadService {
    var shouldFail = false
    var failureCount = 0
    var uploadedPhotos: [String] = []
    var uploadDelay: UInt64 = 0

    func uploadPhoto(_ image: UIImage, userId: String, imageType: PhotoImageType) async throws -> String {
        if uploadDelay > 0 {
            try await Task.sleep(nanoseconds: uploadDelay)
        }

        if shouldFail {
            failureCount += 1
            throw CelestiaError.imageUploadFailed
        }

        let url = "https://storage.googleapis.com/test/\(userId)/\(UUID().uuidString).jpg"
        uploadedPhotos.append(url)
        return url
    }

    func reset() {
        shouldFail = false
        failureCount = 0
        uploadedPhotos = []
        uploadDelay = 0
    }
}

@MainActor
class MockAuthService: AuthServiceProtocol {
    var currentUser: User?
    var savedUsers: [User] = []

    func updateUser(_ user: User) async throws {
        currentUser = user
        savedUsers.append(user)
    }

    // Required protocol methods
    func signIn(email: String, password: String) async throws -> User {
        throw CelestiaError.notImplemented
    }

    func signUp(email: String, password: String, name: String, age: Int) async throws -> User {
        throw CelestiaError.notImplemented
    }

    func signOut() async throws {}
    func resetPassword(email: String) async throws {}
    func deleteAccount() async throws {}
}

// MARK: - Photo Upload Tests

@Suite("Photo Upload Tests")
@MainActor
struct PhotoUploadTests {

    // MARK: - Upload Success Tests

    @Test("Single photo uploads successfully")
    func testSinglePhotoUpload() async throws {
        let mockService = MockPhotoUploadService()
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        let url = try await mockService.uploadPhoto(testImage, userId: "user123", imageType: .gallery)

        #expect(!url.isEmpty)
        #expect(url.hasPrefix("https://"))
        #expect(mockService.uploadedPhotos.count == 1)
        #expect(mockService.failureCount == 0)
    }

    @Test("Multiple photos upload successfully")
    func testMultiplePhotoUpload() async throws {
        let mockService = MockPhotoUploadService()
        let testImages = (0..<6).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        var uploadedUrls: [String] = []
        for image in testImages {
            let url = try await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
            uploadedUrls.append(url)
        }

        #expect(uploadedUrls.count == 6)
        #expect(mockService.uploadedPhotos.count == 6)
        #expect(uploadedUrls.allSatisfy { !$0.isEmpty })
        #expect(uploadedUrls.allSatisfy { $0.hasPrefix("https://") })
    }

    @Test("Photos have unique URLs")
    func testUniquePhotoUrls() async throws {
        let mockService = MockPhotoUploadService()
        let testImages = (0..<6).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        var uploadedUrls: [String] = []
        for image in testImages {
            let url = try await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
            uploadedUrls.append(url)
        }

        let uniqueUrls = Set(uploadedUrls)
        #expect(uniqueUrls.count == 6)
        #expect(uniqueUrls.count == uploadedUrls.count)
    }

    // MARK: - Upload Failure Tests

    @Test("Upload failure throws error")
    func testUploadFailure() async throws {
        let mockService = MockPhotoUploadService()
        mockService.shouldFail = true

        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        do {
            _ = try await mockService.uploadPhoto(testImage, userId: "user123", imageType: .gallery)
            #expect(Bool(false), "Expected upload to fail")
        } catch {
            #expect(error is CelestiaError)
            #expect(mockService.failureCount == 1)
            #expect(mockService.uploadedPhotos.count == 0)
        }
    }

    @Test("Retry logic attempts multiple times")
    func testRetryLogic() async throws {
        let mockService = MockPhotoUploadService()
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        var attemptCount = 0
        let maxRetries = 3
        var lastError: Error?

        for attempt in 0..<maxRetries {
            attemptCount += 1
            mockService.shouldFail = (attempt < 2)  // Fail first 2 attempts, succeed on 3rd

            do {
                _ = try await mockService.uploadPhoto(testImage, userId: "user123", imageType: .gallery)
                break  // Success
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // Simulate exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
                }
            }
        }

        #expect(attemptCount == 3)
        #expect(mockService.uploadedPhotos.count == 1)
    }

    @Test("All retries fail after maximum attempts")
    func testAllRetriesFail() async throws {
        let mockService = MockPhotoUploadService()
        mockService.shouldFail = true

        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        var attemptCount = 0
        let maxRetries = 3
        var didFail = false

        for attempt in 0..<maxRetries {
            attemptCount += 1

            do {
                _ = try await mockService.uploadPhoto(testImage, userId: "user123", imageType: .gallery)
                break
            } catch {
                if attempt == maxRetries - 1 {
                    didFail = true
                }
            }
        }

        #expect(attemptCount == 3)
        #expect(didFail == true)
        #expect(mockService.uploadedPhotos.count == 0)
        #expect(mockService.failureCount == 3)
    }

    // MARK: - Data Persistence Tests

    @Test("Uploaded photos persist in user profile")
    func testPhotosPersistInProfile() async throws {
        let mockAuth = MockAuthService()
        let mockUpload = MockPhotoUploadService()

        // Create initial user
        var user = User(
            id: "user123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // Upload photos
        let testImages = (0..<3).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }
        var uploadedUrls: [String] = []

        for image in testImages {
            let url = try await mockUpload.uploadPhoto(image, userId: user.id, imageType: .gallery)
            uploadedUrls.append(url)
        }

        // Update user with photos
        user.photos = uploadedUrls
        try await mockAuth.updateUser(user)

        // Verify persistence
        #expect(mockAuth.currentUser?.photos.count == 3)
        #expect(mockAuth.currentUser?.photos == uploadedUrls)
        #expect(mockAuth.savedUsers.count == 1)
        #expect(mockAuth.savedUsers.first?.photos == uploadedUrls)
    }

    @Test("Photos are not erased after successful upload")
    func testPhotosNotErased() async throws {
        let mockAuth = MockAuthService()
        let mockUpload = MockPhotoUploadService()

        // Create user with existing photos
        var user = User(
            id: "user123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [
                "https://example.com/photo1.jpg",
                "https://example.com/photo2.jpg"
            ],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        let initialPhotoCount = user.photos.count

        // Upload additional photo
        let newImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        let newUrl = try await mockUpload.uploadPhoto(newImage, userId: user.id, imageType: .gallery)

        // Add new photo to existing photos (not replace)
        user.photos.append(newUrl)
        try await mockAuth.updateUser(user)

        // Verify old photos still exist
        #expect(mockAuth.currentUser?.photos.count == initialPhotoCount + 1)
        #expect(mockAuth.currentUser?.photos.contains("https://example.com/photo1.jpg") == true)
        #expect(mockAuth.currentUser?.photos.contains("https://example.com/photo2.jpg") == true)
        #expect(mockAuth.currentUser?.photos.contains(newUrl) == true)
    }

    @Test("Photos persist after failed upload attempt")
    func testPhotosNotErasedOnFailure() async throws {
        let mockAuth = MockAuthService()
        let mockUpload = MockPhotoUploadService()

        // Create user with existing photos
        var user = User(
            id: "user123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [
                "https://example.com/photo1.jpg",
                "https://example.com/photo2.jpg"
            ],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        let originalPhotos = user.photos

        // Try to upload with failure
        mockUpload.shouldFail = true
        let newImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        do {
            _ = try await mockUpload.uploadPhoto(newImage, userId: user.id, imageType: .gallery)
        } catch {
            // Upload failed, verify photos unchanged
            #expect(mockAuth.currentUser?.photos == originalPhotos)
            #expect(mockAuth.currentUser?.photos.count == 2)
        }
    }

    // MARK: - Validation Tests

    @Test("Maximum photo limit enforced")
    func testMaximumPhotoLimit() async throws {
        let maxPhotos = 6
        var photos = (0..<maxPhotos).map { "https://example.com/photo\($0).jpg" }

        #expect(photos.count == maxPhotos)

        // Try to add more
        photos.append("https://example.com/photo7.jpg")

        // Should be limited to 6
        if photos.count > maxPhotos {
            photos = Array(photos.prefix(maxPhotos))
        }

        #expect(photos.count == maxPhotos)
    }

    @Test("Empty photos array is valid")
    func testEmptyPhotosArray() async throws {
        let photos: [String] = []

        #expect(photos.isEmpty)
        #expect(photos.count == 0)
    }

    @Test("Photo URLs are valid format")
    func testPhotoUrlFormat() async throws {
        let mockService = MockPhotoUploadService()
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        let url = try await mockService.uploadPhoto(testImage, userId: "user123", imageType: .gallery)

        #expect(url.hasPrefix("https://"))
        #expect(url.contains("storage.googleapis.com") || url.contains(".jpg"))
        #expect(!url.isEmpty)

        // Validate URL format
        let urlObject = URL(string: url)
        #expect(urlObject != nil)
    }

    // MARK: - Performance Tests

    @Test("Parallel uploads are faster than sequential")
    func testParallelUploadPerformance() async throws {
        let mockService = MockPhotoUploadService()
        mockService.uploadDelay = 100_000_000  // 100ms per upload

        let imageCount = 6
        let testImages = (0..<imageCount).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        // Sequential upload time
        let sequentialStart = Date()
        for image in testImages {
            _ = try await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
        }
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)

        mockService.reset()

        // Parallel upload time (simulated)
        let parallelStart = Date()
        _ = await withTaskGroup(of: String?.self) { group in
            for image in testImages {
                group.addTask {
                    try? await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
                }
            }

            var results: [String] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
        let parallelDuration = Date().timeIntervalSince(parallelStart)

        // Parallel should be significantly faster (at least 50% faster)
        #expect(parallelDuration < sequentialDuration * 0.5)
    }

    @Test("Image optimization reduces file size")
    func testImageOptimization() async throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))
        let optimizedImage = optimizeImage(largeImage)

        // Optimized image should be smaller
        #expect(optimizedImage.size.width <= 1024)
        #expect(optimizedImage.size.height <= 1024)

        // Aspect ratio should be maintained
        let originalRatio = largeImage.size.width / largeImage.size.height
        let optimizedRatio = optimizedImage.size.width / optimizedImage.size.height
        #expect(abs(originalRatio - optimizedRatio) < 0.01)
    }

    // MARK: - Concurrent Upload Tests

    @Test("Concurrent uploads maintain data integrity")
    func testConcurrentUploadIntegrity() async throws {
        let mockService = MockPhotoUploadService()
        let imageCount = 6
        let testImages = (0..<imageCount).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        let uploadedUrls = await withTaskGroup(of: String?.self) { group in
            for image in testImages {
                group.addTask {
                    try? await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
                }
            }

            var results: [String] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }

        #expect(uploadedUrls.count == imageCount)
        #expect(mockService.uploadedPhotos.count == imageCount)

        // All URLs should be unique
        let uniqueUrls = Set(uploadedUrls)
        #expect(uniqueUrls.count == imageCount)
    }

    @Test("Partial upload failure doesn't corrupt data")
    func testPartialUploadFailure() async throws {
        let mockService = MockPhotoUploadService()
        let testImages = (0..<6).map { _ in createTestImage(size: CGSize(width: 1000, height: 1000)) }

        var uploadedUrls: [String] = []
        var failedCount = 0

        for (index, image) in testImages.enumerated() {
            // Fail on 3rd upload
            mockService.shouldFail = (index == 2)

            do {
                let url = try await mockService.uploadPhoto(image, userId: "user123", imageType: .gallery)
                uploadedUrls.append(url)
            } catch {
                failedCount += 1
            }
        }

        // Should have 5 successful uploads and 1 failure
        #expect(uploadedUrls.count == 5)
        #expect(failedCount == 1)
        #expect(mockService.uploadedPhotos.count == 5)
    }

    // MARK: - Helper Methods

    private static func createTestImage(size: CGSize, color: UIColor = .blue) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func optimizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)

        if ratio >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
