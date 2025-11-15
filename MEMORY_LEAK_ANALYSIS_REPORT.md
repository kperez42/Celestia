# CELESTIA iOS APP - MEMORY LEAK & RETAIN CYCLE ANALYSIS REPORT

## Executive Summary
Found **4 critical memory leaks** involving NotificationCenter observers that are never removed, and **1 high-severity observation** regarding unbounded cache growth. Overall memory management is generally good with proper use of `[weak self]` in most places.

---

## CRITICAL ISSUES (Must Fix)

### 1. OnboardingViewModel - NotificationCenter Observer Memory Leak
**Severity: CRITICAL**  
**File**: `/home/user/Celestia/Celestia/OnboardingViewModel.swift`  
**Lines**: 119-131

**Issue**: 
- Adds a NotificationCenter observer in `observeMilestones()` method (line 120)
- Does NOT store the observer token returned by `addObserver()`
- No `deinit` method to call `removeObserver()`
- Closure captures `[weak self]` (correct), but observer itself is never cleaned up

**Code**:
```swift
private func observeMilestones() {
    NotificationCenter.default.addObserver(
        forName: .milestoneAchieved,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let milestone = notification.userInfo?["milestone"] as? ActivationMetrics.ActivationMilestone else {
            return
        }
        self?.celebrateMilestone(milestone)
    }
}
// NO CLEANUP - Memory leak!
```

**Impact**: Observer remains registered for lifetime of app, even after view model is deallocated.

**Recommended Fix**:
```swift
private var milestoneObserver: NSObjectProtocol?

private func observeMilestones() {
    milestoneObserver = NotificationCenter.default.addObserver(
        forName: .milestoneAchieved,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let milestone = notification.userInfo?["milestone"] as? ActivationMetrics.ActivationMilestone else {
            return
        }
        self?.celebrateMilestone(milestone)
    }
}

deinit {
    if let observer = milestoneObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

---

### 2. MessageQueueManager - NotificationCenter Observer Memory Leak
**Severity: CRITICAL**  
**File**: `/home/user/Celestia/Celestia/MessageQueueManager.swift`  
**Lines**: 177-186

**Issue**:
- Adds observer for network connection in `setupNetworkObserver()` (line 177)
- Does NOT store the returned observer token
- Has a `deinit` that invalidates `syncTimer` BUT does NOT cleanup the notification observer

**Code**:
```swift
private func setupNetworkObserver() {
    // Process queue when connection is restored
    NotificationCenter.default.addObserver(
        forName: .networkConnectionRestored,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.processQueue()
        }
    }
}

deinit {
    syncTimer?.invalidate()  // Only cleans up timer, not observer!
}
```

**Impact**: Observer persists in memory and continues to receive notifications even after the manager is deallocated.

**Recommended Fix**:
```swift
private var networkObserver: NSObjectProtocol?

private func setupNetworkObserver() {
    networkObserver = NotificationCenter.default.addObserver(
        forName: .networkConnectionRestored,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.processQueue()
        }
    }
}

deinit {
    syncTimer?.invalidate()
    if let observer = networkObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

---

### 3. QueryCache (CacheManager) - NotificationCenter Observer Memory Leak
**Severity: CRITICAL**  
**File**: `/home/user/Celestia/Celestia/QueryCache.swift`  
**Lines**: 204-212

**Issue**:
- `CacheManager` adds NotificationCenter observer for memory warnings (line 204)
- Does NOT store the returned observer token
- NO `deinit` method exists to cleanup the observer
- This is a singleton (`static let shared`) that lives for entire app lifetime, but proper cleanup is still critical

**Code**:
```swift
@MainActor
class CacheManager {
    static let shared = CacheManager()
    
    private init() {
        // ... initialization code ...
        
        // PERFORMANCE: Register for memory warning notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
        
        // NO DEINIT - memory leak!
    }
}
```

**Impact**: Memory warning observer is registered but can never be unregistered.

**Recommended Fix**:
```swift
@MainActor
class CacheManager {
    static let shared = CacheManager()
    
    private var memoryWarningObserver: NSObjectProtocol?
    
    private init() {
        // ... initialization code ...
        
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
        
        // ... rest of initialization ...
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

---

### 4. PerformanceMonitor - NotificationCenter Observer Memory Leak
**Severity: CRITICAL**  
**File**: `/home/user/Celestia/Celestia/PerformanceMonitor.swift`  
**Lines**: 94-102

**Issue**:
- Adds NotificationCenter observer for memory warnings in `init` (line 94)
- Does NOT store the returned observer token in a property
- Has a `deinit` (line 505) but it doesn't clean up the observer
- Observer is anonymous and cannot be referenced for removal

**Code**:
```swift
private init() {
    // PERFORMANCE: Register for memory warning notifications
    NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            self?.handleMemoryWarning()
        }
    }
    
    Logger.shared.info("PerformanceMonitor initialized", category: .performance)
}

deinit {
    Task { @MainActor in
        stopMonitoring()  // Does NOT remove observer!
    }
}
```

**Impact**: Memory warning observer continues to fire and execute closures even after deallocation.

**Recommended Fix**:
```swift
private var memoryWarningObserver: NSObjectProtocol?

private init() {
    memoryWarningObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            self?.handleMemoryWarning()
        }
    }
    
    Logger.shared.info("PerformanceMonitor initialized", category: .performance)
}

