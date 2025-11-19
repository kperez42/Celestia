//
//  PhoneVerificationService.swift
//  Celestia
//
//  Phone number verification using Firebase Auth
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class PhoneVerificationService: ObservableObject {
    static let shared = PhoneVerificationService()

    @Published var verificationState: VerificationState = .initial
    @Published var phoneNumber: String = ""
    @Published var verificationCode: String = ""
    @Published var errorMessage: String?

    private var verificationID: String?
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Verification States

    enum VerificationState: Equatable {
        case initial
        case sendingCode
        case codeSent
        case verifying
        case verified
        case failed(Error)

        static func == (lhs: VerificationState, rhs: VerificationState) -> Bool {
            switch (lhs, rhs) {
            case (.initial, .initial),
                 (.sendingCode, .sendingCode),
                 (.codeSent, .codeSent),
                 (.verifying, .verifying),
                 (.verified, .verified):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    // MARK: - Send Verification Code

    /// Send SMS verification code to phone number
    func sendVerificationCode(phoneNumber: String) async throws {
        verificationState = .sendingCode

        // Validate phone number format
        guard isValidPhoneNumber(phoneNumber) else {
            let error = PhoneVerificationError.invalidPhoneNumber
            verificationState = .failed(error)
            errorMessage = error.localizedDescription
            throw error
        }

        self.phoneNumber = phoneNumber

        do {
            // Send verification code via Firebase Auth
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
                phoneNumber,
                uiDelegate: nil
            )

            self.verificationID = verificationID
            verificationState = .codeSent

            Logger.shared.info("Verification code sent to \(phoneNumber)", category: .authentication)

            // Log analytics event
            let countryCode = extractCountryCode(phoneNumber)
            Analytics.logEvent("phone_verification_code_sent", parameters: [
                "phone_number_country": countryCode
            ])

        } catch {
            Logger.shared.error("Failed to send verification code", category: .authentication, error: error)
            verificationState = .failed(error)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Verify Code

    /// Verify the SMS code entered by user
    func verifyCode(_ code: String) async throws {
        guard let verificationID = verificationID else {
            throw PhoneVerificationError.noVerificationID
        }

        verificationState = .verifying
        verificationCode = code

        do {
            // Create phone credential
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code
            )

            // Link phone credential to current user
            guard let currentUser = Auth.auth().currentUser else {
                throw PhoneVerificationError.notAuthenticated
            }

            let authResult = try await currentUser.link(with: credential)

            // Update Firestore with verification status
            try await updateUserVerificationStatus(userId: authResult.user.uid, phoneNumber: phoneNumber)

            verificationState = .verified

            Logger.shared.info("Phone number verified successfully", category: .authentication)

            // Log analytics event
            Analytics.logEvent("phone_verification_completed", parameters: [
                "success": true
            ])

        } catch let error as NSError {
            Logger.shared.error("Phone verification failed", category: .authentication, error: error)

            // Handle specific error cases
            if error.code == AuthErrorCode.invalidVerificationCode.rawValue {
                errorMessage = "Invalid verification code. Please try again."
            } else if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                errorMessage = "This phone number is already in use by another account."
            } else {
                errorMessage = error.localizedDescription
            }

            verificationState = .failed(error)

            // Log analytics event
            let errorCode = error.code
            let errorDomain = error.domain
            Analytics.logEvent("phone_verification_failed", parameters: [
                "error_code": errorCode,
                "error_domain": errorDomain
            ])

            throw error
        }
    }

    // MARK: - Resend Code

    /// Resend verification code
    func resendCode() async throws {
        verificationCode = ""
        try await sendVerificationCode(phoneNumber: phoneNumber)
    }

    // MARK: - Update Firestore

    private func updateUserVerificationStatus(userId: String, phoneNumber: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "phoneNumber": phoneNumber,
            "phoneVerified": true,
            "phoneVerifiedAt": FieldValue.serverTimestamp(),
            "verificationMethods": FieldValue.arrayUnion(["phone"])
        ])

        Logger.shared.info("Updated user verification status in Firestore", category: .authentication)
    }

    // MARK: - Validation

    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Must start with +, followed by country code and number
        // Example: +12025551234
        let pattern = "^\\+[1-9]\\d{1,14}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: phoneNumber.utf16.count)
        return regex?.firstMatch(in: phoneNumber, options: [], range: range) != nil
    }

    private func extractCountryCode(_ phoneNumber: String) -> String {
        // Extract first 1-3 digits after +
        let digits = phoneNumber.dropFirst() // Remove +
        if digits.count >= 1 {
            return String(digits.prefix(3))
        }
        return "unknown"
    }

    // MARK: - Check Verification Status

    /// Check if current user has verified phone
    func isPhoneVerified() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }

        let doc = try await db.collection("users").document(userId).getDocument()
        return doc.data()?["phoneVerified"] as? Bool ?? false
    }

    // MARK: - Reset

    func reset() {
        verificationState = .initial
        phoneNumber = ""
        verificationCode = ""
        verificationID = nil
        errorMessage = nil
    }
}

// MARK: - Errors

enum PhoneVerificationError: LocalizedError {
    case invalidPhoneNumber
    case noVerificationID
    case notAuthenticated
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please enter a valid phone number in international format (e.g., +1234567890)"
        case .noVerificationID:
            return "No verification in progress. Please request a new code."
        case .notAuthenticated:
            return "You must be logged in to verify your phone number."
        case .verificationFailed:
            return "Phone verification failed. Please try again."
        }
    }
}
