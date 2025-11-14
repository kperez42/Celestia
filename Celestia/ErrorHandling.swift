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
    case emailAlreadyExists
    case weakPassword
    case emailNotVerified
    case accountDisabled

    // User Errors
    case userNotFound
    case profileIncomplete
    case invalidProfileData
    case ageRestriction

    // Network Errors
    case networkError
    case timeout
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

    // Rate Limiting
    case rateLimitExceeded
    case rateLimitExceededWithTime(TimeInterval)

    // Media Errors
    case imageUploadFailed
    case imageTooBig
    case invalidImageFormat
    case tooManyImages

    // Premium Errors
    case premiumRequired
    case subscriptionExpired
    case purchaseFailed
    case restoreFailed

    // General Errors
    case unknown
    case invalidData
    case permissionDenied

    var errorDescription: String? {
        switch self {
        // Authentication
        case .notAuthenticated:
            return "You need to be signed in to perform this action."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailAlreadyExists:
            return "This email is already registered. Please sign in instead."
        case .weakPassword:
            return "Password must be at least 8 characters long."
        case .emailNotVerified:
            return "Please verify your email address before continuing."
        case .accountDisabled:
            return "Your account has been disabled. Contact support for help."

        // User
        case .userNotFound:
            return "User not found. They may have deleted their account."
        case .profileIncomplete:
            return "Please complete your profile to continue."
        case .invalidProfileData:
            return "Some profile information is invalid. Please check and try again."
        case .ageRestriction:
            return "You must be 18 or older to use Celestia."

        // Network
        case .networkError:
            return "Network error occurred. Please check your connection."
        case .timeout:
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
        case .imageTooBig:
            return "Image is too large. Please choose a smaller image."
        case .invalidImageFormat:
            return "Invalid image format. Please use JPEG or PNG."
        case .tooManyImages:
            return "You've reached the maximum number of photos (6)."

        // Premium
        case .premiumRequired:
            return "This feature requires Celestia Premium."
        case .subscriptionExpired:
            return "Your premium subscription has expired."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Failed to restore purchases. Please try again."

        // General
        case .unknown:
            return "An unexpected error occurred. Please try again."
        case .invalidData:
            return "Invalid data received. Please try again."
        case .permissionDenied:
            return "Permission denied. Please check your settings."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to your account."
        case .invalidCredentials:
            return "Double-check your email and password."
        case .emailAlreadyExists:
            return "Use the sign in page instead."
        case .weakPassword:
            return "Use a stronger password with letters, numbers, and symbols."
        case .networkError, .noInternetConnection:
            return "Check your internet connection and try again."
        case .serverError, .timeout, .serviceTemporarilyUnavailable:
            return "Wait a moment and try again."
        case .premiumRequired:
            return "Upgrade to Premium to unlock this feature."
        case .imageTooBig:
            return "Reduce image size or quality before uploading."
        case .profileIncomplete:
            return "Complete your profile in Settings."
        case .batchOperationFailed:
            return "The operation will be retried automatically. If the problem persists, contact support."
        default:
            return "If the problem persists, contact support."
        }
    }

    var icon: String {
        switch self {
        case .notAuthenticated, .invalidCredentials:
            return "lock.shield"
        case .networkError, .noInternetConnection, .timeout:
            return "wifi.slash"
        case .serverError, .serviceTemporarilyUnavailable:
            return "server.rack"
        case .userNotFound, .matchNotFound:
            return "person.slash"
        case .premiumRequired, .subscriptionExpired:
            return "crown"
        case .imageUploadFailed, .imageTooBig, .invalidImageFormat:
            return "photo"
        case .messageNotSent, .batchOperationFailed:
            return "message.badge.exclamationmark"
        case .userBlocked:
            return "hand.raised"
        case .inappropriateContent, .inappropriateContentWithReasons:
            return "exclamationmark.triangle.fill"
        case .rateLimitExceeded, .rateLimitExceededWithTime:
            return "clock.fill"
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
                return .timeout
            default:
                return .networkError
            }
        }

        // Firebase errors
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17007: // Email already in use
                return .emailAlreadyExists
            case 17008, 17009: // Invalid credentials
                return .invalidCredentials
            case 17011: // User not found
                return .userNotFound
            case 17026: // Weak password
                return .weakPassword
            default:
                return .unknown
            }
        }

        return .unknown
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

// MARK: - Error State Enum

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(CelestiaError)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var error: CelestiaError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

    var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}

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