deinit {
    if let observer = memoryWarningObserver {
        NotificationCenter.default.removeObserver(observer)
    }
    Task { @MainActor in
        stopMonitoring()
    }
}
```

---

## HIGH-SEVERITY ISSUES

### 5. UserService - Unbounded Search Cache Growth
**Severity: HIGH**  
**File**: `/home/user/Celestia/Celestia/UserService.swift`  
**Lines**: 34-36, 225-237

**Issue**:
- Search results are cached with a 5-minute TTL
- Cache has a max size of 50 items (good!)
- However, the LRU eviction happens ONLY when cache reaches max size
- Cache entries are not proactively removed when TTL expires
- This can cause memory bloat if the cache frequently oscillates near 50 items

**Code**:
```swift
private var searchCache: [String: CachedSearchResult] = [:]
private let searchCacheDuration: TimeInterval = 300 // 5 minutes
private let maxSearchCacheSize = 50 // Limit cache size to prevent memory bloat

// Cache eviction only happens when adding new entries
if searchCache.count >= maxSearchCacheSize {
    let oldestKey = searchCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
    if let key = oldestKey {
        searchCache.removeValue(forKey: key)
    }
}
```

**Impact**: 
- Expired entries remain in memory until new searches push them out
- In low-usage periods, stale data persists longer than intended
- Potential for memory pressure on low-end devices

**Recommended Fix**:
```swift
// Add periodic cleanup task or proactive TTL checking
func getSearchResult(for key: String) -> [User]? {
    guard let cached = searchCache[key], !cached.isExpired else {
        searchCache.removeValue(forKey: key)  // Clean up expired entry
        return nil
    }
    return cached.results
}

// Or add a cleanup method called periodically:
func cleanupExpiredSearchCache() {
    searchCache = searchCache.filter { !$0.value.isExpired }
}
```

---

## GOOD PRACTICES FOUND

✅ **Proper Timer Cleanup**:
- `SplashView.swift` (line 91-94): Invalidates timer in `onDisappear`
- `WelcomeView.swift` (line 73-76): Invalidates timer in `onDisappear`
- `PerformanceMonitor.swift` (line 192-194): Invalidates FPS display link in `stopFPSMonitoring`
- `MessageQueueManager.swift` (line 225-227): Invalidates sync timer in `deinit`

✅ **Proper Listener Cleanup**:
- `ChatViewModel.swift` (line 75, 129-130, 135-136): Removes Firestore listeners in cleanup and deinit
- `MessageService.swift` (line 178-187): Stops listening and cleans up state

✅ **Correct [weak self] Usage**:
- Most closures in async operations correctly use `[weak self]`
- Proper null-coalescing after weak capture

✅ **Proper Observer Pattern Implementation**:
- `ClipboardSecurityManager.swift` (line 67, 274-289): Stores observer token and removes it in `stopMonitoring()` 
- `ScreenshotDetectionService.swift` (line 21, 34-36, 42-50): Stores observer and properly removes in `deinit`
- `ImageCache.swift` (line 31, 66-74, 294-298): Stores observer token and removes in `deinit`

---

## SUMMARY TABLE

| Issue | File | Line | Type | Severity | Status |
|-------|------|------|------|----------|--------|
| Missing observer cleanup | OnboardingViewModel.swift | 120-131 | NotificationCenter | CRITICAL | NOT FIXED |
| Missing observer cleanup | MessageQueueManager.swift | 177-186 | NotificationCenter | CRITICAL | NOT FIXED |
| Missing observer deinit | QueryCache.swift | 204-212 | NotificationCenter | CRITICAL | NOT FIXED |
| Missing observer cleanup | PerformanceMonitor.swift | 94-102 | NotificationCenter | CRITICAL | NOT FIXED |
| Unbounded cache growth | UserService.swift | 34-36 | Cache | HIGH | PARTIALLY FIXED |

---

## RECOMMENDATIONS

### Immediate Actions (Priority 1)
1. Add observer token properties to OnboardingViewModel, MessageQueueManager, QueryCache, and PerformanceMonitor
2. Implement deinit methods (or update existing ones) to call `removeObserver()`
3. Test memory footprint with Xcode's memory debugger

### Medium-term Improvements (Priority 2)
1. Implement periodic TTL cleanup for UserService search cache
2. Consider creating a helper protocol/extension for safe NotificationCenter observation
3. Add memory pressure tests to CI/CD pipeline

### Code Quality (Priority 3)
1. Create a standardized pattern for NotificationCenter observation in the codebase
2. Add linting rules to detect uncleaned observers
3. Document the observer cleanup pattern in coding guidelines

---

## TESTING RECOMMENDATIONS

To verify fixes:

1. **Memory Leak Detection**:
   ```swift
   // Use Xcode Memory Debugger
   // Mark deallocated instances and verify observers are cleared
   ```

2. **Profile with Instruments**:
   - Allocations: Track NotificationCenter object count
   - Leaks: Run leak detection tool
   - System Trace: Monitor for excessive notifications

3. **Unit Tests**:
   ```swift
   func testOnboardingViewModelDealsWithObserver() {
       var viewModel: OnboardingViewModel? = OnboardingViewModel()
       // Verify observer is registered
       viewModel = nil
       // Verify observer is deregistered
   }
   ```

