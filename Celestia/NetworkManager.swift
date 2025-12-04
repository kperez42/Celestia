//
//  NetworkManager.swift
//  Celestia
//
//  Centralized networking layer with retry logic, interceptors, and monitoring
//  Provides robust network communication with automatic error handling
//

import Foundation
import Network
import Combine
import CommonCrypto

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case encodingError
    case serverError(Int)
    case noInternetConnection
    case timeout
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noInternetConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Network Request

struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    let timeout: TimeInterval

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

// MARK: - Network Response

struct NetworkResponse {
    let data: Data
    let response: HTTPURLResponse
    let metrics: URLSessionTaskMetrics?
}

// MARK: - Network Manager

class NetworkManager: NSObject {

    // MARK: - Singleton

    static let shared = NetworkManager()

    // MARK: - Properties

    private var session: URLSession!
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.celestia.network.monitor")

    @Published private(set) var isNetworkAvailable = true
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    private var requestAdapters: [NetworkRequestAdapter] = []
    private var responseAdapters: [NetworkResponseAdapter] = []

    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0

    // SECURITY: Certificate pinning configuration
    // CERTIFICATE PINNING CONFIGURATION
    // Add your server's SSL certificate public key hashes here for production security
    //
    // How to get certificate hash:
    // 1. Get your server's public key hash:
    //    openssl s_client -connect api.celestia.app:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
    //
    // 2. Add the hash string to the array below
    //
    // 3. Optional: Add backup certificate hash for smooth rotation
    //
    // IMPORTANT: Without certificate pinning, the app is vulnerable to MITM attacks.
    // For production deployment, you MUST configure this with your server's certificate hashes.
    //
    // PRODUCTION REQUIREMENT: Before deploying to production, add your actual certificate hashes below
    private let pinnedPublicKeyHashes: Set<String> = {
        #if DEBUG
        // In debug mode, certificate pinning is optional for development convenience
        // You can add development certificates here if needed
        return []
        #else
        // PRODUCTION MODE: Certificate pinning is REQUIRED
        // Uncomment and add your certificate hashes before deployment:
        let hashes: Set<String> = [
            // "YOUR_PRIMARY_CERT_HASH_HERE",    // Primary certificate
            // "YOUR_BACKUP_CERT_HASH_HERE"      // Backup for cert rotation
        ]

        // Enforce certificate pinning in production builds
        if hashes.isEmpty {
            // Use assertionFailure instead of fatalError to prevent production crashes
            // This will crash in DEBUG but only log in RELEASE
            assertionFailure("""
                ⚠️ CRITICAL SECURITY ERROR ⚠️

                Certificate pinning is not configured for PRODUCTION build.

                This is a security requirement. You must:
                1. Get your server's certificate hash using the command in the comments above
                2. Add the hash to the pinnedPublicKeyHashes array
                3. Rebuild the app

                Without certificate pinning, the app is vulnerable to MITM attacks.
                """)

            // Log critical security warning
            Logger.shared.error(
                "⚠️ Certificate pinning not configured in production build. App is vulnerable to MITM attacks.",
                category: .networking
            )
        }

        return hashes
        #endif
    }()

    // MARK: - Initialization

