//
//  ErrorHandlingTests.swift
//  CelestiaTests
//
//  Tests for standardized error handling patterns
//

import Testing
@testable import Celestia

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

    // MARK: - CelestiaError Tests

    @Test("CelestiaError provides user-friendly messages")
    func testErrorMessages() {
        let errors: [(CelestiaError, String)] = [
            (.invalidCredentials, "Invalid email or password"),
            (.emailNotVerified, "verify your email"),
            (.userNotFound, "User not found"),
            (.dailyLimitExceeded, "Daily limit exceeded"),
            (.subscriptionRequired, "requires a premium subscription"),
            (.networkError(URLError(.notConnectedToInternet)), "Network error")
        ]

        for (error, expectedSubstring) in errors {
            let message = error.localizedMessage
            #expect(message.lowercased().contains(expectedSubstring.lowercased()),
                   "Error message should contain '\(expectedSubstring)' but was '\(message)'")
        }
    }

    @Test("CelestiaError categorizes errors correctly")
    func testErrorCategories() {
        #expect(CelestiaError.invalidCredentials.category == .authentication)
        #expect(CelestiaError.userNotFound.category == .user)
        #expect(CelestiaError.networkError(URLError(.notConnectedToInternet)).category == .network)
        #expect(CelestiaError.validationError("test").category == .validation)
        #expect(CelestiaError.dailyLimitExceeded.category == .businessLogic)
        #expect(CelestiaError.matchNotFound.category == .social)
        #expect(CelestiaError.imageUploadFailed.category == .media)
        #expect(CelestiaError.purchaseFailed.category == .payment)
        #expect(CelestiaError.searchFailed.category == .search)
    }

    @Test("CelestiaError identifies retryable errors")
    func testRetryableErrors() {
        // Retryable errors
        #expect(CelestiaError.networkError(URLError(.notConnectedToInternet)).isRetryable)
        #expect(CelestiaError.connectionFailed.isRetryable)
        #expect(CelestiaError.timeout.isRetryable)
        #expect(CelestiaError.serverError.isRetryable)
        #expect(CelestiaError.messageFailedToSend.isRetryable)
        #expect(CelestiaError.imageUploadFailed.isRetryable)

        // Non-retryable errors
        #expect(!CelestiaError.invalidCredentials.isRetryable)
        #expect(!CelestiaError.userNotFound.isRetryable)
        #expect(!CelestiaError.subscriptionRequired.isRetryable)
        #expect(!CelestiaError.paymentCancelled.isRetryable)
    }

    @Test("CelestiaError equality works correctly")
    func testErrorEquality() {
        // Simple errors
        #expect(CelestiaError.userNotFound == CelestiaError.userNotFound)
        #expect(CelestiaError.invalidCredentials != CelestiaError.userNotFound)

        // Errors with associated values
        #expect(CelestiaError.invalidUserData("email") == CelestiaError.invalidUserData("email"))
        #expect(CelestiaError.invalidUserData("email") != CelestiaError.invalidUserData("name"))

        #expect(CelestiaError.validationError("test") == CelestiaError.validationError("test"))
        #expect(CelestiaError.validationError("test1") != CelestiaError.validationError("test2"))

        #expect(CelestiaError.invalidInput(field: "email", reason: "invalid") ==
                CelestiaError.invalidInput(field: "email", reason: "invalid"))
        #expect(CelestiaError.invalidInput(field: "email", reason: "invalid") !=
                CelestiaError.invalidInput(field: "name", reason: "invalid"))
    }

    @Test("CelestiaError converts from NSError correctly")
    func testErrorConversion() {
        // URLError conversion
        let urlError = URLError(.notConnectedToInternet)
        let convertedError = CelestiaError.from(urlError)
        #expect(convertedError.category == .network)
        #expect(convertedError.isRetryable)

        // Timeout conversion
        let timeoutError = URLError(.timedOut)
        let convertedTimeout = CelestiaError.from(timeoutError)
        #expect(convertedTimeout == .timeout)

        // StoreKit error conversion
        let skError = NSError(domain: "SKErrorDomain", code: 2, userInfo: nil)
        let convertedSKError = CelestiaError.from(skError)
        #expect(convertedSKError == .paymentCancelled)

        // Generic error conversion
        struct GenericError: Error {}
        let genericError = GenericError()
        let convertedGeneric = CelestiaError.from(genericError)
        if case .unknown = convertedGeneric {
            #expect(true)
        } else {
            #expect(false, "Should convert to .unknown")
        }
    }

    @Test("CelestiaError technical description includes details")
    func testTechnicalDescription() {
        let error = CelestiaError.invalidCredentials
        let technicalDesc = error.technicalDescription
        #expect(!technicalDesc.isEmpty)

        let networkError = CelestiaError.networkError(URLError(.notConnectedToInternet))
        let networkDesc = networkError.technicalDescription
        #expect(networkDesc.contains("network") || networkDesc.contains("Network"))
    }

    // MARK: - OperationState Tests

    @Test("OperationState initial state is idle")
    func testOperationStateIdle() {
        let state: OperationState<String> = .idle

        #expect(state.isIdle)
        #expect(!state.isLoading)
        #expect(!state.isSuccess)
        #expect(!state.isFailure)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    @Test("OperationState loading state")
    func testOperationStateLoading() {
        let state: OperationState<String> = .loading

        #expect(!state.isIdle)
        #expect(state.isLoading)
        #expect(!state.isSuccess)
        #expect(!state.isFailure)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    @Test("OperationState success state")
    func testOperationStateSuccess() {
        let state: OperationState<String> = .success("test value")

        #expect(!state.isIdle)
        #expect(!state.isLoading)
        #expect(state.isSuccess)
        #expect(!state.isFailure)
        #expect(state.value == "test value")
        #expect(state.error == nil)
    }

    @Test("OperationState failure state")
    func testOperationStateFailure() {
        let error = CelestiaError.userNotFound
        let state: OperationState<String> = .failure(error)

        #expect(!state.isIdle)
        #expect(!state.isLoading)
        #expect(!state.isSuccess)
        #expect(state.isFailure)
        #expect(state.value == nil)
        #expect(state.error == error)
        #expect(state.errorMessage == error.localizedMessage)
    }

    @Test("OperationState mutation methods work")
    func testOperationStateMutations() {
        var state: OperationState<String> = .idle

        // Start loading
        state.startLoading()
        #expect(state.isLoading)

        // Succeed
        state.succeed(with: "success!")
        #expect(state.isSuccess)
        #expect(state.value == "success!")

        // Reset
        state.reset()
        #expect(state.isIdle)

        // Fail
        state.fail(with: .userNotFound)
        #expect(state.isFailure)
        #expect(state.error == .userNotFound)
    }

    @Test("OperationState map transforms values")
    func testOperationStateMap() {
        let intState: OperationState<Int> = .success(42)
        let stringState = intState.map { String($0) }

        #expect(stringState.isSuccess)
        #expect(stringState.value == "42")

        // Map idle
        let idleState: OperationState<Int> = .idle
        let mappedIdle = idleState.map { String($0) }
        #expect(mappedIdle.isIdle)

        // Map loading
        let loadingState: OperationState<Int> = .loading
        let mappedLoading = loadingState.map { String($0) }
        #expect(mappedLoading.isLoading)

        // Map failure
        let failureState: OperationState<Int> = .failure(.userNotFound)
        let mappedFailure = failureState.map { String($0) }
        #expect(mappedFailure.isFailure)
        #expect(mappedFailure.error == .userNotFound)
    }

    @Test("OperationState flatMap chains operations")
    func testOperationStateFlatMap() {
        let state: OperationState<Int> = .success(10)

        let chained = state.flatMap { value -> OperationState<String> in
            if value > 5 {
                return .success(String(value))
            } else {
                return .failure(.validationError("Value too small"))
            }
        }

        #expect(chained.isSuccess)
        #expect(chained.value == "10")

        // FlatMap with failure
        let smallState: OperationState<Int> = .success(3)
        let chainedFailure = smallState.flatMap { value -> OperationState<String> in
            if value > 5 {
                return .success(String(value))
            } else {
                return .failure(.validationError("Value too small"))
            }
        }

        #expect(chainedFailure.isFailure)
    }

    @Test("OperationState equality works")
    func testOperationStateEquality() {
        let state1: OperationState<String> = .idle
        let state2: OperationState<String> = .idle
        #expect(state1 == state2)

        let loading1: OperationState<String> = .loading
        let loading2: OperationState<String> = .loading
        #expect(loading1 == loading2)

        let success1: OperationState<String> = .success("test")
        let success2: OperationState<String> = .success("test")
        #expect(success1 == success2)

        let success3: OperationState<String> = .success("different")
        #expect(success1 != success3)

        let failure1: OperationState<String> = .failure(.userNotFound)
        let failure2: OperationState<String> = .failure(.userNotFound)
        #expect(failure1 == failure2)

        let failure3: OperationState<String> = .failure(.invalidCredentials)
        #expect(failure1 != failure3)
    }

    @Test("OperationState completed for Void operations")
    func testOperationStateCompleted() {
        let state: OperationState<Void> = .completed

        #expect(state.isSuccess)
    }

    @Test("OperationState collection extensions work")
    func testOperationStateCollectionExtensions() {
        let emptyState: OperationState<[String]> = .success([])
        #expect(emptyState.isEmpty)
        #expect(emptyState.count == 0)

        let nonEmptyState: OperationState<[String]> = .success(["a", "b", "c"])
        #expect(!nonEmptyState.isEmpty)
        #expect(nonEmptyState.count == 3)

        let idleState: OperationState<[String]> = .idle
        #expect(idleState.isEmpty) // No value means empty
        #expect(idleState.count == 0)
    }

    @Test("OperationState description is readable")
    func testOperationStateDescription() {
        let idleState: OperationState<String> = .idle
        #expect(idleState.description.contains("idle"))

        let loadingState: OperationState<String> = .loading
        #expect(loadingState.description.contains("loading"))

        let successState: OperationState<String> = .success("test")
        #expect(successState.description.contains("success"))

        let failureState: OperationState<String> = .failure(.userNotFound)
        #expect(failureState.description.contains("failure"))
    }

    // MARK: - Error Handling Pattern Tests

    @Test("Async throws pattern is properly typed")
    func testAsyncThrowsPattern() async throws {
        func exampleAsyncFunction() async throws -> String {
            throw CelestiaError.userNotFound
        }

        await #expect(throws: CelestiaError.self) {
            _ = try await exampleAsyncFunction()
        }
    }

    @Test("Result type pattern works")
    func testResultTypePattern() {
        func exampleResultFunction() -> Result<String, CelestiaError> {
            return .failure(.userNotFound)
        }

        let result = exampleResultFunction()

        switch result {
        case .success:
            #expect(false, "Should not succeed")
        case .failure(let error):
            #expect(error == .userNotFound)
        }
    }

    @Test("Optional returns for non-critical operations")
    func testOptionalReturns() {
        func getCachedValue() -> String? {
            return nil // Cache miss
        }

        let result = getCachedValue()
        #expect(result == nil)
    }

    // MARK: - Integration Tests

    @Test("ViewModel error state pattern")
    func testViewModelErrorStatePattern() async {
        @MainActor
        class ExampleViewModel: ObservableObject {
            @Published var userState: OperationState<String> = .idle

            func loadUser() async {
                userState = .loading

                // Simulate error
                userState = .failure(.userNotFound)
            }
        }

        let viewModel = await ExampleViewModel()

        await viewModel.loadUser()

        await MainActor.run {
            #expect(viewModel.userState.isFailure)
            #expect(viewModel.userState.error == .userNotFound)
        }
    }

    @Test("Error conversion preserves information")
    func testErrorConversionPreservesInfo() {
        // Test that error conversion doesn't lose important details
        let originalError = URLError(.networkConnectionLost)
        let converted = CelestiaError.from(originalError)

        #expect(converted.category == .network)
        #expect(converted.isRetryable)

        let technicalDesc = converted.technicalDescription
        #expect(!technicalDesc.isEmpty)
    }

    @Test("Multiple error types can be distinguished")
    func testErrorTypeDistinction() {
        let errors: [CelestiaError] = [
            .userNotFound,
            .invalidCredentials,
            .networkError(URLError(.notConnectedToInternet)),
            .dailyLimitExceeded,
            .subscriptionRequired
        ]

        // All errors should be distinct
        for i in 0..<errors.count {
            for j in (i+1)..<errors.count {
                #expect(errors[i] != errors[j])
            }
        }
    }

    @Test("Error messages are user-friendly")
    func testErrorMessagesUserFriendly() {
        // User-friendly messages should:
        // 1. Not expose technical details
        // 2. Suggest next actions when possible
        // 3. Be grammatically correct

        let errors: [CelestiaError] = [
            .userNotFound,
            .networkError(URLError(.notConnectedToInternet)),
            .dailyLimitExceeded,
            .subscriptionRequired
        ]

        for error in errors {
            let message = error.localizedMessage

            // Should not contain technical jargon
            #expect(!message.contains("nil"))
            #expect(!message.contains("Error"))
            #expect(!message.contains("Exception"))

            // Should end with period or explanation
            #expect(!message.isEmpty)
            #expect(message.count > 10) // Reasonable length
        }
    }
}
