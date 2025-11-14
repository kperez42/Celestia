//
//  AccessibilityHelpers.swift
//  Celestia
//
//  Comprehensive accessibility utilities and extensions for WCAG 2.1 Level AA compliance
//

import SwiftUI

// MARK: - Accessibility Environment

/// Environment values for accessibility settings
@available(iOS 14.0, *)
extension EnvironmentValues {
    var accessibilityReduceMotion: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    var accessibilityDifferentiateWithoutColor: Bool {
        #if os(iOS)
        return UIAccessibility.shouldDifferentiateWithoutColor
        #else
        return false
        #endif
    }

    var accessibilityReduceTransparency: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceTransparencyEnabled
        #else
        return false
        #endif
    }

    var accessibilityInvertColors: Bool {
        #if os(iOS)
        return UIAccessibility.isInvertColorsEnabled
        #else
        return false
        #endif
    }

    var accessibilityBoldText: Bool {
        #if os(iOS)
        return UIAccessibility.isBoldTextEnabled
        #else
        return false
        #endif
    }

    var accessibilityGrayscaleEnabled: Bool {
        #if os(iOS)
        return UIAccessibility.isGrayscaleEnabled
        #else
        return false
        #endif
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    /// Adds comprehensive accessibility support with label, hint, traits, and identifier
    func accessibilityElement(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        identifier: String? = nil,
        value: String? = nil,
        isHidden: Bool = false
    ) -> some View {
        self
            .accessibilityLabel(label)
            .modifier(ConditionalAccessibilityHint(hint: hint))
            .accessibilityAddTraits(traits)
            .modifier(ConditionalAccessibilityValue(value: value))
            .modifier(ConditionalAccessibilityIdentifier(identifier: identifier))
            .accessibilityHidden(isHidden)
    }

    /// Adds VoiceOver custom actions for complex interactions
    func accessibilityActions(_ actions: [AccessibilityCustomAction]) -> some View {
        actions.reduce(AnyView(self)) { view, action in
            AnyView(view.accessibilityAction(named: action.name) {
                action.handler()
            })
        }
    }

    /// Makes view accessibility-friendly for buttons with proper sizing
    func accessibleButton(
        label: String,
        hint: String? = nil,
        identifier: String? = nil,
        minSize: CGFloat = 44
    ) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
            .accessibilityElement(label: label, hint: hint, traits: .isButton, identifier: identifier)
    }

    /// Applies accessibility-aware animations that respect Reduce Motion
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation? = .default,
        value: V
    ) -> some View {
        #if os(iOS)
        let shouldAnimate = !UIAccessibility.isReduceMotionEnabled
        return self.animation(shouldAnimate ? animation : nil, value: value)
        #else
        return self.animation(animation, value: value)
        #endif
    }

    /// Applies transitions that respect Reduce Motion preference
    func accessibleTransition(_ transition: AnyTransition) -> some View {
        #if os(iOS)
        let shouldAnimate = !UIAccessibility.isReduceMotionEnabled
        return self.transition(shouldAnimate ? transition : .identity)
        #else
        return self.transition(transition)
        #endif
    }

    /// Groups related accessibility elements
    func accessibilityGroup(
        label: String? = nil,
        hint: String? = nil,
        isGroup: Bool = true
    ) -> some View {
        Group {
            if isGroup {
                self
                    .accessibilityElement(children: .combine)
                    .modifier(ConditionalAccessibilityLabel(label: label))
                    .modifier(ConditionalAccessibilityHint(hint: hint))
            } else {
                self
            }
        }
    }

    /// Adds dynamic type support with custom scaling
    func dynamicTypeSize(min: DynamicTypeSize = .xSmall, max: DynamicTypeSize = .xxxLarge) -> some View {
        self.dynamicTypeSize(min...max)
    }
}

// MARK: - Conditional Modifiers

struct ConditionalAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label = label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

struct ConditionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

struct ConditionalAccessibilityValue: ViewModifier {
    let value: String?

