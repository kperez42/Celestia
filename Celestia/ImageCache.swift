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

// MARK: - Image Load Priority

/// Priority levels for image loading - higher priority loads faster
enum ImageLoadPriority {
    case low        // Prefetch, background loading
    case normal     // Default card loading
    case high       // User interaction (tapped card)
    case immediate  // Full screen viewer, current photo

    var taskPriority: TaskPriority {
        switch self {
        case .low: return .utility
        case .normal: return .medium
        case .high: return .userInitiated
        case .immediate: return .high
        }
    }
}

@MainActor
class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // PERFORMANCE: Adaptive cache settings based on device memory
    private let maxMemoryCacheSize: Int
    private let maxDiskCacheSize: Int
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // Memory pressure tracking
    private var isUnderMemoryPressure = false
    private var memoryWarningCount = 0

    // MEMORY LEAK FIX: Store observer token for proper cleanup
    private var memoryWarningObserver: NSObjectProtocol?

    private init() {
        // PERFORMANCE: Adaptive cache sizes based on available device memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = Double(physicalMemory) / 1_073_741_824.0 // Convert to GB

        // Adjust cache sizes based on device memory
        if memoryInGB < 2.0 {
            // Low memory device (e.g., iPhone 6s, SE 1st gen) - 1GB RAM
            maxMemoryCacheSize = 30 * 1024 * 1024 // 30 MB
            maxDiskCacheSize = 200 * 1024 * 1024 // 200 MB
        } else if memoryInGB < 3.0 {
            // Mid-range device (e.g., iPhone 8, X) - 2GB RAM
            maxMemoryCacheSize = 50 * 1024 * 1024 // 50 MB
            maxDiskCacheSize = 300 * 1024 * 1024 // 300 MB
        } else {
            // High-end device (e.g., iPhone 11+) - 3GB+ RAM
            maxMemoryCacheSize = 100 * 1024 * 1024 // 100 MB
            maxDiskCacheSize = 500 * 1024 * 1024 // 500 MB
        }

        // Setup memory cache with adaptive limits
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory

        // Setup disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        // SAFETY: Safely unwrap with fallback to temp directory
        if let cachesPath = paths.first {
            cacheDirectory = cachesPath.appendingPathComponent("ImageCache")
        } else {
            // Fallback to temp directory if caches directory is unavailable
            cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("ImageCache")
        }

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // PERFORMANCE: Register for memory warning notifications
        // MEMORY LEAK FIX: Store observer token for proper cleanup in deinit
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }

        // Clean old cache on init (in background to not block startup)
        Task.detached(priority: .utility) {
            await self.cleanExpiredCache()
        }

        Logger.shared.info(
            "ImageCache initialized (Memory: \(maxMemoryCacheSize / 1024 / 1024)MB, Disk: \(maxDiskCacheSize / 1024 / 1024)MB)",
            category: .storage
        )
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
        // PERFORMANCE: Skip memory cache if under memory pressure
        if !isUnderMemoryPressure {
            memoryCache.setObject(image, forKey: key as NSString)
        }

        // Store on disk asynchronously
        Task {
            await saveToDisk(image: image, key: key)
        }
    }

    /// Store raw image data directly without re-encoding (preserves original quality)
    func setImageData(_ data: Data, for key: String) {
        // Decode with high quality settings
        if let image = Self.decodeImageWithHighQuality(from: data) {
            if !isUnderMemoryPressure {
                memoryCache.setObject(image, forKey: key as NSString)
            }
        }

        // Store original data on disk (no re-encoding = no quality loss)
        Task {
            await saveDataToDisk(data: data, key: key)
        }
    }

    /// High-quality image decoding using ImageIO to prevent automatic downsampling
    /// Includes preparation for display and optional sharpening for crisp rendering
    static func decodeImageWithHighQuality(from data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldAllowFloat: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailFromImageAlways: false  // Don't create thumbnail, use full image
              ] as CFDictionary) else {
            // Fallback to standard UIImage decoding
            return UIImage(data: data)
        }

        // Create UIImage at native scale for Retina displays
        let scale = UIScreen.main.scale
        let image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)

        // iOS 15+: Prepare image for display (optimizes for current screen)
        if #available(iOS 15.0, *) {
            return image.preparingForDisplay() ?? image
        }

        return image
    }

    /// Apply subtle sharpening to enhance image clarity (for card display)
    static func sharpenImage(_ image: UIImage, intensity: Float = 0.4) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        // Use unsharp mask for natural-looking sharpness
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)  // Subtle sharpening
        filter.setValue(2.5, forKey: kCIInputRadiusKey)  // Sharpening radius

        guard let outputImage = filter.outputImage else { return image }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Decode and prepare image for crisp card display
    static func decodeForCardDisplay(from data: Data) -> UIImage? {
        guard let image = decodeImageWithHighQuality(from: data) else { return nil }

        // Apply subtle sharpening for crisp card appearance
        return sharpenImage(image, intensity: 0.3) ?? image
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

    // MARK: - In-Flight Request Deduplication

    /// Track in-flight requests to prevent duplicate network calls
    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]

    /// PERFORMANCE: High-priority URLSession for immediate loads
    private lazy var highPrioritySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.networkServiceType = .responsiveData
        return URLSession(configuration: config)
    }()

    /// Load image with deduplication - prevents multiple network requests for same URL
    /// PERFORMANCE: Supports priority levels for faster user-initiated loads
    /// QUALITY: Uses high-quality decoding and preserves original data without re-encoding
    func loadImageAsync(for url: URL, priority: ImageLoadPriority = .normal) async -> UIImage? {
        let cacheKey = url.absoluteString

        // Check cache first
        if let cachedImage = image(for: cacheKey) {
            return cachedImage
        }

        // Check if there's already an in-flight request for this URL
        if let existingTask = inFlightRequests[cacheKey] {
            return await existingTask.value
        }

        // Create new task for this request with appropriate priority
        let task = Task<UIImage?, Never>(priority: priority.taskPriority) {
            do {
                // Use high-priority session for immediate/high priority requests
                let session = (priority == .immediate || priority == .high) ? highPrioritySession : URLSession.shared
                let (data, _) = try await session.data(from: url)

                guard !Task.isCancelled else { return nil }

                // QUALITY: Use high-quality decoding to prevent downsampling
                if let downloadedImage = Self.decodeImageWithHighQuality(from: data) {
                    // QUALITY: Save raw data without re-encoding to preserve original quality
                    setImageData(data, for: cacheKey)
                    return downloadedImage
                }
            } catch {
                Logger.shared.error("Failed to load image: \(url.absoluteString)", category: .storage, error: error)
            }
            return nil
        }

        inFlightRequests[cacheKey] = task
        let result = await task.value
        inFlightRequests.removeValue(forKey: cacheKey)

        return result
    }

    // MARK: - Image Prefetching

    /// Prefetch images for smooth scrolling - call with upcoming user photo URLs
    func prefetchImages(urls: [String]) {
        for urlString in urls {
            guard let url = URL(string: urlString), !urlString.isEmpty else { continue }

            let cacheKey = url.absoluteString

            // Skip if already cached
            if image(for: cacheKey) != nil { continue }

            // Skip if already loading
            if inFlightRequests[cacheKey] != nil { continue }

            // Start prefetch with low priority
            Task.detached(priority: .utility) {
                _ = await self.loadImageAsync(for: url, priority: .low)
            }
        }
    }

    /// Prefetch images for a list of users
    func prefetchUserImages(users: [User]) {
        var urls: [String] = []
        for user in users {
            // Prefetch first photo or profile image
            if let firstPhoto = user.photos.first, !firstPhoto.isEmpty {
                urls.append(firstPhoto)
            } else if !user.profileImageURL.isEmpty {
                urls.append(user.profileImageURL)
            }
        }
        prefetchImages(urls: urls)
    }

    // MARK: - High Priority Prefetching (User Interaction)

    /// PERFORMANCE: Immediately prefetch all photos for a user when they tap on a card
    /// This ensures photos are ready before the gallery opens
    func prefetchUserPhotosHighPriority(user: User) {
        // Collect all photo URLs
        var photoURLs: [String] = user.photos.filter { !$0.isEmpty }
        if photoURLs.isEmpty && !user.profileImageURL.isEmpty {
            photoURLs = [user.profileImageURL]
        }

        Logger.shared.debug("High-priority prefetching \(photoURLs.count) photos for \(user.fullName)", category: .storage)

        // PERFORMANCE: Load ALL photos with immediate priority for instant gallery opening
        // This ensures when user taps camera icon, all photos are already cached
        for urlString in photoURLs {
            guard let url = URL(string: urlString) else { continue }

            let cacheKey = url.absoluteString

            // Skip if already cached
            if image(for: cacheKey) != nil { continue }

            // ALL images get immediate priority to eliminate white screens in photo gallery
            let priority: ImageLoadPriority = .immediate

            Task(priority: priority.taskPriority) {
                _ = await self.loadImageAsync(for: url, priority: priority)
            }
        }
    }

    /// PERFORMANCE: Prefetch adjacent images in a gallery for smooth swiping
    /// Call this when the user is viewing a photo to preload neighbors
    func prefetchAdjacentPhotos(photos: [String], currentIndex: Int) {
        // Prefetch next 2 and previous 1 photos with high priority
        let indicesToPrefetch = [
            currentIndex - 1,
            currentIndex + 1,
            currentIndex + 2
        ].filter { $0 >= 0 && $0 < photos.count && $0 != currentIndex }

        for index in indicesToPrefetch {
            let urlString = photos[index]
            guard !urlString.isEmpty, let url = URL(string: urlString) else { continue }

            let cacheKey = url.absoluteString
            if image(for: cacheKey) != nil { continue }

            // Adjacent photos get high priority
            Task(priority: .userInitiated) {
                _ = await self.loadImageAsync(for: url, priority: .high)
            }
        }
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

    // MARK: - Memory Pressure Management

    /// Handle memory warning by aggressively clearing caches
    private func handleMemoryWarning() async {
        memoryWarningCount += 1
        isUnderMemoryPressure = true

        Logger.shared.warning(
            "Memory warning received (count: \(memoryWarningCount)) - purging image caches",
            category: .storage
        )

        // Immediately clear memory cache
        memoryCache.removeAllObjects()

        // If multiple warnings, also clear disk cache
        if memoryWarningCount > 2 {
            Logger.shared.warning("Multiple memory warnings - clearing disk cache", category: .storage)
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            memoryWarningCount = 0 // Reset counter after disk clear
        }

        // Reset pressure flag after a delay
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            await MainActor.run {
                isUnderMemoryPressure = false
            }
        }
    }

    /// Get current cache statistics
    func getCacheStatistics() async -> CacheStatistics {
        let diskSize = await getCacheSize()
        let memoryCount = memoryCache.countLimit
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        return CacheStatistics(
            diskCacheSize: diskSize,
            maxDiskCacheSize: Int64(maxDiskCacheSize),
            memoryCacheCount: memoryCount,
            maxMemoryCacheSize: maxMemoryCacheSize,
            isUnderMemoryPressure: isUnderMemoryPressure,
            memoryWarningCount: memoryWarningCount,
            deviceMemoryGB: Double(physicalMemory) / 1_073_741_824.0
        )
    }

    struct CacheStatistics {
        let diskCacheSize: Int64
        let maxDiskCacheSize: Int64
        let memoryCacheCount: Int
        let maxMemoryCacheSize: Int
        let isUnderMemoryPressure: Bool
        let memoryWarningCount: Int
        let deviceMemoryGB: Double

        var diskUsagePercentage: Double {
            return Double(diskCacheSize) / Double(maxDiskCacheSize) * 100.0
        }
    }

    // MARK: - Private Methods

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        // QUALITY: Use high-quality decoding to prevent downsampling
        guard let image = Self.decodeImageWithHighQuality(from: data) else {
            return nil
        }

        // Update access date
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return image
    }

    private func saveToDisk(image: UIImage, key: String) async {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return } // High quality cache for sharp images

        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? data.write(to: fileURL)

        // Check if we need to clean cache
        let cacheSize = await getCacheSize()
        if cacheSize > maxDiskCacheSize {
            await cleanOldestCache()
        }
    }

    /// Save raw image data directly to disk (preserves original quality - no re-encoding)
    private func saveDataToDisk(data: Data, key: String) async {
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

    // MEMORY LEAK FIX: Cleanup observer to prevent memory accumulation
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        Logger.shared.debug("ImageCache deinitialized and observer removed", category: .storage)
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

/// High-performance cached async image with memory and disk caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var retryCount = 0
    // PERFORMANCE FIX: Store task for cancellation when view disappears
    @State private var loadTask: Task<Void, Never>?
    // PERFORMANCE: Track if we've checked cache to avoid re-checking
    @State private var hasCheckedCache = false
    // SMOOTH TRANSITION: Crossfade animation states
    @State private var imageOpacity: Double = 1.0
    @State private var previousImage: UIImage?
    @State private var previousImageOpacity: Double = 0
    @State private var currentURL: URL?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder

        // PERFORMANCE: Check cache immediately on init for instant display
        if let url = url {
            let cacheKey = url.absoluteString
            if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                _image = State(initialValue: cachedImage)
                _hasCheckedCache = State(initialValue: true)
                _imageOpacity = State(initialValue: 1.0)
                _currentURL = State(initialValue: url)
            }
        }
    }

    var body: some View {
        ZStack {
            // SMOOTH TRANSITION: Show previous image during crossfade
            if let previousImage = previousImage {
                content(Image(uiImage: previousImage))
                    .opacity(previousImageOpacity)
            }

            if let image = image {
                content(Image(uiImage: image))
                    .opacity(imageOpacity)
            } else if loadError != nil {
                // Error state with retry button
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        retryCount += 1
                        loadError = nil
                        loadImage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2))
            } else {
                placeholder()
                    .onAppear {
                        // Only load if we haven't checked cache yet or need to fetch
                        if !hasCheckedCache || (image == nil && !isLoading) {
                            loadImage()
                        }
                    }
            }
        }
        // PERFORMANCE FIX: Cancel image loading when view disappears
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        // SMOOTH TRANSITION: Detect URL changes and reload with crossfade
        .onChange(of: url) { oldURL, newURL in
            guard newURL != currentURL else { return }

            // Store current image for crossfade
            if let currentImage = image {
                previousImage = currentImage
                previousImageOpacity = 1.0
            }

            // Reset state for new image
            currentURL = newURL
            image = nil
            imageOpacity = 0
            loadError = nil
            hasCheckedCache = false
            loadTask?.cancel()

            // Check if new image is already cached (instant display)
            if let newURL = newURL {
                let cacheKey = newURL.absoluteString
                if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                    // Instant crossfade for cached images
                    image = cachedImage
                    withAnimation(.easeOut(duration: 0.2)) {
                        imageOpacity = 1.0
                        previousImageOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.previousImage = nil
                    }
                    hasCheckedCache = true
                    return
                }
            }

            // Load new image from network
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        let cacheKey = url.absoluteString
        hasCheckedCache = true
        currentURL = url

        // Check cache first (double-check in case init didn't catch it)
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            // Smooth crossfade from previous image
            withAnimation(.easeOut(duration: 0.2)) {
                self.imageOpacity = 1.0
                self.previousImageOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.previousImage = nil
            }
            return
        }

        // Cancel previous task if any
        loadTask?.cancel()

        // Load from network
        isLoading = true
        loadError = nil

        loadTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                guard !Task.isCancelled else {
                    await MainActor.run { self.isLoading = false }
                    return
                }

                // QUALITY: Use high-quality decoding to prevent downsampling
                if let downloadedImage = ImageCache.decodeImageWithHighQuality(from: data) {
                    await MainActor.run {
                        // QUALITY: Save raw data without re-encoding
                        ImageCache.shared.setImageData(data, for: cacheKey)
                        self.image = downloadedImage
                        self.isLoading = false
                        // Smooth crossfade animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            self.imageOpacity = 1.0
                            self.previousImageOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self.previousImage = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadError = NSError(domain: "ImageCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                }
            } catch {
                guard !Task.isCancelled else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                await MainActor.run {
                    self.isLoading = false
                    self.loadError = error
                }
                Logger.shared.error("Failed to load image from \(url.absoluteString)", category: .storage, error: error)
            }
        }
    }
}

