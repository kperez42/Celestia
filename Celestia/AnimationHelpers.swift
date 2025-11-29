//
//  AnimationHelpers.swift
//  Celestia
//
//  Created by Claude
//  Reusable animations and transitions for smooth UX
//

import SwiftUI

// MARK: - Custom Transitions

extension AnyTransition {
    /// Instant fade transition - no sliding, appears immediately
    static var slideAndFade: AnyTransition {
        .opacity
    }

    /// Quick scale with fade for subtle pop effect
    static var scaleAndFade: AnyTransition {
        .opacity
    }

    /// Instant pop-in - just opacity for smooth appearance
    static var popIn: AnyTransition {
        .opacity
    }

    /// Instant appearance from bottom - opacity only
    static var slideUp: AnyTransition {
        .opacity
    }

    /// Instant appearance from top - opacity only
    static var slideDown: AnyTransition {
        .opacity
    }

    /// Truly instant transition with no animation
    static var instant: AnyTransition {
        .identity
    }
}

// MARK: - Custom Animations

extension Animation {
    /// Ultra-smooth instant animation - butter smooth
    static var smooth: Animation {
        .easeOut(duration: 0.15)
    }

    /// Quick bouncy feel without excessive movement
    static var bouncy: Animation {
        .easeOut(duration: 0.12)
    }

    /// Nearly instant - for snappy interactions
    static var quick: Animation {
        .easeOut(duration: 0.1)
    }

    /// Gentle fade - still fast but slightly softer
    static var gentle: Animation {
        .easeOut(duration: 0.18)
    }

    /// Truly instant - no visible animation
    static var instant: Animation {
        .linear(duration: 0)
    }

    // MARK: - Butter Smooth Animations

    /// Butter smooth spring - natural iOS feel with perfect damping
    static var butterSmooth: Animation {
        .spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)
    }

    /// Snappy spring for interactions - quick response with slight bounce
    static var snappy: Animation {
        .spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0)
    }

    /// Responsive spring for card swipes - physics-based feel
    static var swipeSpring: Animation {
        .interpolatingSpring(mass: 0.8, stiffness: 300, damping: 25, initialVelocity: 0)
    }

    /// Micro-interaction spring - subtle and fast
    static var microSpring: Animation {
        .spring(response: 0.2, dampingFraction: 0.85, blendDuration: 0)
    }

    /// Card dismiss animation - smooth exit
    static var cardDismiss: Animation {
        .interpolatingSpring(mass: 0.6, stiffness: 200, damping: 20, initialVelocity: 5)
    }

    /// Tab switch animation - instant but polished
    static var tabSwitch: Animation {
        .spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0)
    }

    /// Scroll animation - for programmatic scrolling
    static var smoothScroll: Animation {
        .spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0)
    }
}

// MARK: - Shake Animation

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
    }
}

// MARK: - Pulse Animation

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        duration: Double = 1.0
    ) -> some View {
        modifier(PulseEffect(
            minScale: minScale,
            maxScale: maxScale,
            duration: duration
        ))
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 400)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Bouncy Button

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle {
        BouncyButtonStyle()
    }
}

// MARK: - Card Flip

struct CardFlip: ViewModifier {
    var isFlipped: Bool
    var frontView: AnyView
    var backView: AnyView

    func body(content: Content) -> some View {
        ZStack {
            frontView
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 0 : 1)

            backView
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 1 : 0)
        }
    }
}

// MARK: - Animated Gradient

struct AnimatedGradient: View {
    @State private var animateGradient = false

    let colors: [Color]
    let speed: Double

    init(colors: [Color], speed: Double = 3.0) {
        self.colors = colors
        self.speed = speed
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(
                .linear(duration: speed)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Floating Animation

struct FloatingEffect: ViewModifier {
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -10 : 10)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    isFloating.toggle()
                }
            }
    }
}

extension View {
    func floating() -> some View {
        modifier(FloatingEffect())
    }
}

// MARK: - Confetti

struct Confetti: View {
    @State private var animate = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .pink, .purple]

    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { i in
                ConfettiPiece(color: colors.randomElement() ?? .red)
                    .offset(
                        x: animate ? CGFloat.random(in: -300...300) : 0,
                        y: animate ? CGFloat.random(in: -800...0) : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .rotationEffect(.degrees(animate ? Double.random(in: 0...720) : 0))
            }
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 2)
            ) {
                animate = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}

// MARK: - Match Celebration Animation

