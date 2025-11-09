//
//  NetworkMonitor.swift
//  Celestia
//
//  Real-time network connectivity monitoring
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .wifi
    @Published var lastDisconnectedAt: Date?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                // Track when we lose connection
                if wasConnected && !self.isConnected {
                    self.lastDisconnectedAt = Date()
                }

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                // Post notifications for connection changes
                if wasConnected != self.isConnected {
                    NotificationCenter.default.post(
                        name: self.isConnected ? .networkConnected : .networkDisconnected,
                        object: nil
                    )
                }
            }
        }

        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    // MARK: - Helper Methods

    var connectionTypeString: String {
        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Unknown"
        }
    }

    var isExpensiveConnection: Bool {
        // Cellular is considered expensive
        return connectionType == .cellular
    }

    func waitForConnection(timeout: TimeInterval = 30) async throws {
        guard !isConnected else { return }

        let startTime = Date()

        while !isConnected {
            if Date().timeIntervalSince(startTime) > timeout {
                throw NetworkError.timeout
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError
    case unknown

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Connection timeout"
        case .serverError:
            return "Server error"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "The request took too long. Please try again."
        case .serverError:
            return "Our servers are having issues. Please try again later."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