// Convenience initializer with default placeholder - NO loading animation for cleaner look
extension CachedAsyncImage where Placeholder == EmptyView {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { EmptyView() }

        // PERFORMANCE: Check cache immediately on init for instant display
        if let url = url {
            let cacheKey = url.absoluteString
            if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                _image = State(initialValue: cachedImage)
                _hasCheckedCache = State(initialValue: true)
                _imageOpacity = State(initialValue: 1.0)
                _currentURL = State(initialValue: url)
            }
        }
    }
}

// MARK: - Profile Image Variant

/// Cached async image optimized for profile pictures (circular)
struct CachedProfileImage: View {
    let url: URL?
    let size: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var retryCount = 0
    // PERFORMANCE FIX: Store task for cancellation when view disappears
    @State private var loadTask: Task<Void, Never>?
    // PERFORMANCE: Track if we've checked cache to avoid re-checking
    @State private var hasCheckedCache = false
    // SMOOTH TRANSITION: Crossfade animation states
    @State private var imageOpacity: Double = 1.0
    @State private var previousImage: UIImage?
    @State private var previousImageOpacity: Double = 0
    @State private var currentURL: URL?

    // PERFORMANCE: Check cache immediately on init for instant display
    init(url: URL?, size: CGFloat) {
        self.url = url
        self.size = size
        // Pre-load from cache synchronously if available
        if let url = url {
            let cacheKey = url.absoluteString
            if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                _image = State(initialValue: cachedImage)
                _hasCheckedCache = State(initialValue: true)
                _imageOpacity = State(initialValue: 1.0)
                _currentURL = State(initialValue: url)
            }
        }
    }

    var body: some View {
        ZStack {
            // SMOOTH TRANSITION: Show previous image during crossfade
            if let previousImage = previousImage {
                Image(uiImage: previousImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .opacity(previousImageOpacity)
            }

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .opacity(imageOpacity)
            } else if loadError != nil {
                // Error state with retry button
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)

                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: size * 0.25))
                            .foregroundColor(.gray)

                        Button {
                            retryCount += 1
                            loadError = nil
                            loadImage()
                        } label: {
                            Text("Retry")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            } else {
                // Static placeholder - no loading animation for cleaner look
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white.opacity(0.6))
                    )
                    .onAppear {
                        if !hasCheckedCache || (image == nil && !isLoading) {
                            loadImage()
                        }
                    }
            }
        }
        // PERFORMANCE FIX: Cancel image loading when view disappears
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        // SMOOTH TRANSITION: Detect URL changes and reload with crossfade
        .onChange(of: url) { oldURL, newURL in
            guard newURL != currentURL else { return }

            // Store current image for crossfade
            if let currentImage = image {
                previousImage = currentImage
                previousImageOpacity = 1.0
            }

            // Reset state for new image
            currentURL = newURL
            image = nil
            imageOpacity = 0
            loadError = nil
            hasCheckedCache = false
            loadTask?.cancel()

            // Check if new image is already cached (instant display)
            if let newURL = newURL {
                let cacheKey = newURL.absoluteString
                if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                    // Instant crossfade for cached images
                    image = cachedImage
                    withAnimation(.easeOut(duration: 0.2)) {
                        imageOpacity = 1.0
                        previousImageOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.previousImage = nil
                    }
                    hasCheckedCache = true
                    return
                }
            }

            // Load new image from network
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        let cacheKey = url.absoluteString
        hasCheckedCache = true
        currentURL = url

        // Check cache first (double-check in case init didn't catch it)
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            // Smooth crossfade from previous image
            withAnimation(.easeOut(duration: 0.2)) {
                self.imageOpacity = 1.0
                self.previousImageOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.previousImage = nil
            }
            return
        }

        // Cancel previous task if any
        loadTask?.cancel()

        // Load from network
        isLoading = true
        loadError = nil

        loadTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                guard !Task.isCancelled else {
                    await MainActor.run { self.isLoading = false }
                    return
                }

                // QUALITY: Use high-quality decoding to prevent downsampling
                if let downloadedImage = ImageCache.decodeImageWithHighQuality(from: data) {
                    await MainActor.run {
                        // QUALITY: Save raw data without re-encoding
                        ImageCache.shared.setImageData(data, for: cacheKey)
                        self.image = downloadedImage
                        self.isLoading = false
                        // Smooth crossfade animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            self.imageOpacity = 1.0
                            self.previousImageOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self.previousImage = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadError = NSError(domain: "ImageCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                }
            } catch {
                guard !Task.isCancelled else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                await MainActor.run {
                    self.isLoading = false
                    self.loadError = error
                }
                Logger.shared.error("Failed to load profile image", category: .storage, error: error)
            }
        }
    }
}

