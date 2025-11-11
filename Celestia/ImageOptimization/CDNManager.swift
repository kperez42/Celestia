//
//  CDNManager.swift
//  Celestia
//
//  Manages CDN integration for optimized image delivery
//  Supports CloudFront, Cloudflare, and custom CDNs
//

import Foundation

// MARK: - CDN Manager

class CDNManager {

    // MARK: - Singleton

    static let shared = CDNManager()

    // MARK: - Properties

    private var cdnProvider: CDNProvider = .cloudFront
    private var cdnBaseURL: String = ""

    // MARK: - CDN Provider

    enum CDNProvider {
        case cloudFront
        case cloudflare
        case custom(baseURL: String)

        var transformationSupport: Bool {
            switch self {
            case .cloudFront, .cloudflare:
                return true
            case .custom:
                return false
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        Logger.shared.info("CDNManager initialized with provider: \(cdnProvider)", category: .general)
    }

    // MARK: - Configuration

    func configure(provider: CDNProvider, baseURL: String) {
        self.cdnProvider = provider
        self.cdnBaseURL = baseURL

        Logger.shared.info("CDN configured: \(provider) at \(baseURL)", category: .general)
    }

    private func loadConfiguration() {
        // Load from configuration file or environment
        // For now, use defaults
        #if DEBUG
        cdnBaseURL = "https://dev-cdn.celestia.app"
        #else
        cdnBaseURL = "https://cdn.celestia.app"
        #endif
    }

    // MARK: - URL Generation

    /// Generate CDN URL for image
    func url(
        for imageKey: String,
        size: ImageOptimizer.ImageSize,
        format: ImageFormat = .jpeg
    ) -> URL? {
        var urlString = cdnBaseURL

        switch cdnProvider {
        case .cloudFront:
            urlString += cloudFrontPath(imageKey: imageKey, size: size, format: format)

        case .cloudflare:
            urlString += cloudflarePath(imageKey: imageKey, size: size, format: format)

        case .custom:
            urlString += "/\(imageKey)"
        }

        return URL(string: urlString)
    }

    /// Generate multiple CDN URLs for different resolutions
    func urls(for imageKey: String, format: ImageFormat = .jpeg) -> [ImageOptimizer.ImageSize: URL] {
        var urls: [ImageOptimizer.ImageSize: URL] = [:]

        for size in [ImageOptimizer.ImageSize.thumbnail, .small, .medium, .large] {
            if let url = url(for: imageKey, size: size, format: format) {
                urls[size] = url
            }
        }

        return urls
    }

    // MARK: - CloudFront Integration

    private func cloudFrontPath(imageKey: String, size: ImageOptimizer.ImageSize, format: ImageFormat) -> String {
        // CloudFront with Lambda@Edge for on-the-fly resizing
        let width = Int(size.maxDimension)
        let quality = Int(size.compressionQuality * 100)

        return "/images/\(imageKey)?w=\(width)&q=\(quality)&f=\(format.rawValue)"
    }

    // MARK: - Cloudflare Integration

    private func cloudflarePath(imageKey: String, size: ImageOptimizer.ImageSize, format: ImageFormat) -> String {
        // Cloudflare Images API
        let width = Int(size.maxDimension)

        return "/cdn-cgi/image/width=\(width),format=\(format.rawValue),quality=\(Int(size.compressionQuality * 100))/\(imageKey)"
    }

    // MARK: - Image Key Generation

    /// Generate unique image key for storage
    func generateImageKey(userId: String, type: ImageType, index: Int = 0) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)

        return "\(type.rawValue)/\(userId)/\(timestamp)_\(uuid)_\(index)"
    }

    // MARK: - Cache Control

    /// Generate cache control headers
    func cacheControlHeaders(for size: ImageOptimizer.ImageSize) -> [String: String] {
        let maxAge: Int

        switch size {
        case .thumbnail, .small:
            maxAge = 86400 * 30 // 30 days
        case .medium:
            maxAge = 86400 * 14 // 14 days
        case .large:
            maxAge = 86400 * 7 // 7 days
        case .original:
            maxAge = 86400 * 365 // 1 year
        }

        return [
            "Cache-Control": "public, max-age=\(maxAge), immutable",
            "Content-Type": "image/jpeg"
        ]
    }

    // MARK: - Purge Cache

    /// Purge image from CDN cache
    func purgeCache(imageKey: String) async throws {
        Logger.shared.info("Purging cache for: \(imageKey)", category: .general)

        switch cdnProvider {
        case .cloudFront:
            try await purgeCloudFrontCache(imageKey: imageKey)

        case .cloudflare:
            try await purgeCloudflareCache(imageKey: imageKey)

        case .custom:
            Logger.shared.warning("Cache purge not supported for custom CDN", category: .general)
        }
    }

    private func purgeCloudFrontCache(imageKey: String) async throws {
        // CloudFront invalidation API call
        // TODO: Implement CloudFront invalidation
        Logger.shared.info("CloudFront cache purge: \(imageKey)", category: .general)
    }

    private func purgeCloudflareCache(imageKey: String) async throws {
        // Cloudflare purge API call
        // TODO: Implement Cloudflare purge
        Logger.shared.info("Cloudflare cache purge: \(imageKey)", category: .general)
    }

    // MARK: - Bandwidth Optimization

    /// Get optimal image URL based on network conditions
    func optimalURL(
        for imageKey: String,
        networkType: NetworkType,
        screenSize: CGSize
    ) -> URL? {
        let size: ImageOptimizer.ImageSize

        switch networkType {
        case .wifi, .ethernet:
            // High-speed: use larger images
            size = screenSize.width > 750 ? .large : .medium

        case .cellular:
            // Cellular: optimize for data usage
            size = screenSize.width > 375 ? .medium : .small

        case .slow:
            // Slow connection: use smaller images
            size = .small

        case .offline:
            // Offline: rely on cache only
            return nil
        }

        return url(for: imageKey, size: size)
    }
}

// MARK: - Supporting Types

enum ImageFormat: String {
    case jpeg = "jpg"
    case webp = "webp"
    case png = "png"
    case avif = "avif"
}

enum ImageType: String {
    case profile = "profiles"
    case photo = "photos"
    case thumbnail = "thumbnails"
    case cover = "covers"
}

enum NetworkType {
    case wifi
    case cellular
    case ethernet
    case slow
    case offline
}

// MARK: - CDN Configuration

struct CDNConfiguration: Codable {
    let provider: String
    let baseURL: String
    let apiKey: String?
    let distributionId: String?

    static func load() -> CDNConfiguration? {
        // Load from configuration file
        guard let url = Bundle.main.url(forResource: "CDNConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(CDNConfiguration.self, from: data) else {
            return nil
        }

        return config
    }
}
