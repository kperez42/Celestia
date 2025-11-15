//
//  WelcomeView.swift - IMPROVED VERSION
//  Celestia
//
//  ✨ Enhanced with:
//  - Animated gradient background
//  - Floating particles effect
//  - Feature carousel
//  - Better typography & spacing
//  - Smooth animations
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var currentFeature = 0
    @State private var animateGradient = false
    @State private var showContent = false
    @State private var featureTimer: Timer?

    let features = [
        Feature(icon: "globe.americas.fill", title: "Connect Globally", description: "Meet people from 195+ countries"),
        Feature(icon: "heart.text.square.fill", title: "Smart Matching", description: "AI-powered compatibility algorithm"),
        Feature(icon: "message.fill", title: "Real-Time Chat", description: "Instant messaging with translation")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                animatedBackground
                
                // Floating particles
                floatingParticles
                
                // Main content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Logo & branding
                    logoSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -30)
                    
                    Spacer()
                    
                    // Feature carousel
                    featureCarousel
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    Spacer()
                    
                    // CTA Buttons
                    ctaButtons
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        .padding(.bottom, 50)
                }
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    showContent = true
                }
                startFeatureTimer()
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    animateGradient = true
                }
            }
            .onDisappear {
                // Invalidate timer to prevent memory leak
                featureTimer?.invalidate()
                featureTimer = nil
            }
        }
    }
    
    // MARK: - Animated Background
    
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.9),
                    Color.pink.opacity(0.8),
                    Color.blue.opacity(0.7)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            
            // Overlay gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.3),
                    Color.clear,
                    Color.pink.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Floating Particles
    
    private var floatingParticles: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    FloatingParticle(
                        size: CGFloat.random(in: 4...12),
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        duration: Double.random(in: 3...6)
                    )
                }
            }
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 20) {
            // Animated star icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .white.opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 8) {
                Text("Celestia")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 5)
                
                Text("Where hearts connect across the world")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(0.1), radius: 3)
            }
        }
    }
    
    // MARK: - Feature Carousel
    
    private var featureCarousel: some View {
        VStack(spacing: 20) {
            // Current feature card
            FeatureCard(feature: features[currentFeature])
                .accessibleTransition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(features[currentFeature].title). \(features[currentFeature].description)")
            
            // Pagination dots
            HStack(spacing: 10) {
                ForEach(0..<features.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentFeature ? Color.white : Color.white.opacity(0.4))
                        .frame(width: index == currentFeature ? 30 : 8, height: 8)
                        .accessibleAnimation(.spring(response: 0.3), value: currentFeature)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Feature page indicator")
            .accessibilityValue("Page \(currentFeature + 1) of \(features.count)")
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - CTA Buttons
    
    private var ctaButtons: some View {
        VStack(spacing: 15) {
            // Create Account - Primary
            NavigationLink {
                SignUpView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.headline)

                    Text("Create Account")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        Color.white

                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: animateGradient ? 200 : -200)
                    }
                )
                .cornerRadius(28)
                .shadow(color: .white.opacity(0.5), radius: 15, y: 5)
            }
            .accessibilityLabel("Create Account")
            .accessibilityHint("Start creating your Celestia account")
            .accessibilityIdentifier(AccessibilityIdentifier.signUpButton)
            .scaleButton()
            
            // Sign In - Secondary
            NavigationLink {
                LoginView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.headline)

                    Text("Sign In")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.2))
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
            }
            .accessibilityLabel("Sign In")
            .accessibilityHint("Sign in to your existing account")
            .accessibilityIdentifier(AccessibilityIdentifier.signInButton)
            .scaleButton()
            
            // Terms & Privacy
            HStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                
                Button("Terms") {
                    if let url = URL(string: "https://celestia.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                
                Text("&")
                    .font(.caption)
                
                Button("Privacy") {
                    if let url = URL(string: "https://celestia.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.top, 5)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Functions
    
    private func startFeatureTimer() {
        // Invalidate existing timer before creating a new one
        featureTimer?.invalidate()

        // Store timer reference to prevent memory leak
        featureTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                currentFeature = (currentFeature + 1) % features.count
            }
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let feature: Feature
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 15)
                
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Floating Particle

struct FloatingParticle: View {
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let duration: Double
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.3))
            .frame(width: size, height: size)
            .blur(radius: 2)
            .position(x: x, y: y)
            .offset(y: isAnimating ? -100 : 100)
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Feature Model

struct Feature {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}
