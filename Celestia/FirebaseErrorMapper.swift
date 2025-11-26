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

    /// Firebase Auth error codes (FIRAuthErrorDomain)
    /// Reference: https://firebase.google.com/docs/auth/ios/errors
    private enum AuthErrorCodes {
        // Credential errors
        static let invalidCustomToken = 17000
        static let customTokenMismatch = 17001
        static let invalidCredential = 17004
        static let operationNotAllowed = 17006
        static let emailAlreadyInUse = 17007
        static let invalidEmail = 17008
        static let wrongPassword = 17009
        static let userNotFound = 17011
        static let accountExistsWithDifferentCredential = 17012

        // User state errors
        static let userDisabled = 17005
        static let userTokenExpired = 17021
        static let invalidUserToken = 17017
        static let userMismatch = 17018
        static let requiresRecentLogin = 17014

        // Password errors
        static let weakPassword = 17026

        // Network/System errors
        static let networkError = 17020
        static let tooManyRequests = 17010
        static let internalError = 17999
        static let webNetworkRequestFailed = 17062

        // API/App configuration errors
        static let invalidAPIKey = 17023
        static let appNotVerified = 17025
        static let appNotAuthorized = 17028
        static let invalidClientID = 17049
        static let keychainError = 17995

        // Email action errors
        static let invalidActionCode = 17030
        static let expiredActionCode = 17031

        // Provider errors
        static let providerAlreadyLinked = 17015
        static let noSuchProvider = 17016
        static let credentialAlreadyInUse = 17019

        // Captcha/Verification errors
        static let captchaCheckFailed = 17056
        static let webContextCancelled = 17058
        static let webContextAlreadyPresented = 17057

        // Multi-factor errors
        static let missingMultiFactorSession = 17081
        static let missingMultiFactorInfo = 17082
        static let invalidMultiFactorSession = 17083
        static let multiFactorInfoNotFound = 17084
        static let adminRestrictedOperation = 17085
        static let unverifiedEmail = 17086
        static let secondFactorAlreadyEnrolled = 17087
        static let maximumSecondFactorCountExceeded = 17088
        static let unsupportedFirstFactor = 17089
        static let emailChangeNeedsVerification = 17090
    }

    /// Map Firebase Authentication errors to CelestiaError
    private static func mapAuthError(_ error: NSError) -> CelestiaError {
        switch error.code {
        // Email/Password errors
        case AuthErrorCodes.invalidEmail:
            return .invalidEmail

        case AuthErrorCodes.wrongPassword:
            return .wrongPassword

        case AuthErrorCodes.userNotFound:
            return .userNotFound

        case AuthErrorCodes.userDisabled:
            return .accountDisabled

        case AuthErrorCodes.emailAlreadyInUse:
            return .emailAlreadyInUse

        case AuthErrorCodes.weakPassword:
            return .weakPassword

        // Credential errors
        case AuthErrorCodes.invalidCredential:
            return .invalidCredentials

        case AuthErrorCodes.invalidCustomToken, AuthErrorCodes.customTokenMismatch:
            return .authenticationFailed("Invalid authentication token")

        case AuthErrorCodes.accountExistsWithDifferentCredential:
            return .emailAlreadyInUse

        case AuthErrorCodes.credentialAlreadyInUse:
            return .emailAlreadyInUse

        // User state errors
        case AuthErrorCodes.userTokenExpired, AuthErrorCodes.invalidUserToken:
            return .sessionExpired

        case AuthErrorCodes.requiresRecentLogin:
            return .requiresRecentLogin

        case AuthErrorCodes.userMismatch:
            return .authenticationFailed("User mismatch - please sign in again")

        // Network errors
        case AuthErrorCodes.networkError, AuthErrorCodes.webNetworkRequestFailed:
            return .networkError

        // Rate limiting
        case AuthErrorCodes.tooManyRequests:
            return .tooManyRequests

        // Operation not allowed
        case AuthErrorCodes.operationNotAllowed:
            return .authOperationNotAllowed

        // API/App configuration errors
        case AuthErrorCodes.invalidAPIKey:
            return .configurationError("Invalid API key - please update the app")

        case AuthErrorCodes.appNotVerified, AuthErrorCodes.appNotAuthorized:
            return .configurationError("App not authorized - please update the app")

        case AuthErrorCodes.invalidClientID:
            return .configurationError("Invalid client configuration")

        case AuthErrorCodes.keychainError:
            return .configurationError("Keychain access error - please restart the app")

        // Email action errors (verification, password reset)
        case AuthErrorCodes.invalidActionCode:
            return .invalidData

        case AuthErrorCodes.expiredActionCode:
            return .sessionExpired

        // Provider errors
        case AuthErrorCodes.providerAlreadyLinked:
            return .duplicateEntry

        case AuthErrorCodes.noSuchProvider:
            return .authenticationFailed("Sign-in method not available")

        // Captcha/Verification errors
        case AuthErrorCodes.captchaCheckFailed:
            return .authenticationFailed("Verification failed - please try again")

        case AuthErrorCodes.webContextCancelled:
            return .operationCancelled

        case AuthErrorCodes.webContextAlreadyPresented:
            return .operationCancelled

        // Multi-factor authentication errors
        case AuthErrorCodes.missingMultiFactorSession,
             AuthErrorCodes.missingMultiFactorInfo,
             AuthErrorCodes.invalidMultiFactorSession,
             AuthErrorCodes.multiFactorInfoNotFound:
            return .authenticationFailed("Multi-factor authentication error")

        case AuthErrorCodes.secondFactorAlreadyEnrolled:
            return .duplicateEntry

        case AuthErrorCodes.maximumSecondFactorCountExceeded:
            return .rateLimitExceeded

        case AuthErrorCodes.unverifiedEmail, AuthErrorCodes.emailChangeNeedsVerification:
            return .emailNotVerified

        // Internal errors
        case AuthErrorCodes.internalError:
            return .serverError

        default:
            return .authenticationFailed(error.localizedDescription)
        }
    }

    // MARK: - Firebase Storage Error Mapping

    /// Map Firebase Storage errors to CelestiaError
    /// Reference: https://firebase.google.com/docs/storage/ios/handle-errors
    private static func mapStorageError(_ error: NSError) -> CelestiaError {
        switch error.code {
        // Object/Path errors
        case StorageErrorCode.objectNotFound.rawValue:
            return .documentNotFound

        case StorageErrorCode.bucketNotFound.rawValue:
            return .configurationError("Storage bucket not found")

        case StorageErrorCode.projectNotFound.rawValue:
            return .configurationError("Storage project not found")

        case StorageErrorCode.pathError.rawValue:
            return .invalidData

        // Authorization errors
        case StorageErrorCode.unauthorized.rawValue:
            return .unauthorized

        case StorageErrorCode.unauthenticated.rawValue:
            return .unauthenticated

        // Quota/Size errors
        case StorageErrorCode.quotaExceeded.rawValue:
            return .storageQuotaExceeded

        case StorageErrorCode.downloadSizeExceeded.rawValue:
            return .imageTooBig

        // Network/Retry errors
        case StorageErrorCode.retryLimitExceeded.rawValue:
            return .networkError

        case StorageErrorCode.nonMatchingChecksum.rawValue:
            return .uploadFailed("File corrupted during transfer - please try again")

        // Operation errors
        case StorageErrorCode.cancelled.rawValue:
            return .operationCancelled

        case StorageErrorCode.invalidArgument.rawValue:
            return .invalidData

        // Unknown/Internal errors
        case StorageErrorCode.unknown.rawValue:
            return .uploadFailed("Unknown storage error - please try again")

        default:
            return .uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Firebase Firestore Error Mapping

    /// Firestore error codes for comprehensive mapping
    /// Reference: https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Enums/FirestoreErrorCode
    private enum FirestoreErrorCodes {
        static let ok = 0
        static let cancelled = 1
        static let unknown = 2
        static let invalidArgument = 3
        static let deadlineExceeded = 4
        static let notFound = 5
        static let alreadyExists = 6
        static let permissionDenied = 7
        static let resourceExhausted = 8
        static let failedPrecondition = 9
        static let aborted = 10
        static let outOfRange = 11
        static let unimplemented = 12
        static let `internal` = 13
        static let unavailable = 14
        static let dataLoss = 15
        static let unauthenticated = 16
    }

    /// Map Firebase Firestore errors to CelestiaError
    /// Covers all FirestoreErrorCode cases for comprehensive error handling
    private static func mapFirestoreError(_ error: NSError) -> CelestiaError {
        switch error.code {
        // Success (shouldn't normally reach error handling)
        case FirestoreErrorCodes.ok:
            return .unknown("Unexpected success code in error handler")

        // Operation cancelled by caller
        case FirestoreErrorCodes.cancelled:
            return .operationCancelled

        // Unknown error - often a transient issue
        case FirestoreErrorCodes.unknown:
            return .databaseError("Unknown database error - please try again")

        // Invalid argument in query or document
        case FirestoreErrorCodes.invalidArgument:
            return .invalidData

        // Deadline exceeded before operation completed
        case FirestoreErrorCodes.deadlineExceeded:
            return .requestTimeout

        // Document or collection not found
        case FirestoreErrorCodes.notFound:
            return .documentNotFound

        // Document already exists (conflict)
        case FirestoreErrorCodes.alreadyExists:
            return .duplicateEntry

        // User lacks permission for this operation
        case FirestoreErrorCodes.permissionDenied:
            return .permissionDenied

        // Quota exceeded or too many requests
        case FirestoreErrorCodes.resourceExhausted:
            return .rateLimitExceeded

        // Operation rejected due to current system state
        // Example: deleting a non-empty directory, or transaction conflicts
        case FirestoreErrorCodes.failedPrecondition:
            return .databaseError("Operation cannot be performed in current state")

        // Transaction aborted due to conflict
        case FirestoreErrorCodes.aborted:
            return .databaseError("Transaction conflict - please retry")

        // Operation argument out of valid range
        case FirestoreErrorCodes.outOfRange:
            return .invalidData

        // Operation not implemented or supported
        case FirestoreErrorCodes.unimplemented:
            return .notImplemented

        // Internal server error
        case FirestoreErrorCodes.`internal`:
            return .serverError

        // Service temporarily unavailable
        case FirestoreErrorCodes.unavailable:
            return .serviceTemporarilyUnavailable

        // Unrecoverable data loss or corruption
        case FirestoreErrorCodes.dataLoss:
            return .databaseError("Data corruption detected - please contact support")

        // User not authenticated
        case FirestoreErrorCodes.unauthenticated:
            return .unauthenticated

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

    // MARK: - Recovery Suggestions

    /// Get actionable recovery suggestion for an error
    /// Returns a user-friendly suggestion that helps resolve the error
    static func getRecoverySuggestion(for error: NSError) -> String {
        let mappedError = mapError(error)
        return getRecoverySuggestion(for: mappedError, originalError: error)
    }

    /// Get recovery suggestion for CelestiaError with optional original NSError context
    static func getRecoverySuggestion(for error: CelestiaError, originalError: NSError? = nil) -> String {
        switch error {
        // Auth recovery suggestions
        case .invalidEmail:
            return "Check for typos in your email address."
        case .wrongPassword:
            return "Try again or use 'Forgot Password' to reset it."
        case .userNotFound:
            return "Check your email or create a new account."
        case .accountDisabled:
            return "Contact support at help@celestia.app for assistance."
        case .emailAlreadyInUse:
            return "Sign in with this email or use a different one."
        case .weakPassword:
            return "Use at least 8 characters with uppercase, lowercase, and numbers."
        case .invalidCredentials:
            return "Double-check your email and password."
        case .sessionExpired, .requiresRecentLogin:
            return "Sign out and sign back in to continue."
        case .emailNotVerified:
            return "Check your email inbox for a verification link."
        case .authOperationNotAllowed:
            return "This sign-in method may be disabled. Try a different method."

        // Network recovery suggestions
        case .networkError:
            return "Check your Wi-Fi or mobile data connection."
        case .serviceTemporarilyUnavailable:
            return "Wait a few minutes and try again."
        case .requestTimeout:
            return "Try again with a stronger connection."
        case .serverError:
            return "We're experiencing technical difficulties. Please try again later."

        // Storage recovery suggestions
        case .uploadFailed:
            if let nsError = originalError,
               nsError.code == StorageErrorCode.nonMatchingChecksum.rawValue {
                return "The file was corrupted during upload. Try uploading again."
            }
            return "Check your connection and try uploading again."
        case .storageQuotaExceeded:
            return "Delete some photos to free up space, or contact support."
        case .imageTooBig:
            return "Choose a smaller image or reduce image quality in settings."

        // Database recovery suggestions
        case .documentNotFound:
            return "The data may have been deleted. Refresh the page."
        case .permissionDenied:
            return "You may need to sign in or don't have access to this content."
        case .duplicateEntry:
            return "This item already exists. Try editing the existing one."
        case .databaseError(let message):
            if message.contains("conflict") || message.contains("retry") {
                return "Please try again - there was a temporary conflict."
            } else if message.contains("corruption") {
                return "Please contact support immediately."
            }
            return "Please try again. If the problem persists, contact support."

        // Authorization recovery suggestions
        case .unauthorized:
            return "You don't have permission for this action. Contact support if needed."
        case .unauthenticated:
            return "Please sign in to your account."

        // Rate limiting recovery suggestions
        case .rateLimitExceeded, .tooManyRequests:
            return "Wait a few minutes before trying again."
        case .rateLimitExceededWithTime(let seconds):
            if seconds > 60 {
                return "Take a short break and try again in \(Int(seconds / 60)) minutes."
            }
            return "Wait \(Int(seconds)) seconds before trying again."

        // Operation recovery suggestions
        case .operationCancelled:
            return "Try the action again if you didn't mean to cancel."
        case .configurationError:
            return "Please update the app to the latest version."
        case .notImplemented:
            return "This feature is coming soon."
        case .invalidData:
            return "Please check your input and try again."

        default:
            return "If the problem persists, contact support at help@celestia.app"
        }
    }

    /// Determine if error should show a retry button
    static func shouldShowRetryButton(for error: NSError) -> Bool {
        let mappedError = mapError(error)

        switch mappedError {
        // Show retry for transient errors
        case .networkError, .serviceTemporarilyUnavailable,
             .requestTimeout, .serverError:
            return true

        // Show retry for certain database errors
        case .databaseError(let message):
            return message.contains("retry") || message.contains("conflict")

        // Show retry for upload failures (might be network related)
        case .uploadFailed:
            return true

        // Don't show retry for user-fixable errors
        case .invalidEmail, .wrongPassword, .userNotFound,
             .weakPassword, .invalidCredentials, .invalidData:
            return false

        // Don't show retry for permission/auth errors
        case .permissionDenied, .unauthorized, .unauthenticated,
             .accountDisabled:
            return false

        // Don't show retry for rate limiting (auto-retries happen internally)
        case .rateLimitExceeded, .rateLimitExceededWithTime, .tooManyRequests:
            return false

        default:
            return isRecoverable(error)
        }
    }
}

// MARK: - CelestiaError Extension

extension CelestiaError {
    /// User-friendly message for display in Firebase error contexts
    /// This extends the base errorDescription with Firebase-specific messaging
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
        case .emailNotVerified:
            return "Please verify your email address to continue."
        case .authOperationNotAllowed:
            return "This sign-in method is not enabled."

        // Network errors
        case .networkError:
            return "Network connection error. Please check your internet."
        case .serviceTemporarilyUnavailable:
            return "Service temporarily unavailable. Please try again."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .serverError:
            return "Server error occurred. Please try again later."

        // Storage errors
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .storageQuotaExceeded:
            return "Storage quota exceeded. Please contact support."
        case .imageTooBig:
            return "Image is too large. Please choose a smaller image."

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
        case .notImplemented:
            return "This feature is not yet available."
        case .invalidData:
            return "Invalid data received. Please try again."

        default:
            return self.localizedDescription
        }
    }
}
