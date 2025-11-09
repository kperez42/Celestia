//
//  ErrorHandler.swift
//  Celestia
//
//  Centralized error handling with retry logic and exponential backoff
//

import Foundation

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showingError: Bool = false

    private init() {}

    // MARK: - Error Handling

    func handle(_ error: Error, context: String = "") {
        let appError = convertToAppError(error, context: context)
        currentError = appError
        showingError = true

        // Log error for debugging
        print("❌ Error [\(context)]: \(error.localizedDescription)")
    }

    func dismissError() {
        currentError = nil
        showingError = false
    }

    // MARK: - Retry Logic

    func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        exponentialBackoff: Bool = true,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var currentAttempt = 0
        var currentDelay = delay

        while currentAttempt < maxAttempts {
            do {
                return try await operation()
            } catch {
                currentAttempt += 1

                if currentAttempt >= maxAttempts {
                    throw error
                }

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))

                // Exponential backoff: 1s, 2s, 4s, 8s...
                if exponentialBackoff {
                    currentDelay *= 2
                }

                print("⚠️ Retry attempt \(currentAttempt)/\(maxAttempts) after \(currentDelay)s delay")
            }
        }

        // This should never be reached, but Swift requires it
        throw AppError.unknown("Retry attempts exhausted")
    }

    // MARK: - Error Conversion

    private func convertToAppError(_ error: Error, context: String) -> AppError {
        // Check if it's already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .network(.noConnection)
            case .timedOut:
                return .network(.timeout)
            default:
                return .network(.unknown)
            }
        }

        // Check for NSError codes
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(.noConnection)
        }

        // Default to unknown error
        return .unknown(error.localizedDescription)
    }
}

// MARK: - App Error Types

enum AppError: LocalizedError, Identifiable {
    case network(NetworkError)
    case authentication(String)
    case database(String)
    case validation(String)
    case unknown(String)

    var id: String {
        errorDescription ?? "unknown"
    }

    var errorDescription: String? {
        switch self {
        case .network(let networkError):
            return networkError.errorDescription
        case .authentication(let message):
            return message
        case .database(let message):
            return "Database Error: \(message)"
        case .validation(let message):
            return message
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network(let networkError):
            return networkError.recoverySuggestion
        case .authentication:
            return "Please sign in again to continue."
        case .database:
            return "Please try again. If the problem persists, contact support."
        case .validation:
            return "Please check your input and try again."
        case .unknown:
            return "Please try again. If the problem persists, contact support."
        }
    }

    var icon: String {
        switch self {
        case .network:
            return "wifi.exclamationmark"
        case .authentication:
            return "person.crop.circle.badge.exclamationmark"
        case .database:
            return "externaldrive.badge.exclamationmark"
        case .validation:
            return "exclamationmark.triangle"
        case .unknown:
            return "exclamationmark.circle"
        }
    }

    var retryable: Bool {
        switch self {
        case .network, .database, .unknown:
            return true
        case .authentication, .validation:
            return false
        }
    }
}
