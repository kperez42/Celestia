# Celestia Testing Guide

Comprehensive guide for testing the Celestia dating app, including unit tests, integration tests, performance benchmarks, and CI/CD setup.

## 📋 Table of Contents

- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Test Categories](#test-categories)
- [Firebase Emulator Setup](#firebase-emulator-setup)
- [Integration Testing](#integration-testing)
- [Performance Benchmarks](#performance-benchmarks)
- [CI/CD Integration](#cicd-integration)
- [Best Practices](#best-practices)

---

## 📁 Test Structure

```
CelestiaTests/
├── Unit Tests (200+ tests)
│   ├── AuthServiceTests.swift          # Authentication flows
│   ├── MatchServiceTests.swift         # Match creation & management
│   ├── MessageServiceTests.swift       # Messaging functionality
│   ├── SwipeServiceTests.swift         # Swipe logic
│   ├── UserServiceTests.swift          # User management
│   ├── ContentModeratorTests.swift     # Content moderation
│   ├── ReferralManagerTests.swift      # Referral system
│   ├── StoreManagerTests.swift         # In-app purchases
│   ├── MessagePaginationTests.swift    # Pagination logic
│   └── BatchOperationManagerTests.swift # Batch operations
│
├── Integration Tests (NEW)
│   ├── IntegrationTestBase.swift       # Base class with utilities
│   ├── EndToEndFlowTests.swift         # Complete user journeys
│   ├── NetworkFailureTests.swift       # Network error scenarios
│   ├── RaceConditionTests.swift        # Concurrency issues
│   └── PerformanceBenchmarkTests.swift # Performance testing
│
└── Mock Services
    └── MockServices.swift               # Mock implementations
```

---

## 🚀 Running Tests

### Run All Tests
```bash
# In Xcode
⌘ + U

# Command line
xcodebuild test \
  -workspace Celestia.xcworkspace \
  -scheme Celestia \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath TestResults
```

### Run Specific Test Suite
```bash
# Run only integration tests
xcodebuild test \
  -workspace Celestia.xcworkspace \
  -scheme Celestia \
  -only-testing:CelestiaTests/EndToEndFlowTests

# Run only performance benchmarks
xcodebuild test \
  -workspace Celestia.xcworkspace \
  -scheme Celestia \
  -only-testing:CelestiaTests/PerformanceBenchmarkTests
```

### Run Tests with Firebase Emulator
```bash
# Start Firebase Emulator
firebase emulators:start --only auth,firestore,storage

# In another terminal, run tests
xcodebuild test -workspace Celestia.xcworkspace -scheme Celestia
```

---

## 📊 Test Categories

### 1. **Unit Tests (200+ tests)**
Test individual components in isolation.

**Coverage:**
- ✅ Authentication flows (56+ tests)
- ✅ Match creation and management (32+ tests)
- ✅ Message sending and receiving
- ✅ Swipe logic (38+ tests)
- ✅ Content moderation (45+ tests)
- ✅ Referral system (41+ tests)
- ✅ In-app purchases
- ✅ Input sanitization
- ✅ Rate limiting

**Run Command:**
```bash
xcodebuild test -only-testing:CelestiaTests/AuthServiceTests
```

### 2. **Integration Tests (NEW)**
Test complete workflows with real Firebase Emulator.

**Test Scenarios:**
- Complete user journey (signup → match → message)
- Signup with email verification
- Signup with referral code
- Discovery and swiping flow
- Messaging with pagination
- Unmatch flow
- Profile update flow
- Premium upgrade simulation

**Run Command:**
```bash
# Requires Firebase Emulator running
firebase emulators:start --only auth,firestore,storage

# In another terminal
xcodebuild test -only-testing:CelestiaTests/EndToEndFlowTests
```

### 3. **Network Failure Tests**
Simulate and handle network issues.

**Scenarios:**
- Connection loss during operations
- Timeout handling
- Retry mechanisms
- Offline mode behavior
- Network recovery
- Partial write failures

**Run Command:**
```bash
xcodebuild test -only-testing:CelestiaTests/NetworkFailureTests
```

### 4. **Race Condition Tests**
Verify concurrent operation safety.

**Test Cases:**
- Concurrent message sending
- Simultaneous swipes creating match
- Prevent duplicate matches
- Concurrent batch operations
- Real-time listener races
- Pagination with new messages

**Run Command:**
```bash
xcodebuild test -only-testing:CelestiaTests/RaceConditionTests
```

### 5. **Performance Benchmarks**
Measure and track performance metrics.

**Benchmarks:**
- Message load time (50, 100, 1000 messages)
- Search query performance
- Real-time listener latency
- Batch operation speed
- Memory usage
- Match creation time

**Run Command:**
```bash
xcodebuild test -only-testing:CelestiaTests/PerformanceBenchmarkTests
```

---

## 🔥 Firebase Emulator Setup

### Installation
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Emulator
firebase init emulators
```

### Configuration (`firebase.json`)
```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

### Start Emulators
```bash
# Start all emulators
firebase emulators:start

# Start specific emulators only
firebase emulators:start --only auth,firestore,storage

# Start with UI
firebase emulators:start --import=./test-data --export-on-exit
```

### Emulator UI
Access at: http://localhost:4000

**Features:**
- View Firestore data
- Inspect Auth users
- Monitor Storage files
- Debug test data

---

## 🧪 Integration Testing

### Writing Integration Tests

```swift
import Testing
@testable import Celestia

@Suite("My Integration Test")
struct MyIntegrationTest {

    @Test("Test user flow")
    @MainActor
    func testUserFlow() async throws {
        // Setup
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create test data
        let user = try await testBase.createTestUser()

        // Test your flow
        #expect(user.id != nil)

        // Cleanup happens automatically in defer
    }
}
```

### Integration Test Utilities

**IntegrationTestBase provides:**
- `createTestUser()` - Create user in Auth + Firestore
- `createTestMatch()` - Create match between users
- `createTestMessage()` - Create message in conversation
- `createTestConversation()` - Create match + messages
- `waitForCondition()` - Wait for async conditions
- `measureTime()` - Performance measurement
- `measureMemory()` - Memory profiling
- `cleanup()` - Automatic test data cleanup

**Example:**
```swift
// Create conversation with 100 messages
let (match, messages) = try await testBase.createTestConversation(
    user1: user1,
    user2: user2,
    messageCount: 100
)

// Wait for async operation
try await testBase.waitForCondition(timeout: 5.0) {
    !messageService.isLoading
}

// Measure performance
let duration = await testBase.measureTime(operation: "Load messages") {
    await messageService.loadMessages()
}
```

---

## 📈 Performance Benchmarks

### Running Benchmarks
```bash
# Run all performance tests
xcodebuild test -only-testing:CelestiaTests/PerformanceBenchmarkTests

# View performance report
# Reports are logged to console during test run
```

### Performance Baselines

| Operation | Baseline | Acceptable | Needs Improvement |
|-----------|----------|------------|-------------------|
| Message load (50) | < 300ms | < 1s | > 1s |
| Message load (1000) | < 500ms | < 2s | > 2s |
| User search (100) | < 500ms | < 1s | > 1s |
| Listener latency | < 500ms | < 1s | > 1s |
| Batch operation (50) | < 1s | < 2s | > 2s |
| Match creation | < 500ms | < 1s | > 1s |

### Tracking Performance Over Time

```swift
// Performance metrics are logged to PerformanceMetrics class
PerformanceMetrics.log(
    operation: "message_load_50",
    duration: loadTime,
    itemCount: 50
)

// Generate report
let report = PerformanceMetrics.generateReport()
print(report)
```

### Memory Profiling

```swift
let memoryBefore = testBase.measureMemory()

// Perform operation
// ...

let memoryAfter = testBase.measureMemory()
let increase = memoryAfter - memoryBefore

Logger.shared.info("Memory increase: \(increase / 1024 / 1024)MB")
```

---

## 🔄 CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/tests.yml`:

```yaml
name: Run Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_15.0.app

    - name: Install Firebase Emulator
      run: |
        npm install -g firebase-tools
        firebase emulators:start --only auth,firestore,storage &
        sleep 10 # Wait for emulators to start

    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -workspace Celestia.xcworkspace \
          -scheme Celestia \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -resultBundlePath TestResults \
          -only-testing:CelestiaTests

    - name: Run Integration Tests
      run: |
        xcodebuild test \
          -workspace Celestia.xcworkspace \
          -scheme Celestia \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -only-testing:CelestiaTests/EndToEndFlowTests

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: TestResults
```

### Continuous Performance Monitoring

```yaml
# Add to GitHub Actions workflow
- name: Run Performance Benchmarks
  run: |
    xcodebuild test \
      -only-testing:CelestiaTests/PerformanceBenchmarkTests \
      | tee benchmark-results.txt

- name: Check Performance Regression
  run: |
    # Compare with baseline
    python scripts/check_performance_regression.py benchmark-results.txt
```

---

## ✅ Best Practices

### 1. **Test Isolation**
- Each test should be independent
- Use `defer { cleanup() }` for automatic cleanup
- Don't rely on execution order

```swift
@Test("Isolated test")
@MainActor
func testIsolated() async throws {
    let testBase = try await IntegrationTestBase()
    defer { Task { await testBase.cleanup() } }

    // Test code here
}
```

### 2. **Use Meaningful Test Names**
```swift
// ❌ Bad
@Test("Test 1")
func test1() {}

// ✅ Good
@Test("User signup with valid email creates account")
func testUserSignupWithValidEmailCreatesAccount() {}
```

### 3. **Test Edge Cases**
- Empty data
- Maximum values
- Network failures
- Concurrent operations
- Invalid inputs

### 4. **Mock External Dependencies**
- Use MockServices for unit tests
- Use Firebase Emulator for integration tests
- Don't rely on production data

### 5. **Performance Testing**
- Set realistic baselines
- Track trends over time
- Test with production-like data volumes
- Profile memory usage

### 6. **Assertions**
```swift
// ✅ Good assertions with messages
#expect(user != nil, "User should be created")
#expect(messages.count == 50, "Should load exactly 50 messages")

// ❌ Avoid silent failures
#expect(true) // Meaningless
```

### 7. **Cleanup**
- Always clean up test data
- Sign out after auth tests
- Remove listeners
- Clear caches

---

## 🐛 Troubleshooting

### Tests Fail with "Firebase not configured"
**Solution:**
```bash
# Ensure GoogleService-Info.plist exists
# Or configure Firebase in test setup
```

### Emulator Connection Refused
**Solution:**
```bash
# Start emulators before running tests
firebase emulators:start --only auth,firestore,storage

# Check emulator status
curl http://localhost:8080
```

### Tests Timeout
**Solution:**
- Increase timeout values
- Check network connectivity
- Verify emulator is running
- Review Firestore rules

### Memory Leaks Detected
**Solution:**
- Use `[weak self]` in closures
- Remove listeners in cleanup
- Profile with Instruments

---

## 📚 Additional Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Xcode Testing Guide](https://developer.apple.com/documentation/xcode/testing)
- [CI/CD Best Practices](https://docs.github.com/en/actions/automating-builds-and-tests)

---

## 📊 Test Coverage Goals

| Category | Current | Target |
|----------|---------|--------|
| Unit Tests | 85% | 90% |
| Integration Tests | NEW | 70% |
| Performance Tests | NEW | All critical paths |
| Edge Cases | 60% | 80% |

---

## 🎯 Next Steps

1. ✅ Run all existing tests
2. ✅ Set up Firebase Emulator
3. ✅ Run integration tests
4. ✅ Review performance benchmarks
5. ⏳ Set up CI/CD pipeline
6. ⏳ Add more edge case tests
7. ⏳ Increase code coverage to 90%

---

**Last Updated:** $(date)
**Version:** 2.0
**Maintainer:** Development Team
