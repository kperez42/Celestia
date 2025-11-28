//
//  OfflineIndicator.swift
//  Celestia
//
//  UI components for displaying offline status and pending operations
//

import SwiftUI

/// Floating offline indicator banner
struct OfflineIndicator: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var operationQueue = OfflineOperationQueue.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                offlineBanner
                    .transition(.opacity)
            }
        }
        .animation(.quick, value: networkMonitor.isConnected)
    }
    
    private var offlineBanner: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                // Offline icon with animation
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're Offline")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if operationQueue.pendingOperations.isEmpty {
                        Text("Changes will sync when connected")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("\(operationQueue.pendingOperations.count) pending \(operationQueue.pendingOperations.count == 1 ? "action" : "actions")")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                // Expand/collapse button if there are pending operations
                if !operationQueue.pendingOperations.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.95), Color.red.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Expanded pending operations list
            if isExpanded && !operationQueue.pendingOperations.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(operationQueue.pendingOperations) { operation in
                            PendingOperationRow(operation: operation)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 200)
                .background(Color.orange.opacity(0.15))
            }
        }
        .accessibilityLabel("Offline mode active")
        .accessibilityHint("\(operationQueue.pendingOperations.count) pending actions will sync when online")
    }
}

/// Individual pending operation row
struct PendingOperationRow: View {
    let operation: PendingOperation
    
    var body: some View {
        HStack(spacing: 10) {
            // Operation icon
            Image(systemName: operationIcon)
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(operationTitle)
                    .font(.system(size: 13, weight: .medium))
                
                Text(timeAgo(from: operation.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if operation.retryCount > 0 {
                Text("Retry \(operation.retryCount)")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private var operationIcon: String {
        switch operation.type {
        case .sendMessage:
            return "message.fill"
        case .likeUser:
            return "heart.fill"
        case .superLikeUser:
            return "star.fill"
        case .updateProfile:
            return "person.fill"
        case .uploadPhoto:
            return "photo.fill"
        case .deletePhoto:
            return "trash.fill"
        }
    }
    
    private var operationTitle: String {
        switch operation.type {
        case .sendMessage:
            return "Send message"
        case .likeUser:
            return "Like profile"
        case .superLikeUser:
            return "Super like profile"
        case .updateProfile:
            return "Update profile"
        case .uploadPhoto:
            return "Upload photo"
        case .deletePhoto:
            return "Delete photo"
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

/// Small badge showing offline status
struct OfflineBadge: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text("Offline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

/// Connection status view for settings/debug
struct ConnectionStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var operationQueue = OfflineOperationQueue.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection status
            HStack {
                Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                    .font(.title2)
                    .foregroundColor(networkMonitor.isConnected ? .green : .red)
                
                VStack(alignment: .leading) {
                    Text(networkMonitor.isConnected ? "Connected" : "Offline")
                        .font(.headline)
                    
                    if networkMonitor.isConnected {
                        Text(networkMonitor.connectionType.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Quality indicator
            if networkMonitor.isConnected {
                HStack {
                    Text("Connection Quality:")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(networkMonitor.quality.description)
                        .font(.subheadline)
                        .foregroundColor(qualityColor)
                }
            }
            
            // Pending operations
            if !operationQueue.pendingOperations.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Operations")
                        .font(.headline)
                    
                    ForEach(operationQueue.pendingOperations) { operation in
                        PendingOperationRow(operation: operation)
                    }
                }
            }
        }
        .padding()
    }
    
    private var qualityColor: Color {
        switch networkMonitor.quality {
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

#Preview("Offline Indicator") {
    VStack {
        OfflineIndicator()
        Spacer()
    }
}

#Preview("Connection Status") {
    ConnectionStatusView()
}
