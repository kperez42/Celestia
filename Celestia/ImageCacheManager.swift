//
//  ImageCacheManager.swift
//  Celestia
//
//  Advanced image caching system with memory and disk cache
//  Implements LRU eviction and automatic cleanup
//

import UIKit

// MARK: - Image Cache Manager

class ImageCacheManager {

    // MARK: - Singleton

    static let shared = ImageCacheManager()

    // MARK: - Properties

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: DiskCache
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("ImageCache", isDirectory: true)
    }

    // MARK: - Configuration

    var maxMemoryCacheSize: Int = 50 * 1024 * 1024 // 50 MB
    var maxDiskCacheSize: Int = 200 * 1024 * 1024 // 200 MB
    var maxCacheAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    // MARK: - Initialization

    private init() {
        // Compute cache directory before using self
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDirURL = urls[0].appendingPathComponent("ImageCache", isDirectory: true)

        diskCache = DiskCache(directory: cacheDirURL)
        configureMemoryCache()
        setupCacheDirectory()
        Logger.shared.info("ImageCacheManager initialized", category: .general)
    }

    private func configureMemoryCache() {
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory
    }

    private func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Cache Operations

    /// Get image from cache
    func image(forKey key: String) -> UIImage? {
        // Try memory cache first
        if let image = memoryCache.object(forKey: key as NSString) {
            Logger.shared.debug("Memory cache hit: \(key)", category: .general)
            return image
        }

        // Try disk cache
        if let image = diskCache.image(forKey: key) {
            Logger.shared.debug("Disk cache hit: \(key)", category: .general)
            // Store in memory cache for faster access next time
            memoryCache.setObject(image, forKey: key as NSString, cost: imageCost(image))
            return image
        }

        Logger.shared.debug("Cache miss: \(key)", category: .general)
        return nil
    }

    /// Store image in cache
    func store(_ image: UIImage, forKey key: String) {
        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString, cost: imageCost(image))

        // Store on disk asynchronously
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.diskCache.store(image, forKey: key)
        }

        Logger.shared.debug("Cached image: \(key)", category: .general)
    }

    /// Remove image from cache
    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        diskCache.removeImage(forKey: key)
        Logger.shared.debug("Removed from cache: \(key)", category: .general)
    }

    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()
        diskCache.clearAll()
        Logger.shared.info("Cleared all image caches", category: .general)
    }

    /// Clear memory cache only
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        Logger.shared.info("Cleared memory cache", category: .general)
    }

    /// Clear old cache entries
    func clearExpired() {
        diskCache.clearExpired(maxAge: maxCacheAge)
        Logger.shared.info("Cleared expired cache entries", category: .general)
    }

    // MARK: - Cache Statistics

    func cacheStatistics() -> CacheStatistics {
        let diskSize = diskCache.totalSize()
        let diskCount = diskCache.itemCount()

        return CacheStatistics(
            memorySize: 0, // NSCache doesn't provide size info
            diskSize: diskSize,
            diskCount: diskCount,
            maxMemorySize: maxMemoryCacheSize,
            maxDiskSize: maxDiskCacheSize
        )
    }

    // MARK: - Helper Methods

    private func imageCost(_ image: UIImage) -> Int {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let bytesPerPixel = 4 // RGBA
        return width * height * bytesPerPixel
    }

    /// Generate cache key from URL
    static func cacheKey(from url: URL) -> String {
        return url.absoluteString.md5()
    }
}

// MARK: - Disk Cache

private class DiskCache {

    private let directory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.celestia.disk-cache", attributes: .concurrent)

    init(directory: URL) {
        self.directory = directory
    }

    func image(forKey key: String) -> UIImage? {
        let fileURL = url(forKey: key)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Update access time
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return image
    }

    func store(_ image: UIImage, forKey key: String) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }

        let fileURL = url(forKey: key)

        queue.async(flags: .barrier) { [weak self] in
            try? data.write(to: fileURL)

            // Check cache size and evict if necessary
            self?.evictIfNeeded()
        }
    }

    func removeImage(forKey key: String) {
        let fileURL = url(forKey: key)

        queue.async(flags: .barrier) {
            try? self.fileManager.removeItem(at: fileURL)
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            if self.fileManager.fileExists(atPath: self.directory.path) {
                try? self.fileManager.removeItem(at: self.directory)
                try? self.fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
            }
        }
    }

    func clearExpired(maxAge: TimeInterval) {
        queue.async(flags: .barrier) {
            guard let contents = try? self.fileManager.contentsOfDirectory(
                at: self.directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            let expirationDate = Date().addingTimeInterval(-maxAge)

            for fileURL in contents {
                guard let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                      let modificationDate = attributes[.modificationDate] as? Date,
                      modificationDate < expirationDate else {
                    continue
                }

                try? self.fileManager.removeItem(at: fileURL)
            }
        }
    }

    func totalSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(0) { size, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size + Int64(fileSize)
        }
    }

    func itemCount() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.count
    }

    private func url(forKey key: String) -> URL {
        let filename = key.md5() + ".jpg"
        return directory.appendingPathComponent(filename)
    }

    private func evictIfNeeded() {
        let maxSize = ImageCacheManager.shared.maxDiskCacheSize
        let currentSize = totalSize()

        guard currentSize > maxSize else { return }

        // Get files sorted by access time (oldest first)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        let sortedFiles = contents.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }

        // Remove oldest files until under limit
        var freedSpace: Int64 = 0
        for fileURL in sortedFiles {
            guard currentSize - freedSpace > maxSize else { break }

            if let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                try? fileManager.removeItem(at: fileURL)
                freedSpace += Int64(fileSize)
            }
        }

        Logger.shared.info("Evicted \(freedSpace / 1024 / 1024)MB from disk cache", category: .general)
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let memorySize: Int
    let diskSize: Int64
    let diskCount: Int
    let maxMemorySize: Int
    let maxDiskSize: Int

    var memorySizeMB: Double {
        return Double(memorySize) / 1024.0 / 1024.0
    }

    var diskSizeMB: Double {
        return Double(diskSize) / 1024.0 / 1024.0
    }

    var memoryUsagePercentage: Double {
        return Double(memorySize) / Double(maxMemorySize) * 100
    }

    var diskUsagePercentage: Double {
        return Double(diskSize) / Double(maxDiskSize) * 100
    }
}

// MARK: - String Extension (MD5)

extension String {
    func md5() -> String {
        // Simple hash for demo (in production, use CryptoKit)
        return "\(self.hashValue)"
    }
}