// MARK: - Card Image Variant

/// Cached async image optimized for card layouts (discover, matches)
/// PERFORMANCE: Ultra-fast loading with instant cache display and smooth transitions
/// QUALITY: High-resolution rendering with consistent card sizing
struct CachedCardImage: View {
    let url: URL?
    let priority: ImageLoadPriority
    let fixedHeight: CGFloat?  // Optional fixed height for consistent card sizing

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var retryCount = 0
    // PERFORMANCE FIX: Store task for cancellation when view disappears
    @State private var loadTask: Task<Void, Never>?
    // PERFORMANCE: Track if we've checked cache to avoid re-checking
    @State private var hasCheckedCache = false
    // PERFORMANCE: Smooth fade-in animation state
    @State private var imageOpacity: Double = 0
    // SMOOTH TRANSITION: Track previous image for crossfade
    @State private var previousImage: UIImage?
    @State private var previousImageOpacity: Double = 0
    // Track current URL to detect changes
    @State private var currentURL: URL?

    // PERFORMANCE: Check cache immediately on init for instant display
    init(url: URL?, priority: ImageLoadPriority = .normal, fixedHeight: CGFloat? = nil) {
        self.url = url
        self.priority = priority
        self.fixedHeight = fixedHeight
        // Pre-load from cache synchronously if available
        if let url = url {
            let cacheKey = url.absoluteString
            if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                _image = State(initialValue: cachedImage)
                _hasCheckedCache = State(initialValue: true)
                _imageOpacity = State(initialValue: 1.0) // No animation needed for cached
                _currentURL = State(initialValue: url)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let displayHeight = fixedHeight ?? geometry.size.height
            let displayWidth = geometry.size.width

            ZStack {
                // Background for consistent card appearance
                Color.gray.opacity(0.05)

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .renderingMode(.original)  // Preserve original colors
                        .aspectRatio(contentMode: .fill)
                        .frame(width: displayWidth, height: displayHeight)
                        .clipped()
                        .crispImageRendering()  // GPU-accelerated crisp rendering
                        .opacity(imageOpacity)
                        .onAppear {
                            // Smooth fade-in for newly loaded images
                            if imageOpacity < 1.0 {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    imageOpacity = 1.0
                                }
                            }
                        }
                }

                if image == nil && loadError != nil {
                    // Error state with elegant retry button
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))

