//
//  Extensions.swift
//  Celestia
//
//  Useful extensions throughout the app
//

import SwiftUI
import Foundation
import Combine
import FirebaseFirestore

// MARK: - Date Extensions

extension Date {
    // PERFORMANCE: Cached DateFormatters by style to avoid expensive recreation
    private static var cachedFormatters: [DateFormatter.Style: DateFormatter] = [:]
    private static let formatterLock = NSLock()

    private static func formatter(for style: DateFormatter.Style) -> DateFormatter {
        formatterLock.lock()
        defer { formatterLock.unlock() }

        if let cached = cachedFormatters[style] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .short
        cachedFormatters[style] = formatter
        return formatter
    }

    /// Returns a human-readable "time ago" string
    func timeAgo() -> String {
        let interval = Date().timeIntervalSince(self)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }

    /// Returns a short "time ago" string for compact display
    func timeAgoShort() -> String {
        let interval = Date().timeIntervalSince(self)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return "\(weeks)w"
        } else {
            return "1mo+"
        }
    }

    /// Format date for display (uses cached formatter for performance)
    func formatted(style: DateFormatter.Style = .medium) -> String {
        Self.formatter(for: style).string(from: self)
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}

// MARK: - String Extensions

extension String {
    /// NOTE: Email and password validation methods moved to ValidationHelper.swift
    /// Use the computed properties: .isValidEmail and .isValidPassword instead

    /// Truncate string to specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
    
    /// Remove extra whitespaces and newlines
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Capitalize first letter only
    func capitalizedFirst() -> String {
        guard !self.isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    /// Check if string contains only whitespace
    var isBlank: Bool {
        self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - View Extensions

extension View {
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Add placeholder to text fields
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    /// Apply gradient overlay
    func gradientOverlay(_ colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> some View {
        self.overlay(
            LinearGradient(
                colors: colors,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
    
    /// Add loading overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Add corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Custom Shapes

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - LinearGradient Extensions

extension LinearGradient {
    /// Primary brand gradient (purple to pink)
    static var brandPrimary: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Primary brand gradient (vertical orientation)
    static var brandPrimaryVertical: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Primary brand gradient (diagonal)
    static var brandPrimaryDiagonal: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Secondary gradient (purple to blue)
    static var brandSecondary: LinearGradient {
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Success gradient (green shades)
    static var success: LinearGradient {
        LinearGradient(
            colors: [Color.green.opacity(0.9), Color.green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Error gradient (red shades)
    static var error: LinearGradient {
        LinearGradient(
            colors: [Color.red.opacity(0.7), Color.orange.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Warning gradient (yellow/orange)
    static var warning: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Clear gradient (for transparent borders/backgrounds)
    static var clear: LinearGradient {
        LinearGradient(
            colors: [.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Array Extensions

extension Array {
    /// Remove duplicates while preserving order
    func removingDuplicates<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

extension Array where Element: Identifiable {
    /// Remove duplicates based on ID
    func removingDuplicates() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Double Extensions

extension Double {
    // PERFORMANCE: Cached NumberFormatters by locale to avoid expensive recreation
    private static var currencyFormatters: [Locale: NumberFormatter] = [:]
    private static let currencyFormatterLock = NSLock()

    private static func currencyFormatter(for locale: Locale) -> NumberFormatter {
        currencyFormatterLock.lock()
        defer { currencyFormatterLock.unlock() }

        if let cached = currencyFormatters[locale] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        currencyFormatters[locale] = formatter
        return formatter
    }

    /// Format as currency (uses cached formatter for performance)
    func asCurrency(locale: Locale = .current) -> String {
        Self.currencyFormatter(for: locale).string(from: NSNumber(value: self)) ?? "$\(self)"
    }
    
    /// Round to decimal places
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - Int Extensions

extension Int {
    /// Format as abbreviated number (1K, 1M, etc.)
    var abbreviated: String {
        let num = Double(self)
        let sign = num < 0 ? "-" : ""
        let absNum = abs(num)
        
        if absNum < 1000 {
            return "\(self)"
        } else if absNum < 1_000_000 {
            return String(format: "\(sign)%.1fK", absNum / 1000)
        } else if absNum < 1_000_000_000 {
            return String(format: "\(sign)%.1fM", absNum / 1_000_000)
        } else {
            return String(format: "\(sign)%.1fB", absNum / 1_000_000_000)
        }
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    /// Get app version
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// Get build number
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// Get app name
    var appName: String {
        infoDictionary?["CFBundleName"] as? String ?? "Celestia"
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Resize image to fit within specified size
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Compress image to target size in bytes
    func compressed(toMaxBytes maxBytes: Int) -> Data? {
        var compression: CGFloat = 1.0
        var data = self.jpegData(compressionQuality: compression)
        
        while let imageData = data, imageData.count > maxBytes && compression > 0 {
            compression -= 0.1
            data = self.jpegData(compressionQuality: compression)
        }
        
        return data
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for duration
    static func sleep(seconds: Double) async throws {
        try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    /// Save codable object
    func setCodable<T: Codable>(_ object: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(object) {
            set(data, forKey: key)
        }
    }
    
    /// Load codable object
    func codable<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Button Styles

/// Scale button style with tap animation
struct ScaleButtonStyle2: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Keyboard Height Publisher

extension View {
    /// Monitor keyboard height changes
    func keyboardHeight() -> AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
        
        return Publishers.Merge(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - URL Extensions

extension URL {
    /// Check if URL is valid and reachable
    var isReachable: Bool {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.scheme != nil && components.host != nil
    }
}

