//
//  LoadingState.swift
//  Celestia
//
//  Generic loading state pattern for consistent UX across all views
//  Prevents blank screens and provides clear user feedback
//

import Foundation

/// Generic loading state for async operations
///
/// Usage:
/// ```swift
/// @Published var loadingState: LoadingState<[User]> = .idle
///
/// func loadUsers() async {
///     loadingState = .loading
///     do {
///         let users = try await UserService.shared.fetchUsers()
///         loadingState = .loaded(users)
///     } catch {
///         loadingState = .error(error.localizedDescription)
///     }
/// }
/// ```
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)

    /// Check if currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Get loaded data if available
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }

    /// Get error message if in error state
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }

    /// Check if has data
    var hasData: Bool {
        data != nil
    }

    /// Check if has error
    var hasError: Bool {
        errorMessage != nil
    }
}

// MARK: - Equatable Support

extension LoadingState: Equatable where T: Equatable {
    static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsData), .loaded(let rhsData)):
            return lhsData == rhsData
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - SwiftUI View Extensions

import SwiftUI

extension View {
    /// Handle loading state with consistent UI patterns
    ///
    /// Usage:
    /// ```swift
    /// List {
    ///     ForEach(viewModel.users) { user in
    ///         UserRow(user: user)
    ///     }
    /// }
    /// .loadingState(viewModel.loadingState) { users in
    ///     // This closure is called when loaded
    /// } errorView: { errorMessage in
    ///     ErrorView(message: errorMessage)
    /// }
    /// ```
    @ViewBuilder
    func loadingStateOverlay<T>(
        _ state: LoadingState<T>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        self.overlay {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                LoadingView()
            case .loaded:
                EmptyView()
            case .error(let message):
                ErrorStateView(message: message, onRetry: onRetry)
            }
        }
    }
}

// MARK: - Loading View Component

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
    }
}

// MARK: - Error State View Component

struct ErrorStateView: View {
    let message: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Oops!")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            if let retry = onRetry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color.blue)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty State View Component

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?

    init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color.blue)
                        .cornerRadius(DesignSystem.CornerRadius.button)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingState_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView()
                .previewDisplayName("Loading")

            ErrorStateView(message: "Unable to load data. Please check your connection.") {
                print("Retry tapped")
            }
            .previewDisplayName("Error with Retry")

            EmptyStateView(
                title: "No Messages",
                message: "Start matching with people to begin chatting!",
                systemImage: "bubble.left.and.bubble.right",
                actionTitle: "Find Matches",
                action: { print("Action tapped") }
            )
            .previewDisplayName("Empty State")
        }
    }
}
#endif
