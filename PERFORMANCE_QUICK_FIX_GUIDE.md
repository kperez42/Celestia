# Quick Fix Guide - Performance Issues

## Critical Issues (Fix ASAP)

### 1. ProfileViewersView.swift - Lines 336-351
**Issue:** N+1 Query - fetches 1 viewer list + 50 individual user queries

**Quick Fix:** Use batch `whereIn()` instead of loop with individual queries
```
Current Cost: 51 reads per view
Fixed Cost: 5 reads per view
Time: 30 min
```

---

### 2. ReferralManager.swift - Lines 260-273  
**Issue:** Loop with 100 extra queries from getReferralStats() calls

**Quick Fix:** Use QueryCache or denormalize stats into users collection
```
Current Cost: ~100 reads per leaderboard load
Fixed Cost: ~5 reads
Time: 45 min
```

---

### 3. LikeActivityView.swift - Lines 260-343
**Issue:** Gets 130+ likes but doesn't batch fetch user details

**Quick Fix:** Add batch user fetch after collecting activity IDs
```
Current Cost: 130+ reads
Fixed Cost: 8 reads  
Time: 1 hour
```

---

## High Severity Issues

### 4. SearchManager.swift - Line 103
**Issue:** Loads 100 results without pagination cursor

**Quick Fix:** Implement cursor-based pagination like UserService
```
Current: 100 docs loaded
Fixed: 20 docs, paginated
Time: 30 min
```

---

### 5. SavedProfilesView.swift - Lines 470-548
**Issue:** No caching - 6 reads every time view loads

**Quick Fix:** Add QueryCache wrapper
```
Current: 6 reads per load
Fixed: 0 reads (cached for 5 min)
Time: 45 min
```

---

### 6. AnalyticsServiceEnhanced.swift - Lines 83-91
**Issue:** Triple iteration over same data

**Quick Fix:** Single pass with categorization
```
Current: O(3n) iterations
Fixed: O(n) iteration
Time: 20 min
```

---

### 7. DiscoverView.swift - Line 185
**Issue:** Filter runs in view body, every render

**Quick Fix:** Move to ViewModel as @Published var
```
Current: Janky UI updates
Fixed: Smooth responsive UI
Time: 30 min
```

---

## Medium Severity Issues

### 8. FirestoreMessageRepository.swift - Lines 17-29
Add DocumentSnapshot cursor parameter to fetchMessages()
**Time:** 30 min

### 9. SearchManager.swift - Lines 144-175  
Move filter logic to Firestore queries
**Time:** 30 min

### 10. MatchesView.swift - Lines 38-94
Pre-compute filtered/sorted results in ViewModel
**Time:** 45 min

### 11. firestore.indexes.json
Add 3 composite indexes for likes, messages, saved_profiles
**Time:** 15 min

### 12. InterestService.swift - Lines 82-149
Parallelize interest checks with async let
**Time:** 30 min

---

## Implementation Checklist

### Week 1 (Critical Fixes)
- [ ] Fix ProfileViewersView N+1 (30 min)
- [ ] Fix ReferralManager batch (45 min)  
- [ ] Fix LikeActivityView batch (1 hr)
- [ ] Add database indexes (15 min)

**Expected Result:** 60-70% fewer database reads

### Week 2-3 (High Impact Fixes)
- [ ] SavedProfiles caching (45 min)
- [ ] AnalyticsServiceEnhanced fix (20 min)
- [ ] DiscoverView VM filtering (30 min)
- [ ] Search pagination (30 min)

**Expected Result:** Smoother UI, faster interactions

### Week 4+ (Medium Priority)
- [ ] Message cursor pagination (30 min)
- [ ] MatchesView sorting (45 min)
- [ ] Search Firestore filters (30 min)
- [ ] InterestService parallelize (30 min)

---

## Monitoring

After fixes, monitor these metrics:
- Firestore reads/session: Target <100/day
- Cache hit rate: Target >70%
- P95 query latency: Target <500ms
- View render time: Target <60ms

