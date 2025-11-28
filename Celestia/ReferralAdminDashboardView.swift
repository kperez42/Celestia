//
//  ReferralAdminDashboardView.swift
//  Celestia
//
//  Admin dashboard for referral program analytics and management
//  Features: ROI metrics, conversion funnels, fraud review, A/B test results
//

import SwiftUI
import Charts

struct ReferralAdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var referralManager = ReferralManager.shared

    @State private var selectedTab = 0
    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Data
    @State private var dashboardMetrics: ReferralDashboardMetrics?
    @State private var roiMetrics: ReferralROIMetrics?
    @State private var conversionFunnel: ConversionFunnel?
    @State private var topSources: [SourcePerformance] = []
    @State private var flaggedReferrals: [FraudAssessment] = []
    @State private var experimentResults: [String: ReferralExperimentResults] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading analytics...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Period selector
                            periodSelector

                            // Tab selector
                            tabSelector

                            // Content based on selected tab
                            switch selectedTab {
                            case 0:
                                overviewSection
                            case 1:
                                funnelSection
                            case 2:
                                fraudSection
                            case 3:
                                experimentsSection
                            default:
                                overviewSection
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Referral Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([AnalyticsPeriod.day, .week, .month, .quarter], id: \.rawValue) { period in
                    Button {
                        selectedPeriod = period
                        Task { await loadData() }
                    } label: {
                        Text(periodLabel(period))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedPeriod == period ?
                                Color.purple : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
    }

    private func periodLabel(_ period: AnalyticsPeriod) -> String {
        switch period {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                tabButton(index: 0, title: "Overview", icon: "chart.bar.fill")
                tabButton(index: 1, title: "Funnel", icon: "arrow.down.circle.fill")
                tabButton(index: 2, title: "Fraud Review", icon: "shield.fill")
                tabButton(index: 3, title: "A/B Tests", icon: "flask.fill")
            }
        }
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedTab == index ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                selectedTab == index ?
                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 20) {
            // Key metrics grid
            if let metrics = dashboardMetrics {
                keyMetricsGrid(metrics)
            }

            // ROI Card
            if let roi = roiMetrics {
                roiCard(roi)
            }

            // Top Sources
            if !topSources.isEmpty {
                topSourcesCard
            }
        }
    }

    private func keyMetricsGrid(_ metrics: ReferralDashboardMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            metricCard(
                title: "Monthly Referrals",
                value: "\(metrics.monthlyReferrals)",
                icon: "person.3.fill",
                color: .purple
            )

            metricCard(
                title: "Conversion Rate",
                value: String(format: "%.1f%%", metrics.conversionRate * 100),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )

            metricCard(
                title: "Viral Coefficient",
                value: String(format: "%.2f", metrics.viralCoefficient),
                icon: "arrow.triangle.branch",
                color: .blue,
                subtitle: metrics.viralCoefficient >= 1 ? "Viral!" : "Growing"
            )

            metricCard(
                title: "LTV/CAC Ratio",
                value: String(format: "%.1fx", metrics.ltvRatio),
                icon: "dollarsign.circle.fill",
                color: metrics.ltvRatio >= 3 ? .green : .orange,
                subtitle: metrics.ltvRatio >= 3 ? "Healthy" : "Improve"
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let subtitle = subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func roiCard(_ roi: ReferralROIMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ROI Analysis")
                    .font(.headline)

                Spacer()

                Text(roi.referralROI >= 0 ? "+\(String(format: "%.0f%%", roi.referralROI * 100))" : "\(String(format: "%.0f%%", roi.referralROI * 100))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(roi.referralROI >= 0 ? .green : .red)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revenue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", roi.referralRevenue))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", roi.estimatedCostOfPremium))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CPA")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", roi.costPerAcquisition))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg LTV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", roi.averageLTV))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Payback period: \(roi.paybackPeriodDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var topSourcesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Referral Sources")
                .font(.headline)

            ForEach(topSources.prefix(5), id: \.source) { source in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.source.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(source.totalSignups) signups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.1f%%", source.clickToSignupRate * 100))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)

                        Text("conversion")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

                if source.source != topSources.prefix(5).last?.source {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Funnel Section

    private var funnelSection: some View {
        VStack(spacing: 20) {
            if let funnel = conversionFunnel {
                funnelVisualization(funnel)
                funnelDetails(funnel)
            } else {
                Text("No funnel data available")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func funnelVisualization(_ funnel: ConversionFunnel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Conversion Funnel")
                    .font(.headline)

                Spacer()

                Text("\(String(format: "%.1f%%", funnel.overallConversionRate * 100)) overall")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }

            ForEach(Array(funnel.stages.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 8) {
                    HStack {
                        Text(stage.name)
                            .font(.subheadline)

                        Spacer()

                        Text("\(stage.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    GeometryReader { geometry in
                        let width = geometry.size.width * (index == 0 ? 1.0 : stage.conversionRate)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(1 - Double(index) * 0.15), .pink.opacity(1 - Double(index) * 0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(width, 40), height: 24)
                            .animation(.spring(response: 0.5), value: width)
                    }
                    .frame(height: 24)

                    if index < funnel.stages.count - 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .foregroundColor(.gray)
                            Text("-\(String(format: "%.1f%%", stage.dropoffRate * 100))")
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func funnelDetails(_ funnel: ConversionFunnel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Details")
                .font(.headline)

            ForEach(funnel.stages, id: \.name) { stage in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let avgTime = stage.averageTimeToNext {
                            Text("Avg time to next: \(formatDuration(avgTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(stage.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(String(format: "%.1f%% conv.", stage.conversionRate * 100))
                            .font(.caption)
                            .foregroundColor(stage.conversionRate > 0.5 ? .green : .orange)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Fraud Section

    private var fraudSection: some View {
        VStack(spacing: 20) {
            fraudSummaryCard

            if !flaggedReferrals.isEmpty {
                flaggedReferralsCard
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("No Flagged Referrals")
                        .font(.headline)

                    Text("All recent referrals passed fraud detection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }

    private var fraudSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fraud Detection Summary")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(flaggedReferrals.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Flagged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    let blocked = flaggedReferrals.filter { $0.decision == .block }.count
                    Text("\(blocked)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Blocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    let review = flaggedReferrals.filter { $0.reviewRequired }.count
                    Text("\(review)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Need Review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var flaggedReferralsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flagged Referrals")
                .font(.headline)

            ForEach(flaggedReferrals.prefix(10), id: \.assessmentId) { assessment in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User: \(assessment.userId.prefix(8))...")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Risk: \(assessment.riskLevel.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(riskColor(assessment.riskLevel))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f%%", assessment.riskScore * 100))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(riskColor(assessment.riskLevel))

                        Text(assessment.decision.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if assessment.reviewRequired {
                        Button {
                            // Would open review modal
                        } label: {
                            Text("Review")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func riskColor(_ level: FraudRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .blocked: return .red
        }
    }

    // MARK: - Experiments Section

    private var experimentsSection: some View {
        VStack(spacing: 20) {
            let experiments = referralManager.getActiveExperiments()

            if experiments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "flask")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No Active Experiments")
                        .font(.headline)

                    Text("Create an experiment to start A/B testing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.white)
                .cornerRadius(16)
            } else {
                ForEach(experiments) { experiment in
                    experimentCard(experiment)
                }
            }
        }
    }

    private func experimentCard(_ experiment: ReferralExperiment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experiment.name)
                        .font(.headline)

                    Text(experiment.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(experiment.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(experiment.status == .running ? Color.green : Color.gray)
                    .cornerRadius(8)
            }

            Divider()

            // Variants
            ForEach(experiment.variants) { variant in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(variant.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if variant.isControl {
                                Text("Control")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        Text("\(Int(variant.weight * 100))% traffic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let results = experimentResults[experiment.id] {
                        let variantResult = results.variants.first { $0.variantId == variant.id }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f%%", (variantResult?.conversionRate ?? 0) * 100))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if let improvement = variantResult?.relativeImprovement {
                                Text(improvement >= 0 ? "+\(String(format: "%.1f%%", improvement * 100))" : "\(String(format: "%.1f%%", improvement * 100))")
                                    .font(.caption)
                                    .foregroundColor(improvement >= 0 ? .green : .red)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }

            // Results summary
            if let results = experimentResults[experiment.id] {
                HStack {
                    if let winner = results.winner {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("Winner: \(experiment.variants.first { $0.id == winner }?.name ?? winner)")
                            .font(.caption)
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "hourglass")
                            .foregroundColor(.orange)
                        Text(results.recommendation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(Int(seconds / 86400))d"
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let metricsTask = referralManager.getDashboardMetrics()
            async let roiTask = referralManager.getROIMetrics(period: selectedPeriod)
            async let funnelTask = referralManager.getConversionFunnel(period: selectedPeriod)
            async let sourcesTask = referralManager.getTopSources(period: selectedPeriod)
            async let fraudTask = referralManager.getFlaggedReferrals()

            dashboardMetrics = try await metricsTask
            roiMetrics = try await roiTask
            conversionFunnel = try await funnelTask
            topSources = try await sourcesTask
            flaggedReferrals = try await fraudTask

            // Load experiment results
            for experiment in referralManager.getActiveExperiments() {
                if let results = try? await referralManager.getExperimentResults(experimentId: experiment.id) {
                    experimentResults[experiment.id] = results
                }
            }

            errorMessage = nil
        } catch {
            Logger.shared.error("Failed to load admin dashboard data", category: .referral, error: error)
            errorMessage = "Failed to load analytics data"
        }
    }
}

#Preview {
    ReferralAdminDashboardView()
}
