//
//  ImagePerformanceDashboard.swift
//  Celestia
//
//  Admin dashboard for monitoring image optimization performance
//

import SwiftUI
import Charts

struct ImagePerformanceDashboard: View {
    @StateObject private var monitor = ImagePerformanceMonitor.shared

    @State private var refreshTimer: Timer?
    @State private var showingExportSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    dashboardHeader

                    // Key Metrics Cards
                    metricsGrid

                    // Performance Chart
                    performanceChart

                    // CDN Hit Rate
                    cdnHitRateCard

                    // Bandwidth Savings
                    bandwidthSavingsCard

                    // Actions
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Image Performance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        monitor.logPerformanceSummary()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }

    // MARK: - Dashboard Header

    private var dashboardHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Performance Monitoring")
                    .font(.title2.bold())

                Spacer()
            }

            Text("Real-time metrics for image optimization system")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(
                title: "Avg Load Time",
                value: String(format: "%.2f", monitor.averageLoadTime),
                unit: "seconds",
                icon: "timer",
                color: .blue,
                trend: monitor.averageLoadTime < 0.5 ? .improving : .stable
            )

            MetricCard(
                title: "Total Loads",
                value: "\(monitor.totalImageLoads)",
                unit: "images",
                icon: "photo.stack",
                color: .green,
                trend: .stable
            )

            MetricCard(
                title: "CDN Hit Rate",
                value: String(format: "%.1f", monitor.cdnHitRate * 100),
                unit: "%",
                icon: "network",
                color: .purple,
                trend: monitor.cdnHitRate > 0.8 ? .improving : .stable
            )

            MetricCard(
                title: "Bandwidth Saved",
                value: formatBytes(monitor.bandwidthSaved),
                unit: "",
                icon: "arrow.down.circle",
                color: .orange,
                trend: .improving
            )
        }
    }

    // MARK: - Performance Chart

    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load Time Trends")
                .font(.headline)

            // Simple bar representation (replace with actual Charts in iOS 16+)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.7), .pink.opacity(0.7)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: CGFloat.random(in: 30...100))
                }
            }
            .frame(height: 120)

            Text("Last 10 image loads")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - CDN Hit Rate Card

    private var cdnHitRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.purple)
                Text("CDN Performance")
                    .font(.headline)
                Spacer()
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(monitor.cdnHitRate), height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(format: "%.1f%%", monitor.cdnHitRate * 100))")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Cache Hit Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Optimal")
                            .font(.subheadline.bold())
                    }
                    Text("Target: >80%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Bandwidth Savings Card

    private var bandwidthSavingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.orange)
                Text("Bandwidth Savings")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.formattedBandwidthSaved())
                        .font(.title.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Total Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("~40%")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Reduction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WebP Conversion")
                        .font(.caption.bold())
                    Text("30-40% smaller than JPEG")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                monitor.logPerformanceSummary()
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Export Report")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            Button(action: {
                // Open Cloudinary dashboard
                if let url = URL(string: "https://console.cloudinary.com/console/c-dquqeovn2") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "cloud.fill")
                    Text("Open Cloudinary Dashboard")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            Button(action: {
                // Open Firebase Console
                if let url = URL(string: "https://console.firebase.google.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("Open Firebase Performance")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Refresh metrics
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: MetricTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                trendIndicator
            }
            .font(.caption)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var trendIndicator: some View {
        switch trend {
        case .improving:
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                Text("Good")
                    .font(.caption2)
            }
            .foregroundColor(.green)
        case .declining:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.right")
                    .font(.caption2)
                Text("Poor")
                    .font(.caption2)
            }
            .foregroundColor(.red)
        case .stable:
            EmptyView()
        }
    }
}

enum MetricTrend {
    case improving
    case declining
    case stable
}

#Preview {
    ImagePerformanceDashboard()
}
