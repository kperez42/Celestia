//
//  AnalyticsDashboardView.swift
//  Celestia
//
//  Comprehensive analytics dashboard showing profile insights,
//  match quality, trends, and personalized recommendations
//

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var analyticsService = AnalyticsServiceEnhanced.shared
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if analyticsService.isLoading {
                    ProgressView("Loading insights...")
                } else {
                    TabView(selection: $selectedTab) {
                        // Profile Insights
                        ProfileInsightsTab()
                            .tag(0)

                        // Match Quality
                        MatchQualityTab()
                            .tag(1)

                        // Trends
                        TrendsTab()
                            .tag(2)

                        // Recommendations
                        RecommendationsTab()
                            .tag(3)
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle("Your Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshAllData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .onAppear {
                loadAnalytics()
            }
        }
    }

    private func loadAnalytics() {
        guard let userId = authService.currentUser?.effectiveId else { return }

        Task {
            do {
                _ = try await analyticsService.generateUserInsights(userId: userId)
            } catch {
                Logger.shared.error("Failed to load analytics", category: .general, error: error)
            }
        }
    }

    private func refreshAllData() {
        loadAnalytics()
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Profile Insights Tab

struct ProfileInsightsTab: View {
    @StateObject private var analyticsService = AnalyticsServiceEnhanced.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let heatmap = analyticsService.profileHeatmap {
                    // Overview Card
                    OverviewCard(heatmap: heatmap)

                    // Profile Views Heatmap
                    HeatmapCard(heatmap: heatmap)

                    // Peak Times Card
                    PeakTimesCard(heatmap: heatmap)

                    // Views by Source
                    ViewsSourceCard(heatmap: heatmap)
                }
            }
            .padding()
        }
    }
}

struct OverviewCard: View {
    let heatmap: ProfileHeatmap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("Profile Overview")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                TrendIndicator(percentage: heatmap.trendPercentage)
            }

            HStack(spacing: 30) {
                StatBox(
                    value: "\(heatmap.totalViews)",
                    label: "Total Views",
                    icon: "eye"
                )

                Divider()
                    .frame(height: 40)

                StatBox(
                    value: String(format: "%.1f", heatmap.averageViewsPerDay),
                    label: "Per Day",
                    icon: "calendar"
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct HeatmapCard: View {
    let heatmap: ProfileHeatmap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.pink)

                Text("Hourly Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            // Hour bars
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 24), spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    let views = heatmap.hourlyDistribution[hour] ?? 0
                    let maxViews = heatmap.hourlyDistribution.values.max() ?? 1

                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 10, height: CGFloat(views) / CGFloat(maxViews) * 60)
                            .cornerRadius(2)

                        Text("\(hour)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct PeakTimesCard: View {
    let heatmap: ProfileHeatmap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                Text("Best Times")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Peak Hour")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.purple)
                        Text("\(heatmap.peakHour):00")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Peak Day")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                        Text(heatmap.peakDay)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }

            Text("⏰ Be active during these times to maximize visibility!")
                .font(.caption)
                .foregroundColor(.purple)
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct ViewsSourceCard: View {
    let heatmap: ProfileHeatmap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Where People Find You")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ForEach(Array(heatmap.viewsBySource.sorted(by: { $0.value > $1.value })), id: \.key) { source, count in
                HStack {
                    Text(source.capitalized)
                        .font(.subheadline)

                    Spacer()

                    Text("\(count)")
                        .font(.headline)
                        .foregroundColor(.purple)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Match Quality Tab

struct MatchQualityTab: View {
    @StateObject private var analyticsService = AnalyticsServiceEnhanced.shared
    @State private var selectedMatchId: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Match selector (placeholder)
                Text("Select a match to analyze")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()

                // Placeholder for match quality display
                if analyticsService.matchQualityScore > 0 {
                    MatchQualityScoreCard(score: analyticsService.matchQualityScore)
                }
            }
            .padding()
        }
    }
}

struct MatchQualityScoreCard: View {
    let score: Double

    var body: some View {
        VStack(spacing: 20) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: score)

                VStack {
                    Text("\(Int(score))")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Quality Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(getQualityMessage(score: score))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private func getQualityMessage(score: Double) -> String {
        switch score {
        case 80...100: return "Excellent! You two have great chemistry 💕"
        case 60..<80: return "Good connection! Keep the conversation going"
        case 40..<60: return "Average. Try asking more questions"
        case 20..<40: return "Needs improvement. Engage more actively"
        default: return "Very low. Consider reaching out more"
        }
    }
}

// MARK: - Trends Tab

struct TrendsTab: View {
    @StateObject private var analyticsService = AnalyticsServiceEnhanced.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let trend = analyticsService.timeToMatchTrend {
                    TimeToMatchCard(trend: trend)
                }

                Text("More trends coming soon...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .padding()
        }
    }
}

struct TimeToMatchCard: View {
    let trend: TimeToMatchTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.green)

                Text("Time to Match")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatTime(trend.averageTimeToMatch))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Fastest")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatTime(trend.fastestMatch))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }

            TrendDirectionView(direction: trend.trendDirection)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h"
        } else {
            let days = hours / 24
            return "\(days)d"
        }
    }
}

// MARK: - Recommendations Tab

struct RecommendationsTab: View {
    @StateObject private var analyticsService = AnalyticsServiceEnhanced.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let insights = analyticsService.userInsights {
                    ForEach(Array(insights.recommendations.enumerated()), id: \.0) { index, recommendation in
                        RecommendationCard(recommendation: recommendation, index: index)
                    }
                }
            }
            .padding()
        }
    }
}

struct RecommendationCard: View {
    let recommendation: String
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text("\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(recommendation)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TrendIndicator: View {
    let percentage: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)

            Text(String(format: "%.0f%%", abs(percentage)))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(percentage >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (percentage >= 0 ? Color.green : Color.red).opacity(0.1)
        )
        .cornerRadius(8)
    }
}

struct TrendDirectionView: View {
    let direction: TrendDirection

    var body: some View {
        HStack {
            Image(systemName: getIcon())
                .foregroundColor(getColor())

            Text(direction.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(getColor())
        }
        .padding(8)
        .background(getColor().opacity(0.1))
        .cornerRadius(8)
    }

    private func getIcon() -> String {
        switch direction {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }

    private func getColor() -> Color {
        switch direction {
        case .improving: return .green
        case .stable: return .orange
        case .declining: return .red
        }
    }
}

#Preview {
    AnalyticsDashboardView()
        .environmentObject(AuthService.shared)
}
