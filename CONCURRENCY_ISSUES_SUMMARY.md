# Concurrency Safety Issues - Quick Reference

## Issues by Severity

| # | Severity | Issue | File | Lines | Type |
|---|----------|-------|------|-------|------|
| 1 | CRITICAL | Timer-based race condition | PendingMessageQueue.swift | 293-301 | Synchronization |
| 2 | CRITICAL | Unsafe nonisolated(unsafe) usage | DiscoverViewModel.swift | 40-44 | Actor isolation |
| 3 | CRITICAL | DispatchQueue.global race condition | PhotoVerification.swift | 113-119 | Thread safety |
| 4 | HIGH | Missing task cancellation checks | UserService.swift | 256-290 | Task management |
| 5 | HIGH | Weak self capture chains | MessageService.swift | 90-121 | Memory safety |
| 6 | HIGH | Singleton synchronization | AuthService.swift | 248 | Thread safety |
| 7 | HIGH | Fire-and-forget tasks | UserService.swift | 410-419 | Resource leak |
| 8 | HIGH | Missing @MainActor isolation | OfflineManager.swift | 133-139 | Actor isolation |
| 9 | HIGH | Unguarded @Published access | ChatViewModel.swift | 91-93 | Data races |
| 10 | HIGH | Missing listener cancellation | ChatViewModel.swift | 74-96 | Resource leak |
| 11 | MEDIUM | DispatchQueue vs async/await | NetworkManager.swift | 102, 145-156 | Pattern |
| 12 | MEDIUM | Unprotected cache dictionary | UserService.swift | 34-36 | Data races |
| 13 | MEDIUM | Missing task cancellation | DiscoverViewModel.swift | 124-145 | Task management |
| 14 | MEDIUM | Listener deduplication | MessageService.swift | 85-122 | Resource leak |
| 15 | MEDIUM | Observer cleanup missing | QueryCache.swift | 203-212 | Resource leak |
| 16 | MEDIUM | Detached task misuse | ImageUploadService.swift | 47-63 | Pattern |
| 17 | MEDIUM | Main thread assumption | AuthService.swift | 36-40 | Thread safety |
| 18 | MEDIUM | Listener not cancelled | StoreManager.swift | 31-57 | Resource leak |
| 19 | MEDIUM | Memory handler chains | ImageCache.swift | 151-177 | Coordination |
| 20 | MEDIUM | Unguarded @Published | PrivacySettingsView.swift | 261-267 | Context switch |
| 21 | LOW | Inconsistent return type | DailyLikeLimitCache.swift | 90-102 | Code smell |
| 22 | LOW | Polling-based init wait | AuthService.swift | 44-59 | Inefficient |
| 23 | LOW | Silent decode failures | ChatViewModel.swift | 91-93 | Error handling |
| 24 | LOW | Unbounded cleanup task | QueryCache.swift | 297-314 | Resource leak |
| 25 | LOW | Missing error context | Multiple files | Various | Logging |
| 26 | LOW | Cache sync issues | DailyLikeLimitCache.swift | 43-68 | Consistency |
| 27 | LOW | Inconsistent logging | Multiple files | Various | Code consistency |
| 28 | LOW | Missing task cleanup | CacheManager.swift | 214-217 | Resource leak |

## Issues by Category

### Actor Isolation Issues (5)
- #2: Unsafe nonisolated(unsafe) - DiscoverViewModel & UserService
- #8: Missing @MainActor - OfflineManager
- #9: Unguarded @Published - ChatViewModel & MessageService
- #20: Unguarded @Published - PrivacySettingsView
- #17: Main thread assumption - AuthService

### Thread Safety Issues (7)
- #1: Timer race condition - PendingMessageQueue
- #3: DispatchQueue.global - PhotoVerification
- #6: Singleton synchronization - ReferralManager
- #11: DispatchQueue vs async/await - NetworkManager
- #12: Unprotected cache - UserService
- #26: Cache sync issues - DailyLikeLimitCache
- #27: Logging inconsistency - Multiple

