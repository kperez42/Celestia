//
//  Logger.swift
//  Celestia
//
//  Comprehensive logging system to replace print statements
//  Provides structured logging with levels, categories, and persistence
//

import Foundation
import OSLog

// MARK: - Log Level

enum LogLevel: Int, Comparable, CustomStringConvertible {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category

enum LogCategory: String {
    case authentication = "Auth"
    case networking = "Network"
    case database = "Database"
    case ui = "UI"
    case storage = "Storage"
    case messaging = "Messaging"
    case matching = "Matching"
    case payment = "Payment"
    case analytics = "Analytics"
    case push = "Push"
    case referral = "Referral"
    case moderation = "Moderation"
    case security = "Security"
    case performance = "Performance"
    case user = "User"
    case onboarding = "Onboarding"
    case offline = "Offline"
    case admin = "Admin"
    case general = "General"

    var subsystem: String {
        "com.celestia.app"
    }
}

// MARK: - Logger

class Logger {

    // MARK: - Singleton

    static let shared = Logger()

    // MARK: - Properties

    /// Minimum log level to display (can be changed at runtime)
    /// NOTE: Set to .info in DEBUG to capture networking diagnostics for WiFi/upload issues
    var minimumLogLevel: LogLevel = {
        #if DEBUG
        return .info  // Changed from .warning to .info to capture network diagnostics
        #else
        return .warning
        #endif
    }()

    /// Enable/disable logging per category
    var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)

    /// Enable console logging
    var consoleLoggingEnabled = true

    /// Enable persistent logging to file (disabled for performance)
    var fileLoggingEnabled: Bool = false

    /// Maximum log file size (10 MB)
    private let maxLogFileSize: Int = 10 * 1024 * 1024

    /// Log file URL
    private let logFileURL: URL = {
        let fileManager = FileManager.default
        let documentsURLs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)

        // SAFETY: Safely unwrap with fallback to temp directory
        guard let documentsPath = documentsURLs.first else {
            // Fallback to temp directory if documents directory is unavailable
            let tempPath = fileManager.temporaryDirectory
            return tempPath.appendingPathComponent("celestia_logs.txt")
        }

        return documentsPath.appendingPathComponent("celestia_logs.txt")
    }()

    /// OSLog instances per category
    private var osLoggers: [LogCategory: OSLog] = [:]

    /// Serial queue for thread-safe logging
    private let loggingQueue = DispatchQueue(label: "com.celestia.logger", qos: .utility)

    /// Date formatter for log timestamps
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        setupOSLoggers()
        rotateLogFileIfNeeded()
    }

    private func setupOSLoggers() {
        for category in LogCategory.allCases {
            osLoggers[category] = OSLog(subsystem: category.subsystem, category: category.rawValue)
        }
    }

    // MARK: - Public Logging Methods

    /// Log a debug message
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Log an info message
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Log a warning message
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Log an error message
    func error(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Log a critical message
    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    internal func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        // Check if logging is enabled for this level and category
        guard level >= minimumLogLevel else { return }
        guard enabledCategories.contains(category) else { return }

        loggingQueue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = (file as NSString).lastPathComponent
            let logMessage = self.formatLogMessage(
                message: message,
                level: level,
                category: category,
                timestamp: timestamp,
                file: fileName,
                function: function,
                line: line
            )

            // Console logging
            if self.consoleLoggingEnabled {
                self.logToConsole(logMessage, level: level, category: category)
            }

            // File logging
            if self.fileLoggingEnabled {
                self.logToFile(logMessage)
            }

            // OS Log (for Console.app and Xcode)
            self.logToOSLog(message, level: level, category: category)
        }
    }

    private func formatLogMessage(message: String, level: LogLevel, category: LogCategory, timestamp: String, file: String, function: String, line: Int) -> String {
        return "[\(timestamp)] \(level.emoji) [\(level.description)] [\(category.rawValue)] \(file):\(line) \(function) - \(message)"
    }

    // MARK: - Console Logging

    private func logToConsole(_ message: String, level: LogLevel, category: LogCategory) {
        print(message)
    }

    // MARK: - File Logging

    private func logToFile(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }

        rotateLogFileIfNeeded()
    }

    private func rotateLogFileIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxLogFileSize else {
            return
        }

        // Archive old log
        let archiveURL = logFileURL.deletingPathExtension().appendingPathExtension("old.txt")
        try? FileManager.default.removeItem(at: archiveURL)
        try? FileManager.default.moveItem(at: logFileURL, to: archiveURL)
    }

    // MARK: - OS Log

    private func logToOSLog(_ message: String, level: LogLevel, category: LogCategory) {
        guard let osLog = osLoggers[category] else { return }
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
    }

    // MARK: - Log Management

    /// Get the current log file contents
    func getLogFileContents() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    /// Clear the log file
    func clearLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    /// Export logs
    func exportLogs() -> URL? {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return nil
        }
        return logFileURL
    }

    /// Enable/disable a specific category
    func setCategory(_ category: LogCategory, enabled: Bool) {
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
    }

    /// Enable/disable all categories
    func setAllCategories(enabled: Bool) {
        if enabled {
            enabledCategories = Set(LogCategory.allCases)
        } else {
            enabledCategories.removeAll()
        }
    }
}

// MARK: - LogCategory CaseIterable

extension LogCategory: CaseIterable {
    static var allCases: [LogCategory] {
        return [
            .authentication, .networking, .database, .ui, .storage,
            .messaging, .matching, .payment, .analytics, .push,
            .referral, .moderation, .security, .performance, .user, .onboarding, .offline, .admin, .general
        ]
    }
}

// MARK: - Convenience Extensions

extension Logger {

    /// Log authentication events
    func auth(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .authentication, file: file, function: function, line: line)
    }

    /// Log networking events
    func network(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .networking, file: file, function: function, line: line)
    }

    /// Log database events
    func database(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .database, file: file, function: function, line: line)
    }
}

// MARK: - Global Logger Functions

/// Global convenience functions for logging
func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, error: error, file: file, function: function, line: line)
}

func logCritical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, category: category, file: file, function: function, line: line)
}
