//
//  MemoryLeakDetector.swift
//  Celestia
//
//  Detects and tracks memory leaks in the application
//  Monitors object deallocation and reports potential leaks
//

import Foundation
import SwiftUI

// MARK: - Memory Leak Detector

class MemoryLeakDetector {

    // MARK: - Singleton

    static let shared = MemoryLeakDetector()

    // MARK: - Properties

    private var trackedObjects: [WeakObjectWrapper] = []
    private var expectedDeallocations: Set<String> = []
    private let queue = DispatchQueue(label: "com.celestia.memory-leak-detector", attributes: .concurrent)
    private var isEnabled = true

    // MARK: - Configuration

    var warningThreshold: TimeInterval = 10.0 // Warn if object not deallocated after 10 seconds
    var errorThreshold: TimeInterval = 30.0 // Error if object not deallocated after 30 seconds

    // MARK: - Initialization

    private init() {
        #if DEBUG
        isEnabled = true
        Logger.shared.info("MemoryLeakDetector initialized", category: .general)
        startMonitoring()
        #else
        isEnabled = false
        #endif
    }

    // MARK: - Public Methods

    /// Track an object for potential memory leaks
    func track(_ object: AnyObject, name: String? = nil, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }

        let objectName = name ?? String(describing: type(of: object))
        let identifier = "\(ObjectIdentifier(object).hashValue)"
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"

        queue.async(flags: .barrier) {
            let wrapper = WeakObjectWrapper(
                object: object,
                identifier: identifier,
                name: objectName,
                location: location,
                trackingStartTime: Date()
            )

            self.trackedObjects.append(wrapper)
            Logger.shared.debug(
                "Tracking object: \(objectName) [\(identifier)] at \(location)",
                category: .general
            )
        }
    }

    /// Mark an object as expected to be deallocated
    func expectDeallocation(of object: AnyObject, within timeInterval: TimeInterval = 5.0) {
        guard isEnabled else { return }

        let identifier = "\(ObjectIdentifier(object).hashValue)"

        queue.async(flags: .barrier) {
            self.expectedDeallocations.insert(identifier)

            // Schedule check
            DispatchQueue.global().asyncAfter(deadline: .now() + timeInterval) {
                self.checkDeallocation(identifier: identifier)
            }
        }
    }

    /// Force a leak check on all tracked objects
    func checkForLeaks() {
        guard isEnabled else { return }

        queue.async {
            self.performLeakCheck()
        }
    }

    /// Clear all tracking data
    func reset() {
        queue.async(flags: .barrier) {
            self.trackedObjects.removeAll()
            self.expectedDeallocations.removeAll()
            Logger.shared.info("MemoryLeakDetector reset", category: .general)
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        // Periodic leak check every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkForLeaks()
        }
    }

    private func performLeakCheck() {
        let now = Date()

        // Clean up deallocated objects
        trackedObjects = trackedObjects.filter { $0.object != nil }

        // Check for potential leaks
        for wrapper in trackedObjects {
            guard let object = wrapper.object else { continue }

            let timeAlive = now.timeIntervalSince(wrapper.trackingStartTime)

            if timeAlive > errorThreshold {
                reportLeak(wrapper: wrapper, severity: .error, timeAlive: timeAlive)
            } else if timeAlive > warningThreshold {
                reportLeak(wrapper: wrapper, severity: .warning, timeAlive: timeAlive)
            }
        }
    }

    private func checkDeallocation(identifier: String) {
        queue.async {
            // Check if object with this identifier still exists
            if let wrapper = self.trackedObjects.first(where: { $0.identifier == identifier }),
               wrapper.object != nil {
                // Object still exists when it should have been deallocated
                self.reportLeak(
                    wrapper: wrapper,
                    severity: .error,
                    timeAlive: Date().timeIntervalSince(wrapper.trackingStartTime)
                )
            } else {
                // Object was properly deallocated
                self.expectedDeallocations.remove(identifier)
            }
        }
    }

    private func reportLeak(wrapper: WeakObjectWrapper, severity: LeakSeverity, timeAlive: TimeInterval) {
        let message = """
        Potential memory leak detected:
        Object: \(wrapper.name)
        Identifier: \(wrapper.identifier)
        Location: \(wrapper.location)
        Time alive: \(String(format: "%.2f", timeAlive))s
        Severity: \(severity.rawValue)
        """

        switch severity {
        case .warning:
            Logger.shared.warning(message, category: .general)
            CrashlyticsManager.shared.logEvent("memory_leak_warning", parameters: [
                "object": wrapper.name,
                "time_alive": timeAlive,
                "location": wrapper.location
            ])

        case .error:
            Logger.shared.error(message, category: .general)
            CrashlyticsManager.shared.logEvent("memory_leak_error", parameters: [
                "object": wrapper.name,
                "time_alive": timeAlive,
                "location": wrapper.location
            ])

            // Report to Crashlytics
            let error = NSError(
                domain: "com.celestia.memory-leak",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey: message,
                    "object_name": wrapper.name,
                    "time_alive": timeAlive
                ]
            )
            CrashlyticsManager.shared.recordError(error, userInfo: [:])
        }
    }

    // MARK: - Supporting Types

    private class WeakObjectWrapper {
        weak var object: AnyObject?
        let identifier: String
        let name: String
        let location: String
        let trackingStartTime: Date

        init(object: AnyObject, identifier: String, name: String, location: String, trackingStartTime: Date) {
            self.object = object
            self.identifier = identifier
            self.name = name
            self.location = location
            self.trackingStartTime = trackingStartTime
        }
    }

    private enum LeakSeverity: String {
        case warning = "WARNING"
        case error = "ERROR"
    }
}

