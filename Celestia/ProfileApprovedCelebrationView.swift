//
//  ProfileApprovedCelebrationView.swift
//  Celestia
//
//  Celebrates user profile approval with confetti and animations
//

import SwiftUI

struct ProfileApprovedCelebrationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showConfetti = false
    @State private var appearAnimation = false
    @State private var scaleAnimation = false
    @State private var glowAnimation = false
    @State private var confettiPieces: [CelebrationConfettiPiece] = []
    @State private var dismissing = false

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Premium radiant background
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.94, blue: 1.0),
                        Color(red: 0.98, green: 0.96, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Radial glow overlays
                RadialGradient(
                    colors: [Color.green.opacity(0.2), Color.clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 400
                )

                RadialGradient(
                    colors: [Color.blue.opacity(0.1), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 350
                )
            }
            .ignoresSafeArea()

            // Confetti layer
            ForEach(confettiPieces) { piece in
                CelebrationConfettiView(piece: piece)
            }

            // Main content
            VStack(spacing: 32) {
                Spacer()

                // Animated checkmark with premium radial glow
                ZStack {
                    // Large radial glow background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.2),
                                    Color.blue.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .scaleEffect(glowAnimation ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: glowAnimation
                        )

                    // Outer glow rings with gradient stroke
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.4 - Double(index) * 0.1),
                                        Color.blue.opacity(0.3 - Double(index) * 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5 - CGFloat(index) * 0.5
                            )
                            .frame(width: CGFloat(160 + index * 35), height: CGFloat(160 + index * 35))
                            .scaleEffect(glowAnimation ? 1.08 : 1.0)
                            .opacity(glowAnimation ? 0.4 : 0.7)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                                value: glowAnimation
                            )
                    }

                    // Inner gradient background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.15),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    // Main gradient circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color(red: 0.2, green: 0.7, blue: 0.5),
                                    Color.green.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.5), radius: 20, y: 5)
                        .shadow(color: .green.opacity(0.3), radius: 40, y: 10)

                    // Checkmark with subtle shadow
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                        .scaleEffect(scaleAnimation ? 1.0 : 0.3)
                        .opacity(scaleAnimation ? 1.0 : 0)
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.5)
                .opacity(appearAnimation ? 1.0 : 0)

                // Title with premium gradient
                VStack(spacing: 12) {
                    Text("You're Approved!")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, Color(red: 0.2, green: 0.6, blue: 0.5), .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(appearAnimation ? 1.0 : 0.8)

                    Text("Welcome to Celestia")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.secondary, .secondary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .opacity(appearAnimation ? 1.0 : 0)
                .offset(y: appearAnimation ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                // Celebration message with premium card styling
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Your profile is now live")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }

                    Text("Start connecting with amazing people in your community. Your journey begins now!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
                        .shadow(color: .green.opacity(0.1), radius: 30, y: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.2),
                                    Color.blue.opacity(0.15),
                                    Color.green.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 24)
                .opacity(appearAnimation ? 1.0 : 0)
                .offset(y: appearAnimation ? 0 : 40)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)

                Spacer()

                // Premium continue button with glow
                Button(action: {
                    dismissWithAnimation()
                }) {
                    HStack(spacing: 12) {
                        Text("Start Exploring")
                            .font(.headline.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.green,
                                Color(red: 0.2, green: 0.65, blue: 0.5),
                                Color.blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                    .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)
                }
                .scaleButton()
                .padding(.horizontal, 24)
                .opacity(appearAnimation ? 1.0 : 0)
                .offset(y: appearAnimation ? 0 : 50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)
                .padding(.bottom, 40)
            }
        }
        .opacity(dismissing ? 0 : 1)
        .scaleEffect(dismissing ? 1.1 : 1.0)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animation Methods

    private func startAnimations() {
        // Trigger haptic
        HapticManager.shared.notification(.success)

        // Start appearance animation
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            appearAnimation = true
        }

        // Start checkmark scale animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scaleAnimation = true
            }
        }

        // Start glow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            glowAnimation = true
        }

        // Start confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generateConfetti()
        }
    }

    private func generateConfetti() {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            .mint, .cyan, .indigo, .teal
        ]
        let shapes = [
            "circle.fill", "star.fill", "heart.fill", "diamond.fill",
            "sparkle", "seal.fill", "hexagon.fill", "triangle.fill"
        ]

        let screenWidth = UIScreen.main.bounds.width

        // Generate more confetti for a bigger celebration
        for i in 0..<80 {
            let piece = CelebrationConfettiPiece(
                id: i,
                color: colors.randomElement()!,
                shape: shapes.randomElement()!,
                x: CGFloat.random(in: (-30)...(screenWidth + 30)),
                y: CGFloat.random(in: (-80)...(-20)),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.4...1.3),
                delay: Double.random(in: 0...2.0)
            )
            confettiPieces.append(piece)
        }

        showConfetti = true
    }

    private func dismissWithAnimation() {
        HapticManager.shared.impact(.light)
        withAnimation(.easeOut(duration: 0.3)) {
            dismissing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Confetti Piece Model

struct CelebrationConfettiPiece: Identifiable {
    let id: Int
    let color: Color
    let shape: String
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
    let delay: Double
    let horizontalDrift: CGFloat  // Pre-calculated drift for smooth animation

    init(id: Int, color: Color, shape: String, x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat, delay: Double) {
        self.id = id
        self.color = color
        self.shape = shape
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
        self.delay = delay
        self.horizontalDrift = CGFloat.random(in: -60...60)
    }
}

// MARK: - Confetti View

struct CelebrationConfettiView: View {
    let piece: CelebrationConfettiPiece
    @State private var falling = false
    @State private var rotating = false
    @State private var swaying = false

    // Pre-calculated animation durations for consistency
    private var fallDuration: Double {
        2.5 + (Double(piece.id % 15) * 0.1)
    }

    private var rotationDuration: Double {
        1.5 + (Double(piece.id % 10) * 0.15)
    }

    // Gradient colors for premium confetti
    private var confettiGradient: LinearGradient {
        LinearGradient(
            colors: [piece.color, piece.color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Image(systemName: piece.shape)
            .font(.system(size: 12 + CGFloat(piece.id % 6)))
            .foregroundStyle(confettiGradient)
            .shadow(color: piece.color.opacity(0.5), radius: 3, y: 1)
            .scaleEffect(piece.scale)
            .rotationEffect(.degrees(rotating ? piece.rotation + 720 : piece.rotation))
            .rotation3DEffect(.degrees(swaying ? 25 : -25), axis: (x: 1, y: 0, z: 0))
            .position(
                x: piece.x + (falling ? piece.horizontalDrift : 0),
                y: falling ? UIScreen.main.bounds.height + 100 : piece.y
            )
            .opacity(falling ? 0 : 1)
            .onAppear {
                withAnimation(
                    .easeIn(duration: fallDuration)
                    .delay(piece.delay)
                ) {
                    falling = true
                }
                withAnimation(
                    .linear(duration: rotationDuration)
                    .repeatForever(autoreverses: false)
                    .delay(piece.delay)
                ) {
                    rotating = true
                }
                withAnimation(
                    .easeInOut(duration: 0.3)
                    .repeatForever(autoreverses: true)
                    .delay(piece.delay)
                ) {
                    swaying = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ProfileApprovedCelebrationView(onDismiss: {})
        .environmentObject(AuthService.shared)
}
