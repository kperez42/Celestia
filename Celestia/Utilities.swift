//
//  Utilities.swift
//  Celestia
//
//  Created by Claude
//  General utility functions and helpers
//

import Foundation
import SwiftUI

// MARK: - Date Utilities

extension Date {
    // PERFORMANCE: Cache formatters - creating them is expensive
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    func timeAgoDisplay() -> String {
        let seconds = Date().timeIntervalSince(self)
        // Show "1 sec ago" minimum instead of "0 seconds ago"
        if seconds < 1 {
            return "1 sec ago"
        }
        return Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }

    func shortTimeAgo() -> String {
        let seconds = Date().timeIntervalSince(self)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)

        if seconds < 60 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else if days < 7 {
            return "\(days)d"
        } else {
            return Self.shortDateFormatter.string(from: self)
        }
    }

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
}

// MARK: - String Utilities

extension String {
    func initials() -> String {
        let components = self.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined()
    }
}

// MARK: - Array Utilities

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Number Formatting

extension Double {
    func formatted(decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

// MARK: - Distance Calculation

extension User {
    func distance(from otherUser: User) -> Double? {
        guard let lat1 = self.latitude, let lon1 = self.longitude,
              let lat2 = otherUser.latitude, let lon2 = otherUser.longitude else {
            return nil
        }

        return calculateDistance(
            lat1: lat1, lon1: lon1,
            lat2: lat2, lon2: lon2
        )
    }

    func distanceString(from otherUser: User) -> String {
        guard let distance = distance(from: otherUser) else {
            return "Unknown"
        }

        let km = distance
        if km < 1 {
            return "Less than 1 km away"
        } else if km < 10 {
            return "\(Int(km)) km away"
        } else {
            return "\(Int(km/10)*10)+ km away"
        }
    }
}

func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0 // Radius of Earth in kilometers

    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180

    let a = sin(dLat/2) * sin(dLat/2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon/2) * sin(dLon/2)

    let c = 2 * atan2(sqrt(a), sqrt(1-a))

    return R * c
}

// MARK: - Color Utilities

extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

// MARK: - View Utilities
// cardStyle() moved to DesignSystem.swift for consistency

// MARK: - Image Validation

enum ImageValidator {
    static let maxImageSize: Int = 10 * 1024 * 1024 // 10 MB
    static let supportedFormats = ["jpg", "jpeg", "png", "heic"]

    static func validate(_ data: Data) throws {
        guard data.count <= maxImageSize else {
            throw CelestiaError.imageTooBig
        }

        guard let image = UIImage(data: data) else {
            throw CelestiaError.invalidImageFormat
        }

        // Additional validation
        let maxDimension: CGFloat = 4096
        if image.size.width > maxDimension || image.size.height > maxDimension {
            throw CelestiaError.imageTooBig
        }
    }

    static func compress(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxSizeKB * 1024, compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        return imageData
    }
}

// MARK: - Debouncer

class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)

        if let workItem = workItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func cancel() {
        workItem?.cancel()
    }
}

// MARK: - Safe Area Insets

extension UIApplication {
    var safeAreaInsets: UIEdgeInsets {
        let scene = connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets ?? .zero
    }
}

// MARK: - App Version

struct AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var fullVersion: String {
        "\(version) (\(build))"
    }

    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Celestia"
    }
}

// MARK: - Profile Completion

extension User {
    var profileCompletionPercentage: Int {
        var completed = 0
        let total = 10

        if !fullName.isEmpty { completed += 1 }
        if !bio.isEmpty { completed += 1 }
        if !location.isEmpty { completed += 1 }
        if !interests.isEmpty { completed += 1 }
        if !languages.isEmpty { completed += 1 }
        if !photos.isEmpty { completed += 1 }
        if photos.count >= 3 { completed += 1 }
        if !profileImageURL.isEmpty { completed += 1 }
        if age >= 18 { completed += 1 }
        if !gender.isEmpty { completed += 1 }

        return (completed * 100) / total
    }

    var isProfileComplete: Bool {
        profileCompletionPercentage >= 70
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let userDidUpdate = Notification.Name("userDidUpdate")
    static let newMatchReceived = Notification.Name("newMatchReceived")
    static let newMessageReceived = Notification.Name("newMessageReceived")

    // Navigation notifications
    static let openChatWithUser = Notification.Name("OpenChatWithUser")
    static let navigateToMessages = Notification.Name("NavigateToMessages")
}

// MARK: - URL Schemes
// DeepLink is defined in DeepLinkRouter.swift

// MARK: - Preview Helpers

#if DEBUG
extension User {
    static var preview: User {
        User(
            id: "preview",
            email: "test@celestia.app",
            fullName: "Alex Johnson",
            age: 28,
            gender: "Male",
            lookingFor: "Female",
            bio: "Love hiking, coffee, and good conversations. Always up for an adventure!",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            languages: ["English", "Spanish"],
            interests: ["Travel", "Photography", "Hiking", "Coffee"],
            photos: ["photo1", "photo2", "photo3"],
            profileImageURL: "https://picsum.photos/400/500",
            isPremium: true,
            isVerified: true
        )
    }

    static var previews: [User] {
        [
            preview,
            User(
                email: "sarah@test.com",
                fullName: "Sarah Miller",
                age: 25,
                gender: "Female",
                lookingFor: "Male",
                bio: "Artist and dreamer",
                location: "Los Angeles",
                country: "USA"
            ),
            User(
                email: "mike@test.com",
                fullName: "Mike Chen",
                age: 30,
                gender: "Male",
                lookingFor: "Female",
                bio: "Tech enthusiast",
                location: "Seattle",
                country: "USA"
            )
        ]
    }
}
#endif