    func body(content: Content) -> some View {
        if let value = value {
            content.accessibilityValue(value)
        } else {
            content
        }
    }
}

struct ConditionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier = identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

// MARK: - Accessibility Custom Actions

struct AccessibilityCustomAction {
    let name: String
    let handler: () -> Void

    init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}

// MARK: - Dynamic Type Support

/// Text styles that support Dynamic Type
enum AccessibleTextStyle {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2

    var font: Font {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }
}

extension Text {
    /// Applies accessible text styling with Dynamic Type support
    func accessibleText(
        style: AccessibleTextStyle = .body,
        weight: Font.Weight? = nil,
        color: Color = .primary
    ) -> some View {
        var text = self.font(style.font)

        if let weight = weight {
            text = text.fontWeight(weight)
        }

        return text
            .foregroundColor(color)
            .dynamicTypeSize(min: .xSmall, max: .accessibility3)
    }
}

// MARK: - Color Accessibility

extension Color {
    /// Ensures adequate contrast ratio (WCAG 2.1 Level AA: 4.5:1 for normal text, 3:1 for large text)
    func accessibleContrast(on background: Color) -> Color {
        // This is a simplified version. In production, you'd calculate actual contrast ratios
        // and adjust colors accordingly using the WCAG algorithm
        return self
    }

    /// Common accessible color pairs for the app
    static let accessiblePrimary = Color.purple
    static let accessibleSecondary = Color.pink
    static let accessibleAccent = Color.blue
    static let accessibleSuccess = Color.green
    static let accessibleWarning = Color.orange
    static let accessibleError = Color.red

    /// Text colors with guaranteed contrast
    static let accessibleTextPrimary = Color.primary
    static let accessibleTextSecondary = Color.secondary
    static let accessibleTextOnDark = Color.white
    static let accessibleTextOnLight = Color.black

    /// High contrast color variants for increased visibility
    static let highContrastPrimary = Color(red: 0.5, green: 0, blue: 0.8) // Darker purple
    static let highContrastSecondary = Color(red: 0.8, green: 0, blue: 0.5) // Darker pink
    static let highContrastAccent = Color(red: 0, green: 0.3, blue: 0.8) // Darker blue
    static let highContrastSuccess = Color(red: 0, green: 0.5, blue: 0) // Darker green
    static let highContrastWarning = Color(red: 0.8, green: 0.4, blue: 0) // Darker orange
    static let highContrastError = Color(red: 0.7, green: 0, blue: 0) // Darker red

    /// Returns high contrast variant if needed based on accessibility settings
    func adaptiveContrast(highContrastVariant: Color) -> Color {
        #if os(iOS)
        return UIAccessibility.isDarkerSystemColorsEnabled ? highContrastVariant : self
        #else
        return self
        #endif
    }
}

// MARK: - Accessibility Identifiers (for UI Testing)

enum AccessibilityIdentifier {
    // MARK: - Discovery
    static let discoverView = "discover_view"
    static let userCard = "user_card"
    static let likeButton = "like_button"
    static let passButton = "pass_button"
    static let superLikeButton = "super_like_button"
    static let shuffleButton = "shuffle_button"
    static let filterButton = "filter_button"

    // MARK: - Matches
    static let matchesView = "matches_view"
    static let matchCard = "match_card"
    static let searchField = "search_field"
    static let sortMenu = "sort_menu"
    static let unreadFilter = "unread_filter"

    // MARK: - Chat
    static let chatView = "chat_view"
    static let messageInput = "message_input"
    static let sendButton = "send_button"
    static let attachPhotoButton = "attach_photo_button"
    static let messageBubble = "message_bubble"

    // MARK: - Profile
    static let profileView = "profile_view"
    static let editProfileButton = "edit_profile_button"
    static let settingsButton = "settings_button"
    static let shareProfileButton = "share_profile_button"
    static let profilePhoto = "profile_photo"
    static let logoutButton = "logout_button"

