//
//  KeychainManager.swift
//  Celestia
//
//  Secure storage for sensitive data using iOS Keychain
//  Provides encrypted storage for tokens, passwords, and other sensitive information
//

import Foundation
import Security

/// Manages secure storage of sensitive data in iOS Keychain
class KeychainManager {

    // MARK: - Singleton

    static let shared = KeychainManager()

    // MARK: - Properties

    private let serviceName = "com.celestia.app"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Save a string value to Keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    /// - Returns: True if save was successful
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.shared.error("Failed to encode string to data for key: \(key)", category: .security)
            return false
        }

        return save(data, forKey: key)
    }

    /// Save data to Keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to associate with the data
    /// - Returns: True if save was successful
    @discardableResult
    func save(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.shared.debug("Successfully saved item to Keychain for key: \(key)", category: .security)
            return true
        } else {
            Logger.shared.error("Failed to save item to Keychain for key: \(key), status: \(status)", category: .security)
            return false
        }
    }

    /// Retrieve a string value from Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The string value if found, nil otherwise
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Retrieve data from Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The data if found, nil otherwise
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            Logger.shared.debug("Successfully retrieved item from Keychain for key: \(key)", category: .security)
            return result as? Data
        } else if status == errSecItemNotFound {
            Logger.shared.debug("Item not found in Keychain for key: \(key)", category: .security)
            return nil
        } else {
            Logger.shared.error("Failed to retrieve item from Keychain for key: \(key), status: \(status)", category: .security)
            return nil
        }
    }

    /// Delete a value from Keychain
    /// - Parameter key: The key associated with the value to delete
    /// - Returns: True if deletion was successful or item didn't exist
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            Logger.shared.debug("Successfully deleted item from Keychain for key: \(key)", category: .security)
            return true
        } else {
            Logger.shared.error("Failed to delete item from Keychain for key: \(key), status: \(status)", category: .security)
            return false
        }
    }

    /// Delete all values from Keychain for this app
    /// - Returns: True if deletion was successful
    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            Logger.shared.info("Successfully deleted all items from Keychain", category: .security)
            return true
        } else {
            Logger.shared.error("Failed to delete all items from Keychain, status: \(status)", category: .security)
            return false
        }
    }

    // MARK: - Convenience Methods for Common Use Cases

    /// Save password reset token securely
    func savePasswordResetToken(_ token: String) -> Bool {
        return save(token, forKey: "passwordResetToken")
    }

    /// Retrieve password reset token
    func getPasswordResetToken() -> String? {
        return getString(forKey: "passwordResetToken")
    }

    /// Delete password reset token
    func deletePasswordResetToken() -> Bool {
        return delete(forKey: "passwordResetToken")
    }

    /// Save email verification token securely
    func saveEmailVerificationToken(_ token: String) -> Bool {
        return save(token, forKey: "emailVerificationToken")
    }

    /// Retrieve email verification token
    func getEmailVerificationToken() -> String? {
        return getString(forKey: "emailVerificationToken")
    }

    /// Delete email verification token
    func deleteEmailVerificationToken() -> Bool {
        return delete(forKey: "emailVerificationToken")
    }

    /// Save authentication token securely
    func saveAuthToken(_ token: String) -> Bool {
        return save(token, forKey: "authToken")
    }

    /// Retrieve authentication token
    func getAuthToken() -> String? {
        return getString(forKey: "authToken")
    }

    /// Delete authentication token
    func deleteAuthToken() -> Bool {
        return delete(forKey: "authToken")
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case saveFailed
    case retrievalFailed
    case deletionFailed
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save item to Keychain"
        case .retrievalFailed:
            return "Failed to retrieve item from Keychain"
        case .deletionFailed:
            return "Failed to delete item from Keychain"
        case .encodingFailed:
            return "Failed to encode data for Keychain storage"
        case .decodingFailed:
            return "Failed to decode data from Keychain"
        }
    }
}
