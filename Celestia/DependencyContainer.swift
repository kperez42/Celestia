//
//  DependencyContainer.swift
//  Celestia
//
//  Centralized Dependency Injection Container
//  Provides a single source of truth for all service dependencies
//  Enables unit testing by allowing mock service injection
//

import Foundation
import SwiftUI

/// Centralized container for all app dependencies
/// Use this to resolve services throughout the app instead of accessing singletons directly
@MainActor
class DependencyContainer: ObservableObject {

    // MARK: - Singleton for App-Wide Access

    static let shared = DependencyContainer()

    // MARK: - Core Services

    /// Authentication service for user login/signup/session management
    let authService: any AuthServiceProtocol

    /// User service for user data operations
    let userService: any UserServiceProtocol

    /// Match service for match operations
    let matchService: any MatchServiceProtocol

    /// Message service for messaging operations
    let messageService: any MessageServiceProtocol

    /// Swipe service for like/pass/super like operations
    let swipeService: any SwipeServiceProtocol

    // MARK: - Supporting Services

    /// Interest service for sending/managing interests
    let interestService: InterestService

    /// Notification service for push notifications
    let notificationService: NotificationService

    /// Image upload service
    let imageUploadService: ImageUploadService

    /// Verification service
    let verificationService: VerificationService

    /// Reporting service
    let reportingManager: ReportingManager

    /// Referral manager
    let referralManager: ReferralManager

    // MARK: - Managers

    /// Network manager for API calls
    let networkManager: NetworkManager

    /// Logger for application-wide logging
    let logger: Logger

    /// Crashlytics manager for crash reporting
    let crashlyticsManager: CrashlyticsManager

    /// Analytics manager
    let analyticsManager: AnalyticsManager

    /// Performance monitor
    let performanceMonitor: PerformanceMonitor

    // MARK: - Initialization

    /// Default initializer - uses production services
    nonisolated private init() {
        // Core Services (using protocols for testability)
        self.authService = AuthService.shared
        self.userService = UserService.shared
        self.matchService = MatchService.shared
        self.messageService = MessageService.shared
        self.swipeService = SwipeService.shared

        // Supporting Services
        self.interestService = InterestService.shared
        self.notificationService = NotificationService.shared
        self.imageUploadService = ImageUploadService.shared
        self.verificationService = VerificationService.shared
        self.reportingManager = ReportingManager.shared
        self.referralManager = ReferralManager.shared

        // Managers
        self.networkManager = NetworkManager.shared
        self.logger = Logger.shared
        self.crashlyticsManager = CrashlyticsManager.shared
        self.analyticsManager = AnalyticsManager.shared
        self.performanceMonitor = PerformanceMonitor.shared
    }

    /// Test initializer - allows mock service injection
    /// - Parameters:
    ///   - authService: Mock auth service for testing
    ///   - userService: Mock user service for testing
    ///   - matchService: Mock match service for testing
    ///   - messageService: Mock message service for testing
    ///   - swipeService: Mock swipe service for testing
    nonisolated init(
        authService: (any AuthServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        matchService: (any MatchServiceProtocol)? = nil,
        messageService: (any MessageServiceProtocol)? = nil,
        swipeService: (any SwipeServiceProtocol)? = nil,
        interestService: InterestService? = nil,
        notificationService: NotificationService? = nil,
        imageUploadService: ImageUploadService? = nil,
        verificationService: VerificationService? = nil,
        reportingManager: ReportingManager? = nil,
        referralManager: ReferralManager? = nil,
        networkManager: NetworkManager? = nil,
        logger: Logger? = nil,
        crashlyticsManager: CrashlyticsManager? = nil,
        analyticsManager: AnalyticsManager? = nil,
        performanceMonitor: PerformanceMonitor? = nil
    ) {
        // Core Services
        self.authService = authService ?? AuthService.shared
        self.userService = userService ?? UserService.shared
        self.matchService = matchService ?? MatchService.shared
        self.messageService = messageService ?? MessageService.shared
        self.swipeService = swipeService ?? SwipeService.shared

        // Supporting Services
        self.interestService = interestService ?? InterestService.shared
        self.notificationService = notificationService ?? NotificationService.shared
        self.imageUploadService = imageUploadService ?? ImageUploadService.shared
        self.verificationService = verificationService ?? VerificationService.shared
        self.reportingManager = reportingManager ?? ReportingManager.shared
        self.referralManager = referralManager ?? ReferralManager.shared

        // Managers
        self.networkManager = networkManager ?? NetworkManager.shared
        self.logger = logger ?? Logger.shared
        self.crashlyticsManager = crashlyticsManager ?? CrashlyticsManager.shared
        self.analyticsManager = analyticsManager ?? AnalyticsManager.shared
        self.performanceMonitor = performanceMonitor ?? PerformanceMonitor.shared
    }

    // MARK: - Factory Methods for ViewModels

    /// Creates a ChatViewModel with injected dependencies
    func makeChatViewModel(currentUserId: String = "", otherUserId: String = "") -> ChatViewModel {
        return ChatViewModel(
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            matchService: matchService,
            messageService: messageService
        )
    }

    /// Creates a DiscoverViewModel with injected dependencies
    func makeDiscoverViewModel() -> DiscoverViewModel {
        return DiscoverViewModel(
            userService: userService,
            swipeService: swipeService,
            authService: authService
        )
    }

    /// Creates a ProfileEditViewModel with injected dependencies
    func makeProfileEditViewModel() -> ProfileEditViewModel {
        return ProfileEditViewModel(
            userService: userService
        )
    }
}

// MARK: - SwiftUI Environment Key

/// Environment key for dependency injection in SwiftUI
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Inject dependency container into environment
    @MainActor func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencies, container)
    }
}

// MARK: - Usage Examples

/*

 USAGE IN SWIFTUI VIEWS:

 // Option 1: Access via environment
 struct MyView: View {
     @Environment(\.dependencies) var deps

     var body: some View {
         // Use deps.authService, deps.userService, etc.
     }
 }

 // Option 2: Create ViewModels with factory methods
 struct DiscoverView: View {
     @Environment(\.dependencies) var deps
     @StateObject private var viewModel: DiscoverViewModel

     init() {
         _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeDiscoverViewModel())
     }

     var body: some View {
         // Use viewModel
     }
 }

 USAGE IN TESTS:

 func testExample() {
     // Create mock services
     let mockAuth = MockAuthService()
     let mockUser = MockUserService()

     // Create test container with mocks
     let testContainer = DependencyContainer(
         authService: mockAuth,
         userService: mockUser
     )

     // Create ViewModel with mocked dependencies
     let viewModel = testContainer.makeDiscoverViewModel()

     // Test viewModel behavior
     // Assertions will verify mock interactions
 }

 MIGRATION GUIDE:

 Before:
 let authService = AuthService.shared
 let user = authService.currentUser

 After (in View):
 @Environment(\.dependencies) var deps
 let user = deps.authService.currentUser

 Before (ViewModel):
 class MyViewModel {
     func doSomething() {
         AuthService.shared.signOut()
     }
 }

 After (ViewModel):
 class MyViewModel {
     private let authService: any AuthServiceProtocol

     init(authService: (any AuthServiceProtocol)? = nil) {
         self.authService = authService ?? AuthService.shared
     }

     func doSomething() {
         authService.signOut()
     }
 }

 */
