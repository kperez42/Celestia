//
//  SplashView.swift
//  Celestia
//
//  Professional splash screen with brand animation
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var animateGradient = false
    @State private var showTagline = false
    @State private var dotCount = 0
    @State private var dotTimer: Timer?
    @State private var pulseAnimation = false
    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            // Premium animated gradient background
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.15, blue: 0.75),  // Deep Purple
                        Color(red: 0.85, green: 0.25, blue: 0.55),  // Rich Pink
                        Color(red: 0.35, green: 0.45, blue: 0.85)   // Royal Blue
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint: animateGradient ? .bottomTrailing : .topTrailing
                )

                // Radial glow overlay
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }

            VStack(spacing: 32) {
                // Logo icon with premium radial glow effect
                ZStack {
                    // Large radial glow background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.purple.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)

                    // Rotating outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.pink.opacity(0.3),
                                    Color.white.opacity(0.2),
                                    Color.purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(ringRotation))

                    // Second rotating ring (opposite direction)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.cyan.opacity(0.2),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-ringRotation * 0.7))

                    // Outer glow
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 130, height: 130)
                        .blur(radius: 25)

                    // Middle glow
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 115, height: 115)
                        .blur(radius: 12)

                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    // Main icon with gradient
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name with gradient
                Text("Celestia")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95), .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .white.opacity(0.3), radius: 10)
                    .opacity(logoOpacity)

                // Premium loading indicator
                if showTagline {
                    HStack(spacing: 8) {
                        // Animated loading dots
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(dotCount == index ? 1.3 : 0.8)
                                    .opacity(dotCount == index ? 1.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.3),
                                        value: dotCount
                                    )
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .onAppear {
            startAnimations()
            startLoadingDots()
        }
        .onDisappear {
            dotTimer?.invalidate()
            dotTimer = nil
        }
    }

    private func startAnimations() {
        // Logo scale and fade in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Start ring rotation animation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Start pulse animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }

        // Show tagline after logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.5)) {
                showTagline = true
            }
        }
    }

    private func startLoadingDots() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

#Preview {
    SplashView()
}
