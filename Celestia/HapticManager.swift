//
//  HapticManager.swift
//  Celestia
//
//  Created by Claude
//  Centralized haptic feedback management
//

import UIKit

@MainActor
class HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for lower latency
        prepareGenerators()
    }

    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Impact Feedback

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light:
            impactLight.impactOccurred()
            impactLight.prepare()
        case .medium:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        case .heavy:
            impactHeavy.impactOccurred()
            impactHeavy.prepare()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        }
    }

    // MARK: - Selection Feedback

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Notification Feedback

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    // MARK: - Convenience Methods

    func success() {
        notification(.success)
    }

    func warning() {
        notification(.warning)
    }

    func error() {
        notification(.error)
    }

    func lightTap() {
        impact(.light)
    }

    func mediumTap() {
        impact(.medium)
    }

    func heavyTap() {
        impact(.heavy)
    }

    // MARK: - Dating App Specific

    func swipeLeft() {
        impact(.light)
    }

    func swipeRight() {
        impact(.medium)
    }

    func match() {
        // Special pattern for matches - celebratory double tap
        notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impact(.heavy)
        }
    }

    func superLike() {
        impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.notification(.success)
        }
    }

    func messageSent() {
        impact(.light)
    }

    func messageReceived() {
        impact(.medium)
    }

    func buttonPress() {
        impact(.light)
    }

    func cardFlip() {
        impact(.rigid)
    }

    // MARK: - Butter Smooth Haptics

    /// Ultra-subtle haptic for micro-interactions (scrolling, hover states)
    func microFeedback() {
        impact(.soft)
    }

    /// Smooth card swipe feedback - progressive intensity based on distance
    func swipeProgress(intensity: CGFloat) {
        // Clamp intensity between 0 and 1
        let clampedIntensity = max(0.0, min(1.0, intensity))

        if clampedIntensity > 0.7 {
            impact(.medium)
        } else if clampedIntensity > 0.4 {
            impact(.light)
        }
    }

    /// Tab switch feedback - quick and subtle
    func tabSwitch() {
        selection()
    }

    /// Smooth dismiss gesture feedback
    func dismissProgress(progress: CGFloat) {
        if progress > 0.8 {
            impact(.light)
        }
    }

    /// Celebratory haptic sequence for special moments
    func celebration() {
        notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.impact(.light)
        }
    }

    /// Quick pulse for save/bookmark actions
    func bookmarkPulse() {
        impact(.rigid)
    }

    /// Smooth scroll snap feedback
    func scrollSnap() {
        impact(.soft)
    }

    /// Prepare all generators before intensive haptic usage
    func prepareForIntensiveUse() {
        prepareGenerators()
    }
}
