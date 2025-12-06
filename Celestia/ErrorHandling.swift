//
//  ErrorHandling.swift
//  Celestia
//
//  Created by Claude
//  Comprehensive error handling system
//

import Foundation
import SwiftUI

// MARK: - App Errors

enum CelestiaError: LocalizedError, Identifiable {
    var id: String { errorDescription ?? "unknown_error" }

    // Authentication Errors
    case notAuthenticated
    case invalidCredentials
    case invalidEmail
    case wrongPassword
    case emailAlreadyExists
    case emailAlreadyInUse  // Alias for emailAlreadyExists
    case weakPassword
    case emailNotVerified
    case accountDisabled
    case sessionExpired
    case requiresRecentLogin
    case authenticationFailed(String)
    case tooManyRequests
    case authOperationNotAllowed

    // Authorization Errors
    case unauthorized
    case unauthenticated

    // User Errors
    case userNotFound
    case profileIncomplete
    case invalidProfileData
    case ageRestriction
    case validationError(field: String, reason: String)

    // Network Errors
    case networkError
    case timeout
    case requestTimeout
    case serverError
    case noInternetConnection
    case serviceTemporarilyUnavailable

    // Match Errors
    case alreadyMatched
    case matchNotFound
    case cannotMatchWithSelf
    case userBlocked

    // Check-in Errors
    case checkInNotFound

    // Message Errors
    case messageNotSent
    case messageTooLong
    case inappropriateContent
    case inappropriateContentWithReasons([String])
    case batchOperationFailed(operationId: String, underlyingError: Error)
    case messageDeliveryFailed(retryable: Bool)
    case messageQueuedForDelivery
    case editTimeLimitExceeded

    // Rate Limiting
    case rateLimitExceeded
    case rateLimitExceededWithTime(TimeInterval)

    // Media Errors
    case imageUploadFailed
    case uploadFailed(String)
    case imageTooBig
    case invalidImageFormat
    case tooManyImages
    case storageQuotaExceeded
    case contentNotAllowed(String)

    // Premium Errors
    case premiumRequired
    case subscriptionExpired
    case purchaseFailed
    case restoreFailed

    // Database Errors
    case documentNotFound
    case duplicateEntry
    case databaseError(String)

    // Operation Errors
    case operationCancelled
    case configurationError(String)
    case notImplemented
    case invalidInput(String)
    case invalidOperation(String)

    // General Errors
    case unknown(String)
    case invalidData
    case permissionDenied

