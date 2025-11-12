//
//  ErrorPresenter.swift
//  Celestia
//
//  Centralized error presentation and recovery system
//  Manages error display, retry logic, and user feedback
//

import Foundation
import SwiftUI
import Combine

// MARK: - Error Presentation Style

enum ErrorPresentationStyle {
    case banner      // Toast-style banner at top
    case alert       // System alert dialog
    case inline      // Inline error message
    case fullScreen  // Full-screen error view
}

// MARK: - Error Presenter

@MainActor
class ErrorPresenter: ObservableObject {

    static let shared = ErrorPresenter()

    // MARK: - Published Properties

    @Published var currentError: CelestiaError?
    @Published var showBanner: Bool = false
    @Published var showAlert: Bool = false
    @Published var presentationStyle: ErrorPresentationStyle = .banner

    // MARK: - Properties

    private var retryAction: (() async -> Void)?
    private var dismissWorkItem: DispatchWorkItem?
    private var errorHistory: [ErrorRecord] = []

    // MARK: - Initialization

    private init() {
        Logger.shared.info("ErrorPresenter initialized", category: .general)
    }

    // MARK: - Present Error

    /// Present an error to the user with optional retry action
    func presentError(
        _ error: CelestiaError,
        style: ErrorPresentationStyle = .banner,
        retryAction: (() async -> Void)? = nil
    ) {
        Logger.shared.error("Presenting error: \(error.errorDescription ?? "unknown")", category: .general)

        // Record error in history
        recordError(error)

        // Cancel any pending dismissal
        dismissWorkItem?.cancel()

        // Update state
        currentError = error
        presentationStyle = style
        self.retryAction = retryAction

        // Show error based on style
        switch style {
        case .banner:
            showBanner = true
            // Auto-dismiss banner after 5 seconds
            scheduleAutoDismiss(delay: 5.0)

        case .alert:
            showAlert = true

        case .inline, .fullScreen:
            // Handled by view
            break
        }

        // Track error in analytics
        AnalyticsManager.shared.logEvent(.error, parameters: [
            "error_type": String(describing: type(of: error)),
            "error_description": error.errorDescription ?? "unknown",
            "presentation_style": String(describing: style)
        ])
    }

    /// Present a generic error
    func presentError(_ error: Error) {
        let celestiaError = CelestiaError.from(error)
        presentError(celestiaError)
    }

    // MARK: - Dismiss Error

    func dismiss() {
        dismissWorkItem?.cancel()

        withAnimation {
            showBanner = false
            showAlert = false
        }

        // Clear error after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentError = nil
            self?.retryAction = nil
        }
    }

    // MARK: - Retry Action

    func retry() {
        guard let retryAction = retryAction else {
            dismiss()
            return
        }

        dismiss()

        Task {
            await retryAction()
        }
    }

    // MARK: - Private Methods

    private func scheduleAutoDismiss(delay: TimeInterval) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func recordError(_ error: CelestiaError) {
        let record = ErrorRecord(
            error: error,
            timestamp: Date()
        )

        errorHistory.append(record)

        // Keep only last 50 errors
        if errorHistory.count > 50 {
            errorHistory.removeFirst()
        }
    }

    // MARK: - Error Statistics

    /// Get error frequency for rate limiting
    func errorFrequency(for errorType: CelestiaError, within timeInterval: TimeInterval) -> Int {
        let cutoffTime = Date().addingTimeInterval(-timeInterval)

        return errorHistory.filter { record in
            record.timestamp >= cutoffTime &&
            String(describing: record.error) == String(describing: errorType)
        }.count
    }

    /// Check if should show error (to prevent error spam)
    func shouldPresentError(_ error: CelestiaError) -> Bool {
        // Don't show more than 3 of the same error in 10 seconds
        let frequency = errorFrequency(for: error, within: 10)
        return frequency < 3
    }
}

// MARK: - Error Record

private struct ErrorRecord {
    let error: CelestiaError
    let timestamp: Date
}

