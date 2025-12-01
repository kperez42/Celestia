//
//  ShimmerEffect.swift
//  Celestia
//
//  Beautiful shimmer loading effects for skeleton placeholders
//

import SwiftUI

// MARK: - Skeleton Shimmer Effect Modifier

struct SkeletonShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let delay: Double

    init(duration: Double = 1.5, delay: Double = 0) {
        self.duration = duration
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * (width * 1.6) - (width * 0.3))
                    .frame(width: width, height: height, alignment: .leading)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func skeletonShimmer(duration: Double = 1.5, delay: Double = 0) -> some View {
        modifier(SkeletonShimmerEffect(duration: duration, delay: delay))
    }
}

// MARK: - Skeleton Shapes

struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .skeletonShimmer()
    }
}

// MARK: - Profile Card Skeleton

struct ProfileCardSkeleton: View {
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Photo skeleton
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 280)
                .skeletonShimmer()

            // Content skeleton
            VStack(alignment: .leading, spacing: 12) {
                // Name and age row
                HStack {
                    SkeletonShape(width: 140, height: 28)
                    SkeletonShape(width: 40, height: 24)
                    Spacer()
                    SkeletonShape(width: 60, height: 24, cornerRadius: 12)
                }

                // Location and gender
                HStack(spacing: 16) {
                    SkeletonShape(width: 100, height: 18)
                    SkeletonShape(width: 80, height: 18)
                }

                // Email
                SkeletonShape(width: 180, height: 14)

                // Bio
                VStack(spacing: 6) {
                    SkeletonShape(height: 14)
                    SkeletonShape(height: 14)
                    SkeletonShape(width: 200, height: 14)
                }
                .padding(.top, 4)

                Divider()
                    .padding(.vertical, 8)

                // Action buttons skeleton
                HStack(spacing: 16) {
                    SkeletonShape(height: 48, cornerRadius: 12)
                    SkeletonShape(height: 48, cornerRadius: 12)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .scaleEffect(animateIn ? 1 : 0.95)
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Report Row Skeleton

struct ReportRowSkeleton: View {
    let delay: Double

    init(delay: Double = 0) {
        self.delay = delay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SkeletonShape(width: 80, height: 24, cornerRadius: 6)
                Spacer()
                SkeletonShape(width: 60, height: 14)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .skeletonShimmer(delay: delay)

                VStack(alignment: .leading, spacing: 4) {
                    SkeletonShape(width: 120, height: 16)
                    SkeletonShape(width: 160, height: 12)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stat Card Skeleton

struct StatCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .skeletonShimmer()
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(width: 80, height: 12)
                SkeletonShape(width: 50, height: 28)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Pending Profiles Loading View

struct PendingProfilesLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header skeleton
                HStack {
                    SkeletonShape(width: 160, height: 16)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Profile card skeletons
                ForEach(0..<3) { index in
                    ProfileCardSkeleton()
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Reports Loading View

struct ReportsLoadingView: View {
    var body: some View {
        List {
            ForEach(0..<5) { index in
                ReportRowSkeleton(delay: Double(index) * 0.1)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Stats Loading View

struct StatsLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonShape(width: 100, height: 24)
                        SkeletonShape(width: 140, height: 14)
                    }
                    Spacer()
                    SkeletonShape(width: 60, height: 28, cornerRadius: 14)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Stat cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<4) { _ in
                        StatCardSkeleton()
                    }
                }
                .padding(.horizontal)

                // Recent activity skeleton
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 24, height: 24)
                            .skeletonShimmer()
                        SkeletonShape(width: 120, height: 18)
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        ForEach(0..<3) { index in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                    .skeletonShimmer(delay: Double(index) * 0.15)

                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonShape(width: 140, height: 14)
                                    SkeletonShape(width: 80, height: 10)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                )
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Suspicious Profiles Loading View

struct SuspiciousProfilesLoadingView: View {
    var body: some View {
        List {
            ForEach(0..<5) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 12, height: 12)
                        .skeletonShimmer(delay: Double(index) * 0.1)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonShape(width: 120, height: 16)
                        SkeletonShape(width: 100, height: 12)
                        SkeletonShape(width: 160, height: 10)
                    }

                    Spacer()

                    SkeletonShape(width: 50, height: 12)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Appeals Loading View

struct AppealsLoadingView: View {
    var body: some View {
        List {
            ForEach(0..<5) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SkeletonShape(width: 100, height: 24, cornerRadius: 6)
                        Spacer()
                        SkeletonShape(width: 60, height: 14)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                            .skeletonShimmer(delay: Double(index) * 0.1)

                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonShape(width: 120, height: 16)
                            SkeletonShape(width: 80, height: 12)
                        }
                    }

                    SkeletonShape(height: 40, cornerRadius: 8)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Profile Card Skeleton") {
    VStack {
        ProfileCardSkeleton()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Loading Views") {
    TabView {
        PendingProfilesLoadingView()
            .tabItem { Label("Pending", systemImage: "person.badge.plus") }

        ReportsLoadingView()
            .tabItem { Label("Reports", systemImage: "exclamationmark.triangle") }

        StatsLoadingView()
            .tabItem { Label("Stats", systemImage: "chart.bar") }
    }
}
