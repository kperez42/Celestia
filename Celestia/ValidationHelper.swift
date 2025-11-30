//
//  ValidationHelper.swift
//  Celestia
//
//  Centralized input validation utility
//  Eliminates code duplication and ensures consistent validation across the app
//
//  CODE QUALITY IMPROVEMENT:
//  This utility eliminates 15+ instances of duplicated validation code across:
//  - AuthService (email, password validation)
//  - SignUpView (email validation)
//  - Extensions (email validation)
//  - ClipboardSecurityManager (email validation)
//  - ProfileEditViewModel (bio validation)
//  - Multiple other views
//
//  BENEFITS:
//  - Single source of truth for validation rules
//  - Consistent error messages
//  - Easy to update validation logic
//  - Comprehensive test coverage in one place
//  - Better developer experience
//

import Foundation

/// Centralized validation utility for user input
/// Provides consistent validation rules and error messages across the app
enum ValidationHelper {

    // MARK: - Validation Results

    /// Result of a validation check with detailed error message
    enum ValidationResult {
        case valid
        case invalid(String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }

    // MARK: - Email Validation

    /// Validate email format
    /// Uses the same regex pattern currently used in AuthService, SignUpView, Extensions, etc.
    static func validateEmail(_ email: String) -> ValidationResult {
        let sanitizedEmail = InputSanitizer.email(email)

        guard !sanitizedEmail.isEmpty else {
            return .invalid("Email address is required.")
        }

        // Standard email regex (used across the app)
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: sanitizedEmail) else {
            return .invalid("Please enter a valid email address.")
        }

        return .valid
    }

    /// Check if email format is valid (convenience method)
    static func isValidEmail(_ email: String) -> Bool {
        return validateEmail(email).isValid
    }

    // MARK: - Password Validation

    /// Validate password strength
    /// Requirements:
    /// - At least 8 characters (AppConstants.Limits.minPasswordLength)
    /// - Contains at least one letter
    /// - Contains at least one number
    static func validatePassword(_ password: String) -> ValidationResult {
        guard !password.isEmpty else {
            return .invalid("Password is required.")
        }

        let minLength = AppConstants.Limits.minPasswordLength
        guard password.count >= minLength else {
            return .invalid("Password must be at least \(minLength) characters.")
        }

        // Check for at least one letter
        let letterRegex = ".*[A-Za-z]+.*"
        let letterPredicate = NSPredicate(format: "SELF MATCHES %@", letterRegex)
        guard letterPredicate.evaluate(with: password) else {
            return .invalid("Password must contain at least one letter.")
        }

        // Check for at least one number
        let numberRegex = ".*[0-9]+.*"
        let numberPredicate = NSPredicate(format: "SELF MATCHES %@", numberRegex)
        guard numberPredicate.evaluate(with: password) else {
            return .invalid("Password must contain at least one number.")
        }

        return .valid
    }

    /// Check if password meets strength requirements (convenience method)
    static func isValidPassword(_ password: String) -> Bool {
        return validatePassword(password).isValid
    }

    // MARK: - Bio Validation

    /// Validate bio text length and content
    /// Max length: 500 characters (AppConstants.Limits.maxBioLength)
    /// Also checks for inappropriate content (profanity, spam, contact info)
    static func validateBio(_ bio: String) -> ValidationResult {
        let sanitizedBio = InputSanitizer.standard(bio)

        // Bio is optional, empty is valid
        if sanitizedBio.isEmpty {
            return .valid
        }

        let maxLength = AppConstants.Limits.maxBioLength
        guard sanitizedBio.count <= maxLength else {
            return .invalid("Bio must be \(maxLength) characters or less. Currently: \(sanitizedBio.count)")
        }

        // CONTENT MODERATION: Check for inappropriate content
        if !ContentModerator.shared.isAppropriate(sanitizedBio) {
            let violations = ContentModerator.shared.getViolations(sanitizedBio)
            if !violations.isEmpty {
                return .invalid(violations.first ?? "Bio contains inappropriate content.")
            }
            return .invalid("Bio contains inappropriate content.")
        }

        return .valid
    }

    /// Check if bio is valid length (convenience method)
    static func isValidBio(_ bio: String) -> Bool {
        return validateBio(bio).isValid
    }

    // MARK: - Name Validation

    /// Validate full name
    /// Requirements:
    /// - Not empty
    /// - 2-50 characters
    /// - Only letters, spaces, hyphens, apostrophes
    /// - No inappropriate/sexual/profane content
    static func validateName(_ name: String) -> ValidationResult {
        let sanitizedName = InputSanitizer.strict(name)

        guard !sanitizedName.isEmpty else {
            return .invalid("Name is required.")
        }

        guard sanitizedName.count >= 2 else {
            return .invalid("Name must be at least 2 characters.")
        }

        guard sanitizedName.count <= 50 else {
            return .invalid("Name must be 50 characters or less.")
        }

        // Allow only letters, spaces, hyphens, apostrophes
        let nameRegex = "^[a-zA-Z\\s'-]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        guard namePredicate.evaluate(with: sanitizedName) else {
            return .invalid("Name can only contain letters, spaces, hyphens, and apostrophes.")
        }

        // CONTENT MODERATION: Check for inappropriate/sexual/profane names
        let nameValidation = ContentModerator.shared.validateName(sanitizedName)
        guard nameValidation.isValid else {
            return .invalid(nameValidation.reason ?? "Name contains inappropriate content.")
        }

