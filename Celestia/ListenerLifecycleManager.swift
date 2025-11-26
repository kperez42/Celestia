//
//  ListenerLifecycleManager.swift
//  Celestia
//
//  Manages Firestore listener lifecycle across app state changes
//  Handles reconnection on foreground/network recovery
//

import Foundation
import UIKit
import Combine

// MARK: - Listener Lifecycle Protocol

/// Protocol for services that have Firestore listeners and need lifecycle management
protocol ListenerLifecycleAware: AnyObject {
    /// Unique identifier for this listener owner
    var listenerId: String { get }

    /// Called when app enters foreground or network is restored - should restart listeners
    func reconnectListeners()

    /// Called when app enters background or network is lost - should pause/cleanup listeners
    func pauseListeners()

    /// Whether listeners are currently active
    var areListenersActive: Bool { get }
}

// MARK: - Listener Lifecycle Manager

/// Centralized manager for coordinating Firestore listener lifecycle across the app
/// Handles:
/// - App background/foreground transitions
/// - Network connectivity changes
/// - Automatic reconnection with debouncing
@MainActor
class ListenerLifecycleManager: ObservableObject {
    static let shared = ListenerLifecycleManager()

    // MARK: - Published State

    @Published private(set) var isAppActive = true
    @Published private(set) var isNetworkAvailable = true
    @Published private(set) var lastReconnectTime: Date?

    // MARK: - Private Properties

    private var registeredListeners: [String: WeakListenerRef] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var reconnectDebounceTask: Task<Void, Never>?

    // Debounce interval to prevent rapid reconnection attempts
    private let reconnectDebounceInterval: TimeInterval = 1.0

    // Track if we need to reconnect after debounce
    private var pendingReconnect = false

    // MARK: - Initialization

    private init() {
        setupObservers()
        Logger.shared.info("ListenerLifecycleManager initialized", category: .general)
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)

