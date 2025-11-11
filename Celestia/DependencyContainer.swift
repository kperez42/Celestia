//
//  DependencyContainer.swift
//  Celestia
//
//  Dependency Injection Container
//  Provides centralized service management and dependency resolution
//

import Foundation
import SwiftUI

// MARK: - Dependency Container

/// Main dependency injection container for the app
class DependencyContainer {

    // MARK: - Singleton

    static let shared = DependencyContainer()

    // MARK: - Services

    private(set) var authService: any AuthServiceProtocol
    private(set) var userService: any UserServiceProtocol
    private(set) var matchService: any MatchServiceProtocol
    private(set) var messageService: any MessageServiceProtocol
    private(set) var swipeService: any SwipeServiceProtocol
    private(set) var referralManager: any ReferralManagerProtocol
    private(set) var storeManager: any StoreManagerProtocol
    private(set) var notificationService: any NotificationServiceProtocol
    private(set) var imageUploadService: any ImageUploadServiceProtocol
    private(set) var contentModerator: any ContentModeratorProtocol
    private(set) var analyticsManager: any AnalyticsManagerProtocol
    private(set) var blockReportService: any BlockReportServiceProtocol
    private(set) var networkManager: any NetworkManagerProtocol

    // MARK: - Initialization

    private init() {
        // Initialize services in dependency order

        // Core infrastructure
        self.networkManager = NetworkManager()
        self.contentModerator = ContentModerator.shared
        self.analyticsManager = AnalyticsManager.shared

        // Authentication & User Management
        self.authService = AuthService.shared
        self.userService = UserService.shared

        // Core Features
        self.matchService = MatchService.shared
        self.messageService = MessageService.shared
        self.swipeService = SwipeService.shared

        // Supporting Services
        self.referralManager = ReferralManager.shared
        self.storeManager = StoreManager.shared
        self.notificationService = NotificationService.shared
        self.imageUploadService = ImageUploadService.shared
        self.blockReportService = BlockReportService.shared

        Logger.shared.info("DependencyContainer initialized", category: .general)
    }

    // MARK: - Factory Methods

    /// Create a new instance with custom services (for testing)
    static func createForTesting(
        authService: (any AuthServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        matchService: (any MatchServiceProtocol)? = nil,
        messageService: (any MessageServiceProtocol)? = nil,
        swipeService: (any SwipeServiceProtocol)? = nil,
        networkManager: (any NetworkManagerProtocol)? = nil
    ) -> DependencyContainer {
        let container = DependencyContainer()

        if let authService = authService {
            container.replaceAuthService(authService)
        }
        if let userService = userService {
            container.replaceUserService(userService)
        }
        if let matchService = matchService {
            container.replaceMatchService(matchService)
        }
        if let messageService = messageService {
            container.replaceMessageService(messageService)
        }
        if let swipeService = swipeService {
            container.replaceSwipeService(swipeService)
        }
        if let networkManager = networkManager {
            container.replaceNetworkManager(networkManager)
        }

        return container
    }

    // MARK: - Service Replacement (for testing)

    func replaceAuthService(_ service: any AuthServiceProtocol) {
        self.authService = service
    }

    func replaceUserService(_ service: any UserServiceProtocol) {
        self.userService = service
    }

    func replaceMatchService(_ service: any MatchServiceProtocol) {
        self.matchService = service
    }

    func replaceMessageService(_ service: any MessageServiceProtocol) {
        self.messageService = service
    }

    func replaceSwipeService(_ service: any SwipeServiceProtocol) {
        self.swipeService = service
    }

    func replaceNetworkManager(_ manager: any NetworkManagerProtocol) {
        self.networkManager = manager
    }

    // MARK: - Reset

    /// Reset all services (useful for sign out)
    func resetServices() {
        Logger.shared.info("Resetting all services", category: .general)

        // Stop listeners
        if let matchService = matchService as? MatchService {
            matchService.stopListening()
        }

        // Clear caches
        ImageCache.shared.clearAll()

        Logger.shared.info("Services reset complete", category: .general)
    }
}

// MARK: - SwiftUI Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    func dependencies(_ container: DependencyContainer) -> some View {
        environment(\.dependencies, container)
    }
}

// MARK: - View Extension for Easy Access

extension View {
    var container: DependencyContainer {
        DependencyContainer.shared
    }
}

// MARK: - Property Wrapper for Dependency Injection

@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>

    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }

    var wrappedValue: T {
        DependencyContainer.shared[keyPath: keyPath]
    }
}

// MARK: - Convenience Property Wrappers

@propertyWrapper
struct InjectedAuthService {
    var wrappedValue: any AuthServiceProtocol {
        DependencyContainer.shared.authService
    }
}

@propertyWrapper
struct InjectedUserService {
    var wrappedValue: any UserServiceProtocol {
        DependencyContainer.shared.userService
    }
}

@propertyWrapper
struct InjectedMatchService {
    var wrappedValue: any MatchServiceProtocol {
        DependencyContainer.shared.matchService
    }
}

@propertyWrapper
struct InjectedMessageService {
    var wrappedValue: any MessageServiceProtocol {
        DependencyContainer.shared.messageService
    }
}

@propertyWrapper
struct InjectedSwipeService {
    var wrappedValue: any SwipeServiceProtocol {
        DependencyContainer.shared.swipeService
    }
}

@propertyWrapper
struct InjectedNetworkManager {
    var wrappedValue: any NetworkManagerProtocol {
        DependencyContainer.shared.networkManager
    }
}

// MARK: - Usage Examples

/*

 // In a ViewModel
 class ProfileViewModel: ObservableObject {
     @InjectedUserService private var userService
     @InjectedAuthService private var authService

     func loadProfile() async {
         let user = try await userService.fetchUser(userId: authService.currentUserId)
     }
 }

 // In a View
 struct ProfileView: View {
     @Environment(\.dependencies) var dependencies

     var body: some View {
         Text("Profile")
             .onAppear {
                 Task {
                     await dependencies.userService.loadProfile()
                 }
             }
     }
 }

 // For testing
 func testProfileLoad() {
     let mockAuth = MockAuthService()
     let mockUser = MockUserService()
     let container = DependencyContainer.createForTesting(
         authService: mockAuth,
         userService: mockUser
     )

     let viewModel = ProfileViewModel(dependencies: container)
     // Test with mocks
 }

 */
