//
//  BiometricAuthManager.swift
//  Celestia
//
//  Manages Face ID and Touch ID authentication
//  Provides secure biometric login and app locking
//

import Foundation
import LocalAuthentication

/// Manages biometric authentication (Face ID/Touch ID)
@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    // MARK: - Published Properties

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "biometric_auth_enabled")
        }
    }

    @Published var requireOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(requireOnLaunch, forKey: "biometric_required_on_launch")
        }
    }

    // MARK: - Properties

    private let context = LAContext()

    var biometricType: BiometricType {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    var isBiometricAvailable: Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        }
    }

    // MARK: - Initialization

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled")
        self.requireOnLaunch = UserDefaults.standard.bool(forKey: "biometric_required_on_launch")
    }

    // MARK: - Public Methods

    /// Authenticate user with biometrics
    /// - Parameter reason: Reason shown to user in prompt
    /// - Returns: True if authentication succeeded
    func authenticate(reason: String = "Authenticate to access Celestia") async throws -> Bool {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Logger.shared.error("Biometric auth not available: \(error?.localizedDescription ?? "Unknown")", category: .authentication)
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                Logger.shared.info("Biometric authentication succeeded", category: .authentication)
                recordSuccessfulAuth()
            }

            return success
        } catch let error as LAError {
            Logger.shared.warning("Biometric auth failed: \(error.localizedDescription)", category: .authentication)
            throw BiometricError.from(laError: error)
        }
    }

    /// Authenticate with fallback to passcode
    /// - Parameter reason: Reason shown to user
    /// - Returns: True if authentication succeeded
    func authenticateWithPasscode(reason: String = "Authenticate to access Celestia") async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // Falls back to passcode if biometrics fail
                localizedReason: reason
            )

            if success {
                Logger.shared.info("Authentication succeeded (biometric or passcode)", category: .authentication)
                recordSuccessfulAuth()
            }

            return success
        } catch let error as LAError {
            Logger.shared.warning("Authentication failed: \(error.localizedDescription)", category: .authentication)
            throw BiometricError.from(laError: error)
        }
    }

    /// Enable biometric authentication
    /// - Returns: True if successfully enabled
    func enableBiometricAuth() async throws -> Bool {
        guard isBiometricAvailable else {
            throw BiometricError.notAvailable
        }

        // Verify user can authenticate before enabling
        let success = try await authenticate(reason: "Enable \(biometricTypeString) for Celestia")

        if success {
            isEnabled = true
            Logger.shared.info("Biometric auth enabled", category: .authentication)
            AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                "feature": "biometric_auth",
                "action": "enabled",
                "type": biometricTypeString
            ])
        }

        return success
    }

    /// Disable biometric authentication
    func disableBiometricAuth() {
        isEnabled = false
        requireOnLaunch = false
        Logger.shared.info("Biometric auth disabled", category: .authentication)
        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "biometric_auth",
            "action": "disabled"
        ])
    }

    /// Check if should authenticate on app launch
    /// - Returns: True if authentication is required
    func shouldAuthenticateOnLaunch() -> Bool {
        return isEnabled && requireOnLaunch
    }

    // MARK: - Private Methods

    private func recordSuccessfulAuth() {
        UserDefaults.standard.set(Date(), forKey: "last_biometric_auth_date")
        AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "biometric_auth",
            "action": "success",
            "type": biometricTypeString
        ])
    }

    /// Get last successful authentication date
    var lastAuthenticationDate: Date? {
        return UserDefaults.standard.object(forKey: "last_biometric_auth_date") as? Date
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case faceID
    case touchID
    case opticID
    case none
}

// MARK: - Biometric Error

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    case userCancel
    case userFallback
    case biometryNotEnrolled
    case biometryLockout
    case passcodeNotSet
    case systemCancel
    case appCancel
    case invalidContext
    case notInteractive

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .userCancel:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to enter password"
        case .biometryNotEnrolled:
            return "Biometric authentication is not set up on this device. Please enable it in Settings"
        case .biometryLockout:
            return "Biometric authentication is locked due to too many failed attempts. Please try again later"
        case .passcodeNotSet:
            return "Device passcode is not set. Please enable it in Settings"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .appCancel:
            return "Authentication was cancelled by the app"
        case .invalidContext:
            return "Authentication context is invalid"
        case .notInteractive:
            return "Authentication failed because user interaction is not allowed"
        }
    }

    static func from(laError: LAError) -> BiometricError {
        switch laError.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .passcodeNotSet:
            return .passcodeNotSet
        case .systemCancel:
            return .systemCancel
        case .appCancel:
            return .appCancel
        case .invalidContext:
            return .invalidContext
        case .notInteractive:
            return .notInteractive
        default:
            return .authenticationFailed
        }
    }
}

// MARK: - Usage Example

/*
 // In Settings View:

 @StateObject private var biometricAuth = BiometricAuthManager.shared

 Toggle(isOn: $biometricAuth.isEnabled) {
     HStack {
         Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
         Text("Enable \(biometricAuth.biometricTypeString)")
     }
 }
 .onChange(of: biometricAuth.isEnabled) { newValue in
     Task {
         if newValue {
             do {
                 _ = try await biometricAuth.enableBiometricAuth()
             } catch {
                 // Handle error
             }
         } else {
             biometricAuth.disableBiometricAuth()
         }
     }
 }

 // In App Launch (CelestiaApp.swift or RootView):

 .onAppear {
     if BiometricAuthManager.shared.shouldAuthenticateOnLaunch() {
         Task {
             do {
                 let success = try await BiometricAuthManager.shared.authenticate()
                 if !success {
                     // Lock app or show auth screen
                 }
             } catch {
                 // Handle error or show fallback
             }
         }
     }
 }

 // In Profile Edit or Sensitive Actions:

 Button("Delete Account") {
     Task {
         do {
             let authenticated = try await BiometricAuthManager.shared.authenticateWithPasscode(
                 reason: "Authenticate to delete your account"
             )

             if authenticated {
                 await deleteAccount()
             }
         } catch {
             showError(error.localizedDescription)
         }
     }
 }
 */
