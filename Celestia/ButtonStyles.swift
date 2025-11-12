//
//  ButtonStyles.swift
//  Celestia
//
//  Unified button styles for consistent interactive feedback
//

import SwiftUI

// MARK: - Scale Button Style

/// Button style that scales down on press with customizable scale factor
struct ScaleButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Primary Button Style

/// Primary button with gradient background and scale effect
struct PrimaryButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.96
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Secondary button with outline and scale effect
struct SecondaryButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.96
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Destructive button with red gradient and scale effect
struct DestructiveButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.96
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

/// Icon button with circle background and scale effect
struct IconButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.92
    var backgroundColor: Color = Color.white.opacity(0.2)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card Button Style

/// Card/row button with subtle highlight effect
struct CardButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.98

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Action Button Style

/// Action button for swipe actions with bounce effect
struct ActionButtonStyle: ButtonStyle {
    var scaleEffect: CGFloat = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply scale button style with default scale factor
    func scaleButton(scale: CGFloat = 0.96) -> some View {
        self.buttonStyle(ScaleButtonStyle(scaleEffect: scale))
    }

    /// Apply primary button style
    func primaryButton(disabled: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isDisabled: disabled))
    }

    /// Apply secondary button style
    func secondaryButton(disabled: Bool = false) -> some View {
        self.buttonStyle(SecondaryButtonStyle(isDisabled: disabled))
    }

    /// Apply destructive button style
    func destructiveButton(disabled: Bool = false) -> some View {
        self.buttonStyle(DestructiveButtonStyle(isDisabled: disabled))
    }

    /// Apply icon button style
    func iconButton(backgroundColor: Color = Color.white.opacity(0.2)) -> some View {
        self.buttonStyle(IconButtonStyle(backgroundColor: backgroundColor))
    }

    /// Apply card button style
    func cardButton() -> some View {
        self.buttonStyle(CardButtonStyle())
    }

    /// Apply action button style (for swipe buttons)
    func actionButton() -> some View {
        self.buttonStyle(ActionButtonStyle())
    }
}