        // Observe network connectivity changes
        NotificationCenter.default.publisher(for: .networkConnectionRestored)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleNetworkRestored(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .networkConnectionLost)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleNetworkLost()
            }
            .store(in: &cancellables)

        // Observe network monitor directly for initial state
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isNetworkAvailable = isConnected
            }
            .store(in: &cancellables)
    }

    // MARK: - Registration

    /// Register a listener-aware service for lifecycle management
    func register(_ listener: ListenerLifecycleAware) {
        cleanupStaleReferences()
        registeredListeners[listener.listenerId] = WeakListenerRef(listener)
        Logger.shared.debug("Registered listener: \(listener.listenerId)", category: .general)
    }

    /// Unregister a listener-aware service
    func unregister(_ listener: ListenerLifecycleAware) {
        registeredListeners.removeValue(forKey: listener.listenerId)
        Logger.shared.debug("Unregistered listener: \(listener.listenerId)", category: .general)
    }

    /// Unregister by ID (for when object is being deallocated)
    func unregister(id: String) {
        registeredListeners.removeValue(forKey: id)
    }

    // MARK: - App Lifecycle Handlers

    private func handleAppWillEnterForeground() {
        Logger.shared.info("App entering foreground - preparing to reconnect listeners", category: .general)
        isAppActive = true

        // Debounced reconnection to avoid rapid reconnects
        scheduleReconnect(reason: "foreground")
    }

    private func handleAppDidEnterBackground() {
        Logger.shared.info("App entering background - pausing listeners", category: .general)
        isAppActive = false

        // Cancel any pending reconnect
        reconnectDebounceTask?.cancel()
        reconnectDebounceTask = nil

        // Pause all listeners to save resources
        pauseAllListeners()
    }

    private func handleAppDidBecomeActive() {
        // Only reconnect if we were paused and are now active
        if !isAppActive {
            isAppActive = true
            scheduleReconnect(reason: "became active")
        }
    }

    // MARK: - Network Handlers

    private func handleNetworkRestored(_ notification: Notification) {
        Logger.shared.info("Network restored - scheduling listener reconnection", category: .networking)
        isNetworkAvailable = true

        // Only reconnect if app is active
        guard isAppActive else {
            Logger.shared.debug("App in background - deferring reconnection", category: .networking)
            return
        }

        let offlineDuration = notification.userInfo?["offlineDuration"] as? TimeInterval ?? 0

        // If we were offline for more than 30 seconds, do a full reconnect
        if offlineDuration > 30 {
            scheduleReconnect(reason: "network restored after \(Int(offlineDuration))s offline")
        } else {
            // For brief disconnections, Firestore should auto-reconnect
            Logger.shared.debug("Brief network interruption - relying on Firestore auto-reconnect", category: .networking)
        }
    }

    private func handleNetworkLost() {
        Logger.shared.warning("Network lost - listeners may become stale", category: .networking)
        isNetworkAvailable = false

        // Don't pause listeners immediately - Firestore handles offline mode
        // But mark that we'll need to verify/reconnect when network returns
    }

    // MARK: - Reconnection Logic

    /// Schedule a debounced reconnection
    private func scheduleReconnect(reason: String) {
        pendingReconnect = true

        // Cancel existing debounce task
        reconnectDebounceTask?.cancel()

        reconnectDebounceTask = Task { [weak self] in
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (self?.reconnectDebounceInterval ?? 1.0)))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self, self.pendingReconnect else { return }
                self.pendingReconnect = false
                self.reconnectAllListeners(reason: reason)
            }
        }
    }

    /// Reconnect all registered listeners
    private func reconnectAllListeners(reason: String) {
        cleanupStaleReferences()

        let activeListeners = registeredListeners.values.compactMap { $0.listener }

        guard !activeListeners.isEmpty else {
            Logger.shared.debug("No registered listeners to reconnect", category: .general)
            return
        }

        Logger.shared.info("Reconnecting \(activeListeners.count) listeners (reason: \(reason))", category: .general)

        lastReconnectTime = Date()

        for listener in activeListeners {
            Logger.shared.debug("Reconnecting listener: \(listener.listenerId)", category: .general)
            listener.reconnectListeners()
        }

        // Track analytics
        AnalyticsManager.shared.logEvent(.listenersReconnected, parameters: [
            "listener_count": activeListeners.count,
            "reason": reason
        ])
    }

    /// Pause all registered listeners
    private func pauseAllListeners() {
        cleanupStaleReferences()

        let activeListeners = registeredListeners.values.compactMap { $0.listener }

        guard !activeListeners.isEmpty else { return }

        Logger.shared.info("Pausing \(activeListeners.count) listeners", category: .general)

        for listener in activeListeners {
            Logger.shared.debug("Pausing listener: \(listener.listenerId)", category: .general)
            listener.pauseListeners()
        }
    }

    // MARK: - Manual Control

    /// Force reconnection of all listeners (for debugging/manual recovery)
    func forceReconnect() {
        guard isAppActive && isNetworkAvailable else {
            Logger.shared.warning("Cannot force reconnect - app inactive or offline", category: .general)
            return
        }

        reconnectAllListeners(reason: "manual force reconnect")
    }

    /// Get status of all registered listeners
    func getListenerStatus() -> [(id: String, isActive: Bool)] {
        cleanupStaleReferences()

        return registeredListeners.values.compactMap { ref -> (id: String, isActive: Bool)? in
            guard let listener = ref.listener else { return nil }
            return (id: listener.listenerId, isActive: listener.areListenersActive)
        }
    }

    // MARK: - Cleanup

    private func cleanupStaleReferences() {
        // Remove any weak references that have been deallocated
        registeredListeners = registeredListeners.filter { $0.value.listener != nil }
    }
}

// MARK: - Weak Reference Wrapper

private class WeakListenerRef {
    weak var listener: ListenerLifecycleAware?

    init(_ listener: ListenerLifecycleAware) {
        self.listener = listener
    }
}