    var errorDescription: String? {
        switch self {
        // Authentication
        case .notAuthenticated:
            return "You need to be signed in to perform this action."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .emailAlreadyExists, .emailAlreadyInUse:
            return "This email is already registered. Please sign in instead."
        case .weakPassword:
            return "Password must be at least 8 characters long."
        case .emailNotVerified:
            return "Please verify your email address before continuing."
        case .accountDisabled:
            return "Your account has been disabled. Contact support for help."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .requiresRecentLogin:
            return "For security, please sign in again to continue."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .authOperationNotAllowed:
            return "This operation is not allowed. Please contact support."

        // Authorization
        case .unauthorized:
            return "You are not authorized for this action."
        case .unauthenticated:
            return "Please sign in to continue."

        // User
        case .userNotFound:
            return "User not found. They may have deleted their account."
        case .profileIncomplete:
            return "Please complete your profile to continue."
        case .invalidProfileData:
            return "Some profile information is invalid. Please check and try again."
        case .ageRestriction:
            return "You must be 18 or older to use Celestia."
        case .validationError(let field, let reason):
            return "Validation error for \(field): \(reason)"

        // Network
        case .networkError:
            return "Network error occurred. Please check your connection."
        case .timeout, .requestTimeout:
            return "Request timed out. Please try again."
        case .serverError:
            return "Server error occurred. Please try again later."
        case .noInternetConnection:
            return "No internet connection. Please check your network settings."
        case .serviceTemporarilyUnavailable:
            return "Service temporarily unavailable. Please try again in a few moments."

        // Match
        case .alreadyMatched:
            return "You're already matched with this user."
        case .matchNotFound:
            return "Match not found."
        case .cannotMatchWithSelf:
            return "You cannot match with yourself."
        case .userBlocked:
            return "This user has blocked you or you've blocked them."

        // Check-in
        case .checkInNotFound:
            return "Check-in not found."

        // Message
        case .messageNotSent:
            return "Message failed to send. Please try again."
        case .messageTooLong:
            return "Message is too long. Please shorten your message."
        case .inappropriateContent:
            return "Message contains inappropriate content."
        case .inappropriateContentWithReasons(let reasons):
            return "Content violation: " + reasons.joined(separator: ", ")
        case .batchOperationFailed(let operationId, let underlyingError):
            return "Operation \(operationId) failed after multiple retries: \(underlyingError.localizedDescription)"
        case .messageDeliveryFailed(let retryable):
            return retryable ? "Message delivery failed. It will be retried automatically." : "Message could not be delivered."
        case .messageQueuedForDelivery:
            return "Message queued. It will be sent when connection is restored."
        case .editTimeLimitExceeded:
            return "Messages can only be edited within 15 minutes of sending."

        // Rate Limiting
        case .rateLimitExceeded:
            return "You're doing that too often. Please wait a moment and try again."
        case .rateLimitExceededWithTime(let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
            let timeString = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
            return "Rate limit exceeded. Try again in \(timeString)."

        // Media
        case .imageUploadFailed:
            return "Failed to upload image. Please try again."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .imageTooBig:
            return "Image is too large. Please choose a smaller image."
        case .invalidImageFormat:
            return "Invalid image format. Please use JPEG or PNG."
        case .tooManyImages:
            return "You've reached the maximum number of photos (6)."
        case .storageQuotaExceeded:
            return "Storage quota exceeded. Please contact support."
        case .contentNotAllowed(let message):
            return message.isEmpty ? "This content is not allowed. Please choose appropriate content." : message

        // Premium
        case .premiumRequired:
            return "This feature requires Celestia Premium."
        case .subscriptionExpired:
            return "Your premium subscription has expired."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Failed to restore purchases. Please try again."

        // Database
        case .documentNotFound:
            return "Requested data not found."
        case .duplicateEntry:
            return "This entry already exists."
        case .databaseError(let message):
            return "Database error: \(message)"

        // Operations
        case .operationCancelled:
            return "Operation was cancelled."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .notImplemented:
            return "This feature is not implemented in test mode."
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"

        // General
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred. Please try again." : message
        case .invalidData:
            return "Invalid data received. Please try again."
        case .permissionDenied:
            return "Permission denied. Please check your settings."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated, .unauthenticated:
            return "Please sign in to your account."
        case .invalidCredentials, .invalidEmail, .wrongPassword:
            return "Double-check your email and password."
        case .emailAlreadyExists, .emailAlreadyInUse:
            return "Use the sign in page instead."
        case .weakPassword:
            return "Use a stronger password with letters, numbers, and symbols."
        case .networkError, .noInternetConnection:
            return "Check your internet connection and try again."
        case .serverError, .timeout, .requestTimeout, .serviceTemporarilyUnavailable:
            return "Wait a moment and try again."
        case .sessionExpired, .requiresRecentLogin:
            return "Please sign in again."
        case .premiumRequired:
            return "Upgrade to Premium to unlock this feature."
        case .imageTooBig:
            return "Reduce image size or quality before uploading."
        case .contentNotAllowed:
            return "Choose a different photo that follows our community guidelines."
        case .profileIncomplete:
            return "Complete your profile in Settings."
        case .batchOperationFailed:
            return "The operation will be retried automatically. If the problem persists, contact support."
        case .messageDeliveryFailed(let retryable):
            return retryable ? "Check your internet connection. The message will be sent automatically when connected." : "Please try sending the message again."
        case .messageQueuedForDelivery:
            return "Your message is saved and will be sent automatically when you're back online."
        case .tooManyRequests, .rateLimitExceeded, .rateLimitExceededWithTime:
            return "Please wait a moment before trying again."
        case .unauthorized, .permissionDenied:
            return "Contact support if you believe this is an error."
        default:
            return "If the problem persists, contact support."
        }
    }

    var icon: String {
        switch self {
        case .notAuthenticated, .invalidCredentials, .invalidEmail, .wrongPassword,
             .sessionExpired, .requiresRecentLogin, .authenticationFailed,
             .unauthenticated, .unauthorized:
            return "lock.shield"
        case .networkError, .noInternetConnection, .timeout, .requestTimeout:
            return "wifi.slash"
        case .serverError, .serviceTemporarilyUnavailable:
            return "server.rack"
        case .userNotFound, .matchNotFound, .documentNotFound:
            return "person.slash"
        case .premiumRequired, .subscriptionExpired:
            return "crown"
        case .imageUploadFailed, .uploadFailed, .imageTooBig, .invalidImageFormat, .storageQuotaExceeded:
            return "photo"
        case .contentNotAllowed:
            return "exclamationmark.triangle.fill"
        case .messageNotSent, .batchOperationFailed, .messageDeliveryFailed:
            return "message.badge.exclamationmark"
        case .messageQueuedForDelivery:
            return "clock.arrow.circlepath"
        case .userBlocked:
            return "hand.raised"
        case .inappropriateContent, .inappropriateContentWithReasons:
            return "exclamationmark.triangle.fill"
        case .rateLimitExceeded, .rateLimitExceededWithTime, .tooManyRequests:
            return "clock.fill"
        case .operationCancelled:
            return "xmark.circle"
        case .configurationError, .databaseError:
            return "gearshape.fill"
        default:
            return "exclamationmark.triangle"
        }
    }

    static func from(_ error: Error) -> CelestiaError {
        if let celestiaError = error as? CelestiaError {
            return celestiaError
        }

        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .noInternetConnection
            case NSURLErrorTimedOut:
                return .requestTimeout
            default:
                return .networkError
            }
        }