struct MatchCelebrationView: View {
    @State private var showConfetti = false
    @State private var showHearts = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            if showConfetti {
                Confetti()
            }

            VStack(spacing: 30) {
                // Animated hearts
                HStack(spacing: 20) {
                    if showHearts {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.pink, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(showHearts ? 1.0 : 0.5)
                                .opacity(showHearts ? 1.0 : 0.0)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.6)
                                    .delay(Double(i) * 0.1),
                                    value: showHearts
                                )
                        }
                    }
                }
                .floating()

                Text("It's a Match! 🎉")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .onAppear {
            // Stagger animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.bouncy) {
                    scale = 1.0
                    opacity = 1.0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showHearts = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Loading Dots

struct LoadingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12, height: 12)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Slide In From Edge

struct SlideInModifier: ViewModifier {
    let edge: Edge
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .transition(.opacity)
            .animation(.quick, value: isPresented)
    }
}

extension View {
    func slideIn(from edge: Edge, isPresented: Binding<Bool>) -> some View {
        modifier(SlideInModifier(edge: edge, isPresented: isPresented))
    }
}

// MARK: - Butter Smooth View Modifiers

/// View modifier for butter-smooth scale animations on press
struct ButterSmoothPressEffect: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.snappy, value: isPressed)
    }
}

/// View modifier for smooth spring opacity
struct SmoothFadeModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.butterSmooth, value: isVisible)
    }
}

/// Smooth card swipe gesture modifier
struct SmoothSwipeModifier: ViewModifier {
    @Binding var offset: CGSize
    let onSwipeEnd: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .animation(.swipeSpring, value: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        onSwipeEnd(value.translation)
                    }
            )
    }
}

extension View {
    /// Apply butter-smooth press scale effect
    func butterSmoothPress(isPressed: Bool, scale: CGFloat = 0.95) -> some View {
        modifier(ButterSmoothPressEffect(isPressed: isPressed, scale: scale))
    }

    /// Apply smooth fade in/out
    func smoothFade(isVisible: Bool) -> some View {
        modifier(SmoothFadeModifier(isVisible: isVisible))
    }

    /// Apply smooth swipe gesture
    func smoothSwipe(offset: Binding<CGSize>, onEnd: @escaping (CGSize) -> Void) -> some View {
        modifier(SmoothSwipeModifier(offset: offset, onSwipeEnd: onEnd))
    }

    /// GPU-accelerated rendering for complex views
    func gpuAccelerated() -> some View {
        self
            .drawingGroup(opaque: false)
            .compositingGroup()
    }

    /// Optimize for smooth scrolling in lists
    func smoothScrollOptimized() -> some View {
        self
            .drawingGroup(opaque: false)
    }
}

// MARK: - Smooth Scale Button Style

/// Button style with butter-smooth press animation
struct SmoothScaleButtonStyle: ButtonStyle {
    let scaleEffect: CGFloat

    init(scaleEffect: CGFloat = 0.95) {
        self.scaleEffect = scaleEffect
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .animation(.snappy, value: configuration.isPressed)
    }
}

/// Button style with spring animation for interactive elements
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.microSpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SmoothScaleButtonStyle {
    static var smoothScale: SmoothScaleButtonStyle {
        SmoothScaleButtonStyle()
    }

    static func smoothScale(_ scale: CGFloat) -> SmoothScaleButtonStyle {
        SmoothScaleButtonStyle(scaleEffect: scale)
    }
}

extension ButtonStyle where Self == SpringButtonStyle {
    static var springy: SpringButtonStyle {
        SpringButtonStyle()
    }
}

// MARK: - Smooth Scroll View Wrapper

/// A scroll view that enables smooth, butter-like scrolling
struct SmoothScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: () -> Content

    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Smooth List Row Appearance

/// View modifier for smooth list row appearance animation
struct SmoothRowAppearance: ViewModifier {
    let delay: Double
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1.0 : 0.0)
            .offset(y: hasAppeared ? 0 : 10)
            .onAppear {
                withAnimation(.butterSmooth.delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Animate row appearance with staggered delay
    func smoothRowAppearance(delay: Double = 0) -> some View {
        modifier(SmoothRowAppearance(delay: delay))
    }
}

// MARK: - Preview

#Preview("Match Celebration") {
    ZStack {
        Color.black
        MatchCelebrationView()
    }
    .ignoresSafeArea()
}

#Preview("Loading Dots") {
    LoadingDots()
}

#Preview("Animated Gradient") {
    AnimatedGradient(colors: [.purple, .pink, .orange])
        .ignoresSafeArea()
}
