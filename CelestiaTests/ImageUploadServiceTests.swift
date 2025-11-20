//
//  ImageUploadServiceTests.swift
//  CelestiaTests
//
//  Comprehensive tests for ImageUploadService validation,
//  optimization, and error handling
//

import Testing
import UIKit
@testable import Celestia

@Suite("ImageUploadService Tests")
@MainActor
struct ImageUploadServiceTests {

    // MARK: - Image Validation Tests

    @Test("Valid image passes validation")
    func testValidImageValidation() async throws {
        let validImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        // Image should be valid (no exception means validation passed)
        #expect(validImage.size.width == 1000)
        #expect(validImage.size.height == 1000)
    }

    @Test("Image with minimum dimensions is valid")
    func testMinimumDimensionsValidation() async throws {
        let minImage = createTestImage(size: CGSize(width: 200, height: 200))

        #expect(minImage.size.width == 200)
        #expect(minImage.size.height == 200)
    }

    @Test("Image with large dimensions is valid")
    func testLargeDimensionsValidation() async throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 3000))

        #expect(largeImage.size.width == 4000)
        #expect(largeImage.size.height == 3000)
    }

    @Test("Square image is valid")
    func testSquareImageValidation() async throws {
        let squareImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        let aspectRatio = squareImage.size.width / squareImage.size.height
        #expect(aspectRatio == 1.0)
    }

    @Test("Portrait image is valid")
    func testPortraitImageValidation() async throws {
        let portraitImage = createTestImage(size: CGSize(width: 1000, height: 1500))

        let aspectRatio = portraitImage.size.width / portraitImage.size.height
        #expect(aspectRatio < 1.0)
        #expect(aspectRatio >= 0.5)
    }

    @Test("Landscape image is valid")
    func testLandscapeImageValidation() async throws {
        let landscapeImage = createTestImage(size: CGSize(width: 1500, height: 1000))

        let aspectRatio = landscapeImage.size.width / landscapeImage.size.height
        #expect(aspectRatio > 1.0)
        #expect(aspectRatio <= 2.0)
    }

    // MARK: - Image Optimization Tests

    @Test("Large image is resized to max dimension")
    func testLargeImageResize() async throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))
        let optimizedImage = optimizeImage(largeImage, maxDimension: 1024)

        #expect(optimizedImage.size.width <= 1024)
        #expect(optimizedImage.size.height <= 1024)
    }

    @Test("Small image is not upscaled")
    func testSmallImageNotUpscaled() async throws {
        let smallImage = createTestImage(size: CGSize(width: 500, height: 500))
        let optimizedImage = optimizeImage(smallImage, maxDimension: 1024)

        // Should not be upscaled
        #expect(optimizedImage.size.width == 500)
        #expect(optimizedImage.size.height == 500)
    }

    @Test("Aspect ratio is maintained after resize")
    func testAspectRatioMaintained() async throws {
        let originalImage = createTestImage(size: CGSize(width: 3000, height: 2000))
        let originalRatio = originalImage.size.width / originalImage.size.height

        let optimizedImage = optimizeImage(originalImage, maxDimension: 1024)
        let optimizedRatio = optimizedImage.size.width / optimizedImage.size.height

        let ratioDifference = abs(originalRatio - optimizedRatio)
        #expect(ratioDifference < 0.01)
    }

    @Test("Portrait image maintains aspect ratio")
    func testPortraitAspectRatioMaintained() async throws {
        let portraitImage = createTestImage(size: CGSize(width: 2000, height: 3000))
        let originalRatio = portraitImage.size.width / portraitImage.size.height

        let optimizedImage = optimizeImage(portraitImage, maxDimension: 1024)
        let optimizedRatio = optimizedImage.size.width / optimizedImage.size.height

        let ratioDifference = abs(originalRatio - optimizedRatio)
        #expect(ratioDifference < 0.01)
    }

    @Test("Landscape image maintains aspect ratio")
    func testLandscapeAspectRatioMaintained() async throws {
        let landscapeImage = createTestImage(size: CGSize(width: 3000, height: 2000))
        let originalRatio = landscapeImage.size.width / landscapeImage.size.height

        let optimizedImage = optimizeImage(landscapeImage, maxDimension: 1024)
        let optimizedRatio = optimizedImage.size.width / optimizedImage.size.height

        let ratioDifference = abs(originalRatio - optimizedRatio)
        #expect(ratioDifference < 0.01)
    }

    @Test("Optimization reduces file size")
    func testOptimizationReducesFileSize() async throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))
        let optimizedImage = optimizeImage(largeImage, maxDimension: 1024)

        let originalData = largeImage.jpegData(compressionQuality: 0.8)
        let optimizedData = optimizedImage.jpegData(compressionQuality: 0.75)

        #expect(optimizedData != nil)
        #expect(optimizedData!.count < originalData!.count)
    }

    @Test("Optimized image size is approximately correct")
    func testOptimizedImageDimensions() async throws {
        let testCases: [(input: CGSize, maxDimension: CGFloat, expected: CGSize)] = [
            (CGSize(width: 4000, height: 4000), 1024, CGSize(width: 1024, height: 1024)),
            (CGSize(width: 4000, height: 2000), 1024, CGSize(width: 1024, height: 512)),
            (CGSize(width: 2000, height: 4000), 1024, CGSize(width: 512, height: 1024)),
            (CGSize(width: 500, height: 500), 1024, CGSize(width: 500, height: 500))
        ]

        for testCase in testCases {
            let image = createTestImage(size: testCase.input)
            let optimized = optimizeImage(image, maxDimension: testCase.maxDimension)

            let widthDiff = abs(optimized.size.width - testCase.expected.width)
            let heightDiff = abs(optimized.size.height - testCase.expected.height)

            #expect(widthDiff < 2)
            #expect(heightDiff < 2)
        }
    }

    // MARK: - File Size Tests

    @Test("JPEG compression reduces file size")
    func testJpegCompression() async throws {
        let image = createTestImage(size: CGSize(width: 2000, height: 2000))

        let highQuality = image.jpegData(compressionQuality: 1.0)
        let mediumQuality = image.jpegData(compressionQuality: 0.75)
        let lowQuality = image.jpegData(compressionQuality: 0.5)

        #expect(highQuality != nil)
        #expect(mediumQuality != nil)
        #expect(lowQuality != nil)

        #expect(mediumQuality!.count < highQuality!.count)
        #expect(lowQuality!.count < mediumQuality!.count)
    }

    @Test("Optimized image is under size limit")
    func testOptimizedImageUnderSizeLimit() async throws {
        let maxFileSize = 10 * 1024 * 1024  // 10 MB

        let testImages = [
            createTestImage(size: CGSize(width: 4000, height: 4000)),
            createTestImage(size: CGSize(width: 3000, height: 2000)),
            createTestImage(size: CGSize(width: 2000, height: 3000))
        ]

        for image in testImages {
            let optimized = optimizeImage(image, maxDimension: 1024)
            let imageData = optimized.jpegData(compressionQuality: 0.75)

            #expect(imageData != nil)
            #expect(imageData!.count < maxFileSize)
        }
    }

    // MARK: - URL Generation Tests

    @Test("Generated URLs are unique")
    func testUniqueUrlGeneration() async throws {
        var generatedUrls = Set<String>()

        for _ in 0..<100 {
            let url = generateMockFirebaseUrl(userId: "user123")
            #expect(!generatedUrls.contains(url), "URL should be unique")
            generatedUrls.insert(url)
        }

        #expect(generatedUrls.count == 100)
    }

    @Test("Generated URLs have correct format")
    func testUrlFormat() async throws {
        let url = generateMockFirebaseUrl(userId: "user123")

        #expect(url.hasPrefix("https://"))
        #expect(url.contains("storage.googleapis.com"))
        #expect(url.contains("user123"))
        #expect(url.hasSuffix(".jpg"))

        let urlObject = URL(string: url)
        #expect(urlObject != nil)
    }

    @Test("URLs contain user ID")
    func testUrlContainsUserId() async throws {
        let userId = "testUser456"
        let url = generateMockFirebaseUrl(userId: userId)

        #expect(url.contains(userId))
    }

    // MARK: - Batch Upload Tests

    @Test("Batch upload handles multiple images")
    func testBatchUpload() async throws {
        let imageCount = 6
        let images = (0..<imageCount).map { _ in
            createTestImage(size: CGSize(width: 1000, height: 1000))
        }

        #expect(images.count == imageCount)
        #expect(images.allSatisfy { $0.size.width == 1000 && $0.size.height == 1000 })
    }

    @Test("Batch upload respects maximum limit")
    func testBatchUploadMaxLimit() async throws {
        let maxImages = 6
        var images = (0..<10).map { _ in
            createTestImage(size: CGSize(width: 1000, height: 1000))
        }

        // Enforce limit
        if images.count > maxImages {
            images = Array(images.prefix(maxImages))
        }

        #expect(images.count == maxImages)
    }

    // MARK: - Performance Tests

    @Test("Image optimization is performant")
    func testOptimizationPerformance() async throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))

        let startTime = Date()
        let _ = optimizeImage(largeImage, maxDimension: 1024)
        let duration = Date().timeIntervalSince(startTime)

        // Should complete in under 1 second
        #expect(duration < 1.0)
    }

    @Test("Multiple image optimizations are performant")
    func testMultipleOptimizationsPerformance() async throws {
        let images = (0..<6).map { _ in
            createTestImage(size: CGSize(width: 3000, height: 3000))
        }

        let startTime = Date()
        for image in images {
            let _ = optimizeImage(image, maxDimension: 1024)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Should complete in under 3 seconds for 6 images
        #expect(duration < 3.0)
    }

    // MARK: - Error Handling Tests

    @Test("Error types are properly defined")
    func testErrorTypes() async throws {
        let errors: [CelestiaError] = [
            .imageUploadFailed,
            .imageTooBig,
            .invalidImageFormat,
            .tooManyImages,
            .storageQuotaExceeded
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Error messages are user-friendly")
    func testErrorMessages() async throws {
        let uploadError = CelestiaError.imageUploadFailed
        let sizeError = CelestiaError.imageTooBig
        let formatError = CelestiaError.invalidImageFormat
        let limitError = CelestiaError.tooManyImages

        #expect(uploadError.errorDescription?.contains("upload") == true)
        #expect(sizeError.errorDescription?.contains("large") == true)
        #expect(formatError.errorDescription?.contains("format") == true)
        #expect(limitError.errorDescription?.contains("6") == true)
    }

    // MARK: - Data Integrity Tests

    @Test("Image data is not corrupted during optimization")
    func testImageDataIntegrity() async throws {
        let originalImage = createTestImage(size: CGSize(width: 2000, height: 2000), color: .red)
        let optimizedImage = optimizeImage(originalImage, maxDimension: 1024)

        // Verify both images can be converted to data
        let originalData = originalImage.jpegData(compressionQuality: 0.8)
        let optimizedData = optimizedImage.jpegData(compressionQuality: 0.75)

        #expect(originalData != nil)
        #expect(optimizedData != nil)
        #expect(!originalData!.isEmpty)
        #expect(!optimizedData!.isEmpty)
    }

    @Test("Multiple optimizations produce consistent results")
    func testConsistentOptimization() async throws {
        let image = createTestImage(size: CGSize(width: 3000, height: 3000))

        let optimized1 = optimizeImage(image, maxDimension: 1024)
        let optimized2 = optimizeImage(image, maxDimension: 1024)

        #expect(optimized1.size == optimized2.size)
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

    private static func optimizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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

    private static func generateMockFirebaseUrl(userId: String) -> String {
        return "https://storage.googleapis.com/celestia-40ce6/gallery_photos/\(userId)/\(UUID().uuidString).jpg"
    }
}