                        Text("Image unavailable")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            retryCount += 1
                            loadError = nil
                            loadImage()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                        }
                    }
                    .frame(width: displayWidth, height: displayHeight)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }

                if image == nil && loadError == nil {
                    // Static placeholder - no loading animation for cleaner look
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: displayWidth, height: displayHeight)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: min(displayWidth, displayHeight) * 0.3))
                            .foregroundColor(.white.opacity(0.4))
                    )
                    .onAppear {
                        // Only load if we haven't checked cache yet or need to fetch
                        if !hasCheckedCache {
                            loadImage()
                        } else if image == nil && !isLoading {
                            loadImage()
                        }
                    }
                }
            }
            .frame(width: displayWidth, height: displayHeight)
        }
        // PERFORMANCE FIX: Cancel image loading when view disappears
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        // SMOOTH TRANSITION: Detect URL changes and reload with crossfade
        .onChange(of: url) { oldURL, newURL in
            guard newURL != currentURL else { return }

            // Store current image for crossfade
            if let currentImage = image {
                previousImage = currentImage
                previousImageOpacity = 1.0
            }

            // Reset state for new image
            currentURL = newURL
            image = nil
            imageOpacity = 0
            loadError = nil
            hasCheckedCache = false
            loadTask?.cancel()

            // Check if new image is already cached (instant display)
            if let newURL = newURL {
                let cacheKey = newURL.absoluteString
                if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                    // Instant crossfade for cached images
                    image = cachedImage
                    withAnimation(.easeOut(duration: 0.2)) {
                        imageOpacity = 1.0
                        previousImageOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.previousImage = nil
                    }
                    hasCheckedCache = true
                    return
                }
            }

            // Load new image from network
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        let cacheKey = url.absoluteString
        hasCheckedCache = true

        // Check cache first (double-check in case init didn't catch it)
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            self.imageOpacity = 1.0 // Instant display for cached
            return
        }

        // Cancel previous task if any
        loadTask?.cancel()

        // Load using deduplicated method with priority
        isLoading = true
        loadError = nil

        loadTask = Task(priority: priority.taskPriority) {
            // Use deduplicated loading to prevent multiple network requests
            let loadedImage = await ImageCache.shared.loadImageAsync(for: url, priority: priority)

            guard !Task.isCancelled else {
                await MainActor.run { self.isLoading = false }
                return
            }

            await MainActor.run {
                if let loadedImage = loadedImage {
                    self.image = loadedImage
                    self.isLoading = false
                    // Trigger smooth fade-in animation
                    self.imageOpacity = 0
                } else {
                    self.isLoading = false
                    self.loadError = NSError(domain: "ImageCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
                }
            }
        }
    }
}

