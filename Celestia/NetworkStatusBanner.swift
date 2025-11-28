//
//  NetworkStatusBanner.swift
//  Celestia
//
//  Network status banner to show offline/online state
//  UX FIX: Prevents user confusion when network is unavailable
//

import SwiftUI

/// Banner that appears at the top when offline
struct NetworkStatusBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.subheadline)

                    Text("No Internet Connection")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Offline")
                        .font(.caption)
                        .foregroundColor(.white.opacity(DesignSystem.Opacity.xl))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(Color.orange)
            }
            .transition(.opacity)
            .animation(.quick, value: networkMonitor.isConnected)
        }
    }
}

/// Connection quality indicator (optional)
struct NetworkQualityIndicator: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if networkMonitor.isConnected {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                // Connection type icon
                Image(systemName: networkMonitor.connectionType == .wifi ? "wifi" : "antenna.radiowaves.left.and.right")
                    .font(.caption)

                // Signal strength dots
                HStack(spacing: 2) {
                    ForEach(0..<qualityBars, id: \.self) { _ in
                        Circle()
                            .fill(qualityColor)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .foregroundColor(qualityColor)
        } else {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("Offline")
                    .font(.caption2)
            }
            .foregroundColor(.gray)
        }
    }

    private var qualityBars: Int {
        switch networkMonitor.quality {
        case .excellent:
            return 4
        case .good:
            return 3
        case .fair:
            return 2
        case .poor:
            return 1
        case .unknown:
            return 3
        }
    }

    private var qualityColor: Color {
        switch networkMonitor.quality {
        case .excellent:
            return .green
        case .good:
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

/// View extension for easy network status banner integration
extension View {
    /// Add network status banner at the top of the view
    func networkStatusBanner() -> some View {
        VStack(spacing: 0) {
            NetworkStatusBanner()
            self
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkStatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Offline state
            NetworkStatusBanner()
                .previewDisplayName("Offline Banner")

            // Quality indicator
            VStack {
                NetworkQualityIndicator()
                    .padding()
                Spacer()
            }
            .previewDisplayName("Quality Indicator")

            // Full integration example
            VStack {
                Text("Your content here")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
            .networkStatusBanner()
            .previewDisplayName("With Banner")
        }
    }
}
#endif
