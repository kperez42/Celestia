//
//  ContentModerationService.swift
//  Celestia
//
//  Service to check photos for inappropriate content before upload
//  Uses Google Cloud Vision SafeSearch via Firebase Cloud Functions
//

import Foundation
import FirebaseFunctions
import UIKit

// MARK: - Content Moderation Service

@MainActor
class ContentModerationService: ObservableObject {

    // MARK: - Singleton

    static let shared = ContentModerationService()

    // MARK: - Properties

    @Published var isChecking = false

    private lazy var functions = Functions.functions()

    // MARK: - Moderation Result

    struct ModerationResult {
        let approved: Bool
        let message: String
        let reason: String?
        let hasWarning: Bool

        static let approved = ModerationResult(approved: true, message: "Photo looks good!", reason: nil, hasWarning: false)
    }

    // MARK: - Pre-Check Photo

    /// Check if a photo will pass moderation before uploading
    /// This helps provide immediate feedback to users about inappropriate content
    /// Has a 10-second timeout to prevent blocking uploads on slow networks
    func preCheckPhoto(_ image: UIImage) async -> ModerationResult {
        isChecking = true
        defer { isChecking = false }

        Logger.shared.info("🔍 Content moderation: Starting pre-check...", category: .networking)

        // Use a timeout to prevent blocking uploads if Cloud Function is slow
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
            return ModerationResult(
                approved: true,
                message: "Moderation check timed out - proceeding with upload",
                reason: nil,
                hasWarning: true
            )
        }

        let moderationTask = Task { () -> ModerationResult in
            do {
                // Compress image and convert to base64
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    Logger.shared.error("🔍 Content moderation: Failed to compress image", category: .networking)
                    return .approved // Allow on error, will be checked server-side
                }

                Logger.shared.info("🔍 Content moderation: Image compressed (\(imageData.count / 1024) KB), calling Cloud Function...", category: .networking)

                let base64String = imageData.base64EncodedString()

                // Call Cloud Function
                let result = try await functions.httpsCallable("preCheckPhoto").call([
                    "photoBase64": base64String
                ])

                // Parse response
                guard let data = result.data as? [String: Any] else {
                    Logger.shared.error("🔍 Content moderation: Invalid response from Cloud Function", category: .networking)
                    return .approved
                }

                let approved = data["approved"] as? Bool ?? true
                let message = data["message"] as? String ?? ""
                let reason = data["reason"] as? String
                let hasWarning = data["warning"] as? Bool ?? false

                Logger.shared.info("🔍 Content moderation: Result - approved=\(approved), message=\(message)", category: .networking)

                return ModerationResult(
                    approved: approved,
                    message: message,
                    reason: reason,
                    hasWarning: hasWarning
                )

            } catch {
                Logger.shared.warning("🔍 Content moderation: Check failed - \(error.localizedDescription)", category: .networking)
                // On error, allow the upload (server will still check)
                return ModerationResult(
                    approved: true,
                    message: "Unable to pre-check photo",
                    reason: nil,
                    hasWarning: true
                )
            }
        }

        // Race between timeout and moderation check
        let result = await withTaskGroup(of: ModerationResult.self) { group in
            group.addTask { await moderationTask.value }
            group.addTask {
                do {
                    return try await timeoutTask.value
                } catch {
                    return .approved
                }
            }

            // Return whichever finishes first
            if let first = await group.next() {
                group.cancelAll()
                return first
            }
            return .approved
        }

        Logger.shared.info("🔍 Content moderation: Completed - approved=\(result.approved)", category: .networking)
        return result
    }

    /// Check multiple photos in sequence
    func preCheckPhotos(_ images: [UIImage]) async -> (allApproved: Bool, failedIndex: Int?, result: ModerationResult) {
        for (index, image) in images.enumerated() {
            let result = await preCheckPhoto(image)
            if !result.approved {
                return (false, index, result)
            }
        }
        return (true, nil, .approved)
    }
}

// MARK: - Moderation Error

enum ContentModerationError: LocalizedError {
    case photoNotApproved(message: String)
    case checkFailed

    var errorDescription: String? {
        switch self {
        case .photoNotApproved(let message):
            return message
        case .checkFailed:
            return "Unable to verify photo content. Please try again."
        }
    }
}
