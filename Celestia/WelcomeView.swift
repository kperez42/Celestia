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
    @State private var showAwarenessSlides = false
    @State private var navigateToSignUp = false

    let features = [
        Feature(icon: "heart.circle.fill", title: "Find Your Match", description: "Meet amazing people near you"),
        Feature(icon: "heart.text.square.fill", title: "Smart Matching", description: "AI-powered compatibility algorithm"),
        Feature(icon: "message.fill", title: "Real-Time Chat", description: "Instant messaging with your matches")
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
            // Awareness slides shown before signup
            .fullScreenCover(isPresented: $showAwarenessSlides) {
                WelcomeAwarenessSlidesView {
                    // After completing awareness slides, navigate to signup
                    showAwarenessSlides = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToSignUp = true
                    }
                }
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
            // Guard against invalid geometry that would cause NaN errors
            let safeWidth = max(geometry.size.width, 1)
            let safeHeight = max(geometry.size.height, 1)

            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    FloatingParticle(
                        size: CGFloat.random(in: 4...12),
                        x: CGFloat.random(in: 0...safeWidth),
                        y: CGFloat.random(in: 0...safeHeight),
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
                
                Text("Find friends, dates, and meaningful connections")
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
                    Circle()
                        .fill(index == currentFeature ? Color.white : Color.white.opacity(0.4))
                        .frame(width: index == currentFeature ? 12 : 8, height: index == currentFeature ? 12 : 8)
                        .scaleEffect(index == currentFeature ? 1.0 : 0.85)
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
            // Create Account - Primary (shows awareness slides first)
            Button {
                HapticManager.shared.impact(.medium)
                showAwarenessSlides = true
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

            // Hidden NavigationLink for programmatic navigation after awareness slides
            NavigationLink(destination: SignUpView(), isActive: $navigateToSignUp) {
                EmptyView()
            }
            .hidden()
            
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

// MARK: - Welcome Awareness Slides View
// Shows app guidelines and features BEFORE signup to educate new users

struct WelcomeAwarenessSlidesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    let onComplete: () -> Void

    // Awareness slides content - educates users about the app
    let slides: [AwarenessSlide] = [
        AwarenessSlide(
            icon: "star.circle.fill",
            title: "Welcome to Celestia!",
            description: "Your journey to meaningful connections starts here. Let us show you how it works!",
            color: .purple,
            tips: [
                "Be authentic and genuine in your profile",
                "Add photos that show your personality",
                "Write a bio that sparks conversation"
            ]
        ),
        AwarenessSlide(
            icon: "hand.point.up.left.fill",
            title: "Discover & Swipe",
            description: "Swipe right to like someone, or left to pass. When you both like each other, it's a match!",
            color: .pink,
            tips: [
                "Tap the profile to view more details",
                "Super Like to stand out from the crowd",
                "Take your time - quality over quantity"
            ]
        ),
        AwarenessSlide(
            icon: "heart.fill",
            title: "Make Matches",
            description: "When someone you liked also likes you back, you'll both be notified and can start chatting!",
            color: .red,
            tips: [
                "Matches appear in your Matches tab",
                "Send the first message to break the ice",
                "Be respectful and genuine"
            ]
        ),
        AwarenessSlide(
            icon: "message.fill",
            title: "Start Conversations",
            description: "Once matched, send a message to start getting to know each other better.",
            color: .blue,
            tips: [
                "Ask about their interests",
                "Reference something from their profile",
                "Be yourself and have fun!"
            ]
        ),
        AwarenessSlide(
            icon: "person.crop.circle.fill.badge.checkmark",
            title: "Complete Your Profile",
            description: "High-quality profiles get 5x more matches. Add photos, write a bio, and share your interests!",
            color: .green,
            tips: [
                "Add 4-6 clear photos of yourself",
                "Write a bio that shows your personality",
                "Select interests to find like-minded people"
            ]
        ),
        AwarenessSlide(
            icon: "shield.checkered",
            title: "Stay Safe",
            description: "Your safety is our priority. We review all profiles and provide tools to report inappropriate behavior.",
            color: .orange,
            tips: [
                "Meet in public places for first dates",
                "Tell a friend about your plans",
                "Trust your instincts always",
                "Report and block suspicious accounts"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [slides[currentPage].color.opacity(0.15), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with skip button
                HStack {
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage >= index ? slides[currentPage].color : Color.gray.opacity(0.3))
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    Spacer()

                    Button {
                        onComplete()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(slides[currentPage].color)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Swipeable slides
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        AwarenessSlideView(slide: slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                currentPage -= 1
                                HapticManager.shared.impact(.light)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(slides[currentPage].color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(slides[currentPage].color, lineWidth: 2)
                            )
                        }
                    }

                    Button {
                        if currentPage < slides.count - 1 {
                            withAnimation(.spring(response: 0.3)) {
                                currentPage += 1
                                HapticManager.shared.impact(.medium)
                            }
                        } else {
                            HapticManager.shared.notification(.success)
                            onComplete()
                        }
                    } label: {
                        HStack {
                            Text(currentPage < slides.count - 1 ? "Next" : "Get Started")
                                .fontWeight(.semibold)

                            Image(systemName: currentPage < slides.count - 1 ? "chevron.right" : "arrow.right.circle.fill")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [slides[currentPage].color, slides[currentPage].color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: slides[currentPage].color.opacity(0.3), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Awareness Slide Model

struct AwarenessSlide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
    let tips: [String]
}

// MARK: - Awareness Slide View

struct AwarenessSlideView: View {
    let slide: AwarenessSlide

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(slide.color.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)

                Circle()
                    .fill(slide.color.opacity(0.1))
                    .frame(width: 150, height: 150)

                Image(systemName: slide.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [slide.color, slide.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 16) {
                Text(slide.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(slide.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                ForEach(slide.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(slide.color.opacity(0.15))
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(slide.color)
                        }

                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.8))

                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}

#Preview("Awareness Slides") {
    WelcomeAwarenessSlidesView {
        print("Completed")
    }
}
