//
//  CelestiaError.swift
//  Celestia
//
//  Centralized error handling for the app
//

import Foundation

/// App-wide error type with user-friendly messages
enum CelestiaError: LocalizedError, Equatable {

    // MARK: - Authentication Errors

    case invalidCredentials
    case emailNotVerified
    case accountDisabled
    case weakPassword
    case emailAlreadyInUse
    case invalidEmail
    case userNotAuthenticated

    // MARK: - User & Profile Errors

    case userNotFound
    case profileIncomplete
    case invalidUserData(String)
    case ageRestriction
    case blockedUser
    case reportedUser

    // MARK: - Database & Network Errors

    case databaseError(Error)
    case networkError(Error)
    case connectionFailed
    case timeout
    case serverError

    // MARK: - Validation Errors

    case validationError(String)
    case invalidInput(field: String, reason: String)
    case missingRequiredField(String)
    case contentModeration(reason: String)

    // MARK: - Business Logic Errors

    case dailyLimitExceeded
    case subscriptionRequired
    case insufficientBalance
    case featureNotAvailable
    case actionNotAllowed(reason: String)

    // MARK: - Match & Message Errors

    case matchNotFound
    case messageFailedToSend
    case conversationNotFound
    case cannotUnmatch

    // MARK: - Media Errors

    case imageUploadFailed
    case imageProcessingFailed
    case invalidImageFormat
    case imageTooLarge

    // MARK: - Payment Errors

    case purchaseFailed
    case receiptValidationFailed
    case productNotFound
    case paymentCancelled

    // MARK: - Search & Discovery Errors

    case searchFailed
    case noResultsFound
    case invalidSearchQuery

    // MARK: - Unknown Error

    case unknown(Error)

    // MARK: - LocalizedError Protocol

    var errorDescription: String? {
        localizedMessage
    }

