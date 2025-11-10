//
//  ImageCache.swift
//  Celestia
//
//  Created by Claude
//  High-performance image caching with memory and disk storage
//

import SwiftUI
import UIKit
import CryptoKit

@MainActor
class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // Cache settings
    private let maxMemoryCacheSize = 100 * 1024 * 1024 // 100 MB
    private let maxDiskCacheSize = 500 * 1024 * 1024 // 500 MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        // Setup memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory

        // Setup disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Clean old cache on init
        Task {
            await cleanExpiredCache()
        }
    }

    // MARK: - Public Methods

    func image(for key: String) -> UIImage? {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            return cachedImage
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Store in memory for faster access
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        return nil
    }

    func setImage(_ image: UIImage, for key: String) {
        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString)

        // Store on disk asynchronously
        Task {
            await saveToDisk(image: image, key: key)
        }
    }

    func removeImage(for key: String) {
        memoryCache.removeObject(forKey: key as NSString)

        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func getCacheSize() async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    // MARK: - Private Methods

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Update access date
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return image
    }

    private func saveToDisk(image: UIImage, key: String) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? data.write(to: fileURL)

        // Check if we need to clean cache
        let cacheSize = await getCacheSize()
        if cacheSize > maxDiskCacheSize {
            await cleanOldestCache()
        }
    }

    private func cleanExpiredCache() async {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let expirationDate = Date().addingTimeInterval(-maxCacheAge)

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modificationDate = resourceValues.contentModificationDate else {
                continue
            }

            if modificationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func cleanOldestCache() async {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }

        var files: [(url: URL, date: Date, size: Int64)] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = resourceValues.contentModificationDate,
                  let fileSize = resourceValues.fileSize else {
                continue
            }

            files.append((fileURL, modificationDate, Int64(fileSize)))
        }

        // Sort by modification date (oldest first)
        files.sort { $0.date < $1.date }

        var currentSize: Int64 = files.reduce(0) { $0 + $1.size }
        let targetSize = Int64(Double(maxDiskCacheSize) * 0.8) // Clean to 80% of max

        // Remove oldest files until we reach target size
        for file in files {
            if currentSize <= targetSize {
                break
            }

            try? fileManager.removeItem(at: file.url)
            currentSize -= file.size
        }
    }
}

// MARK: - String Extension for Hashing

extension String {
    func sha256() -> String {
        // Use CryptoKit for proper cryptographic hashing
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        let cacheKey = url.absoluteString

        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            return
        }

        // Load from network
        isLoading = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                if let downloadedImage = UIImage(data: data) {
                    await MainActor.run {
                        ImageCache.shared.setImage(downloadedImage, for: cacheKey)
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load image: \(error)")
            }
        }
    }
}

// Convenience initializer with default placeholder
extension CachedAsyncImage where Placeholder == Color {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { Color.gray.opacity(0.2) }
    }
}