// MARK: - High Quality Card Image for Feed/Profile Consistency

/// High-quality image component that maintains consistent card dimensions
/// Used for feed cards and profile integration with matching visual appearance
struct HighQualityCardImage: View {
    let url: URL?
    let targetHeight: CGFloat
    let cornerRadius: CGFloat
    let priority: ImageLoadPriority

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var hasCheckedCache = false
    @State private var loadTask: Task<Void, Never>?
    @State private var imageOpacity: Double = 0

    init(
        url: URL?,
        targetHeight: CGFloat = 400,
        cornerRadius: CGFloat = 0,
        priority: ImageLoadPriority = .normal
    ) {
        self.url = url
        self.targetHeight = targetHeight
        self.cornerRadius = cornerRadius
        self.priority = priority

        // Pre-load from cache
        if let url = url {
            let cacheKey = url.absoluteString
            if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                _image = State(initialValue: cachedImage)
                _hasCheckedCache = State(initialValue: true)
                _imageOpacity = State(initialValue: 1.0)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid background ensures consistent card size
                Color(.systemGray6)

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: targetHeight)
                        .clipped()
                        .opacity(imageOpacity)
                        .onAppear {
                            if imageOpacity < 1.0 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    imageOpacity = 1.0
                                }
                            }
                        }
                } else if loadError != nil {
                    // Error placeholder
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))

                        Button {
                            loadError = nil
                            loadImage()
                        } label: {
                            Text("Tap to retry")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                } else {
                    // Beautiful placeholder with gradient and subtle icon
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.15),
                                Color.pink.opacity(0.1),
                                Color.purple.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Subtle pattern overlay
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.1), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 30)

                        // Person icon
                        Image(systemName: "person.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .onAppear {
                        if !hasCheckedCache {
                            loadImage()
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: targetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .frame(height: targetHeight)
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .onChange(of: url) { _, newURL in
            image = nil
            imageOpacity = 0
            loadError = nil
            hasCheckedCache = false
            loadTask?.cancel()

            if let newURL = newURL {
                let cacheKey = newURL.absoluteString
                if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                    image = cachedImage
                    imageOpacity = 1.0
                    hasCheckedCache = true
                    return
                }
            }
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }

        hasCheckedCache = true

        if let cachedImage = ImageCache.shared.image(for: url.absoluteString) {
            self.image = cachedImage
            self.imageOpacity = 1.0
            return
        }

        loadTask?.cancel()
        isLoading = true
        loadError = nil

        loadTask = Task(priority: priority.taskPriority) {
            let loadedImage = await ImageCache.shared.loadImageAsync(for: url, priority: priority)

            guard !Task.isCancelled else {
                await MainActor.run { isLoading = false }
                return
            }

            await MainActor.run {
                isLoading = false
                if let loadedImage = loadedImage {
                    self.image = loadedImage
                    self.imageOpacity = 0
                } else {
                    self.loadError = NSError(domain: "ImageCache", code: -1)
                }
            }
        }
    }
}

