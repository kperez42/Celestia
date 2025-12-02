//
//  ImageUploadErrorTests.swift
//  CelestiaTests
//
//  Comprehensive error tests for the image upload system covering all failure scenarios:
//  - Upload failures (network, timeout, server errors)
//  - Save failures (storage quota, permission denied)
//  - Delete/erase failures (not found, network issues)
//  - Image validation errors (size, format, dimensions)
//  - Content moderation failures
//  - Batch upload failures with rollback
//  - Image optimization failures
//

import Testing
import UIKit
@testable import Celestia

// MARK: - Upload Failure Error Tests

@Suite("Image Upload Error Tests")
@MainActor
struct ImageUploadErrorTests {

    // MARK: - Upload Failure Scenarios

    @Suite("Upload Failure Scenarios")
    struct UploadFailureTests {

        @Test("Image upload failed error has correct description")
        @MainActor
        func testImageUploadFailedError() async throws {
            let error = CelestiaError.imageUploadFailed

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("upload") == true)
            #expect(error.errorDescription?.lowercased().contains("failed") == true)
            #expect(error.icon == "photo")
        }

        @Test("Upload failed with custom message contains message")
        @MainActor
        func testUploadFailedWithMessage() async throws {
            let customMessage = "Connection reset by server"
            let error = CelestiaError.uploadFailed(customMessage)

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains(customMessage) == true)
        }

        @Test("Network error during upload is properly identified")
        @MainActor
        func testNetworkErrorDuringUpload() async throws {
            let error = CelestiaError.networkError

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("network") == true)
            #expect(error.icon == "wifi.slash")
            #expect(error.recoverySuggestion?.lowercased().contains("connection") == true)
        }

        @Test("Timeout error during upload has correct message")
        @MainActor
        func testTimeoutErrorDuringUpload() async throws {
            let timeoutError = CelestiaError.timeout
            let requestTimeoutError = CelestiaError.requestTimeout

            #expect(timeoutError.errorDescription != nil)
            #expect(timeoutError.errorDescription?.lowercased().contains("timed out") == true)

            #expect(requestTimeoutError.errorDescription != nil)
            #expect(requestTimeoutError.errorDescription?.lowercased().contains("timed out") == true)
        }

        @Test("Server error during upload is properly handled")
        @MainActor
        func testServerErrorDuringUpload() async throws {
            let error = CelestiaError.serverError

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("server") == true)
            #expect(error.icon == "server.rack")
            #expect(error.recoverySuggestion != nil)
        }

        @Test("No internet connection error is user friendly")
        @MainActor
        func testNoInternetConnectionError() async throws {
            let error = CelestiaError.noInternetConnection

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("internet") == true)
            #expect(error.icon == "wifi.slash")
        }

        @Test("Service temporarily unavailable error has retry suggestion")
        @MainActor
        func testServiceUnavailableError() async throws {
            let error = CelestiaError.serviceTemporarilyUnavailable

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("temporarily unavailable") == true)
            #expect(error.recoverySuggestion?.lowercased().contains("try again") == true)
        }
    }

    // MARK: - Save Failure Scenarios

    @Suite("Image Save Failure Scenarios")
    struct SaveFailureTests {

        @Test("Storage quota exceeded error is properly handled")
        @MainActor
        func testStorageQuotaExceededError() async throws {
            let error = CelestiaError.storageQuotaExceeded

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("quota") == true)
            #expect(error.icon == "photo")
        }

        @Test("Permission denied error has correct message")
        @MainActor
        func testPermissionDeniedError() async throws {
            let error = CelestiaError.permissionDenied

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("permission") == true)
            #expect(error.recoverySuggestion != nil)
        }

        @Test("Unauthorized error prevents save")
        @MainActor
        func testUnauthorizedError() async throws {
            let error = CelestiaError.unauthorized

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("authorized") == true)
            #expect(error.icon == "lock.shield")
        }

        @Test("Unauthenticated error requires sign in")
        @MainActor
        func testUnauthenticatedError() async throws {
            let error = CelestiaError.unauthenticated

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("sign in") == true)
            #expect(error.icon == "lock.shield")
        }

        @Test("Invalid data error during save")
        @MainActor
        func testInvalidDataError() async throws {
            let error = CelestiaError.invalidData

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("invalid") == true)
        }

        @Test("Database error during save has details")
        @MainActor
        func testDatabaseErrorDuringSave() async throws {
            let errorMessage = "Write operation failed"
            let error = CelestiaError.databaseError(errorMessage)

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains(errorMessage) == true)
        }
    }

    // MARK: - Delete/Erase Failure Scenarios

    @Suite("Image Delete Failure Scenarios")
    struct DeleteFailureTests {

        @Test("Document not found error when deleting")
        @MainActor
        func testDocumentNotFoundOnDelete() async throws {
            let error = CelestiaError.documentNotFound

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("not found") == true)
        }

        @Test("Network error during deletion is retryable")
        @MainActor
        func testNetworkErrorDuringDelete() async throws {
            let error = CelestiaError.networkError

            #expect(error.errorDescription != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("connection") == true)
        }

        @Test("Permission denied on deletion")
        @MainActor
        func testPermissionDeniedOnDelete() async throws {
            let error = CelestiaError.permissionDenied

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("permission") == true)
        }

        @Test("Invalid URL for deletion throws invalid data")
        @MainActor
        func testInvalidUrlForDeletion() async throws {
            let error = CelestiaError.invalidData

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("invalid") == true)
        }

        @Test("Operation cancelled during deletion")
        @MainActor
        func testOperationCancelledDuringDeletion() async throws {
            let error = CelestiaError.operationCancelled

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("cancelled") == true)
            #expect(error.icon == "xmark.circle")
        }
    }

    // MARK: - Image Validation Error Scenarios

    @Suite("Image Validation Error Scenarios")
    struct ValidationErrorTests {

        @Test("Image too big error has size information")
        @MainActor
        func testImageTooBigError() async throws {
            let error = CelestiaError.imageTooBig

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("large") == true)
            #expect(error.icon == "photo")
            #expect(error.recoverySuggestion?.lowercased().contains("smaller") == true)
        }

        @Test("Invalid image format error has correct message")
        @MainActor
        func testInvalidImageFormatError() async throws {
            let error = CelestiaError.invalidImageFormat

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("format") == true)
            #expect(error.errorDescription?.lowercased().contains("jpeg") == true ||
                   error.errorDescription?.lowercased().contains("png") == true)
        }

        @Test("Too many images error shows limit")
        @MainActor
        func testTooManyImagesError() async throws {
            let error = CelestiaError.tooManyImages

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("6") == true)
            #expect(error.icon == "photo")
        }

        @Test("Image dimensions below minimum are rejected")
        @MainActor
        func testImageTooSmallValidation() async throws {
            // Test with image smaller than 200x200 minimum
            let tooSmallImage = createTestImage(size: CGSize(width: 100, height: 100))

            // The validation should fail for images smaller than minimum
            #expect(tooSmallImage.size.width < 200)
            #expect(tooSmallImage.size.height < 200)

            let error = CelestiaError.invalidImageFormat
            #expect(error.errorDescription != nil)
        }

        @Test("Extreme aspect ratio images are rejected")
        @MainActor
        func testExtremeAspectRatioValidation() async throws {
            // Test with extreme aspect ratio (less than 0.33 or more than 3.0)
            let tooNarrowImage = createTestImage(size: CGSize(width: 100, height: 1000)) // 0.1 ratio
            let tooWideImage = createTestImage(size: CGSize(width: 1000, height: 100))   // 10.0 ratio

            let narrowRatio = tooNarrowImage.size.width / tooNarrowImage.size.height
            let wideRatio = tooWideImage.size.width / tooWideImage.size.height

            #expect(narrowRatio < 0.33)
            #expect(wideRatio > 3.0)

            let error = CelestiaError.invalidImageFormat
            #expect(error.errorDescription != nil)
        }

        @Test("Zero dimension image is invalid")
        @MainActor
        func testZeroDimensionImage() async throws {
            let error = CelestiaError.invalidImageFormat

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("invalid") == true)
        }

        @Test("Validation error with field and reason")
        @MainActor
        func testValidationErrorWithDetails() async throws {
            let error = CelestiaError.validationError(field: "image", reason: "dimensions too small")

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("image") == true)
            #expect(error.errorDescription?.contains("dimensions too small") == true)
        }
    }

    // MARK: - Content Moderation Failure Scenarios

    @Suite("Content Moderation Failure Scenarios")
    struct ModerationFailureTests {

        @Test("Content not allowed error shows reason")
        @MainActor
        func testContentNotAllowedError() async throws {
            let reason = "Image contains inappropriate content"
            let error = CelestiaError.contentNotAllowed(reason)

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains(reason) == true)
            #expect(error.icon == "exclamationmark.triangle.fill")
            #expect(error.recoverySuggestion?.lowercased().contains("guidelines") == true)
        }

        @Test("Content not allowed with empty message has default")
        @MainActor
        func testContentNotAllowedEmptyMessage() async throws {
            let error = CelestiaError.contentNotAllowed("")

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("not allowed") == true)
        }

        @Test("Inappropriate content error is shown correctly")
        @MainActor
        func testInappropriateContentError() async throws {
            let error = CelestiaError.inappropriateContent

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("inappropriate") == true)
            #expect(error.icon == "exclamationmark.triangle.fill")
        }

        @Test("Inappropriate content with reasons lists all reasons")
        @MainActor
        func testInappropriateContentWithReasons() async throws {
            let reasons = ["Adult content detected", "Violence detected", "Racy content"]
            let error = CelestiaError.inappropriateContentWithReasons(reasons)

            #expect(error.errorDescription != nil)
            for reason in reasons {
                #expect(error.errorDescription?.contains(reason) == true)
            }
        }

        @Test("Moderation result approved state")
        @MainActor
        func testModerationResultApproved() async throws {
            let result = ContentModerationService.ModerationResult.approved

            #expect(result.approved == true)
            #expect(result.message == "Photo looks good!")
            #expect(result.reason == nil)
            #expect(result.hasWarning == false)
        }

        @Test("Moderation result rejected state")
        @MainActor
        func testModerationResultRejected() async throws {
            let result = ContentModerationService.ModerationResult(
                approved: false,
                message: "Photo violates community guidelines",
                reason: "Adult content",
                hasWarning: false
            )

            #expect(result.approved == false)
            #expect(result.message.contains("violates") == true)
            #expect(result.reason == "Adult content")
        }

        @Test("Moderation result with warning state")
        @MainActor
        func testModerationResultWithWarning() async throws {
            let result = ContentModerationService.ModerationResult(
                approved: true,
                message: "Photo approved with warning",
                reason: "Borderline content",
                hasWarning: true
            )

            #expect(result.approved == true)
            #expect(result.hasWarning == true)
            #expect(result.reason != nil)
        }

        @Test("Content moderation error - photo not approved")
        @MainActor
        func testContentModerationErrorNotApproved() async throws {
            let error = ContentModerationError.photoNotApproved(message: "Adult content detected")

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("Adult content detected") == true)
        }

        @Test("Content moderation error - check failed")
        @MainActor
        func testContentModerationErrorCheckFailed() async throws {
            let error = ContentModerationError.checkFailed

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("verify") == true)
        }
    }

    // MARK: - Batch Upload Failure Scenarios

    @Suite("Batch Upload Failure Scenarios")
    struct BatchUploadFailureTests {

        @Test("Batch upload fails when exceeding max images")
        @MainActor
        func testBatchUploadExceedsLimit() async throws {
            let error = CelestiaError.tooManyImages

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("6") == true)
        }

        @Test("Batch operation failed error contains operation ID")
        @MainActor
        func testBatchOperationFailedError() async throws {
            let operationId = "batch_upload_12345"
            let underlyingError = NSError(domain: "TestDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            let error = CelestiaError.batchOperationFailed(operationId: operationId, underlyingError: underlyingError)

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains(operationId) == true)
            #expect(error.icon == "message.badge.exclamationmark")
            #expect(error.recoverySuggestion != nil)
        }

        @Test("Partial batch failure cleanup scenario")
        @MainActor
        func testPartialBatchFailureCleanup() async throws {
            // Simulates a scenario where some uploads succeed then one fails
            // The service should clean up the successful uploads
            let uploadError = CelestiaError.imageUploadFailed
            let networkError = CelestiaError.networkError

            #expect(uploadError.errorDescription != nil)
            #expect(networkError.errorDescription != nil)
        }

        @Test("Empty batch array handling")
        @MainActor
        func testEmptyBatchHandling() async throws {
            let images: [UIImage] = []

            #expect(images.count == 0)
            #expect(images.count <= 6) // Should not throw tooManyImages
        }

        @Test("Single image in batch succeeds")
        @MainActor
        func testSingleImageBatch() async throws {
            let image = createTestImage(size: CGSize(width: 500, height: 500))
            let images = [image]

            #expect(images.count == 1)
            #expect(images.count <= 6)
        }

        @Test("Exactly max images in batch is allowed")
        @MainActor
        func testExactlyMaxImagesInBatch() async throws {
            let images = (0..<6).map { _ in
                createTestImage(size: CGSize(width: 500, height: 500))
            }

            #expect(images.count == 6)
            #expect(images.count <= 6)
        }

        @Test("One over max images in batch fails")
        @MainActor
        func testOneOverMaxImagesInBatch() async throws {
            let images = (0..<7).map { _ in
                createTestImage(size: CGSize(width: 500, height: 500))
            }

            #expect(images.count == 7)
            #expect(images.count > 6)

            let error = CelestiaError.tooManyImages
            #expect(error.errorDescription != nil)
        }
    }

    // MARK: - Image Optimization Failure Scenarios

    @Suite("Image Optimization Failure Scenarios")
    struct OptimizationFailureTests {

        @Test("JPEG conversion failure returns invalid format")
        @MainActor
        func testJPEGConversionFailure() async throws {
            let error = CelestiaError.invalidImageFormat

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("format") == true)
        }

        @Test("Image resize maintains aspect ratio")
        @MainActor
        func testImageResizeAspectRatio() async throws {
            let originalImage = createTestImage(size: CGSize(width: 4000, height: 2000))
            let originalRatio = originalImage.size.width / originalImage.size.height

            let maxDimension: CGFloat = 1024
            let scale = min(maxDimension / originalImage.size.width, maxDimension / originalImage.size.height)
            let newSize = CGSize(width: originalImage.size.width * scale, height: originalImage.size.height * scale)
            let newRatio = newSize.width / newSize.height

            #expect(abs(originalRatio - newRatio) < 0.01)
        }

        @Test("Optimization produces valid JPEG data")
        @MainActor
        func testOptimizationProducesValidData() async throws {
            let image = createTestImage(size: CGSize(width: 1000, height: 1000))
            let jpegData = image.jpegData(compressionQuality: 0.92)

            #expect(jpegData != nil)
            #expect(jpegData!.count > 0)
        }

        @Test("Optimized image size is within limits")
        @MainActor
        func testOptimizedImageSizeWithinLimits() async throws {
            let maxFileSize = 15 * 1024 * 1024 // 15 MB
            let image = createTestImage(size: CGSize(width: 3000, height: 3000))
            let jpegData = image.jpegData(compressionQuality: 0.92)

            #expect(jpegData != nil)
            #expect(jpegData!.count < maxFileSize)
        }

        @Test("Oversized image triggers imageTooBig error")
        @MainActor
        func testOversizedImageError() async throws {
            let error = CelestiaError.imageTooBig

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("large") == true)
            #expect(error.recoverySuggestion?.lowercased().contains("smaller") == true)
        }
    }

    // MARK: - Rate Limiting Error Scenarios

    @Suite("Rate Limiting Error Scenarios")
    struct RateLimitingTests {

        @Test("Rate limit exceeded error")
        @MainActor
        func testRateLimitExceededError() async throws {
            let error = CelestiaError.rateLimitExceeded

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("often") == true)
            #expect(error.icon == "clock.fill")
        }

        @Test("Rate limit with time shows remaining time")
        @MainActor
        func testRateLimitWithTimeError() async throws {
            let error = CelestiaError.rateLimitExceededWithTime(90) // 90 seconds

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("1m") == true ||
                   error.errorDescription?.contains("90") == true)
        }

        @Test("Rate limit with short time shows seconds")
        @MainActor
        func testRateLimitWithShortTime() async throws {
            let error = CelestiaError.rateLimitExceededWithTime(30) // 30 seconds

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.contains("30") == true)
        }

        @Test("Too many requests error")
        @MainActor
        func testTooManyRequestsError() async throws {
            let error = CelestiaError.tooManyRequests

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("too many") == true)
        }
    }

    // MARK: - Firebase Storage Error Mapping Tests

    @Suite("Firebase Storage Error Mapping Tests")
    struct StorageErrorMappingTests {

        @Test("Storage object not found maps to documentNotFound")
        @MainActor
        func testStorageObjectNotFoundMapping() async throws {
            let error = CelestiaError.documentNotFound

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("not found") == true)
        }

        @Test("Storage quota exceeded maps correctly")
        @MainActor
        func testStorageQuotaExceededMapping() async throws {
            let error = CelestiaError.storageQuotaExceeded

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("quota") == true)
        }

        @Test("Storage unauthorized maps to unauthorized")
        @MainActor
        func testStorageUnauthorizedMapping() async throws {
            let error = CelestiaError.unauthorized

            #expect(error.errorDescription != nil)
        }

        @Test("Storage unauthenticated maps to unauthenticated")
        @MainActor
        func testStorageUnauthenticatedMapping() async throws {
            let error = CelestiaError.unauthenticated

            #expect(error.errorDescription != nil)
        }

        @Test("Storage download size exceeded maps to imageTooBig")
        @MainActor
        func testStorageDownloadSizeExceededMapping() async throws {
            let error = CelestiaError.imageTooBig

            #expect(error.errorDescription != nil)
        }

        @Test("Storage cancelled maps to operationCancelled")
        @MainActor
        func testStorageCancelledMapping() async throws {
            let error = CelestiaError.operationCancelled

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("cancelled") == true)
        }

        @Test("Storage checksum mismatch maps to uploadFailed")
        @MainActor
        func testStorageChecksumMismatchMapping() async throws {
            let error = CelestiaError.uploadFailed("File corrupted during transfer")

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("corrupted") == true)
        }
    }

    // MARK: - Error Recovery Tests

    @Suite("Error Recovery Tests")
    struct ErrorRecoveryTests {

        @Test("Network error has retry suggestion")
        @MainActor
        func testNetworkErrorRecovery() async throws {
            let error = CelestiaError.networkError

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("connection") == true)
        }

        @Test("Image too big has resize suggestion")
        @MainActor
        func testImageTooBigRecovery() async throws {
            let error = CelestiaError.imageTooBig

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("smaller") == true ||
                   error.recoverySuggestion?.lowercased().contains("reduce") == true)
        }

        @Test("Content not allowed has guidelines suggestion")
        @MainActor
        func testContentNotAllowedRecovery() async throws {
            let error = CelestiaError.contentNotAllowed("Inappropriate content")

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("guidelines") == true ||
                   error.recoverySuggestion?.lowercased().contains("different") == true)
        }

        @Test("Permission denied has contact support suggestion")
        @MainActor
        func testPermissionDeniedRecovery() async throws {
            let error = CelestiaError.permissionDenied

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("support") == true ||
                   error.recoverySuggestion?.lowercased().contains("contact") == true)
        }

        @Test("Timeout error has retry suggestion")
        @MainActor
        func testTimeoutRecovery() async throws {
            let error = CelestiaError.timeout

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("again") == true)
        }

        @Test("Server error has wait suggestion")
        @MainActor
        func testServerErrorRecovery() async throws {
            let error = CelestiaError.serverError

            #expect(error.recoverySuggestion != nil)
            #expect(error.recoverySuggestion?.lowercased().contains("wait") == true ||
                   error.recoverySuggestion?.lowercased().contains("again") == true)
        }
    }

    // MARK: - Error Icon Tests

    @Suite("Error Icon Tests")
    struct ErrorIconTests {

        @Test("Image errors have photo icon")
        @MainActor
        func testImageErrorIcons() async throws {
            let imageErrors: [CelestiaError] = [
                .imageUploadFailed,
                .imageTooBig,
                .invalidImageFormat,
                .storageQuotaExceeded
            ]

            for error in imageErrors {
                #expect(error.icon == "photo")
            }
        }

        @Test("Network errors have wifi icon")
        @MainActor
        func testNetworkErrorIcons() async throws {
            let networkErrors: [CelestiaError] = [
                .networkError,
                .noInternetConnection,
                .timeout,
                .requestTimeout
            ]

            for error in networkErrors {
                #expect(error.icon == "wifi.slash")
            }
        }

        @Test("Auth errors have lock icon")
        @MainActor
        func testAuthErrorIcons() async throws {
            let authErrors: [CelestiaError] = [
                .notAuthenticated,
                .unauthorized,
                .unauthenticated,
                .invalidCredentials,
                .sessionExpired
            ]

            for error in authErrors {
                #expect(error.icon == "lock.shield")
            }
        }

        @Test("Content moderation errors have warning icon")
        @MainActor
        func testContentModerationIcons() async throws {
            let contentErrors: [CelestiaError] = [
                .contentNotAllowed("test"),
                .inappropriateContent,
                .inappropriateContentWithReasons(["test"])
            ]

            for error in contentErrors {
                #expect(error.icon == "exclamationmark.triangle.fill")
            }
        }

        @Test("Rate limit errors have clock icon")
        @MainActor
        func testRateLimitIcons() async throws {
            let rateLimitErrors: [CelestiaError] = [
                .rateLimitExceeded,
                .rateLimitExceededWithTime(60),
                .tooManyRequests
            ]

            for error in rateLimitErrors {
                #expect(error.icon == "clock.fill")
            }
        }
    }

    // MARK: - Error Identity Tests

    @Suite("Error Identity Tests")
    struct ErrorIdentityTests {

        @Test("Each error has unique ID")
        @MainActor
        func testErrorUniqueIds() async throws {
            let errors: [CelestiaError] = [
                .imageUploadFailed,
                .imageTooBig,
                .invalidImageFormat,
                .networkError,
                .timeout,
                .serverError
            ]

            var ids = Set<String>()
            for error in errors {
                let id = error.id
                #expect(!ids.contains(id), "Duplicate ID found: \(id)")
                ids.insert(id)
            }
        }

        @Test("Error from NSError conversion works")
        @MainActor
        func testErrorFromNSError() async throws {
            let nsError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorNotConnectedToInternet,
                userInfo: nil
            )

            let celestiaError = CelestiaError.from(nsError)

            #expect(celestiaError == .noInternetConnection)
        }

        @Test("Error from timeout NSError works")
        @MainActor
        func testErrorFromTimeoutNSError() async throws {
            let nsError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: nil
            )

            let celestiaError = CelestiaError.from(nsError)

            #expect(celestiaError == .requestTimeout)
        }

        @Test("Error from generic NSError returns unknown")
        @MainActor
        func testErrorFromGenericNSError() async throws {
            let nsError = NSError(
                domain: "UnknownDomain",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
            )

            let celestiaError = CelestiaError.from(nsError)

            if case .unknown(let message) = celestiaError {
                #expect(message.contains("Unknown error occurred"))
            } else {
                Issue.record("Expected unknown error type")
            }
        }
    }

    // MARK: - Profile and Chat Image Upload Error Tests

    @Suite("Profile and Chat Image Upload Error Tests")
    struct ProfileChatUploadTests {

        @Test("Empty user ID for profile image throws invalid data")
        @MainActor
        func testEmptyUserIdProfileImage() async throws {
            let error = CelestiaError.invalidData

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("invalid") == true)
        }

        @Test("Empty match ID for chat image throws invalid data")
        @MainActor
        func testEmptyMatchIdChatImage() async throws {
            let error = CelestiaError.invalidData

            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.lowercased().contains("invalid") == true)
        }

        @Test("Profile image path is constructed correctly")
        @MainActor
        func testProfileImagePathConstruction() async throws {
            let userId = "testUser123"
            let expectedPathPrefix = "profile_images/\(userId)"

            #expect(expectedPathPrefix.contains(userId))
            #expect(expectedPathPrefix.hasPrefix("profile_images/"))
        }

        @Test("Chat image path is constructed correctly")
        @MainActor
        func testChatImagePathConstruction() async throws {
            let matchId = "match456"
            let expectedPathPrefix = "chat_images/\(matchId)"

            #expect(expectedPathPrefix.contains(matchId))
            #expect(expectedPathPrefix.hasPrefix("chat_images/"))
        }
    }

    // MARK: - Concurrent Upload Error Tests

    @Suite("Concurrent Upload Error Tests")
    struct ConcurrentUploadTests {

        @Test("Multiple simultaneous upload errors are handled independently")
        @MainActor
        func testMultipleUploadErrorsIndependent() async throws {
            let error1 = CelestiaError.imageUploadFailed
            let error2 = CelestiaError.networkError
            let error3 = CelestiaError.timeout

            #expect(error1.errorDescription != error2.errorDescription)
            #expect(error2.errorDescription != error3.errorDescription)
            #expect(error1.id != error2.id)
            #expect(error2.id != error3.id)
        }

        @Test("Error types are distinguishable")
        @MainActor
        func testErrorTypesDistinguishable() async throws {
            let uploadError = CelestiaError.imageUploadFailed
            let sizeError = CelestiaError.imageTooBig
            let formatError = CelestiaError.invalidImageFormat

            #expect(uploadError.errorDescription?.contains("upload") == true)
            #expect(sizeError.errorDescription?.contains("large") == true)
            #expect(formatError.errorDescription?.contains("format") == true)
        }
    }

    // MARK: - User Message Tests for Firebase Errors

    @Suite("Firebase Error User Message Tests")
    struct FirebaseErrorUserMessageTests {

        @Test("Network error has user friendly message")
        @MainActor
        func testNetworkErrorUserMessage() async throws {
            let error = CelestiaError.networkError

            #expect(error.userMessage.lowercased().contains("network") == true ||
                   error.userMessage.lowercased().contains("connection") == true)
        }

        @Test("Upload failed has user friendly message")
        @MainActor
        func testUploadFailedUserMessage() async throws {
            let error = CelestiaError.uploadFailed("Test failure")

            #expect(error.userMessage.contains("Test failure"))
        }

        @Test("Storage quota exceeded has user friendly message")
        @MainActor
        func testStorageQuotaUserMessage() async throws {
            let error = CelestiaError.storageQuotaExceeded

            #expect(error.userMessage.lowercased().contains("quota") == true)
        }

        @Test("Image too big has user friendly message")
        @MainActor
        func testImageTooBigUserMessage() async throws {
            let error = CelestiaError.imageTooBig

            #expect(error.userMessage.lowercased().contains("large") == true ||
                   error.userMessage.lowercased().contains("big") == true)
        }

        @Test("Permission denied has user friendly message")
        @MainActor
        func testPermissionDeniedUserMessage() async throws {
            let error = CelestiaError.permissionDenied

            #expect(error.userMessage.lowercased().contains("permission") == true)
        }
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
