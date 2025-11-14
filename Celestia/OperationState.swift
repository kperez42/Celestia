//
//  OperationState.swift
//  Celestia
//
//  Generic state wrapper for async operations with loading/success/error states
//

import Foundation

/// Represents the state of an asynchronous operation
///
/// Usage:
/// ```swift
/// @Published var userState: OperationState<User> = .idle
///
/// func loadUser() async {
///     userState = .loading
///     do {
///         let user = try await userService.fetchUser(id: "123")
///         userState = .success(user)
///     } catch let error as CelestiaError {
///         userState = .failure(error)
///     }
/// }
/// ```
enum OperationState<T>: Equatable where T: Equatable {
    /// Initial state - no operation has been performed
    case idle

    /// Operation is in progress
    case loading

    /// Operation completed successfully with a value
    case success(T)

    /// Operation failed with an error
    case failure(CelestiaError)

    // MARK: - Computed Properties

    /// Whether the operation is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Whether the operation completed successfully
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    /// Whether the operation failed
    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }

    /// Whether the operation is idle
    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    /// The success value if available
    var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    /// The error if the operation failed
    var error: CelestiaError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

    /// User-friendly error message if available
    var errorMessage: String? {
        error?.localizedMessage
    }

    // MARK: - Convenience Methods

    /// Reset to idle state
    mutating func reset() {
        self = .idle
    }

    /// Start loading
    mutating func startLoading() {
        self = .loading
    }

    /// Set success with value
    mutating func succeed(with value: T) {
        self = .success(value)
    }

    /// Set failure with error
    mutating func fail(with error: CelestiaError) {
        self = .failure(error)
    }

    /// Map success value to another type
    func map<U>(_ transform: (T) -> U) -> OperationState<U> where U: Equatable {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Flat map for chaining operations
    func flatMap<U>(_ transform: (T) -> OperationState<U>) -> OperationState<U> where U: Equatable {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Equatable

    static func == (lhs: OperationState<T>, rhs: OperationState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.success(let lValue), .success(let rValue)):
            return lValue == rValue
        case (.failure(let lError), .failure(let rError)):
            return lError == rError
        default:
            return false
        }
    }
}

// MARK: - Extensions for Common Types

extension OperationState where T == Void {
    /// Create a success state for Void operations
    static var completed: OperationState<Void> {
        return .success(())
    }
}

extension OperationState where T: Collection {
    /// Whether the success value is empty
    var isEmpty: Bool {
        value?.isEmpty ?? true
    }

    /// Count of elements if success
    var count: Int {
        value?.count ?? 0
    }
}

// MARK: - CustomStringConvertible

extension OperationState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            return "OperationState.idle"
        case .loading:
            return "OperationState.loading"
        case .success:
            return "OperationState.success(\(String(describing: value)))"
        case .failure(let error):
            return "OperationState.failure(\(error.localizedMessage))"
        }
    }
}

// MARK: - Helper for Array Operations

/// State for operations returning arrays
typealias ListState<T: Equatable> = OperationState<[T]>

extension OperationState where T == [Any] {
    /// Whether the list has items
    var hasItems: Bool {
        if case .success(let items) = self, !items.isEmpty {
            return true
        }
        return false
    }
}
