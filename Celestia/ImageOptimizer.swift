//
//  ImageOptimizer.swift
//  Celestia
//
//  Optimizes images with compression, resizing, and format conversion
//  Generates multiple resolutions for different use cases
//

import UIKit
import Accelerate

// MARK: - Image Optimizer

class ImageOptimizer {

    // MARK: - Singleton

    static let shared = ImageOptimizer()

    // MARK: - Image Sizes

    enum ImageSize {
        case thumbnail      // 200x200 - Grid views, small previews
        case small          // 500x500 - List items
        case medium         // 1000x1000 - Profile cards
        case large          // 2000x2000 - Full screen view
        case original       // Original size - Upload/storage

        var maxDimension: CGFloat {
            switch self {
            case .thumbnail: return 200
            case .small: return 500
            case .medium: return 1000
            case .large: return 2000
            case .original: return .infinity
            }
        }

        var compressionQuality: CGFloat {
            switch self {
            case .thumbnail: return 0.85
            case .small: return 0.88
            case .medium: return 0.92   // Higher quality for profile cards
            case .large: return 0.95    // Near-original quality for full screen
            case .original: return 0.98
            }
        }
    }

    // MARK: - Initialization

    private init() {
        Logger.shared.info("ImageOptimizer initialized", category: .general)
    }

    // MARK: - Compression

    /// Compress image with specified quality
    func compress(_ image: UIImage, quality: CGFloat = 0.9) -> Data? {
        guard let data = image.jpegData(compressionQuality: quality) else {
            Logger.shared.error("Failed to compress image", category: .general)
            return nil
        }

        let originalSize = image.pngData()?.count ?? 0
        let compressedSize = data.count
        let savings = Double(originalSize - compressedSize) / Double(originalSize) * 100

        Logger.shared.info("Compressed image: \(originalSize / 1024)KB → \(compressedSize / 1024)KB (saved \(Int(savings))%)", category: .general)

        return data
    }

    /// Compress image to target file size (in bytes)
    func compress(_ image: UIImage, targetSize: Int, tolerance: Int = 50_000) -> Data? {
        var compression: CGFloat = 1.0
        let data = image.jpegData(compressionQuality: compression)

        guard var imageData = data else { return nil }

        // Binary search for optimal compression
        var minCompression: CGFloat = 0.0
        var maxCompression: CGFloat = 1.0

        for _ in 0..<10 {
            if imageData.count < targetSize - tolerance {
                break
            }

            let midCompression = (minCompression + maxCompression) / 2

            if imageData.count > targetSize {
                maxCompression = midCompression
            } else {
                minCompression = midCompression
            }

            compression = midCompression
            if let newData = image.jpegData(compressionQuality: compression) {
                imageData = newData
            }
        }

        Logger.shared.info("Compressed to target: \(imageData.count / 1024)KB (target: \(targetSize / 1024)KB)", category: .general)

        return imageData
    }

    // MARK: - Resizing

    /// Resize image to specified size with high-quality interpolation
    func resize(_ image: UIImage, to size: ImageSize) -> UIImage? {
        let maxDimension = size.maxDimension

        if maxDimension == .infinity {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        var newSize: CGSize

        if image.size.width > image.size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Use high-quality rendering with optimal settings
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale  // Match device scale for Retina
        format.opaque = false
        format.preferredRange = .extended  // Extended color range for better quality

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            // Set high-quality interpolation
            context.cgContext.interpolationQuality = .high
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsAntialiasing(true)

            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        Logger.shared.debug("Resized image: \(image.size) → \(newSize)", category: .general)

        return resizedImage
    }

    /// Resize image to exact dimensions (may crop) with high-quality interpolation
    func resize(_ image: UIImage, toExact size: CGSize, contentMode: UIView.ContentMode = .scaleAspectFill) -> UIImage? {
        // Use high-quality rendering settings
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        format.preferredRange = .extended

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            // Set high-quality interpolation
            context.cgContext.interpolationQuality = .high
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsAntialiasing(true)

            let aspectWidth = size.width / image.size.width
            let aspectHeight = size.height / image.size.height

            let aspectRatio: CGFloat
            var drawRect = CGRect.zero

            switch contentMode {
            case .scaleAspectFill:
                aspectRatio = max(aspectWidth, aspectHeight)
                let scaledWidth = image.size.width * aspectRatio
                let scaledHeight = image.size.height * aspectRatio
                let x = (size.width - scaledWidth) / 2
                let y = (size.height - scaledHeight) / 2
                drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)

            case .scaleAspectFit:
                aspectRatio = min(aspectWidth, aspectHeight)
                let scaledWidth = image.size.width * aspectRatio
                let scaledHeight = image.size.height * aspectRatio
                let x = (size.width - scaledWidth) / 2
                let y = (size.height - scaledHeight) / 2
                drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)

            default:
                drawRect = CGRect(origin: .zero, size: size)
            }