        return .valid
    }

    /// Check if name is valid (convenience method)
    static func isValidName(_ name: String) -> Bool {
        return validateName(name).isValid
    }

    // MARK: - Age Validation

    /// Validate age (must be 18+)
    static func validateAge(_ age: Int) -> ValidationResult {
        guard age >= 18 else {
            return .invalid("You must be at least 18 years old to use Celestia.")
        }

        guard age <= 120 else {
            return .invalid("Please enter a valid age.")
        }

        return .valid
    }

    /// Check if age is valid (convenience method)
    static func isValidAge(_ age: Int) -> Bool {
        return validateAge(age).isValid
    }

    // MARK: - Username Validation

    /// Validate username
    /// Requirements:
    /// - 3-20 characters
    /// - Only letters, numbers, underscores
    /// - Cannot start with number
    static func validateUsername(_ username: String) -> ValidationResult {
        let sanitizedUsername = InputSanitizer.alphanumeric(username, allowSpaces: false)

        guard !sanitizedUsername.isEmpty else {
            return .invalid("Username is required.")
        }

        guard sanitizedUsername.count >= 3 else {
            return .invalid("Username must be at least 3 characters.")
        }

        guard sanitizedUsername.count <= 20 else {
            return .invalid("Username must be 20 characters or less.")
        }

        // Only alphanumeric and underscores, cannot start with number
        let usernameRegex = "^[a-zA-Z][a-zA-Z0-9_]*$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        guard usernamePredicate.evaluate(with: sanitizedUsername) else {
            return .invalid("Username can only contain letters, numbers, and underscores, and must start with a letter.")
        }

        return .valid
    }

    /// Check if username is valid (convenience method)
    static func isValidUsername(_ username: String) -> Bool {
        return validateUsername(username).isValid
    }

    // MARK: - URL Validation

    /// Validate URL format
    static func validateURL(_ urlString: String) -> ValidationResult {
        guard let sanitizedURL = InputSanitizer.url(urlString) else {
            return .invalid("Please enter a valid URL (must start with http:// or https://).")
        }

        // Additional validation: must be a valid URL object
        guard URL(string: sanitizedURL) != nil else {
            return .invalid("Please enter a valid URL.")
        }

        return .valid
    }

    /// Check if URL is valid (convenience method)
    static func isValidURL(_ urlString: String) -> Bool {
        return validateURL(urlString).isValid
    }

    // MARK: - Phone Number Validation

    /// Validate phone number format (basic validation)
    /// Accepts: +1234567890, (123) 456-7890, 123-456-7890, etc.
    static func validatePhoneNumber(_ phone: String) -> ValidationResult {
        let sanitizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedPhone.isEmpty else {
            return .invalid("Phone number is required.")
        }

        // Extract only digits
        let digits = sanitizedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Most countries: 10-15 digits
        guard digits.count >= 10 && digits.count <= 15 else {
            return .invalid("Please enter a valid phone number (10-15 digits).")
        }

        return .valid
    }

    /// Check if phone number is valid (convenience method)
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        return validatePhoneNumber(phone).isValid
    }

    // MARK: - Profile Fields Validation

    /// Validate all profile fields at once
    /// Returns first validation error encountered, or .valid if all pass
    static func validateProfile(
        name: String,
        age: Int,
        bio: String,
        email: String? = nil
    ) -> ValidationResult {
        // Validate name
        let nameResult = validateName(name)
        if !nameResult.isValid { return nameResult }

        // Validate age
        let ageResult = validateAge(age)
        if !ageResult.isValid { return ageResult }

        // Validate bio (optional but must be valid length if provided)
        let bioResult = validateBio(bio)
        if !bioResult.isValid { return bioResult }

        // Validate email if provided
        if let email = email {
            let emailResult = validateEmail(email)
            if !emailResult.isValid { return emailResult }
        }

        return .valid
    }

    // MARK: - Sign Up Validation

    /// Validate sign up form fields
    static func validateSignUp(
        email: String,
        password: String,
        name: String,
        age: Int
    ) -> ValidationResult {
        // Validate email
        let emailResult = validateEmail(email)
        if !emailResult.isValid { return emailResult }

        // Validate password
        let passwordResult = validatePassword(password)
        if !passwordResult.isValid { return passwordResult }

        // Validate name
        let nameResult = validateName(name)
        if !nameResult.isValid { return nameResult }

        // Validate age
        let ageResult = validateAge(age)
        if !ageResult.isValid { return ageResult }

        return .valid
    }

    // MARK: - Helper Methods

    /// Check if string is empty or whitespace only
    static func isEmpty(_ text: String) -> Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Get sanitized and validated text
    /// Returns nil if validation fails
    static func getSanitizedText(_ text: String, validator: (String) -> ValidationResult) -> String? {
        let sanitized = InputSanitizer.standard(text)
        let result = validator(sanitized)
        return result.isValid ? sanitized : nil
    }
}

// MARK: - String Extension

extension String {
    /// Convenience property to check if email is valid
    var isValidEmail: Bool {
        return ValidationHelper.isValidEmail(self)
    }

    /// Convenience property to validate email and get result
    var emailValidation: ValidationHelper.ValidationResult {
        return ValidationHelper.validateEmail(self)
    }

    /// Convenience property to check if password is valid
    var isValidPassword: Bool {
        return ValidationHelper.isValidPassword(self)
    }

    /// Convenience property to validate password and get result
    var passwordValidation: ValidationHelper.ValidationResult {
        return ValidationHelper.validatePassword(self)
    }
}
