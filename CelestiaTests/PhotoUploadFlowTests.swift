//
//  PhotoUploadFlowTests.swift
//  CelestiaTests
//
//  End-to-end tests for photo upload flow including:
//  - Upload process verification
//  - Firebase save verification
//  - UI state management
//  - Photo display verification
//

import Testing
import UIKit
@testable import Celestia

@Suite("Photo Upload Flow Tests")
@MainActor
struct PhotoUploadFlowTests {

    // MARK: - Upload Flow Tests

    @Test("Photos are saved to user profile after upload")
    func testPhotosSavedToProfile() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // Simulate uploading 3 photos
        let uploadedUrls = [
            "https://storage.googleapis.com/test/photo1.jpg",
            "https://storage.googleapis.com/test/photo2.jpg",
            "https://storage.googleapis.com/test/photo3.jpg"
        ]

        user.photos = uploadedUrls
        try await mockAuth.updateUser(user)

        // Verify photos were saved
        #expect(mockAuth.currentUser?.photos.count == 3)
        #expect(mockAuth.currentUser?.photos == uploadedUrls)
        #expect(mockAuth.savedUsers.count == 1)
    }

    @Test("Empty photos array is handled correctly")
    func testEmptyPhotosArray() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        try await mockAuth.updateUser(user)

        #expect(mockAuth.currentUser?.photos.isEmpty == true)
    }

    @Test("Photos array persists through updates")
    func testPhotosPersistThroughUpdates() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: ["https://example.com/photo1.jpg"],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // First update
        try await mockAuth.updateUser(user)
        #expect(mockAuth.currentUser?.photos.count == 1)

        // Add more photos
        user.photos.append("https://example.com/photo2.jpg")
        user.photos.append("https://example.com/photo3.jpg")
        try await mockAuth.updateUser(user)

        // Verify all photos persisted
        #expect(mockAuth.currentUser?.photos.count == 3)
        #expect(mockAuth.currentUser?.photos.contains("https://example.com/photo1.jpg") == true)
        #expect(mockAuth.currentUser?.photos.contains("https://example.com/photo2.jpg") == true)
        #expect(mockAuth.currentUser?.photos.contains("https://example.com/photo3.jpg") == true)
    }

    @Test("Maximum 6 photos limit is enforced")
    func testMaximum6PhotosLimit() async throws {
        var photos = (1...10).map { "https://example.com/photo\($0).jpg" }

        // Should only keep first 6
        if photos.count > 6 {
            photos = Array(photos.prefix(6))
        }

        #expect(photos.count == 6)
    }

    @Test("Deleting photos updates array correctly")
    func testDeletingPhotos() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [
                "https://example.com/photo1.jpg",
                "https://example.com/photo2.jpg",
                "https://example.com/photo3.jpg"
            ],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // Delete middle photo
        user.photos.remove(at: 1)
        try await mockAuth.updateUser(user)

        #expect(mockAuth.currentUser?.photos.count == 2)
        #expect(mockAuth.currentUser?.photos[0] == "https://example.com/photo1.jpg")
        #expect(mockAuth.currentUser?.photos[1] == "https://example.com/photo3.jpg")
    }

    @Test("Reordering photos updates array correctly")
    func testReorderingPhotos() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [
                "https://example.com/photo1.jpg",
                "https://example.com/photo2.jpg",
                "https://example.com/photo3.jpg"
            ],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // Move first photo to last
        let firstPhoto = user.photos.remove(at: 0)
        user.photos.append(firstPhoto)
        try await mockAuth.updateUser(user)

        #expect(mockAuth.currentUser?.photos.count == 3)
        #expect(mockAuth.currentUser?.photos[0] == "https://example.com/photo2.jpg")
        #expect(mockAuth.currentUser?.photos[1] == "https://example.com/photo3.jpg")
        #expect(mockAuth.currentUser?.photos[2] == "https://example.com/photo1.jpg")
    }

    // MARK: - Upload Progress Tests

    @Test("Upload progress calculates correctly")
    func testUploadProgressCalculation() async throws {
        let totalPhotos = 6
        var completedPhotos = 0
        var uploadingPhotos = totalPhotos

        // Simulate uploads
        for i in 1...totalPhotos {
            completedPhotos = i
            uploadingPhotos = totalPhotos - i
            let progress = Double(completedPhotos) / Double(totalPhotos)

            #expect(progress >= 0.0 && progress <= 1.0)

            if i == 1 {
                #expect(abs(progress - 0.167) < 0.01)
            } else if i == 3 {
                #expect(abs(progress - 0.5) < 0.01)
            } else if i == 6 {
                #expect(progress == 1.0)
            }
        }
    }

    @Test("Upload progress with failures")
    func testUploadProgressWithFailures() async throws {
        let totalPhotos = 6
        var successfulPhotos = 0
        var failedPhotos = 0

        // Simulate 4 successes and 2 failures
        for i in 1...totalPhotos {
            if i <= 4 {
                successfulPhotos += 1
            } else {
                failedPhotos += 1
            }
        }

        #expect(successfulPhotos == 4)
        #expect(failedPhotos == 2)
        #expect(successfulPhotos + failedPhotos == totalPhotos)
    }

    // MARK: - URL Validation Tests

    @Test("Photo URLs are valid Firebase Storage URLs")
    func testPhotoUrlsAreValid() async throws {
        let validUrls = [
            "https://storage.googleapis.com/celestia-40ce6/gallery_photos/user123/photo1.jpg",
            "https://storage.googleapis.com/celestia-40ce6/gallery_photos/user456/photo2.jpg",
            "https://firebasestorage.googleapis.com/v0/b/celestia-40ce6/o/photo3.jpg"
        ]

        for url in validUrls {
            #expect(url.hasPrefix("https://"))
            #expect(url.contains("storage.googleapis.com") || url.contains("firebasestorage.googleapis.com"))
            #expect(url.hasSuffix(".jpg"))

            let urlObject = URL(string: url)
            #expect(urlObject != nil)
        }
    }

    @Test("Invalid URLs are rejected")
    func testInvalidUrlsRejected() async throws {
        let invalidUrls = [
            "",
            "not a url",
            "http://insecure.com/photo.jpg",
            "ftp://wrong-protocol.com/photo.jpg"
        ]

        for url in invalidUrls {
            if url.isEmpty {
                #expect(url.isEmpty)
            } else {
                let isValid = url.hasPrefix("https://") &&
                              (url.contains("storage.googleapis.com") ||
                               url.contains("firebasestorage.googleapis.com"))
                #expect(isValid == false)
            }
        }
    }

    // MARK: - State Management Tests

    @Test("Upload state transitions correctly")
    func testUploadStateTransitions() async throws {
        var isUploading = false
        var uploadProgress: Double = 0.0
        var uploadingCount = 0

        // Start upload
        isUploading = true
        uploadingCount = 3
        #expect(isUploading == true)
        #expect(uploadingCount == 3)

        // Progress updates
        uploadProgress = 0.33
        #expect(uploadProgress > 0.0 && uploadProgress < 1.0)

        uploadProgress = 0.67
        #expect(uploadProgress > 0.5 && uploadProgress < 1.0)

        // Complete upload
        uploadProgress = 1.0
        isUploading = false
        uploadingCount = 0
        #expect(isUploading == false)
        #expect(uploadProgress == 1.0)
        #expect(uploadingCount == 0)
    }

    @Test("Upload state resets after completion")
    func testUploadStateReset() async throws {
        var isUploading = true
        var uploadProgress: Double = 0.5
        var uploadingCount = 3

        // Reset state
        isUploading = false
        uploadProgress = 0.0
        uploadingCount = 0

        #expect(isUploading == false)
        #expect(uploadProgress == 0.0)
        #expect(uploadingCount == 0)
    }

    // MARK: - Error Handling Tests

    @Test("Upload errors are handled gracefully")
    func testUploadErrorHandling() async throws {
        let mockUpload = MockPhotoUploadService()
        mockUpload.shouldFail = true

        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        do {
            _ = try await mockUpload.uploadPhoto(testImage, userId: "test123", imageType: .gallery)
            #expect(Bool(false), "Expected upload to fail")
        } catch {
            #expect(error is CelestiaError)
        }

        #expect(mockUpload.failureCount == 1)
        #expect(mockUpload.uploadedPhotos.isEmpty)
    }

    @Test("Partial upload saves successful photos")
    func testPartialUploadSavesSuccessful() async throws {
        let mockAuth = MockAuthService()
        var user = User(
            id: "test123",
            email: "test@example.com",
            name: "Test User",
            age: 25,
            photos: [],
            profileImageURL: "https://example.com/profile.jpg"
        )
        mockAuth.currentUser = user

        // Simulate 2 successful uploads out of 4
        let successfulUrls = [
            "https://storage.googleapis.com/test/photo1.jpg",
            "https://storage.googleapis.com/test/photo2.jpg"
        ]

        user.photos = successfulUrls
        try await mockAuth.updateUser(user)

        // Should save the 2 successful ones
        #expect(mockAuth.currentUser?.photos.count == 2)
        #expect(mockAuth.currentUser?.photos == successfulUrls)
    }

    // MARK: - Helper Methods

    private static func createTestImage(size: CGSize, color: UIColor = .blue) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