    /// User-friendly error message
    var localizedMessage: String {
        switch self {
        // Authentication
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailNotVerified:
            return "Please verify your email address to continue."
        case .accountDisabled:
            return "Your account has been disabled. Contact support for help."
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and numbers."
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in instead."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .userNotAuthenticated:
            return "You must be signed in to perform this action."

        // User & Profile
        case .userNotFound:
            return "User not found. They may have deleted their account."
        case .profileIncomplete:
            return "Please complete your profile to continue."
        case .invalidUserData(let field):
            return "Invalid data for \(field). Please check and try again."
        case .ageRestriction:
            return "You must be 18 or older to use this app."
        case .blockedUser:
            return "You have blocked this user."
        case .reportedUser:
            return "This user has been reported."

        // Database & Network
        case .databaseError:
            return "Database error. Please try again later."
        case .networkError:
            return "Network error. Check your internet connection."
        case .connectionFailed:
            return "Connection failed. Please check your internet and try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError:
            return "Server error. Our team has been notified."

        // Validation
        case .validationError(let message):
            return message
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .missingRequiredField(let field):
            return "\(field) is required."
        case .contentModeration(let reason):
            return "Content not allowed: \(reason)"

        // Business Logic
        case .dailyLimitExceeded:
            return "Daily limit exceeded. Upgrade to premium for unlimited access."
        case .subscriptionRequired:
            return "This feature requires a premium subscription."
        case .insufficientBalance:
            return "Insufficient balance. Please purchase more to continue."
        case .featureNotAvailable:
            return "This feature is not available yet."
        case .actionNotAllowed(let reason):
            return "Action not allowed: \(reason)"

        // Match & Message
        case .matchNotFound:
            return "Match not found. You may have been unmatched."
        case .messageFailedToSend:
            return "Failed to send message. Please try again."
        case .conversationNotFound:
            return "Conversation not found."
        case .cannotUnmatch:
            return "Cannot unmatch at this time. Please try again later."

        // Media
        case .imageUploadFailed:
            return "Failed to upload image. Please try again."
        case .imageProcessingFailed:
            return "Failed to process image. Try a different image."
        case .invalidImageFormat:
            return "Invalid image format. Please use JPG or PNG."
        case .imageTooLarge:
            return "Image is too large. Maximum size is 10MB."

        // Payment
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .receiptValidationFailed:
            return "Receipt validation failed. Contact support if charged."
        case .productNotFound:
            return "Product not found in the App Store."
        case .paymentCancelled:
            return "Payment cancelled."

        // Search & Discovery
        case .searchFailed:
            return "Search failed. Please try again."
        case .noResultsFound:
            return "No results found. Try a different search."
        case .invalidSearchQuery:
            return "Invalid search query. Please try different keywords."

        // Unknown
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }

    /// Technical error message for logging
    var technicalDescription: String {
        switch self {
        case .databaseError(let error),
             .networkError(let error),
             .unknown(let error):
            return "\(self): \(error.localizedDescription)"
        default:
            return "\(self)"
        }
    }

    /// Error category for analytics
    var category: ErrorCategory {
        switch self {
        case .invalidCredentials, .emailNotVerified, .accountDisabled, .weakPassword,
             .emailAlreadyInUse, .invalidEmail, .userNotAuthenticated:
            return .authentication

        case .userNotFound, .profileIncomplete, .invalidUserData, .ageRestriction,
             .blockedUser, .reportedUser:
            return .user

        case .databaseError, .networkError, .connectionFailed, .timeout, .serverError:
            return .network

        case .validationError, .invalidInput, .missingRequiredField, .contentModeration:
            return .validation

        case .dailyLimitExceeded, .subscriptionRequired, .insufficientBalance,
             .featureNotAvailable, .actionNotAllowed:
            return .businessLogic

        case .matchNotFound, .messageFailedToSend, .conversationNotFound, .cannotUnmatch:
            return .social

        case .imageUploadFailed, .imageProcessingFailed, .invalidImageFormat, .imageTooLarge:
            return .media

        case .purchaseFailed, .receiptValidationFailed, .productNotFound, .paymentCancelled:
            return .payment

        case .searchFailed, .noResultsFound, .invalidSearchQuery:
            return .search

        case .unknown:
            return .unknown
        }
    }

    /// Whether this error should be retried
    var isRetryable: Bool {
        switch self {
        case .networkError, .connectionFailed, .timeout, .serverError,
             .messageFailedToSend, .imageUploadFailed:
            return true
        default:
            return false
        }
    }

    // MARK: - Equatable

    static func == (lhs: CelestiaError, rhs: CelestiaError) -> Bool {
        switch (lhs, rhs) {
        // Authentication
        case (.invalidCredentials, .invalidCredentials),
             (.emailNotVerified, .emailNotVerified),
             (.accountDisabled, .accountDisabled),
             (.weakPassword, .weakPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.invalidEmail, .invalidEmail),
             (.userNotAuthenticated, .userNotAuthenticated),

        // User & Profile
             (.userNotFound, .userNotFound),
             (.profileIncomplete, .profileIncomplete),
             (.ageRestriction, .ageRestriction),
             (.blockedUser, .blockedUser),
             (.reportedUser, .reportedUser),

        // Database & Network
             (.connectionFailed, .connectionFailed),
             (.timeout, .timeout),
             (.serverError, .serverError),

        // Business Logic
             (.dailyLimitExceeded, .dailyLimitExceeded),
             (.subscriptionRequired, .subscriptionRequired),
             (.insufficientBalance, .insufficientBalance),
             (.featureNotAvailable, .featureNotAvailable),

        // Match & Message
             (.matchNotFound, .matchNotFound),
             (.messageFailedToSend, .messageFailedToSend),
             (.conversationNotFound, .conversationNotFound),
             (.cannotUnmatch, .cannotUnmatch),

        // Media
             (.imageUploadFailed, .imageUploadFailed),
             (.imageProcessingFailed, .imageProcessingFailed),
             (.invalidImageFormat, .invalidImageFormat),
             (.imageTooLarge, .imageTooLarge),

        // Payment
             (.purchaseFailed, .purchaseFailed),
             (.receiptValidationFailed, .receiptValidationFailed),
             (.productNotFound, .productNotFound),
             (.paymentCancelled, .paymentCancelled),

        // Search
             (.searchFailed, .searchFailed),
             (.noResultsFound, .noResultsFound),
             (.invalidSearchQuery, .invalidSearchQuery):
            return true

        // Cases with associated values
        case (.invalidUserData(let l), .invalidUserData(let r)),
             (.validationError(let l), .validationError(let r)),
             (.contentModeration(let l), .contentModeration(let r)),
             (.missingRequiredField(let l), .missingRequiredField(let r)):
            return l == r

        case (.invalidInput(let lField, let lReason), .invalidInput(let rField, let rReason)):
            return lField == rField && lReason == rReason

        case (.actionNotAllowed(let l), .actionNotAllowed(let r)):
            return l == r

        default:
            return false
        }
    }
}

// MARK: - Error Category

enum ErrorCategory: String {
    case authentication
    case user
    case network
    case validation
    case businessLogic
    case social
    case media
    case payment
    case search
    case unknown
}

// MARK: - Error Conversion Helpers

extension CelestiaError {
    /// Convert from NSError
    static func from(_ error: Error) -> CelestiaError {
        // Already a CelestiaError
        if let celestiaError = error as? CelestiaError {
            return celestiaError
        }

        // Network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .networkError(error)
            case .timedOut:
                return .timeout
            default:
                return .networkError(error)
            }
        }

        // StoreKit errors
        if let nsError = error as NSError, nsError.domain == "SKErrorDomain" {
            switch nsError.code {
            case 2: // SKError.paymentCancelled
                return .paymentCancelled
            default:
                return .purchaseFailed
            }
        }

        // Default
        return .unknown(error)
    }
}
