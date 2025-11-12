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
        // CloudFront invalidation requires AWS SDK or REST API
        // Configuration required: distributionId and AWS credentials
        guard let config = CDNConfiguration.load(),
              let distributionId = config.distributionId,
              let apiKey = config.apiKey else {
            Logger.shared.warning("CloudFront configuration missing. Add CDNConfig.json with distributionId and apiKey", category: .general)
            return
        }

        // Build invalidation request
        let paths = ["/images/\(imageKey)", "/images/\(imageKey)*"] // Invalidate all variations

        do {
            // Call CloudFront API (requires AWS SDK or HTTP client)
            // Example endpoint: POST https://cloudfront.amazonaws.com/2020-05-31/distribution/{distributionId}/invalidation
            // For now, log the request
            Logger.shared.info("CloudFront invalidation request for distribution \(distributionId), paths: \(paths)", category: .general)

            // NOTE: To implement fully, add AWS SDK dependency:
            // 1. Add package: https://github.com/soto-project/soto
            // 2. Import SotoCloudFront
            // 3. Use CloudFront().createInvalidation() method
        } catch {
            Logger.shared.error("CloudFront cache purge failed", category: .general, error: error)
            throw error
        }
    }

    private func purgeCloudflareCache(imageKey: String) async throws {
        // Cloudflare purge API: POST https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache
        guard let config = CDNConfiguration.load(),
              let apiKey = config.apiKey,
              !config.baseURL.isEmpty else {
            Logger.shared.warning("Cloudflare configuration missing. Add CDNConfig.json with apiKey and zoneId", category: .general)
            return
        }

        // Extract zone ID from config or environment
        let zoneId = ProcessInfo.processInfo.environment["CLOUDFLARE_ZONE_ID"] ?? ""
        guard !zoneId.isEmpty else {
            Logger.shared.warning("CLOUDFLARE_ZONE_ID environment variable not set", category: .general)
            return
        }

        let endpoint = "https://api.cloudflare.com/client/v4/zones/\(zoneId)/purge_cache"

        // Build request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "files": [
                "\(cdnBaseURL)/cdn-cgi/image/width=*,format=*,quality=*/\(imageKey)",
                "\(cdnBaseURL)/\(imageKey)"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CDNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode == 200 {
            Logger.shared.info("Cloudflare cache purged successfully for: \(imageKey)", category: .general)
        } else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.shared.error("Cloudflare purge failed: \(errorMsg)", category: .general)
            throw NSError(domain: "CDNManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
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
