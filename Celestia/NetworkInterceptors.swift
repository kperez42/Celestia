//
//  NetworkInterceptors.swift
//  Celestia
//
//  Consolidated network interceptor protocols and implementations
//  Shared between BackendAPIService and NetworkManager
//

import Foundation

// MARK: - Interceptor Protocols

/// Protocol for intercepting and modifying requests before they are sent
protocol RequestInterceptor {
    func intercept(request: inout URLRequest) async throws
}

/// Protocol for intercepting and processing responses
protocol ResponseInterceptor {
    func intercept(data: Data, response: URLResponse) async throws -> Data
}

// MARK: - Default Interceptors

/// Logging interceptor that logs request and response details
struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    func intercept(request: inout URLRequest) async throws {
        Logger.shared.debug("🌐 Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")", category: .network)

        if let headers = request.allHTTPHeaderFields {
            Logger.shared.debug("📋 Headers: \(headers)", category: .network)
        }
    }

    func intercept(data: Data, response: URLResponse) async throws -> Data {
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = httpResponse.statusCode < 400 ? "✅" : "❌"
            Logger.shared.debug("\(statusEmoji) Response: \(httpResponse.statusCode) (\(data.count) bytes)", category: .network)
        }
        return data
    }
}

/// Analytics interceptor that tracks API calls and responses
struct AnalyticsInterceptor: RequestInterceptor, ResponseInterceptor {
    func intercept(request: inout URLRequest) async throws {
        // Track API call
        if let url = request.url {
            AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                "feature": "api_call",
                "endpoint": url.path,
                "method": request.httpMethod ?? "GET"
            ])
        }
    }

    func intercept(data: Data, response: URLResponse) async throws -> Data {
        // Track API response
        if let httpResponse = response as? HTTPURLResponse {
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "operation": "api_response",
                "status_code": httpResponse.statusCode,
                "response_size": data.count
            ])
        }
        return data
    }
}