// MARK: - SwiftUI View Tracking

extension View {
    /// Track this view for memory leaks
    func trackMemoryLeaks(name: String? = nil, file: String = #file, line: Int = #line) -> some View {
        #if DEBUG
        let viewName = name ?? String(describing: type(of: self))
        MemoryLeakDetector.shared.track(self as AnyObject, name: viewName, file: file, line: line)
        #endif
        return self
    }
}

// MARK: - ViewController Tracking

#if canImport(UIKit)
import UIKit

extension UIViewController {
    /// Automatically track view controller lifecycle for memory leaks
    static func enableMemoryLeakTracking() {
        #if DEBUG
        swizzleViewDidLoad()
        swizzleViewDidDisappear()
        #endif
    }

    private static func swizzleViewDidLoad() {
        let originalSelector = #selector(viewDidLoad)
        let swizzledSelector = #selector(swizzled_viewDidLoad)

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func swizzled_viewDidLoad() {
        swizzled_viewDidLoad() // Call original

        let vcName = String(describing: type(of: self))
        MemoryLeakDetector.shared.track(self, name: vcName)
    }

    private static func swizzleViewDidDisappear() {
        let originalSelector = #selector(viewDidDisappear(_:))
        let swizzledSelector = #selector(swizzled_viewDidDisappear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func swizzled_viewDidDisappear(_ animated: Bool) {
        swizzled_viewDidDisappear(animated) // Call original

        if isBeingDismissed || isMovingFromParent {
            MemoryLeakDetector.shared.expectDeallocation(of: self, within: 5.0)
        }
    }
}
#endif

// MARK: - Retain Cycle Detector

class RetainCycleDetector {

    static let shared = RetainCycleDetector()

    private init() {}

    /// Check if two objects have a retain cycle
    func checkRetainCycle(between object1: AnyObject, and object2: AnyObject) -> Bool {
        #if DEBUG
        // This is a simplified check
        // In production, you'd use more sophisticated tools like FBRetainCycleDetector
        let id1 = ObjectIdentifier(object1)
        let id2 = ObjectIdentifier(object2)

        Logger.shared.debug(
            "Checking retain cycle between \(id1) and \(id2)",
            category: .general
        )

        // Check if objects reference each other
        let mirror1 = Mirror(reflecting: object1)
        let mirror2 = Mirror(reflecting: object2)

        for child in mirror1.children {
            if let childObject = child.value as? AnyObject,
               ObjectIdentifier(childObject) == id2 {
                Logger.shared.warning(
                    "Potential retain cycle detected: \(type(of: object1)) -> \(type(of: object2))",
                    category: .general
                )
                return true
            }
        }

        for child in mirror2.children {
            if let childObject = child.value as? AnyObject,
               ObjectIdentifier(childObject) == id1 {
                Logger.shared.warning(
                    "Potential retain cycle detected: \(type(of: object2)) -> \(type(of: object1))",
                    category: .general
                )
                return true
            }
        }
        #endif

        return false
    }
}