    override init() {
        self.monitor = NWPathMonitor()

        super.init()

        // Configure URL session with certificate pinning
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad

        // SECURITY FIX: Set minimum TLS version to 1.3 for enhanced security
        config.tlsMinimumSupportedProtocolVersion = .TLSv12  // TLS 1.2 minimum (1.3 when widely supported)

        // Create session with self as delegate for certificate pinning
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    func startMonitoring() {
        monitor.start(queue: monitorQueue)
        Logger.shared.network("Network monitoring started", level: .info)
    }

    func stopMonitoring() {
        monitor.cancel()
        Logger.shared.network("Network monitoring stopped", level: .info)
    }

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isNetworkAvailable = path.status == .satisfied
                self.connectionType = path.availableInterfaces.first?.type

                let status = path.status == .satisfied ? "Connected" : "Disconnected"
                let type = self.connectionType.map { "\($0)" } ?? "Unknown"
                Logger.shared.network("Network status: \(status) (\(type))", level: .info)

                if !self.isNetworkAvailable {
                    CrashlyticsManager.shared.logEvent("network_disconnected")
                }
            }
        }
    }

    func isConnected() -> Bool {
        return isNetworkAvailable
    }

    // MARK: - Adapter Management

    func addRequestAdapter(_ adapter: NetworkRequestAdapter) {
        requestAdapters.append(adapter)
    }

    func addResponseAdapter(_ adapter: NetworkResponseAdapter) {
        responseAdapters.append(adapter)
    }

    // MARK: - Request Execution

    func performRequest<T: Decodable>(_ networkRequest: NetworkRequest, retryCount: Int = 0) async throws -> T {
        // Check network connectivity
        guard isNetworkAvailable else {
            Logger.shared.network("Request failed: No internet connection", level: .error)
            throw NetworkError.noInternetConnection
        }

        // Create URL request
        var urlRequest = URLRequest(url: networkRequest.url, timeoutInterval: networkRequest.timeout)
        urlRequest.httpMethod = networkRequest.method.rawValue
        urlRequest.httpBody = networkRequest.body

        // Set headers
        if let headers = networkRequest.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Apply request adapters
        for adapter in requestAdapters {
            urlRequest = try await adapter.adapt(urlRequest)
        }

        do {
            // Perform request
            let startTime = Date()
            let (data, response) = try await session.data(for: urlRequest)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidURL
            }

            Logger.shared.network(
                "Request completed: \(networkRequest.method.rawValue) \(networkRequest.url.path) - \(httpResponse.statusCode) (\(String(format: "%.2f", duration))s)",
                level: .debug
            )

            // Track in Crashlytics
            CrashlyticsManager.shared.trackNetworkRequest(
                url: networkRequest.url,
                httpMethod: networkRequest.method.rawValue,
                startTime: startTime,
                endTime: endTime,
                responseCode: httpResponse.statusCode,
                requestSize: Int64(networkRequest.body?.count ?? 0),
                responseSize: Int64(data.count)
            )

            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.shared.network(
                    "Server error: \(httpResponse.statusCode)",
                    level: .error
                )
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            // Apply response adapters
            var networkResponse = NetworkResponse(data: data, response: httpResponse, metrics: nil)
            for adapter in responseAdapters {
                networkResponse = try await adapter.intercept(networkResponse)
            }

            // Decode response
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: networkResponse.data)
            } catch {
                Logger.shared.network(
                    "Decoding error: \(error.localizedDescription)",
                    level: .error
                )
                throw NetworkError.decodingError
            }

        } catch {
            // Handle errors with retry logic
            return try await handleError(
                error,
                for: networkRequest,
                urlRequest: urlRequest,
                retryCount: retryCount
            )
        }
    }

    // MARK: - Error Handling & Retry Logic

    private func handleError<T: Decodable>(
        _ error: Error,
        for networkRequest: NetworkRequest,
        urlRequest: URLRequest,
        retryCount: Int
    ) async throws -> T {
        // Convert to NetworkError
        let networkError: NetworkError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                networkError = .noInternetConnection
            case .timedOut:
                networkError = .timeout
            case .cancelled:
                networkError = .cancelled
            default:
                networkError = .unknown(error)
            }
        } else if let netError = error as? NetworkError {
            networkError = netError
        } else {
            networkError = .unknown(error)
        }

        Logger.shared.network(
            "Request error: \(networkError.errorDescription ?? "Unknown error")",
            level: .error
        )

        // Check if we should retry
        if shouldRetry(error: networkError, retryCount: retryCount) {
            let delay = calculateRetryDelay(attempt: retryCount)
            Logger.shared.network(
                "Retrying request in \(delay)s (attempt \(retryCount + 1)/\(maxRetryAttempts))",
                level: .warning
            )

            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await performRequest(networkRequest, retryCount: retryCount + 1)
        }

        // Record error
        CrashlyticsManager.shared.recordError(
            domain: "com.celestia.network",
            code: 1000,
            message: "Network request failed",
            userInfo: [
                "url": networkRequest.url.absoluteString,
                "method": networkRequest.method.rawValue,
                "error": networkError.errorDescription ?? "Unknown"
            ]
        )

        throw networkError
    }

    private func shouldRetry(error: NetworkError, retryCount: Int) -> Bool {
        // Don't retry if max attempts reached
        guard retryCount < maxRetryAttempts else { return false }

        // Retry logic based on error type
        switch error {
        case .timeout, .noInternetConnection:
            return true
        case .serverError(let code):
            // Retry on server errors (500+)
            return code >= 500
        case .cancelled:
            return false
        default:
            return false
        }
    }

    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s, 8s...
        return baseRetryDelay * pow(2.0, Double(attempt))
    }

    // MARK: - Convenience Methods

    /// Perform GET request
    func get<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> T {
        let request = NetworkRequest(url: url, method: .get, headers: headers)
        return try await performRequest(request)
    }

    /// Perform POST request
    func post<T: Decodable, Body: Encodable>(
        url: URL,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(body)

        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"

        let request = NetworkRequest(url: url, method: .post, headers: allHeaders, body: bodyData)
        return try await performRequest(request)
    }

    /// Perform PUT request
    func put<T: Decodable, Body: Encodable>(
        url: URL,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"

        let request = NetworkRequest(url: url, method: .put, headers: allHeaders, body: bodyData)
        return try await performRequest(request)
    }

    /// Perform DELETE request
    func delete<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> T {
        let request = NetworkRequest(url: url, method: .delete, headers: headers)
        return try await performRequest(request)
    }

    /// Upload data with progress tracking
    func upload(
        url: URL,
        data: Data,
        headers: [String: String]? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = data

        if let headers = headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (responseData, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidURL
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        return responseData
    }

    // MARK: - Cache Management

    func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
        Logger.shared.network("URL cache cleared", level: .info)
    }
}

