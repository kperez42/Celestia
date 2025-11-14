//
//  FirebaseErrorMapper.swift
//  Celestia
//
//  Centralized Firebase error mapping to eliminate code duplication
//  Converts Firebase error codes to user-friendly messages
//
//  CODE QUALITY IMPROVEMENT:
//  This utility eliminates 20+ instances of duplicated error handling code
//  across services, providing:
//  - Single source of truth for error messages
//  - Consistent user experience
//  - Easy maintenance and updates
//  - Better error tracking and analytics
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

/// Centralized Firebase error mapping utility
/// Converts Firebase NSError codes to user-friendly CelestiaError types and messages
enum FirebaseErrorMapper {

    // MARK: - Main Error Mapping

    /// Map any Firebase NSError to a user-friendly error
    /// Automatically detects error domain and delegates to appropriate handler
    static func mapError(_ error: NSError) -> CelestiaError {
        switch error.domain {
        case "FIRAuthErrorDomain":
            return mapAuthError(error)
        case "FIRStorageErrorDomain":
            return mapStorageError(error)
        case "FIRFirestoreErrorDomain":
            return mapFirestoreError(error)
        default:
            return .unknown(error.localizedDescription)
        }
    }

    /// Get user-friendly error message from NSError
    /// Use this when you don't need the CelestiaError type
    static func getUserFriendlyMessage(for error: NSError) -> String {
        return mapError(error).userMessage
    }

    // MARK: - Firebase Auth Error Mapping

    /// Map Firebase Authentication errors to CelestiaError
    private static func mapAuthError(_ error: NSError) -> CelestiaError {
        switch error.code {
        // Email/Password errors
        case 17008: // AuthErrorCode.invalidEmail
            return .invalidEmail

        case 17009: // AuthErrorCode.wrongPassword
            return .wrongPassword

        case 17011: // AuthErrorCode.userNotFound
            return .userNotFound

        case 17010: // AuthErrorCode.userDisabled / tooManyRequests (Firebase uses same code)
            return .accountDisabled

        case 17007: // AuthErrorCode.emailAlreadyInUse
            return .emailAlreadyInUse

        case 17026: // AuthErrorCode.weakPassword
            return .weakPassword

        // Network errors
        case 17020: // AuthErrorCode.networkError
            return .networkError

        // Too many requests (17046 is actual code for tooManyRequests)
        case 17046: // AuthErrorCode.tooManyRequests
            return .tooManyRequests

        // Operation not allowed
        case 17006: // AuthErrorCode.operationNotAllowed
            return .authOperationNotAllowed

        // Invalid credential
        case 17004: // AuthErrorCode.invalidCredential
            return .invalidCredentials

        // User token expired
        case 17012: // AuthErrorCode.userTokenExpired
            return .sessionExpired

        // Invalid API key
        case 17000: // AuthErrorCode.invalidAPIKey
            return .configurationError("Invalid API key")

        // App not authorized
        case 17028: // AuthErrorCode.appNotAuthorized
            return .configurationError("App not authorized")

        // Requires recent login
        case 17014: // AuthErrorCode.requiresRecentLogin
            return .requiresRecentLogin

        default:
            return .authenticationFailed(error.localizedDescription)
        }
    }

    // MARK: - Firebase Storage Error Mapping