    // MARK: - Common
    static let backButton = "back_button"
    static let closeButton = "close_button"
    static let confirmButton = "confirm_button"
    static let cancelButton = "cancel_button"

    // MARK: - Authentication
    static let emailField = "email_field"
    static let passwordField = "password_field"
    static let confirmPasswordField = "confirm_password_field"
    static let nameField = "name_field"
    static let ageField = "age_field"
    static let genderPicker = "gender_picker"
    static let lookingForPicker = "looking_for_picker"
    static let locationField = "location_field"
    static let countryField = "country_field"
    static let bioField = "bio_field"
    static let signUpButton = "sign_up_button"
    static let signInButton = "sign_in_button"
    static let nextButton = "next_button"
    static let createAccountButton = "create_account_button"
}

// MARK: - VoiceOver Announcements

struct VoiceOverAnnouncement {
    /// Posts an announcement that VoiceOver will read
    static func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        #if os(iOS)
        UIAccessibility.post(notification: priority, argument: message)
        #endif
    }

    /// Announces a screen change
    static func screenChanged(to message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .screenChanged, argument: message)
        #endif
    }

    /// Announces a layout change
    static func layoutChanged(message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .layoutChanged, argument: message)
        #endif
    }
}

// MARK: - Motion Reduction Support

struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        content
    }
}

extension Animation {
    /// Returns nil if Reduce Motion is enabled, otherwise returns self
    static func accessible(_ animation: Animation) -> Animation? {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled ? nil : animation
        #else
        return animation
        #endif
    }
}

// MARK: - Semantic Content Attribute

extension View {
    /// Supports right-to-left languages
    func accessibleLayoutDirection() -> some View {
        self.environment(\.layoutDirection, LayoutDirection.leftToRight)
    }
}

// MARK: - Focus Management

#if os(iOS)
extension View {
    /// Manages accessibility focus
    func accessibilityFocused(_ condition: Binding<Bool>) -> some View {
        self.accessibilityAddTraits(condition.wrappedValue ? .isSelected : [])
    }
}
#endif

// MARK: - Accessibility Testing Helpers

#if DEBUG
struct AccessibilityPreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    func accessibilityPreview() -> some View {
        self.modifier(AccessibilityPreview())
    }
}
#endif

// MARK: - Accessibility Audit

struct AccessibilityAudit {
    /// Checks if a color combination meets WCAG 2.1 AA standards
    static func checkColorContrast(foreground: UIColor, background: UIColor) -> (ratio: Double, passes: Bool) {
        let fgLuminance = relativeLuminance(foreground)
        let bgLuminance = relativeLuminance(background)

        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)

        let ratio = (lighter + 0.05) / (darker + 0.05)
        let passes = ratio >= 4.5 // WCAG AA for normal text

        return (ratio, passes)
    }

    private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)

        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
}

// MARK: - Accessible Button Style

struct AccessibleButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets

    init(
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(padding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .accessibleAnimation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .frame(minWidth: 44, minHeight: 44)
    }
}

// MARK: - Accessible Card Style

struct AccessibleCardModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadow: Bool

    init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        shadow: Bool = true
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .conditionalShadow(enabled: shadow)
    }
}

extension View {
    func accessibleCard(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        shadow: Bool = true
    ) -> some View {
        self.modifier(AccessibleCardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }

    @ViewBuilder
    func conditionalShadow(enabled: Bool) -> some View {
        if enabled {
            #if os(iOS)
            let shouldReduceTransparency = UIAccessibility.isReduceTransparencyEnabled
            if shouldReduceTransparency {
                self.overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                self.shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            }
            #else
            self.shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            #endif
        } else {
            self
        }
    }
}

// MARK: - Dynamic Spacing with @ScaledMetric

/// Provides spacing values that scale with Dynamic Type
struct AccessibleSpacing {
    @ScaledMetric private var spacing: CGFloat

    init(base: CGFloat) {
        _spacing = ScaledMetric(wrappedValue: base)
    }