            image.draw(in: drawRect)
        }
    }

    // MARK: - Generate Multiple Resolutions

    /// Generate all resolution variants of an image
    func generateResolutions(from image: UIImage) -> [ImageSize: Data] {
        var resolutions: [ImageSize: Data] = [:]

        for size in [ImageSize.thumbnail, .small, .medium, .large] {
            if let resized = resize(image, to: size),
               let data = compress(resized, quality: size.compressionQuality) {
                resolutions[size] = data
            }
        }

        Logger.shared.info("Generated \(resolutions.count) resolution variants", category: .general)

        return resolutions
    }

    // MARK: - WebP Support

    /// Convert image to WebP format (if available)
    /// Note: WebP support requires third-party library (e.g., SDWebImage)
    func convertToWebP(_ image: UIImage) -> Data? {
        // Placeholder for WebP conversion
        // In production, use SDWebImageWebPCoder or similar
        Logger.shared.warning("WebP conversion not implemented (requires library)", category: .general)

        // Fallback to JPEG
        return compress(image, quality: 0.92)
    }

    // MARK: - Blur Effect

    /// Generate blurred thumbnail for placeholder
    func generateBlurredThumbnail(_ image: UIImage) -> UIImage? {
        // Resize to very small first (faster blur)
        guard let tiny = resize(image, toExact: CGSize(width: 20, height: 20)) else {
            return nil
        }

        guard let ciImage = CIImage(image: tiny) else {
            return nil
        }

        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(10.0, forKey: kCIInputRadiusKey)

        guard let outputImage = filter?.outputImage else {
            return nil
        }

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Image Analysis

    /// Calculate image file size
    func fileSize(of image: UIImage) -> Int {
        return image.jpegData(compressionQuality: 1.0)?.count ?? 0
    }

    /// Estimate optimal compression quality
    func estimateCompressionQuality(for image: UIImage, targetSize: Int) -> CGFloat {
        let currentSize = fileSize(of: image)

        if currentSize <= targetSize {
            return 1.0
        }

        let ratio = Double(targetSize) / Double(currentSize)
        return CGFloat(max(0.5, min(1.0, ratio)))
    }

    // MARK: - Image Validation

    /// Check if image meets requirements
    func validate(_ image: UIImage, minSize: CGSize, maxSize: CGSize, maxFileSize: Int) -> (valid: Bool, error: String?) {
        // Check dimensions
        if image.size.width < minSize.width || image.size.height < minSize.height {
            return (false, "Image too small. Minimum size: \(Int(minSize.width))x\(Int(minSize.height))")
        }

        if image.size.width > maxSize.width || image.size.height > maxSize.height {
            return (false, "Image too large. Maximum size: \(Int(maxSize.width))x\(Int(maxSize.height))")
        }

        // Check file size
        let size = fileSize(of: image)
        if size > maxFileSize {
            return (false, "File size too large. Maximum: \(maxFileSize / 1024 / 1024)MB")
        }

        return (true, nil)
    }

    // MARK: - Batch Processing

    /// Process multiple images in parallel
    func processImages(_ images: [UIImage], size: ImageSize) async -> [Data] {
        await withTaskGroup(of: Data?.self) { group in
            for image in images {
                group.addTask {
                    if let resized = self.resize(image, to: size) {
                        return self.compress(resized, quality: size.compressionQuality)
                    }
                    return nil
                }
            }

            var results: [Data] = []
            for await result in group {
                if let data = result {
                    results.append(data)
                }
            }
            return results
        }
    }
}

// MARK: - Image Processing Pipeline

struct ImageProcessingPipeline {

    static func process(
        _ image: UIImage,
        size: ImageOptimizer.ImageSize,
        generateBlur: Bool = true
    ) -> ProcessedImage {
        let optimizer = ImageOptimizer.shared

        // Resize
        guard let resized = optimizer.resize(image, to: size) else {
            Logger.shared.error("Failed to resize image", category: .general)
            return ProcessedImage(original: image, resized: image, data: Data(), blurHash: nil)
        }

        // Compress
        guard let data = optimizer.compress(resized, quality: size.compressionQuality) else {
            Logger.shared.error("Failed to compress image", category: .general)
            return ProcessedImage(original: image, resized: resized, data: Data(), blurHash: nil)
        }

        // Generate blur placeholder
        var blurHash: String?
        if generateBlur, let blurred = optimizer.generateBlurredThumbnail(image) {
            blurHash = blurred.base64EncodedString()
        }

        return ProcessedImage(
            original: image,
            resized: resized,
            data: data,
            blurHash: blurHash
        )
    }
}

// MARK: - Processed Image

struct ProcessedImage {
    let original: UIImage
    let resized: UIImage
    let data: Data
    let blurHash: String?

    var sizeInBytes: Int {
        return data.count
    }

    var sizeInKB: Int {
        return data.count / 1024
    }

    var sizeInMB: Double {
        return Double(data.count) / 1024.0 / 1024.0
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Get base64 encoded string with high quality
    func base64EncodedString() -> String? {
        return jpegData(compressionQuality: 0.9)?.base64EncodedString()
    }

    /// Compress to specific size
    func compressed(to size: ImageOptimizer.ImageSize) -> Data? {
        return ImageOptimizer.shared.compress(self, quality: size.compressionQuality)
    }

    /// Resize to specific size
    func resized(to size: ImageOptimizer.ImageSize) -> UIImage? {
        return ImageOptimizer.shared.resize(self, to: size)
    }
}