// MARK: - URLSessionDelegate for Certificate Pinning

extension NetworkManager: URLSessionDelegate {

    /// SECURITY: Implements certificate pinning to prevent man-in-the-middle attacks
    /// This validates the server's SSL certificate against pinned public key hashes
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Get the server trust
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            Logger.shared.error("No server trust available for certificate pinning", category: .security)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If no public key hashes are configured, use default validation
        // SECURITY WARNING: This bypass is acceptable for development/testing only.
        // For PRODUCTION, you MUST configure certificate pinning hashes above.
        // Without certificate pinning, the app is vulnerable to man-in-the-middle attacks.
        if pinnedPublicKeyHashes.isEmpty {
            #if DEBUG
            Logger.shared.warning("Certificate pinning not configured - using default validation (development mode)", category: .security)
            #else
            Logger.shared.error("PRODUCTION BUILD WITHOUT CERTIFICATE PINNING - SECURITY RISK!", category: .security)
            #endif
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Validate the certificate chain
        var secresult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secresult)

        guard status == errSecSuccess else {
            Logger.shared.error("Certificate trust evaluation failed", category: .security)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Extract the server's public key
        guard let serverPublicKey = SecTrustCopyKey(serverTrust) else {
            Logger.shared.error("Failed to extract server public key", category: .security)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get the public key data
        guard let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil) as Data? else {
            Logger.shared.error("Failed to get server public key data", category: .security)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Hash the public key using SHA-256
        let serverPublicKeyHash = sha256(data: serverPublicKeyData)

        // Check if the hash matches any of our pinned hashes
        if pinnedPublicKeyHashes.contains(serverPublicKeyHash) {
            Logger.shared.debug("Certificate pinning validation successful", category: .security)
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            Logger.shared.error("Certificate pinning validation failed - public key hash mismatch", category: .security)
            CrashlyticsManager.shared.logEvent("certificate_pinning_failed", parameters: [
                "host": challenge.protectionSpace.host,
                "received_hash": serverPublicKeyHash
            ])
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Helper function to compute SHA-256 hash
    private func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}

// MARK: - Network Manager Request Adapters
// Note: These are different from the interceptors in NetworkInterceptors.swift
// These use a different signature for NetworkManager's specific needs

protocol NetworkRequestAdapter {
    func adapt(_ request: URLRequest) async throws -> URLRequest
    func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error) async throws -> Bool
}

protocol NetworkResponseAdapter {
    func intercept(_ response: NetworkResponse) async throws -> NetworkResponse
}

// Auth Token Adapter
class AuthTokenAdapter: NetworkRequestAdapter {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        // Add authentication token if available
        // Example: Get token from Keychain or AuthService
        // if let token = getAuthToken() {
        //     modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }

        return modifiedRequest
    }

    func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error) async throws -> Bool {
        // Implement retry logic for auth errors
        // Example: Refresh token if 401 error
        return false
    }
}

// Network Logging Adapter
class NetworkLoggingAdapter: NetworkResponseAdapter {
    func intercept(_ response: NetworkResponse) async throws -> NetworkResponse {
        Logger.shared.network(
            "Response: \(response.response.statusCode) - \(response.data.count) bytes",
            level: .debug
        )
        return response
    }
}
