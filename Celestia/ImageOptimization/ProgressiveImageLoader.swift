//
//  ProgressiveImageLoader.swift
//  Celestia
//
//  Progressive image loading with blur placeholder and lazy loading
//  SwiftUI components for optimized image display
//

import SwiftUI
import Combine

// MARK: - Progressive Image Loader

@MainActor
class ProgressiveImageLoader: ObservableObject {

    // MARK: - Published Properties

    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var loadingProgress: Double = 0.0

    // MARK: - Properties

    private let url: URL
    private let cache = ImageCacheManager.shared
    private let cdn = CDNManager.shared
    private var cancellable: AnyCancellable?
    private var downloadTask: URLSessionDataTask?

    // MARK: - Initialization

    init(url: URL) {
        self.url = url
    }

    // MARK: - Loading

    func load(size: ImageOptimizer.ImageSize = .medium) {
        let cacheKey = ImageCacheManager.cacheKey(from: url)

        // Check cache first
        if let cachedImage = cache.image(forKey: cacheKey) {
            self.image = cachedImage
            return
        }

        // Start loading
        isLoading = true
        error = nil

        // Download image
        downloadImage(size: size, cacheKey: cacheKey)
    }

    private func downloadImage(size: ImageOptimizer.ImageSize, cacheKey: String) {
        // Create download task with progress tracking
        let session = URLSession.shared
        downloadTask = session.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    self.error = error
                    Logger.shared.error("Failed to load image", category: .general, error: error)
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    self.error = ImageLoadError.invalidData
                    return
                }

                // Cache the image
                self.cache.store(image, forKey: cacheKey)

                // Set the image
                self.image = image

                Logger.shared.debug("Loaded image: \(self.url.lastPathComponent)", category: .general)
            }
        }

        downloadTask?.resume()
    }

    func cancel() {
        downloadTask?.cancel()
        cancellable?.cancel()
        isLoading = false
    }
}

// MARK: - Async Image Loader (with Combine)

class AsyncImageLoader {

    static let shared = AsyncImageLoader()

    private let cache = ImageCacheManager.shared
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50 MB
            diskCapacity: 200 * 1024 * 1024    // 200 MB
        )
        self.session = URLSession(configuration: configuration)
    }

    func loadImage(from url: URL) -> AnyPublisher<UIImage, Error> {
        let cacheKey = ImageCacheManager.cacheKey(from: url)

        // Check cache
        if let cached = cache.image(forKey: cacheKey) {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        // Download
        return session.dataTaskPublisher(for: url)
            .tryMap { data, _ in
                guard let image = UIImage(data: data) else {
                    throw ImageLoadError.invalidData
                }
                return image
            }
            .handleEvents(receiveOutput: { [weak self] image in
                self?.cache.store(image, forKey: cacheKey)
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - SwiftUI Components

/// Progressive Image View with blur placeholder
struct OptimizedImage: View {
    let url: URL?
    let size: ImageOptimizer.ImageSize
    let contentMode: ContentMode

    @StateObject private var loader: ProgressiveImageLoader
    @State private var showPlaceholder = true

    init(url: URL?, size: ImageOptimizer.ImageSize = .medium, contentMode: ContentMode = .fill) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        _loader = StateObject(wrappedValue: ProgressiveImageLoader(url: url ?? URL(string: "https://example.com")!))
    }

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholderView
            }
        }
        .onAppear {
            if url != nil {
                loader.load(size: size)
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)

            if loader.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
}

/// Cached Async Image (simpler version)
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader: ProgressiveImageLoader

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ProgressiveImageLoader(url: url ?? URL(string: "https://example.com")!))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            if url != nil {
                loader.load()
            }
        }
    }
}

/// Profile Image with circular shape and optimization
struct ProfileImageView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        OptimizedImage(url: url, size: .small, contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(radius: 2)
    }
}

/// Photo Grid Item with lazy loading
struct PhotoGridItem: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        OptimizedImage(url: url, size: .medium, contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .cornerRadius(8)
    }
}

/// Full-screen photo viewer with high-quality image
struct FullScreenPhotoView: View {
    let url: URL?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            OptimizedImage(url: url, size: .large, contentMode: .fit)

            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

/// Lazy Loading Grid
struct LazyImageGrid: View {
    let imageURLs: [URL]
    let columns: Int

    private let spacing: CGFloat = 8

    var body: some View {
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columns
        )

        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(imageURLs.indices, id: \.self) { index in
                OptimizedImage(
                    url: imageURLs[index],
                    size: .small,
                    contentMode: .fill
                )
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Errors

enum ImageLoadError: Error {
    case invalidURL
    case invalidData
    case networkError
    case cancelled
}

// MARK: - View Modifiers

extension View {
    /// Apply shimmer effect while loading
    func shimmer(isLoading: Bool) -> some View {
        modifier(ShimmerModifier(isLoading: isLoading))
    }
}

struct ShimmerModifier: ViewModifier {
    let isLoading: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                isLoading ?
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                } : nil
            )
    }
}

// MARK: - Prefetching

class ImagePrefetcher {

    static let shared = ImagePrefetcher()

    private var prefetchTasks: [URL: URLSessionDataTask] = [:]

    func prefetch(_ urls: [URL]) {
        for url in urls {
            prefetch(url)
        }
    }

    func prefetch(_ url: URL) {
        let cacheKey = ImageCacheManager.cacheKey(from: url)

        // Skip if already cached
        if ImageCacheManager.shared.image(forKey: cacheKey) != nil {
            return
        }

        // Skip if already prefetching
        if prefetchTasks[url] != nil {
            return
        }

        // Start prefetch
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { self.prefetchTasks.removeValue(forKey: url) }

            guard let data = data, let image = UIImage(data: data) else {
                return
            }

            ImageCacheManager.shared.store(image, forKey: cacheKey)
            Logger.shared.debug("Prefetched: \(url.lastPathComponent)", category: .general)
        }

        prefetchTasks[url] = task
        task.resume()
    }

    func cancelPrefetch(_ url: URL) {
        prefetchTasks[url]?.cancel()
        prefetchTasks.removeValue(forKey: url)
    }

    func cancelAll() {
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
    }
}