    /// Map Firebase Storage errors to CelestiaError
    private static func mapStorageError(_ error: NSError) -> CelestiaError {
        switch error.code {
        case StorageErrorCode.objectNotFound.rawValue:
            return .invalidData

        case StorageErrorCode.unauthorized.rawValue:
            return .unauthorized

        case StorageErrorCode.quotaExceeded.rawValue:
            return .storageQuotaExceeded

        case StorageErrorCode.unauthenticated.rawValue:
            return .unauthenticated

        case StorageErrorCode.retryLimitExceeded.rawValue:
            return .networkError

        case StorageErrorCode.cancelled.rawValue:
            return .operationCancelled

        default:
            return .uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Firebase Firestore Error Mapping

    /// Map Firebase Firestore errors to CelestiaError
    private static func mapFirestoreError(_ error: NSError) -> CelestiaError {
        switch error.code {
        case FirestoreErrorCode.notFound.rawValue:
            return .documentNotFound

        case FirestoreErrorCode.permissionDenied.rawValue:
            return .permissionDenied

        case FirestoreErrorCode.unavailable.rawValue:
            return .serviceTemporarilyUnavailable

        case FirestoreErrorCode.unauthenticated.rawValue:
            return .unauthenticated

        case FirestoreErrorCode.aborted.rawValue:
            return .operationCancelled

        case FirestoreErrorCode.alreadyExists.rawValue:
            return .duplicateEntry

        case FirestoreErrorCode.resourceExhausted.rawValue:
            return .rateLimitExceeded

        case FirestoreErrorCode.deadlineExceeded.rawValue:
            return .requestTimeout

        default:
            return .databaseError(error.localizedDescription)
        }
    }

    // MARK: - Error Tracking & Analytics

    /// Log error with analytics for monitoring
    /// Call this when catching Firebase errors to track patterns
    static func logError(_ error: NSError, context: String) {
        let mappedError = mapError(error)

        Logger.shared.error(
            "Firebase error in \(context) - Domain: \(error.domain), Code: \(error.code)",
            category: .general,
            error: error
        )

        // Log analytics asynchronously to avoid blocking
        // Swift 6 concurrency: AnalyticsManager is @MainActor isolated
        Task { @MainActor in
            AnalyticsManager.shared.logEvent(.errorOccurred, parameters: [
                "error_domain": error.domain,
                "error_code": error.code,
                "error_type": String(describing: mappedError),
                "context": context,
                "user_message": mappedError.userMessage
            ])
        }
    }

    // MARK: - Helper Methods

    /// Check if error is a network error
    static func isNetworkError(_ error: NSError) -> Bool {
        switch error.domain {
        case "FIRAuthErrorDomain":
            return error.code == 17020 // AuthErrorCode.networkError
        case "FIRStorageErrorDomain":
            return error.code == StorageErrorCode.retryLimitExceeded.rawValue
        case "FIRFirestoreErrorDomain":
            return error.code == FirestoreErrorCode.unavailable.rawValue
        default:
            return false
        }
    }

    /// Check if error is recoverable (user can retry)
    static func isRecoverable(_ error: NSError) -> Bool {
        let mappedError = mapError(error)

        switch mappedError {
        // Recoverable errors - user can retry
        case .networkError, .serviceTemporarilyUnavailable,
             .requestTimeout, .operationCancelled:
            return true

        // Non-recoverable errors - user must fix something
        case .invalidEmail, .emailAlreadyInUse, .weakPassword,
             .wrongPassword, .userNotFound, .accountDisabled,
             .permissionDenied, .unauthorized:
            return false

        default:
            // Default to recoverable for unknown errors
            return true
        }
    }

    /// Get retry delay for recoverable errors
    /// Returns nil if error is not recoverable
    static func getRetryDelay(for error: NSError, attempt: Int) -> TimeInterval? {
        guard isRecoverable(error) else { return nil }

        // Exponential backoff: 2s, 4s, 8s, 16s, 30s (max)
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 30.0
        let delay = baseDelay * pow(2.0, Double(attempt - 1))

        return min(delay, maxDelay)
    }
}

// MARK: - CelestiaError Extension

extension CelestiaError {
    /// User-friendly message for display
    var userMessage: String {
        switch self {
        // Auth errors
        case .invalidEmail:
            return "Please enter a valid email address."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .accountDisabled:
            return "This account has been disabled."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 8 characters with letters and numbers."
        case .invalidCredentials:
            return "Invalid email or password."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .requiresRecentLogin:
            return "For security, please sign in again to continue."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"

        // Network errors
        case .networkError:
            return "Network connection error. Please check your internet."
        case .serviceTemporarilyUnavailable:
            return "Service temporarily unavailable. Please try again."
        case .requestTimeout:
            return "Request timed out. Please try again."

        // Storage errors
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .storageQuotaExceeded:
            return "Storage quota exceeded. Please contact support."

        // Firestore errors
        case .documentNotFound:
            return "Requested data not found."
        case .permissionDenied:
            return "You don't have permission to access this."
        case .duplicateEntry:
            return "This entry already exists."
        case .databaseError(let message):
            return "Database error: \(message)"

        // Authorization errors
        case .unauthorized:
            return "You are not authorized for this action."
        case .unauthenticated:
            return "Please sign in to continue."

        // Rate limiting
        case .rateLimitExceeded:
            return "Too many requests. Please wait and try again."
        case .rateLimitExceededWithTime(let seconds):
            let minutes = Int(seconds / 60)
            if minutes > 0 {
                return "Too many requests. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")."
            } else {
                return "Too many requests. Please try again in \(Int(seconds)) seconds."
            }
        case .tooManyRequests:
            return "Too many attempts. Please try again later."

        // Operation errors
        case .operationCancelled:
            return "Operation cancelled."
        case .configurationError(let message):
            return "Configuration error: \(message)"

        default:
            return self.localizedDescription
        }
    }
}