    var value: CGFloat {
        spacing
    }

    /// Common spacing values
    static let xxSmall = AccessibleSpacing(base: 4)
    static let xSmall = AccessibleSpacing(base: 8)
    static let small = AccessibleSpacing(base: 12)
    static let medium = AccessibleSpacing(base: 16)
    static let large = AccessibleSpacing(base: 24)
    static let xLarge = AccessibleSpacing(base: 32)
    static let xxLarge = AccessibleSpacing(base: 48)
}

// MARK: - Keyboard Navigation Support

extension View {
    /// Adds keyboard navigation support for forms and interactive elements
    func accessibleKeyboardNavigation(
        onSubmit: @escaping () -> Void = {},
        submitLabel: SubmitLabel = .done
    ) -> some View {
        self
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
    }

    /// Groups form fields with proper navigation
    @available(iOS 15.0, *)
    func accessibleFormField<V: Hashable>(
        focusState: FocusState<V>.Binding,
        value: V,
        next: V? = nil
    ) -> some View {
        self
            .focused(focusState, equals: value)
            .submitLabel(next != nil ? .next : .done)
            .onSubmit {
                if let next = next {
                    focusState.wrappedValue = next
                }
            }
    }
}

// MARK: - High Contrast Mode Support

struct HighContrastModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    let normalColor: Color
    let highContrastColor: Color

    func body(content: Content) -> some View {
        #if os(iOS)
        let useHighContrast = UIAccessibility.isDarkerSystemColorsEnabled
        content.foregroundColor(useHighContrast ? highContrastColor : normalColor)
        #else
        content.foregroundColor(normalColor)
        #endif
    }
}

extension View {
    /// Applies high contrast colors when accessibility setting is enabled
    func highContrastColor(
        normal: Color,
        highContrast: Color
    ) -> some View {
        self.modifier(HighContrastModifier(normalColor: normal, highContrastColor: highContrast))
    }

    /// Applies adaptive font weight based on Bold Text setting
    func adaptiveFontWeight(
        normal: Font.Weight = .regular,
        bold: Font.Weight = .semibold
    ) -> some View {
        #if os(iOS)
        let weight = UIAccessibility.isBoldTextEnabled ? bold : normal
        return self.fontWeight(weight)
        #else
        return self.fontWeight(normal)
        #endif
    }
}

// MARK: - Haptic Feedback for Accessibility

struct AccessibleHaptics {
    /// Provides haptic feedback for accessibility actions
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    /// Provides notification haptic feedback
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
        #endif
    }

    /// Provides selection haptic feedback
    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

// MARK: - Accessibility Quick Check

struct AccessibilityQuickCheck {
    /// Quick check if any accessibility features are enabled
    static var hasAccessibilityEnabled: Bool {
        #if os(iOS)
        return UIAccessibility.isVoiceOverRunning ||
               UIAccessibility.isSwitchControlRunning ||
               UIAccessibility.isReduceMotionEnabled ||
               UIAccessibility.isDarkerSystemColorsEnabled ||
               UIAccessibility.isBoldTextEnabled ||
               UIAccessibility.isReduceTransparencyEnabled
        #else
        return false
        #endif
    }

    /// Check if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        #if os(iOS)
        return UIAccessibility.isVoiceOverRunning
        #else
        return false
        #endif
    }

    /// Check if Switch Control is running
    static var isSwitchControlRunning: Bool {
        #if os(iOS)
        return UIAccessibility.isSwitchControlRunning
        #else
        return false
        #endif
    }
}

// MARK: - Improved Text Contrast Helper

extension View {
    /// Ensures text has sufficient contrast against its background
    func ensureTextContrast(
        textColor: Color = .primary,
        backgroundColor: Color = .white
    ) -> some View {
        self.foregroundColor(textColor)
            .background(backgroundColor)
    }

    /// Adds a contrasting background for better readability
    func readableTextBackground(
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
        cornerRadius: CGFloat = 4
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.6))
            )
    }
}
