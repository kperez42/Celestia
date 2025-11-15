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

    var body: some View {
        ZStack {
            // Animated gradient background matching WelcomeView
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.2, blue: 0.8),  // Purple
                    Color(red: 0.9, green: 0.3, blue: 0.6),  // Pink
                    Color(red: 0.4, green: 0.5, blue: 0.9)   // Blue
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }

            VStack(spacing: 30) {
                // Logo icon with glow effect
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)

                    // Middle glow
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 15)

                    // Icon background
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)

                    // Main icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                Text("Celestia")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(logoOpacity)

                // Loading indicator with animated dots
                if showTagline {
                    HStack(spacing: 4) {
                        Text("Loading")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Text(String(repeating: ".", count: dotCount))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20, alignment: .leading)
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            startAnimations()
            startLoadingDots()
        }
        .onDisappear {
            // Clean up timer to prevent memory leak
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
