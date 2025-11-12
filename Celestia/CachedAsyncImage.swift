//
//  CachedAsyncImage.swift
//  Celestia
//
//  Reusable AsyncImage component with error handling and retry
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View, ErrorView: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let errorView: () -> ErrorView

    @State private var retryCount = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                content(image)
            case .failure:
                // Error state with retry option
                errorView()
            case .empty:
                // Loading state
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .id(retryCount) // Forces reload when retryCount changes
    }

    func retry() {
        retryCount += 1
    }
}

// Convenience initializer with default views
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView>, ErrorView == DefaultErrorView {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
        self.errorView = { DefaultErrorView() }
    }
}

// Default error view
struct DefaultErrorView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Failed to load")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
    }
}

// Profile image variant with retry button
struct ProfileAsyncImage: View {
    let url: URL?
    let size: CGFloat

    @State private var retryCount = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure:
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
                        } label: {
                            Text("Retry")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            case .empty:
                // Loading state
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)

                    ProgressView()
                }
            @unknown default:
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
        .id(retryCount)
    }
}

// Card image variant with better error handling
struct CardAsyncImage: View {
    let url: URL?

    @State private var retryCount = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))

                    Text("Image unavailable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        retryCount += 1
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .empty:
                // Loading state
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                }
            @unknown default:
                Color.gray.opacity(0.2)
            }
        }
        .id(retryCount)
    }
}
