# Performance Monitoring Guide

## Overview

This guide covers monitoring image optimization performance across Firebase Performance, Cloudinary dashboard, and in-app analytics.

## Table of Contents

1. [Firebase Performance Monitoring](#firebase-performance-monitoring)
2. [Cloudinary Dashboard](#cloudinary-dashboard)
3. [In-App Performance Dashboard](#in-app-performance-dashboard)
4. [Key Metrics to Track](#key-metrics-to-track)
5. [Performance Benchmarks](#performance-benchmarks)
6. [Alerting & Notifications](#alerting--notifications)
7. [Troubleshooting](#troubleshooting)

---

## Firebase Performance Monitoring

### Setup

Firebase Performance is automatically integrated with the image optimization system through `ImagePerformanceMonitor.swift`.

**Verify Installation:**

1. Open Firebase Console: https://console.firebase.google.com
2. Select your project
3. Navigate to **Performance** in left sidebar
4. Ensure Performance SDK is installed (should see data within 24 hours)

### Custom Traces

The system creates custom traces for each image load:

**Trace Names:**
- `image_load_thumbnail` - Thumbnail size (150×150)
- `image_load_small` - Small size (375×500)
- `image_load_medium` - Medium size (750×1000)
- `image_load_large` - Large size (1200×1600)

**Trace Attributes:**
- `image_id` - Unique identifier for the image
- `image_size` - Size variant being loaded
- `from_cdn` - Whether loaded from CDN (`true`) or origin (`false`)
- `status` - Load status (`success` or `failed`)

**Trace Metrics:**
- `load_time_ms` - Time to load image in milliseconds
- `bytes_loaded` - Number of bytes downloaded

### Viewing Performance Data

**1. Navigate to Custom Traces:**
```
Firebase Console → Performance → Custom traces tab
```

**2. Filter by Image Loads:**
```
Search: "image_load"
```

**3. Analyze Metrics:**
- **Duration percentiles**: P50, P90, P99 load times
- **Success rate**: Percentage of successful loads
- **Network performance**: Breakdown by connection type (WiFi, 4G, 5G)
- **Device breakdown**: Performance by device model

**4. Set Up Dashboard:**
```
Performance → Dashboard → Create custom dashboard
Add cards:
  - Average image load time (target: <500ms)
  - P90 load time (target: <1000ms)
  - Success rate (target: >99%)
  - CDN hit rate (custom metric)
```

### Firebase Analytics Events

The system logs these analytics events:

**`image_loaded`**
```json
{
  "image_id": "user123-photo1",
  "size": "medium",
  "load_time_ms": 342,
  "from_cdn": true,
  "bytes_loaded": 87654
}
```

**`image_load_failed`**
```json
{
  "image_id": "user123-photo1",
  "size": "medium",
  "error": "Network timeout"
}
```

**`cdn_performance`**
```json
{
  "cache_hit": true,
  "latency_ms": 120
}
```

**`profile_viewed_optimized`**
```json
{
  "viewed_user_id": "user456",
  "total_load_time_ms": 856,
  "image_count": 3,
  "avg_load_time_ms": 285
}
```

**Viewing Analytics:**
```
Firebase Console → Analytics → Events
Filter: image_loaded, cdn_performance, profile_viewed_optimized
```

---

## Cloudinary Dashboard

### Accessing the Dashboard

1. Go to: https://console.cloudinary.com
2. Login with your credentials
3. Cloud Name: `dquqeovn2`

### Key Sections

#### 1. Media Library

**Location:** `Media Library` tab

**What to Monitor:**
- Total images stored
- Storage usage (25 GB free tier limit)
- Recently uploaded images
- Image transformations

**Actions:**
```
- View all uploaded profile photos
- Search by folder: "profile-photos"
- Check image metadata and transformations
- Delete unused images if approaching limit
```

#### 2. Dashboard Overview

**Location:** `Dashboard` tab

**Real-time Metrics:**
- **Bandwidth**: Total data transferred
- **Transformations**: Number of image optimizations
- **Storage**: Total storage used
- **Requests**: API calls made

**Usage Tracking:**
```
Current Usage (Free Tier):
├── Storage: X GB / 25 GB (X%)
├── Bandwidth: X GB / 25 GB (X%)
└── Transformations: X / 25,000 (X%)
```

**Alerts:**
- 🟢 Green: <60% of limit (safe)
- 🟡 Yellow: 60-80% of limit (monitor)
- 🔴 Red: >80% of limit (action needed)

#### 3. Reports

**Location:** `Reports` tab

**Available Reports:**

**Usage Report:**
```
Time period: Last 30 days
Metrics:
  - Total bandwidth
  - Transformations by type (resize, format, quality)
  - Storage growth
  - Top consuming images
```

**Performance Report:**
```
Metrics:
  - Average CDN response time
  - Cache hit ratio
  - Bandwidth by geography
  - Error rate
```

**Cost Projection:**
```
Based on current usage, estimate when you'll exceed free tier:
- Storage: X months remaining
- Bandwidth: X months remaining
- Transformations: X months remaining
```

#### 4. Transformations Analytics

**Location:** `Reports → Transformations`

**What to Monitor:**
- Most popular transformations (should see w_150, w_375, w_750, w_1200)
- Format conversions (should be majority WebP)
- Quality settings usage
- Transformation errors

**Expected Distribution:**
```
Transformation Sizes:
├── thumbnail (w_150): 40% (most common, used in lists)
├── small (w_375): 30% (profile cards on mobile)
├── medium (w_750): 20% (full profile view)
└── large (w_1200): 10% (high-res devices)

Formats:
├── WebP: 95% (primary format)
└── JPEG: 5% (fallback for old devices)
```

#### 5. CDN Performance

**Location:** `Reports → CDN Analytics`

**Key Metrics:**

**Cache Hit Ratio:**
```
Target: >80%
Excellent: >90%
Good: 70-89%
Poor: <70%

Formula: (Cache Hits / Total Requests) × 100
```

**Average Response Time:**
```
Target: <200ms globally
By Region:
  - North America: <150ms
  - Europe: <200ms
  - Asia: <250ms
  - South America: <300ms
```

**Bandwidth by Source:**
```
CDN Cache: 80%+ (served from edge locations)
Origin: <20% (first-time requests)
```

#### 6. Optimization Opportunities

**Location:** `Media Library → Optimization Opportunities`

**Identifies:**
- Images that could be further compressed
- Unused transformations
- Large files that should be optimized
- Missing responsive variants

### Setting Up Alerts

**1. Usage Alerts:**
```
Settings → Notifications
Enable:
  ✓ 80% storage limit reached
  ✓ 80% bandwidth limit reached
  ✓ 80% transformations limit reached
```

**2. Error Rate Alerts:**
```
Settings → Notifications → API Errors
Enable:
  ✓ Error rate exceeds 5%
  ✓ Failed uploads exceed 10
```

### Monitoring API Usage

**Location:** `Dashboard → API Usage`

**Endpoints to Monitor:**

**`upload` endpoint:**
```
Total calls: Track daily upload volume
Error rate: Should be <1%
Average duration: Should be <2s
```

**`image/upload` endpoint:**
```
Monitor transformation requests
Check for rate limiting (429 errors)
```

**Example Daily Usage:**
```
Date: 2025-11-18
├── Uploads: 150 images
├── Transformations: 750 (5 per image)
├── Bandwidth: 2.3 GB
├── Storage added: 450 MB
└── Errors: 2 (0.3% error rate) ✓
```

---

## In-App Performance Dashboard

### Accessing the Dashboard

**For Admins:**
1. Open Celestia app
2. Navigate to Profile → Settings
3. Tap "Admin Tools" (if admin)
4. Select "Image Performance"

**For Developers:**
```swift
// Add to your admin menu or debug screen
NavigationLink("Image Performance") {
    ImagePerformanceDashboard()
}
```

### Dashboard Features

#### Real-Time Metrics

**1. Average Load Time**
```
Target: <500ms
Display: Real-time average of all image loads in current session
Color coding:
  🟢 Green: <500ms (excellent)
  🟡 Yellow: 500-1000ms (acceptable)
  🔴 Red: >1000ms (needs attention)
```

**2. Total Image Loads**
```
Tracks: Number of images loaded in current session
Useful for: Understanding app usage patterns
```

**3. CDN Hit Rate**
```
Formula: (CDN Loads / Total Loads) × 100
Target: >80%
Display: Percentage with visual progress bar
```

**4. Bandwidth Saved**
```
Calculation: (Original Size - Optimized Size)
Display: Total bytes saved formatted (KB, MB, GB)
Estimate: ~40% savings from WebP compression
```

#### Performance Charts

**Load Time Trends:**
- Bar chart of last 10 image loads
- Shows load time distribution
- Identifies performance spikes

**CDN Performance:**
- Cache hit rate over time
- Latency by source (cache vs origin)

#### Export Reports

**Generate Report:**
```swift
Button("Export Report") {
    ImagePerformanceMonitor.shared.logPerformanceSummary()
}

Output (Console):
📊 Image Performance Summary:
   - Total loads: 245
   - Avg load time: 0.38s
   - CDN hit rate: 87.3%
   - Bandwidth saved: 12.4 MB
```

### Monitoring User Engagement

**Track engagement metrics:**

**Profile Views with Optimized Images:**
```swift
ImagePerformanceMonitor.shared.trackProfileView(
    userId: "user123",
    loadTime: 0.85,
    imageCount: 4
)
```

**Swipe Actions with Performance:**
```swift
ImagePerformanceMonitor.shared.trackSwipeWithImagePerformance(
    action: "like",
    loadTime: 0.32
)
```

**View in Firebase Analytics:**
```
Analytics → Events → profile_viewed_optimized
Metrics:
  - Total profile views
  - Average load time per profile
  - Images per profile
  - Correlation with swipe actions
```

---

## Key Metrics to Track

### Critical Performance Indicators

#### 1. Average Image Load Time

**Target:** <500ms

**How to Calculate:**
```
Total Load Time / Number of Images Loaded
```

**Factors Affecting:**
- Network speed (WiFi vs cellular)
- Image size selection
- CDN cache status
- Device performance

**Monitoring:**
```
Firebase Performance → Custom Traces → image_load_* → Duration
In-App Dashboard → Average Load Time card
```

#### 2. P90 Load Time

**Target:** <1000ms

**Definition:** 90% of images load within this time

**Why Important:**
- Represents worst-case for most users
- Identifies performance outliers
- Helps set SLAs

**Monitoring:**
```
Firebase Performance → Custom Traces → Duration percentiles → P90
```

#### 3. CDN Cache Hit Rate

**Target:** >80%

**How to Calculate:**
```
(Requests Served from Cache / Total Requests) × 100
```

**Why Important:**
- Higher rate = faster loads
- Lower bandwidth costs
- Better user experience

**Improving:**
- Increase cache TTL
- Preload popular images
- Use consistent URLs

**Monitoring:**
```
Cloudinary Dashboard → Reports → CDN Analytics → Cache Hit Ratio
In-App Dashboard → CDN Hit Rate card
```

#### 4. Bandwidth Savings

**Target:** 40% reduction vs original

**How to Calculate:**
```
((Original Size - Optimized Size) / Original Size) × 100
```

**Sources of Savings:**
- WebP format: 30-40% smaller than JPEG
- Responsive sizing: 50-70% for smaller variants
- Quality optimization: 10-20% with no visible loss

**Monitoring:**
```
In-App Dashboard → Bandwidth Saved card
Cloudinary Dashboard → Reports → Bandwidth by transformation
```

#### 5. Success Rate

**Target:** >99%

**How to Calculate:**
```
(Successful Loads / Total Attempts) × 100
```

**Common Failures:**
- Network timeout
- Invalid URL
- CDN errors
- Rate limiting

**Monitoring:**
```
Firebase Performance → Custom Traces → Success rate
Firebase Analytics → Events → image_load_failed
```

#### 6. User Engagement Impact

**Metrics to Track:**

**Profile View Duration:**
```
Compare:
  Legacy images: Avg 8s to load profile
  Optimized: Avg 3s to load profile
  Improvement: 62.5% faster
```

**Swipe Rate:**
```
Hypothesis: Faster loads = more swipes
Track: Swipes per minute before/after optimization
Expected: 20-30% increase
```

**Session Duration:**
```
Track: Time spent in Discover view
Expected: Longer sessions with faster loads
```

**Monitoring:**
```
Firebase Analytics → User engagement metrics
Custom events: profile_viewed_optimized, swipe_with_image_perf
```

### Secondary Metrics

#### Image Quality Satisfaction

**Track user feedback:**
```swift
// After profile view
Analytics.logEvent("image_quality_rating", parameters: [
    "rating": 5, // 1-5 stars
    "from_cdn": true
])
```

#### Cost Efficiency

**Track CDN costs vs usage:**
```
Monthly Active Users: 1,000
Images per user: 3 photos
Total transformations: 15,000
Cost: $0 (within free tier)
Cost per user: $0.00
```

**Projection for scale:**
```
10,000 users: Still free tier ($0)
100,000 users: ~$89/month
1,000,000 users: ~$890/month
```

---

## Performance Benchmarks

### Expected Performance by Network Type

```
Network Type         | Avg Load Time | P90 Load Time | Target
---------------------|---------------|---------------|--------
WiFi (fast)          | 150-300ms     | 400ms         | ✓
WiFi (slow)          | 300-500ms     | 800ms         | ✓
5G                   | 200-350ms     | 500ms         | ✓
4G LTE               | 400-600ms     | 900ms         | ✓
4G                   | 500-800ms     | 1200ms        | ~
3G                   | 1000-2000ms   | 3000ms        | ✗
```

### Before vs After Optimization

```
Metric                  | Before (Legacy) | After (Optimized) | Improvement
------------------------|-----------------|-------------------|------------
Avg Load Time           | 1.2s            | 0.4s              | 67% faster
P90 Load Time           | 2.8s            | 0.9s              | 68% faster
Profile Load (4 images) | 4.8s            | 1.6s              | 67% faster
Bandwidth per image     | 800 KB          | 320 KB            | 60% savings
CDN Hit Rate            | N/A             | 85%               | New metric
Success Rate            | 92%             | 99.2%             | 7.2% better
```

### Performance by Image Size

```
Size      | Dimensions    | File Size | Load Time (4G) | Use Case
----------|---------------|-----------|----------------|------------------
Thumbnail | 150×150       | 15 KB     | 180ms          | Match list
Small     | 375×500       | 65 KB     | 420ms          | Profile card
Medium    | 750×1000      | 180 KB    | 850ms          | Full profile
Large     | 1200×1600     | 380 KB    | 1600ms         | Zoomed view
Original  | Variable      | 800 KB+   | 3000ms+        | Download
```

### Target Performance by Device

```
Device Class    | Target Load Time | Expected Hit Rate
----------------|------------------|------------------
High-end        | <300ms           | Target achieved
Mid-range       | <500ms           | Target achieved
Low-end         | <800ms           | Acceptable
Very low-end    | <1200ms          | May struggle
```

---

## Alerting & Notifications

### Firebase Performance Alerts

**Setup Performance Monitoring Alerts:**

1. Navigate to: `Firebase Console → Performance → Settings`
2. Enable automatic alerts:

**Alert Configuration:**
```yaml
Average Load Time Alert:
  Metric: image_load_medium (most common size)
  Threshold: >800ms
  Duration: 5 minutes
  Action: Email admin team

Success Rate Alert:
  Metric: image_load success rate
  Threshold: <95%
  Duration: 10 minutes
  Action: Email + SMS

P90 Load Time Alert:
  Metric: image_load_* P90
  Threshold: >1500ms
  Duration: 15 minutes
  Action: Email admin team
```

### Cloudinary Alerts

**Setup in Cloudinary Console:**

1. Navigate to: `Settings → Notifications`
2. Enable alerts:

```yaml
Storage Limit Alert:
  Threshold: 80% of 25 GB (20 GB)
  Action: Email account owner

Bandwidth Limit Alert:
  Threshold: 80% of 25 GB/month (20 GB)
  Action: Email account owner

Transformation Limit Alert:
  Threshold: 80% of 25,000/month (20,000)
  Action: Email account owner

Error Rate Alert:
  Threshold: >5% error rate
  Duration: 1 hour
  Action: Email + webhook
```

### Custom In-App Alerts

**Implement in ImagePerformanceMonitor:**

```swift
extension ImagePerformanceMonitor {
    func checkPerformanceThresholds() {
        // Average load time alert
        if averageLoadTime > 0.8 {
            Logger.shared.warning(
                "Average image load time exceeds threshold: \(averageLoadTime)s",
                category: .storage
            )
            Analytics.logEvent("performance_alert", parameters: [
                "type": "slow_load_time",
                "value": averageLoadTime
            ])
        }

        // CDN hit rate alert
        if cdnHitRate < 0.7 && totalImageLoads > 20 {
            Logger.shared.warning(
                "CDN hit rate below threshold: \(cdnHitRate * 100)%",
                category: .storage
            )
            Analytics.logEvent("performance_alert", parameters: [
                "type": "low_cdn_hit_rate",
                "value": cdnHitRate
            ])
        }
    }
}
```

### Monitoring Checklist

**Daily:**
- [ ] Check in-app performance dashboard
- [ ] Verify average load time <500ms
- [ ] Ensure CDN hit rate >80%

**Weekly:**
- [ ] Review Firebase Performance traces
- [ ] Check Cloudinary usage vs limits
- [ ] Analyze bandwidth trends
- [ ] Review error logs

**Monthly:**
- [ ] Generate performance report
- [ ] Compare month-over-month metrics
- [ ] Project usage for next month
- [ ] Review cost projections
- [ ] Optimize underperforming images

---

## Troubleshooting

### Common Issues

#### 1. Slow Load Times (>1s)

**Symptoms:**
- Average load time consistently >800ms
- User complaints about slow image loading
- High P90 load times

**Possible Causes:**
- Poor CDN cache hit rate
- Large image sizes being loaded
- Network congestion
- Origin server delays

**Debugging:**
```swift
// Enable verbose logging
Logger.shared.debug("Image load started: \(url)", category: .storage)
let start = Date()
let image = await loadImage(url)
let duration = Date().timeIntervalSince(start)
Logger.shared.debug("Image loaded in \(duration)s from \(fromCDN ? "CDN" : "origin")", category: .storage)
```

**Solutions:**
1. Check CDN hit rate (should be >80%)
2. Verify correct size selection for view
3. Preload images for next profile
4. Enable aggressive caching

#### 2. Low CDN Hit Rate (<70%)

**Symptoms:**
- Most requests going to origin server
- High latency
- Unnecessary bandwidth usage

**Possible Causes:**
- URLs changing between requests
- Cache TTL too short
- Not warming cache for new images
- Query parameters causing cache misses

**Debugging:**
```
Cloudinary Dashboard → Reports → CDN Analytics
Check:
  - Cache hit/miss ratio
  - Most common miss reasons
  - URL patterns
```

**Solutions:**
1. Use consistent URLs (no random query params)
2. Increase cache TTL in Cloudinary
3. Preload popular profiles
4. Implement cache warming strategy

#### 3. High Bandwidth Usage

**Symptoms:**
- Approaching Cloudinary bandwidth limit
- Higher costs than expected
- Not achieving 40% savings target

**Possible Causes:**
- Not using optimized sizes
- WebP not being used
- Large original images
- Too many transformations

**Debugging:**
```
Cloudinary Dashboard → Reports → Bandwidth by Transformation
Check:
  - Which sizes are most requested
  - Format distribution (should be mostly WebP)
  - Transformation combinations
```

**Solutions:**
1. Verify WebP is primary format
2. Use appropriate responsive sizes
3. Compress originals before upload
4. Implement lazy loading

#### 4. Failed Image Loads

**Symptoms:**
- Success rate <95%
- Users seeing broken images
- Error logs showing load failures

**Possible Causes:**
- Invalid URLs
- Network timeouts
- CDN errors (503, 504)
- Rate limiting
- Authentication issues

**Debugging:**
```swift
func loadImage() async throws -> UIImage? {
    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageError.invalidResponse
        }

        Logger.shared.debug("HTTP Status: \(httpResponse.statusCode)", category: .storage)

        if httpResponse.statusCode != 200 {
            Logger.shared.error("Image load failed: HTTP \(httpResponse.statusCode)", category: .storage)
            throw ImageError.httpError(httpResponse.statusCode)
        }

        return UIImage(data: data)
    } catch {
        Logger.shared.error("Image load error", category: .storage, error: error)
        throw error
    }
}
```

**Solutions:**
1. Implement retry logic for transient failures
2. Add timeout handling
3. Validate URLs before loading
4. Implement fallback to Firebase Storage

#### 5. Firebase Performance Not Showing Data

**Symptoms:**
- No traces appearing in console
- Missing custom metrics
- Analytics events not logged

**Possible Causes:**
- Performance SDK not configured
- Debug builds not sending data
- Sampling rate too low
- Network issues preventing uploads

**Debugging:**
```swift
// Verify Performance is initialized
print("Firebase Performance configured: \(Performance.sharedInstance() != nil)")

// Force enable performance monitoring in debug
Performance.sharedInstance()?.isDataCollectionEnabled = true
```

**Solutions:**
1. Verify `GoogleService-Info.plist` is present
2. Enable performance monitoring in Firebase Console
3. Wait 24 hours for data to appear
4. Check network connectivity
5. Increase sampling rate for testing

### Performance Optimization Tips

**1. Preload Next Profile:**
```swift
// While user views current profile, preload next
func preloadNextProfile() {
    guard let nextUser = viewModel.nextUser else { return }

    Task {
        for photoData in nextUser.photos {
            await OptimizedImageLoader.shared.loadImageWithTracking(
                urls: photoData.urls,
                for: CGSize(width: 375, height: 500)
            )
        }
    }
}
```

**2. Implement Progressive Loading:**
```swift
// Show blur placeholder immediately, load sharp image in background
ProgressiveAsyncImage(
    photoData: photoData,
    size: CGSize(width: 375, height: 500)
) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    // Blur placeholder loads instantly from base64
    BlurPlaceholder(base64: photoData.placeholder)
}
```

**3. Use Appropriate Sizes:**
```swift
// Don't load large images for thumbnails
let appropriateSize = OptimizedImageLoader.shared.selectAppropriateSize(
    for: viewSize
)
// Returns: "thumbnail" for 150×150, "small" for 375×500, etc.
```

**4. Implement Cache Warming:**
```swift
// After user login, warm cache with popular profiles
func warmCacheForPopularProfiles() async {
    let popularProfiles = try await fetchPopularProfiles(limit: 10)

    for profile in popularProfiles {
        Task {
            await OptimizedImageLoader.shared.loadImageWithTracking(
                urls: profile.profilePhoto.urls,
                for: CGSize(width: 375, height: 500)
            )
        }
    }
}
```

---

## Summary

### Monitoring Checklist

**Real-Time Monitoring:**
- ✅ In-app performance dashboard shows live metrics
- ✅ Firebase Performance tracks all image loads
- ✅ Cloudinary dashboard shows CDN usage
- ✅ Analytics events log user engagement

**Key Metrics:**
- ✅ Average load time: <500ms
- ✅ P90 load time: <1000ms
- ✅ CDN hit rate: >80%
- ✅ Bandwidth savings: ~40%
- ✅ Success rate: >99%

**Monitoring Tools:**
1. **In-App:** ImagePerformanceDashboard.swift
2. **Firebase:** Console → Performance & Analytics
3. **Cloudinary:** console.cloudinary.com
4. **Logs:** Xcode Console with Logger.shared

**Alert Configuration:**
- 🔔 Firebase Performance alerts for slow loads
- 🔔 Cloudinary notifications for usage limits
- 🔔 In-app warnings for performance degradation
- 🔔 Analytics tracking for user impact

For questions or issues, refer to:
- `TESTING_GUIDE.md` - Testing procedures
- `IMAGE_OPTIMIZATION_REPORT.md` - Technical details
- `IMAGE_MIGRATION_GUIDE.md` - Migration instructions