        // Firebase errors - delegate to FirebaseErrorMapper if available
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17007: // Email already in use
                return .emailAlreadyInUse
            case 17008: // Invalid email
                return .invalidEmail
            case 17009: // Wrong password
                return .wrongPassword
            case 17011: // User not found
                return .userNotFound
            case 17026: // Weak password
                return .weakPassword
            case 17010: // User disabled
                return .accountDisabled
            case 17020: // Network error
                return .networkError
            default:
                return .unknown(nsError.localizedDescription)
            }
        }

        return .unknown(nsError.localizedDescription)
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlert: ViewModifier {
    @Binding var error: CelestiaError?

    func body(content: Content) -> some View {
        content
            .alert(item: $error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage(for: error)),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private func errorMessage(for error: CelestiaError) -> String {
        var message = error.errorDescription ?? "An error occurred"
        if let suggestion = error.recoverySuggestion {
            message += "\n\n\(suggestion)"
        }
        return message
    }
}

extension View {
    func errorAlert(_ error: Binding<CelestiaError?>) -> some View {
        modifier(ErrorAlert(error: error))
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: CelestiaError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: error.icon)
                .font(.title2)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(error.errorDescription ?? "An error occurred")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: CelestiaError
    let retryAction: (() -> Void)?

    init(error: CelestiaError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: error.icon)
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.7))

            VStack(spacing: 12) {
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(error.errorDescription ?? "An error occurred")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)

            if let retryAction = retryAction {
                Button {
                    retryAction()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State Enum (REMOVED - now using LoadingState.swift)
// LoadingState<T> is now defined in LoadingState.swift for consistent usage across the app

#Preview("Error View") {
    ErrorView(error: .networkError) {
        print("Retry tapped")
    }
}

#Preview("Error Banner") {
    VStack {
        ErrorBanner(error: .notAuthenticated) {
            print("Dismissed")
        }
        Spacer()
    }
}