// MARK: - View Modifiers

struct ErrorBannerModifier: ViewModifier {
    @ObservedObject var presenter = ErrorPresenter.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if presenter.showBanner, let error = presenter.currentError {
                ErrorBanner(error: error) {
                    presenter.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: presenter.showBanner)
                .zIndex(999)
            }
        }
    }
}

struct ErrorHandlingModifier: ViewModifier {
    @ObservedObject var presenter = ErrorPresenter.shared

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $presenter.showAlert) {
                if let error = presenter.currentError {
                    return Alert(
                        title: Text("Error"),
                        message: Text(errorMessage(for: error)),
                        primaryButton: presenter.retryAction != nil ?
                            .default(Text("Try Again")) {
                                presenter.retry()
                            } : .default(Text("OK")) {
                                presenter.dismiss()
                            },
                        secondaryButton: .cancel {
                            presenter.dismiss()
                        }
                    )
                }
                return Alert(title: Text("Error"))
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

// MARK: - View Extensions

extension View {
    /// Add error banner support to view
    func withErrorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }

    /// Add full error handling support (alerts + banners)
    func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
            .modifier(ErrorBannerModifier())
    }
}

// MARK: - Retry Manager

@MainActor
class RetryManager {

    static let shared = RetryManager()

    private init() {}

    /// Execute operation with exponential backoff retry
    func executeWithRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 1
        var lastError: Error?

        while attempt <= maxAttempts {
            do {
                let result = try await operation()

                if attempt > 1 {
                    Logger.shared.info("Operation succeeded on attempt \(attempt)", category: .network)
                }

                return result
            } catch {
                lastError = error

                Logger.shared.warning("Operation failed on attempt \(attempt): \(error.localizedDescription)", category: .network)

                // Don't retry on certain errors
                if let celestiaError = error as? CelestiaError {
                    switch celestiaError {
                    case .notAuthenticated, .invalidCredentials, .permissionDenied, .userBlocked:
                        // These errors won't be fixed by retrying
                        throw error
                    default:
                        break
                    }
                }

                // If this was the last attempt, throw the error
                if attempt >= maxAttempts {
                    break
                }

                // Calculate exponential backoff delay
                let delay = initialDelay * pow(2.0, Double(attempt - 1))
                Logger.shared.info("Retrying in \(delay) seconds...", category: .network)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            }
        }

        // If we get here, all attempts failed
        throw lastError ?? CelestiaError.unknown
    }
}

// MARK: - Offline State Manager

@MainActor
class OfflineStateManager: ObservableObject {

    static let shared = OfflineStateManager()

    @Published var isOffline: Bool = false
    @Published var showOfflineMessage: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupReachabilityMonitoring()
    }

    private func setupReachabilityMonitoring() {
        // Monitor network reachability
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                self?.handleConnectivityChange(isConnected: isConnected)
            }
            .store(in: &cancellables)
    }

    private func handleConnectivityChange(isConnected: Bool) {
        isOffline = !isConnected

        if !isConnected {
            Logger.shared.warning("Device went offline", category: .network)
            showOfflineMessage = true

            // Present offline error
            ErrorPresenter.shared.presentError(.noInternetConnection, style: .banner)
        } else if isOffline != !isConnected {
            Logger.shared.info("Device came back online", category: .network)
            showOfflineMessage = false

            // Dismiss offline error if shown
            if let currentError = ErrorPresenter.shared.currentError,
               case .noInternetConnection = currentError {
                ErrorPresenter.shared.dismiss()
            }
        }
    }
}

// MARK: - Offline Banner View

struct OfflineBanner: View {
    @ObservedObject var offlineManager = OfflineStateManager.shared

    var body: some View {
        if offlineManager.showOfflineMessage {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)

                Text("No Internet Connection")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .background(Color.orange)
            .transition(.move(edge: .top))
            .animation(.spring(response: 0.3), value: offlineManager.showOfflineMessage)
        }
    }
}
