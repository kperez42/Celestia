//
//  Constants.swift
//  Celestia
//
//  Centralized constants for the app
//

import Foundation
import SwiftUI

enum AppConstants {
    // MARK: - API Configuration
    enum API {
        static let baseURL = "https://api.celestia.app"
        static let timeout: TimeInterval = 30
        static let retryAttempts = 3
    }
    
    // MARK: - Content Limits
    enum Limits {
        static let maxBioLength = 500
        static let maxMessageLength = 1000
        static let maxInterestMessage = 300
        static let maxInterests = 10
        static let maxLanguages = 5
        static let maxPhotos = 6
        static let minAge = 18
        static let maxAge = 99
        static let minPasswordLength = 8
        static let maxNameLength = 50
    }
    
    // MARK: - Pagination
    enum Pagination {
        static let usersPerPage = 20
        static let messagesPerPage = 50
        static let matchesPerPage = 30
        static let interestsPerPage = 20
    }
    
    // MARK: - Premium Pricing
    enum Premium {
        static let monthlyPrice = 9.99
        static let threeMonthPrice = 24.99
        static let yearlyPrice = 79.99
        static let lifetimePrice = 199.99
        
        // Features
        static let freeSwipesPerDay = 50
        static let premiumUnlimitedSwipes = true
        static let premiumSeeWhoLiked = true
        static let premiumBoostProfile = true
    }
    
    // MARK: - Colors
    enum Colors {
        static let primary = Color.purple
        static let secondary = Color.blue
        static let accent = Color.pink
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        static let gradientStart = Color.purple
        static let gradientEnd = Color.blue
        
        static func primaryGradient() -> LinearGradient {
            LinearGradient(
                colors: [gradientStart, gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static func accentGradient() -> LinearGradient {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Animation Durations
    enum Animation {
        static let quick: TimeInterval = 0.2
        static let standard: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
        static let splash: TimeInterval = 2.0
    }
    
    // MARK: - Layout
    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let smallCornerRadius: CGFloat = 10
        static let largeCornerRadius: CGFloat = 20
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
    }
    
    // MARK: - Image Sizes
    enum ImageSize {
        static let thumbnail: CGFloat = 50
        static let small: CGFloat = 70
        static let medium: CGFloat = 100
        static let large: CGFloat = 150
        static let profile: CGFloat = 130
        static let hero: CGFloat = 400
    }
    
    // MARK: - Feature Flags
    enum Features {
        static let voiceMessagesEnabled = false
        static let videoCallsEnabled = false
        static let storiesEnabled = false
        static let groupChatsEnabled = false
        static let gifSupportEnabled = true
        static let locationTrackingEnabled = true
    }
    
    // MARK: - Firebase Collections
    enum Collections {
        static let users = "users"
        static let matches = "matches"
        static let messages = "messages"
        static let interests = "interests"
        static let reports = "reports"
        static let blockedUsers = "blocked_users"
        static let analytics = "analytics"
    }
    
    // MARK: - Storage Paths
    enum StoragePaths {
        static let profileImages = "profile_images"
        static let chatImages = "chat_images"
        static let userPhotos = "user_photos"
        static let voiceMessages = "voice_messages"
        static let videoMessages = "video_messages"
    }
    
    // MARK: - Rate Limiting
    enum RateLimit {
        static let messageInterval: TimeInterval = 0.5
        static let likeInterval: TimeInterval = 1.0
        static let searchInterval: TimeInterval = 0.3
        static let maxMessagesPerMinute = 30
        static let maxLikesPerDay = 10 // For free users - premium gets unlimited
        static let maxDailyMessagesForFreeUsers = 10 // Total daily messages across ALL conversations
    }
    
    // MARK: - Cache
    enum Cache {
        static let maxImageCacheSize = 100
        static let imageCacheDuration: TimeInterval = 3600 // 1 hour
        static let userDataCacheDuration: TimeInterval = 300 // 5 minutes
    }
    
    // MARK: - Notifications
    enum Notifications {
        static let newMatchTitle = "New Match! 💫"
        static let newMessageTitle = "New Message"
        static let newInterestTitle = "Someone likes you! 💖"
    }
    
    // MARK: - Analytics Events
    enum AnalyticsEvents {
        static let appLaunched = "app_launched"
        static let userSignedUp = "user_signed_up"
        static let userSignedIn = "user_signed_in"
        static let profileViewed = "profile_viewed"
        static let matchCreated = "match_created"
        static let messageSent = "message_sent"
        static let interestSent = "interest_sent"
        static let swipeRight = "swipe_right"
        static let swipeLeft = "swipe_left"
        static let profileEdited = "profile_edited"
        static let premiumViewed = "premium_viewed"
        static let premiumPurchased = "premium_purchased"
    }
    
    // MARK: - Error Messages
    enum ErrorMessages {
        static let networkError = "Please check your internet connection and try again."
        static let genericError = "Something went wrong. Please try again."
        static let authError = "Authentication failed. Please try again."
        static let invalidEmail = "Please enter a valid email address."
        static let weakPassword = "Password must be at least 8 characters with numbers and letters."
        static let passwordMismatch = "Passwords do not match."
        static let accountNotFound = "No account found with this email."
        static let emailInUse = "This email is already registered."
        static let invalidAge = "You must be at least 18 years old."
        static let bioTooLong = "Bio must be less than 500 characters."
        static let messageTooLong = "Message must be less than 1000 characters."
    }
    
    // MARK: - URLs
    enum URLs {
        static let privacyPolicy = "https://celestia.app/privacy"
        static let termsOfService = "https://celestia.app/terms"
        static let support = "mailto:support@celestia.app"
        static let website = "https://celestia.app"
        static let instagramURL = "https://instagram.com/celestia"
        static let twitterURL = "https://twitter.com/celestia"
    }
    
    // MARK: - Debug
    enum Debug {
        #if DEBUG
        static let loggingEnabled = true
        static let showDebugInfo = true
        #else
        static let loggingEnabled = false
        static let showDebugInfo = false
        #endif
    }
}

// MARK: - Convenience Extensions

extension AppConstants {
    static func log(_ message: String, category: String = "General") {
        if Debug.loggingEnabled {
            print("[\(category)] \(message)")
        }
    }
    
    static func logError(_ error: Error, context: String = "") {
        if Debug.loggingEnabled {
            print("❌ [\(context)] Error: \(error.localizedDescription)")
        }
    }
}