// MARK: - Shimmer Loading View

/// Animated shimmer effect for loading states
struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.1)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - High Quality Image View Modifier

/// View modifier that applies CALayer settings for crisp image rendering
struct HighQualityImageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                HighQualityLayerView()
            )
    }
}

/// UIViewRepresentable that configures CALayer for maximum image quality
struct HighQualityLayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        // Configure layer for high-quality rendering
        view.layer.minificationFilter = .trilinear  // Best quality when scaling down
        view.layer.magnificationFilter = .trilinear  // Best quality when scaling up
        view.layer.allowsEdgeAntialiasing = true
        view.layer.contentsScale = UIScreen.main.scale
        view.layer.shouldRasterize = false  // Don't rasterize (keeps quality)
        view.layer.drawsAsynchronously = true  // Better performance

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update scale in case of display changes
        uiView.layer.contentsScale = UIScreen.main.scale
    }
}

extension View {
    /// Apply high-quality layer settings for crisp image rendering
    func highQualityRendering() -> some View {
        self
            .drawingGroup(opaque: false, colorMode: .extendedLinear)  // GPU-accelerated with extended color
    }

    /// Apply crisp rendering optimizations for card images
    func crispImageRendering() -> some View {
        self
            .compositingGroup()  // Flatten for better rendering
            .drawingGroup(opaque: false, colorMode: .nonLinear)  // GPU rendering
    }
}