### Resource Leaks (8)
- #7: Fire-and-forget tasks - UserService
- #10: Missing listener cancellation - ChatViewModel
- #14: Listener deduplication - MessageService
- #15: Observer cleanup - QueryCache
- #18: Listener not cancelled - StoreManager
- #24: Unbounded cleanup task - QueryCache
- #28: Missing task cleanup - CacheManager
- #5: Weak self chains - MessageService (memory safety)

### Task Management (5)
- #4: Missing cancellation checks - UserService
- #5: Weak self capture chains - MessageService
- #7: Fire-and-forget tasks - UserService
- #13: Missing task cancellation - DiscoverViewModel
- #18: Listener not cancelled - StoreManager

### Inefficient Patterns (6)
- #11: DispatchQueue vs async/await - NetworkManager
- #16: Detached task misuse - ImageUploadService
- #19: Memory handler chains - ImageCache
- #22: Polling-based wait - AuthService
- #25: Missing error context - Multiple
- #27: Inconsistent logging - Multiple

---

## Fix Priority Queue

### Sprint 1 (Critical Fixes - Blocking)
1. Fix #2: DiscoverViewModel/UserService nonisolated(unsafe)
2. Fix #1: PendingMessageQueue Timer race
3. Fix #3: PhotoVerification DispatchQueue continuation

### Sprint 2 (High-Severity)
4. Fix #4: UserService task cancellation
5. Fix #5: MessageService weak self chains
6. Fix #6: Singleton synchronization
7. Fix #7: UserService fire-and-forget tasks
8. Fix #8: OfflineManager @MainActor

### Sprint 3 (Remaining High)
9. Fix #9: ChatViewModel @Published
10. Fix #10: ChatViewModel listener cleanup

### Sprint 4+ (Medium & Low)
11-20. Medium severity items (cache protection, observer cleanup, etc.)
21-28. Low severity items (logging, patterns, edge cases)

---

## Files Requiring Most Attention

| File | Issues | Severity |
|------|--------|----------|
| DiscoverViewModel.swift | 2, 13 | CRITICAL, MEDIUM |
| UserService.swift | 4, 7, 12 | HIGH, HIGH, MEDIUM |
| ChatViewModel.swift | 9, 10, 23 | HIGH, HIGH, LOW |
| PhotoVerification.swift | 3 | CRITICAL |
| PendingMessageQueue.swift | 1 | CRITICAL |
| MessageService.swift | 5, 14 | HIGH, MEDIUM |
| OfflineManager.swift | 8 | HIGH |
| ImageCache.swift | 19 | MEDIUM |
| QueryCache.swift | 15, 24 | MEDIUM, LOW |
| StoreManager.swift | 18 | MEDIUM |

---

## Code Snippets for Quick Reference

### Pattern: Proper Task Tracking
```swift
private var tasks: [String: Task<Void, Never>] = [:]

func doWork(id: String) async {
    tasks[id]?.cancel()
    tasks[id] = Task {
        defer { tasks.removeValue(forKey: id) }
        // ... work here
    }
}
```

### Pattern: Proper Observer Cleanup
```swift
private var memoryWarningObserver: NSObjectProtocol?

private init() {
    memoryWarningObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.handleMemoryWarning()
        }
    }
}

deinit {
    if let observer = memoryWarningObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### Pattern: Thread-Safe Singleton with Actor
```swift
actor SingletonService {
    static let shared = SingletonService()
    
    private init() {}
    
    func doWork() async {
        // Thread-safe by default
    }
}
```

### Pattern: Proper Continuation Usage
```swift
return try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global().async {
        do {
            let result = try performWork()
            DispatchQueue.main.async {
                continuation.resume(returning: result)
            }
        } catch {
            DispatchQueue.main.async {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

---

## Testing Checklist

- [ ] Test concurrent access to searchCache
- [ ] Test message queue doesn't duplicate
- [ ] Test PhotoVerification continuation thread safety
- [ ] Test message listener cleanup on deinit
- [ ] Test timer doesn't create duplicate processing
- [ ] Test weak self chains don't crash
- [ ] Test task cancellation works
- [ ] Test singleton thread safety
- [ ] Test @Published updates on main thread only
- [ ] Test observer cleanup prevents leaks

