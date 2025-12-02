//
//  NetworkMonitor.swift
//  Celestia
//
//  Network reachability monitoring with NWPathMonitor
//  Tracks internet connectivity and connection quality
//

import Foundation
import Network
import Combine
import SwiftUI

// MARK: - Network Status

enum NetworkStatus {
    case connected(NetworkConnectionType)
    case disconnected

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

enum NetworkConnectionType {
    case wifi
    case cellular
    case wiredEthernet
    case other

    var description: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .other: return "Unknown"
        }
    }

    var isMetered: Bool {
        switch self {
        case .cellular:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Quality

enum NetworkQuality {
    case excellent  // < 50ms latency
    case good       // 50-150ms latency
    case fair       // 150-300ms latency
    case poor       // > 300ms latency
    case unknown

    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Network Monitor

@MainActor
class NetworkMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    @Published private(set) var status: NetworkStatus = .disconnected
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: NetworkConnectionType = .other
    @Published private(set) var quality: NetworkQuality = .unknown
    @Published private(set) var isExpensive: Bool = false

    // MARK: - Properties

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.celestia.networkmonitor")
    private var lastConnectivityChange = Date()

    // MARK: - Initialization

    private init() {
        setupMonitor()
        Logger.shared.info("NetworkMonitor initialized", category: .networking)
    }

    // MARK: - Setup

    private func setupMonitor() {
        // CRITICAL FIX: Get current path synchronously FIRST before setting up async handler
        // This prevents the race condition where isConnected is false on first check
        let currentPath = monitor.currentPath
        handlePathUpdate(currentPath)
        Logger.shared.info("📶 Initial network state: connected=\(isConnected), type=\(connectionType.description)", category: .networking)

        // Then set up async handler for future updates
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }

        monitor.start(queue: monitorQueue)
    }

    // MARK: - Path Handling

    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
            status = .connected(.wifi)
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
            status = .connected(.cellular)
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
            status = .connected(.wiredEthernet)
        } else if isConnected {
            connectionType = .other
            status = .connected(.other)
        } else {
            status = .disconnected
        }

        // Log connectivity changes
        if wasConnected != isConnected {
            let timeSinceLastChange = Date().timeIntervalSince(lastConnectivityChange)
            lastConnectivityChange = Date()

            if isConnected {
                Logger.shared.info("Network connected via \(connectionType.description)", category: .networking)

                // Track in analytics
                AnalyticsManager.shared.logEvent(.networkConnected, parameters: [
                    "connection_type": connectionType.description,
                    "is_expensive": isExpensive,
                    "offline_duration": timeSinceLastChange
                ])

                // RECONNECTION FIX: Post notification so all services can reconnect listeners
                NotificationCenter.default.post(
                    name: .networkConnectionRestored,
                    object: nil,
                    userInfo: [
                        "connectionType": connectionType.description,
                        "offlineDuration": timeSinceLastChange
                    ]
                )

                // Process pending offline operations when connection is restored
                Task {
                    await OfflineOperationQueue.shared.processPendingOperations()
                }
            } else {
                Logger.shared.warning("Network disconnected", category: .networking)

                // Track in analytics
                AnalyticsManager.shared.logEvent(.networkDisconnected, parameters: [
                    "online_duration": timeSinceLastChange
                ])

                // RECONNECTION FIX: Post notification so services can pause listeners
                NotificationCenter.default.post(
                    name: .networkConnectionLost,
                    object: nil,
                    userInfo: [
                        "onlineDuration": timeSinceLastChange
                    ]
                )
            }
        }

        // Estimate network quality based on connection type
        estimateQuality()
    }

    private func estimateQuality() {
        // This is a rough estimation - real quality measurement would require latency tests
        if !isConnected {
            quality = .unknown
        } else {
            switch connectionType {
            case .wifi, .wiredEthernet:
                quality = .excellent
            case .cellular:
                quality = isExpensive ? .fair : .good
            case .other:
                quality = .good
            }
        }
    }

    // MARK: - Network Quality Testing

    /// Test network latency to estimate connection quality
    func testLatency() async -> TimeInterval? {
        guard isConnected else { return nil }

        let startTime = Date()

        do {
            // CODE QUALITY FIX: Removed force unwrapping - use guard let instead
            guard let url = URL(string: "https://www.google.com") else {
                Logger.shared.error("Invalid latency test URL", category: .networking)
                return nil
            }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let latency = Date().timeIntervalSince(startTime)
            updateQuality(basedOnLatency: latency)

            Logger.shared.debug("Network latency: \(Int(latency * 1000))ms", category: .networking)

            return latency
        } catch {
            Logger.shared.error("Failed to test network latency", category: .networking, error: error)
            return nil
        }
    }

    private func updateQuality(basedOnLatency latency: TimeInterval) {
        let latencyMs = latency * 1000

        if latencyMs < 50 {
            quality = .excellent
        } else if latencyMs < 150 {
            quality = .good
        } else if latencyMs < 300 {
            quality = .fair
        } else {
            quality = .poor
        }
    }

    // MARK: - Connectivity Verification

    /// Verify actual internet connectivity by making a quick request
    /// ALWAYS tests network regardless of NWPathMonitor state
    func verifyConnectivity() async -> Bool {
        Logger.shared.debug("📶 Verifying connectivity (NWPathMonitor says: \(isConnected ? "connected" : "disconnected"))", category: .networking)

        // ALWAYS test actual connectivity - don't trust NWPathMonitor alone
        // This catches cases where NWPathMonitor is wrong about connection state
        do {
            guard let url = URL(string: "https://www.google.com/generate_204") else {
                Logger.shared.warning("📶 Invalid verification URL", category: .networking)
                return isConnected
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10.0 // Give it more time
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Google's generate_204 returns 204 on success
                let success = httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode)
                Logger.shared.info("📶 Connectivity test result: \(success ? "CONNECTED" : "FAILED") (status: \(httpResponse.statusCode))", category: .networking)

                // Update isConnected if verification disagrees with NWPathMonitor
                if success && !isConnected {
                    Logger.shared.warning("📶 NWPathMonitor was wrong - we ARE connected!", category: .networking)
                }

                return success
            }

            return true
        } catch {
            Logger.shared.warning("📶 Connectivity verification error: \(error.localizedDescription)", category: .networking)
            // Network request failed - we're probably offline
            return false
        }
    }

    // MARK: - Utility Methods

    /// Check if should use high-quality images based on connection
    var shouldUseHighQualityImages: Bool {
        guard isConnected else { return false }

        switch connectionType {
        case .wifi, .wiredEthernet:
            return true
        case .cellular:
            return !isExpensive && quality != .poor
        case .other:
            return quality == .excellent || quality == .good
        }
    }

    /// Check if should use video autoplay
    var shouldAutoplayVideos: Bool {
        guard isConnected else { return false }

        switch connectionType {
        case .wifi, .wiredEthernet:
            return true
        case .cellular, .other:
            return false
        }
    }

    /// Get recommended image quality
    var recommendedImageQuality: CDNImageQuality {
        guard isConnected else { return .thumbnail }

        if !shouldUseHighQualityImages {
            return .medium
        }

        switch quality {
        case .excellent, .good:
            return .high
        case .fair:
            return .medium
        case .poor, .unknown:
            return .low
        }
    }
}

// MARK: - Image Quality Enum

enum CDNImageQuality {
    case thumbnail
    case low
    case medium
    case high

    var compressionQuality: CGFloat {
        switch self {
        case .thumbnail: return 0.3
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.9
        }
    }

    var maxDimension: CGFloat {
        switch self {
        case .thumbnail: return 200
        case .low: return 400
        case .medium: return 800
        case .high: return 1600
        }
    }
}

// MARK: - Network Status View

struct NetworkStatusBadge: View {
    @ObservedObject var monitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)

            Text(statusText)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(8)
    }

    private var iconName: String {
        switch monitor.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .wiredEthernet:
            return "cable.connector"
        case .other:
            return "network"
        }
    }

    private var statusText: String {
        if !monitor.isConnected {
            return "Offline"
        }

        return monitor.connectionType.description
    }

    private var backgroundColor: Color {
        if !monitor.isConnected {
            return .red
        }

        switch monitor.quality {
        case .excellent, .good:
            return .green
        case .fair:
            return .orange
        case .poor:
            return .red
        case .unknown:
            return .gray
        }
    }
}
