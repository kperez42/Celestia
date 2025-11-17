# Sophisticated Matching Algorithm Implementation Plan

**Status**: 🔴 CRITICAL PRIORITY
**Current State**: Basic `lastActive` sorting only
**Target State**: Multi-factor compatibility scoring with ML
**Impact**: Core product value, competitive differentiation
**Effort**: 2-3 weeks

---

## Current Implementation Analysis

**File**: `Celestia/UserService.swift:62`

**Current Algorithm**:
```swift
.order(by: "lastActive", descending: true)
```

**What This Means**:
- Shows most recently active users first
- No personalization
- No compatibility consideration
- No interest matching
- No behavioral signals

**Result**: Random matches with no optimization for compatibility

---

## Proposed Matching Algorithm

### Multi-Factor Scoring System

```swift
// Create: Celestia/Matching/MatchingAlgorithm.swift

struct MatchScore {
    let userId: String
    let totalScore: Double      // 0-100
    let breakdown: ScoreBreakdown
}

struct ScoreBreakdown {
    let interestSimilarity: Double    // 30% weight
    let proximityScore: Double        // 25% weight
    let activityScore: Double         // 20% weight
    let attractivenessScore: Double   // 15% weight
    let behavioralScore: Double       // 10% weight
}

class MatchingAlgorithm {
    // Weights can be A/B tested
    private let weights = [
        "interests": 0.30,
        "proximity": 0.25,
        "activity": 0.20,
        "attractiveness": 0.15,
        "behavioral": 0.10
    ]

    func calculateMatchScore(
        currentUser: User,
        candidate: User,
        behavioralData: BehavioralData?
    ) -> MatchScore {

        let interestScore = calculateInterestSimilarity(
            currentUser.interests,
            candidate.interests
        )

        let proximityScore = calculateProximityScore(
            currentUser.location,
            candidate.location,
            currentUser.maxDistance
        )

        let activityScore = calculateActivityScore(candidate)

        let attractivenessScore = calculateAttractivenessScore(
            candidate,
            basedOn: behavioralData
        )

        let behavioralScore = calculateBehavioralScore(
            currentUser,
            candidate,
            behavioralData
        )

        let totalScore =
            interestScore * weights["interests"]! +
            proximityScore * weights["proximity"]! +
            activityScore * weights["activity"]! +
            attractivenessScore * weights["attractiveness"]! +
            behavioralScore * weights["behavioral"]!

        return MatchScore(
            userId: candidate.id!,
            totalScore: totalScore * 100,
            breakdown: ScoreBreakdown(
                interestSimilarity: interestScore * 100,
                proximityScore: proximityScore * 100,
                activityScore: activityScore * 100,
                attractivenessScore: attractivenessScore * 100,
                behavioralScore: behavioralScore * 100
            )
        )
    }
}
```

---

## Component Algorithms

### 1. Interest Similarity (30% weight)

**Algorithm**: Jaccard Similarity Coefficient

```swift
func calculateInterestSimilarity(_ userA: [String], _ userB: [String]) -> Double {
    // Jaccard similarity: intersection / union
    let setA = Set(userA)
    let setB = Set(userB)

    let intersection = setA.intersection(setB).count
    let union = setA.union(setB).count

    guard union > 0 else { return 0.0 }

    let jaccardScore = Double(intersection) / Double(union)

    // Bonus for multiple shared interests
    let sharedBonus = min(Double(intersection) * 0.1, 0.3)

    return min(jaccardScore + sharedBonus, 1.0)
}
```

**Example**:
```
User A interests: [Hiking, Photography, Coffee, Travel, Music]
User B interests: [Coffee, Travel, Yoga, Reading, Music]

Intersection: 3 (Coffee, Travel, Music)
Union: 8 (all unique interests)
Jaccard: 3/8 = 0.375
Bonus: 3 * 0.1 = 0.3
Final: min(0.375 + 0.3, 1.0) = 0.675 (67.5%)
```

**Enhancement**: Weight popular interests less (Travel common, Skydiving rare = higher score)

---

### 2. Proximity Score (25% weight)

**Algorithm**: Distance decay with preference consideration

```swift
func calculateProximityScore(
    _ userLocation: CLLocation,
    _ candidateLocation: CLLocation,
    _ maxDistanceKm: Int
) -> Double {
    let distanceKm = userLocation.distance(from: candidateLocation) / 1000

    // If beyond max distance, return 0
    guard distanceKm <= Double(maxDistanceKm) else { return 0.0 }

    // Exponential decay: closer = better
    // Score = e^(-distance / decay_factor)
    let decayFactor = Double(maxDistanceKm) / 3.0
    let score = exp(-distanceKm / decayFactor)

    return score
}
```

**Distance Score Examples**:
```
Max distance: 50km
- 5km away:  score = 0.95 (excellent)
- 15km away: score = 0.80 (good)
- 30km away: score = 0.55 (decent)
- 50km away: score = 0.30 (far)
- 60km away: score = 0.00 (too far)
```

**Firestore Integration**:
```swift
// Add geohash to User model
extension User {
    var geohash: String {
        guard let lat = latitude, let lon = longitude else { return "" }
        return GeoFire.geohashQueryBounds(
            forLocation: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            withRadius: Double(maxDistance) * 1000
        ).first?.startValue ?? ""
    }
}

// Query nearby users
let geoQuery = db.collection("users")
    .whereField("geohash", isGreaterThanOrEqualTo: startGeoHash)
    .whereField("geohash", isLessThanOrEqualTo: endGeoHash)
```

---

### 3. Activity Score (20% weight)

**Algorithm**: Recency and engagement combination

```swift
func calculateActivityScore(_ candidate: User) -> Double {
    guard let lastActive = candidate.lastActive else { return 0.0 }

    let hoursSinceActive = Date().timeIntervalSince(lastActive) / 3600

    // Recency score (last 24 hours = best)
    let recencyScore: Double
    switch hoursSinceActive {
    case 0..<1:    recencyScore = 1.0    // Online now
    case 1..<6:    recencyScore = 0.9    // Recently active
    case 6..<24:   recencyScore = 0.7    // Active today
    case 24..<72:  recencyScore = 0.4    // Last 3 days
    case 72..<168: recencyScore = 0.2    // Last week
    default:       recencyScore = 0.1    // Inactive
    }

    // Engagement score (profile completeness)
    let profileCompleteness = Double(candidate.profileCompletion) / 100.0

    // Response rate (if available from behavioral data)
    let responseRate = candidate.averageResponseRate ?? 0.5

    // Combine: 50% recency, 30% completeness, 20% responsiveness
    return (recencyScore * 0.5) +
           (profileCompleteness * 0.3) +
           (responseRate * 0.2)
}
```

---

### 4. Attractiveness Score (15% weight)

**Algorithm**: Collaborative filtering based on swipe patterns

```swift
func calculateAttractivenessScore(
    _ candidate: User,
    basedOn behavioralData: BehavioralData?
) -> Double {
    guard let behavioral = behavioralData else {
        // Fallback: use photo count and verification
        let hasPhotos = !candidate.photos.isEmpty
        let isVerified = candidate.isVerified
        return (hasPhotos ? 0.5 : 0.0) + (isVerified ? 0.5 : 0.0)
    }

    // ELO-style rating based on swipe outcomes
    // High ELO = frequently liked, rarely passed
    let eloScore = behavioral.eloRating / 2000.0 // Normalize to 0-1

    // Photo quality score (if using Vision API)
    let photoScore = candidate.photoQualityScore ?? 0.5

    // Like-to-view ratio
    let likeRatio = Double(candidate.likesReceived) /
                    Double(max(candidate.profileViews, 1))
    let normalizedLikeRatio = min(likeRatio, 1.0)

    // Combine: 50% ELO, 30% like ratio, 20% photo quality
    return (eloScore * 0.5) +
           (normalizedLikeRatio * 0.3) +
           (photoScore * 0.2)
}

// ELO Rating Update (after each swipe)
func updateEloRating(
    winner: inout User,  // User who got liked
    loser: inout User,    // User who got passed
    kFactor: Double = 32
) {
    let expectedWinner = 1.0 / (1.0 + pow(10, (loser.eloRating - winner.eloRating) / 400.0))
    let expectedLoser = 1.0 / (1.0 + pow(10, (winner.eloRating - loser.eloRating) / 400.0))

    winner.eloRating += kFactor * (1.0 - expectedWinner)
    loser.eloRating += kFactor * (0.0 - expectedLoser)
}
```

**Data Model Addition**:
```swift
extension User {
    var eloRating: Double = 1500.0  // Starting ELO
    var photoQualityScore: Double?
    var averageResponseRate: Double?
}
```

---

### 5. Behavioral Score (10% weight)

**Algorithm**: Past interaction patterns predict future compatibility

```swift
struct BehavioralData {
    let userId: String
    let typicalResponseTime: TimeInterval?
    let averageMessageLength: Int?
    let preferredActivityTimes: [HourRange]
    let swipePatterns: SwipePatterns
    let matchSuccessRate: Double
}

struct SwipePatterns {
    let likesAgeRange: ClosedRange<Int>
    let prefersVerified: Bool
    let prefersWithBio: Bool
    let minimumPhotoCount: Int
}

func calculateBehavioralScore(
    _ currentUser: User,
    _ candidate: User,
    _ behavioralData: BehavioralData?
) -> Double {
    guard let behavioral = behavioralData else { return 0.5 }

    var score = 0.0
    var factors = 0

    // 1. Age preference alignment
    if behavioral.swipePatterns.likesAgeRange.contains(candidate.age) {
        score += 1.0
    }
    factors += 1

    // 2. Verification preference
    if !behavioral.swipePatterns.prefersVerified || candidate.isVerified {
        score += 1.0
    }
    factors += 1

    // 3. Bio preference
    if !behavioral.swipePatterns.prefersWithBio || !candidate.bio.isEmpty {
        score += 1.0
    }
    factors += 1

    // 4. Photo count preference
    if candidate.photos.count >= behavioral.swipePatterns.minimumPhotoCount {
        score += 1.0
    }
    factors += 1

    // 5. Similar activity patterns (online at same times)
    let activityOverlap = calculateActivityOverlap(
        behavioral.preferredActivityTimes,
        candidate.activityPattern ?? []
    )
    score += activityOverlap
    factors += 1

    return score / Double(factors)
}

func calculateActivityOverlap(
    _ userPattern: [HourRange],
    _ candidatePattern: [HourRange]
) -> Double {
    var overlapHours = 0
    for userRange in userPattern {
        for candidateRange in candidatePattern {
            let overlap = userRange.intersection(candidateRange)
            overlapHours += overlap?.count ?? 0
        }
    }
    return Double(overlapHours) / 24.0 // Normalize to 0-1
}
```

**Data Collection**:
```swift
// Track behavioral data
class BehavioralTracker {
    func recordSwipe(userId: String, targetUserId: String, action: SwipeAction) {
        let target = try await userService.fetchUser(userId: targetUserId)

        // Update swipe patterns
        if action == .like {
            // Track age preferences
            behavioralData.swipePatterns.updateAgePreference(target.age)

            // Track verification preference
            if target.isVerified {
                behavioralData.swipePatterns.verifiedLikeCount += 1
            }
        }

        // Save to Firestore
        db.collection("behavioral_data").document(userId).setData(behavioralData)
    }
}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

**Tasks**:
1. Add new fields to User model
   ```swift
   extension User {
       var eloRating: Double = 1500.0
       var photoQualityScore: Double?
       var averageResponseRate: Double?
       var activityPattern: [HourRange]?
       var geohash: String?
   }
   ```

2. Create BehavioralData collection in Firestore
   ```typescript
   // Firestore structure
   behavioral_data/
     {userId}/
       swipePatterns: { ... }
       activityTimes: [ ... ]
       responseRate: 0.75
       averageMessageLength: 42
   ```

3. Create MatchingAlgorithm.swift
4. Add unit tests for each scoring function

**Deliverable**: Scoring algorithms implemented and tested

---

### Phase 2: Data Collection (Week 2)

**Tasks**:
1. Implement BehavioralTracker
2. Add swipe event tracking
3. Add message response time tracking
4. Add activity pattern tracking
5. Backfill existing user data

**Migration Script**:
```typescript
// CloudFunctions/migrations/backfillBehavioralData.js
exports.backfillBehavioralData = async () => {
    const users = await admin.firestore().collection('users').get()

    for (const userDoc of users.docs) {
        const userId = userDoc.id

        // Calculate ELO from historical swipes
        const swipes = await admin.firestore()
            .collection('likes')
            .where('targetUserId', '==', userId)
            .get()

        const likes = swipes.docs.filter(d => d.data().action === 'like')
        const views = userDoc.data().profileViews || 1
        const eloRating = 1500 + ((likes.length / views) * 1000)

        // Calculate response rate
        const messages = await admin.firestore()
            .collection('messages')
            .where('senderId', '==', userId)
            .get()

        // Update user
        await userDoc.ref.update({
            eloRating: eloRating,
            messageCount: messages.size
        })
    }
}
```

**Deliverable**: Behavioral data collected for all users

---

### Phase 3: Algorithm Integration (Week 3)

**Tasks**:
1. Modify UserService.fetchUsers() to use matching algorithm
2. Implement score caching (5-minute TTL)
3. Add performance monitoring
4. A/B test: old algorithm vs new

**Implementation**:
```swift
// Celestia/UserService.swift - Updated
func fetchUsers(
    for currentUser: User,
    limit: Int = 20
) async throws -> [User] {
    // 1. Get candidates from Firestore
    let candidates = try await fetchCandidates(
        currentUser: currentUser,
        limit: limit * 3  // Fetch 3x, then score and sort
    )

    // 2. Calculate match scores
    let matchingAlgorithm = MatchingAlgorithm()
    let behavioralData = try? await fetchBehavioralData(userId: currentUser.id!)

    var scoredUsers: [(User, MatchScore)] = []

    for candidate in candidates {
        let score = matchingAlgorithm.calculateMatchScore(
            currentUser: currentUser,
            candidate: candidate,
            behavioralData: behavioralData
        )
        scoredUsers.append((candidate, score))
    }

    // 3. Sort by match score
    scoredUsers.sort { $0.1.totalScore > $1.1.totalScore }

    // 4. Return top matches
    let topMatches = Array(scoredUsers.prefix(limit)).map { $0.0 }

    // 5. Cache scores for analytics
    await cacheMatchScores(scoredUsers)

    // 6. Log for analysis
    Logger.shared.info(
        "Showed \(topMatches.count) users with avg score: \(averageScore)",
        category: .matching
    )

    return topMatches
}

// Cache scores for later analysis
func cacheMatchScores(_ scores: [(User, MatchScore)]) async {
    let cache = scores.map { user, score in
        [
            "userId": user.id!,
            "score": score.totalScore,
            "breakdown": [
                "interests": score.breakdown.interestSimilarity,
                "proximity": score.breakdown.proximityScore,
                "activity": score.breakdown.activityScore,
                "attractiveness": score.breakdown.attractivenessScore,
                "behavioral": score.breakdown.behavioralScore
            ]
        ]
    }

    // Store in Redis or Firestore cache collection
    try? await db.collection("match_score_cache")
        .document(currentUser.id!)
        .setData(["scores": cache, "timestamp": FieldValue.serverTimestamp()])
}
```

**Deliverable**: New algorithm deployed with A/B testing

---

## A/B Testing Plan

### Experiment Setup

**Hypothesis**: Multi-factor matching algorithm will increase:
- Match quality (response rate)
- User engagement (session duration)
- Premium conversion
- User retention

**Experiment Design**:
```swift
// ABTestingManager integration
let matchingExperiment = ABTest(
    name: "sophisticated_matching_v1",
    variants: [
        .control: 0.5,   // 50% see old algorithm
        .treatment: 0.5  // 50% see new algorithm
    ],
    targetAudience: .allUsers
)

// In UserService.fetchUsers()
let variant = ABTestingManager.shared.getVariant(
    experiment: "sophisticated_matching_v1",
    userId: currentUser.id!
)

if variant == .treatment {
    // Use new matching algorithm
    return try await fetchUsersWithMatching(currentUser, limit)
} else {
    // Use old algorithm (lastActive sort)
    return try await fetchUsersLegacy(currentUser, limit)
}
```

### Success Metrics

**Primary Metrics** (after 2 weeks):
- Match rate: Control vs Treatment
- Message response rate: Control vs Treatment
- Matches leading to conversations: Control vs Treatment

**Secondary Metrics**:
- Session duration
- Swipes per session
- Premium conversion rate
- Day 7 retention

**Target Improvements**:
- 20-30% increase in match quality
- 15-25% increase in response rate
- 10-15% more matches per user

### Rollout Plan

**Week 1**: 10% traffic
- Monitor for bugs
- Check performance impact

**Week 2**: 25% traffic
- Analyze early metrics
- Gather user feedback

**Week 3**: 50% traffic
- Full A/B comparison
- Statistical significance

**Week 4**: 100% rollout or rollback
- Decision based on metrics
- Document learnings

---

## Machine Learning Enhancement (Phase 4 - Future)

### Collaborative Filtering Model

**Goal**: Learn from successful matches to predict compatibility

**Approach**: Matrix factorization (similar to Netflix recommendations)

```python
# Train model using historical match data
import tensorflow as tf

class MatchRecommender(tf.keras.Model):
    def __init__(self, num_users, num_candidates, embedding_dim=50):
        super().__init__()
        self.user_embedding = tf.keras.layers.Embedding(
            num_users, embedding_dim
        )
        self.candidate_embedding = tf.keras.layers.Embedding(
            num_candidates, embedding_dim
        )

    def call(self, user_id, candidate_id):
        user_vector = self.user_embedding(user_id)
        candidate_vector = self.candidate_embedding(candidate_id)
        return tf.reduce_sum(user_vector * candidate_vector, axis=1)

# Training data: (user_id, candidate_id, outcome)
# outcome: 1 = mutual match, 0.5 = one-way like, 0 = pass
```

**Integration**:
```swift
// Call ML model via Cloud Function
func getMLMatchScore(userId: String, candidateId: String) async -> Double {
    let response = try await BackendAPIService.shared.mlMatchPrediction(
        userId: userId,
        candidateId: candidateId
    )
    return response.score
}

// Use as 6th factor (5% weight)
let mlScore = await getMLMatchScore(currentUser.id!, candidate.id!)
totalScore += mlScore * 0.05
```

**Timeline**: 3-6 months after Phase 3 launch

---

## Performance Considerations

### Caching Strategy

**Problem**: Scoring 60+ users per fetch is CPU intensive

**Solution**: Multi-level caching

```swift
// 1. In-memory cache (60 seconds)
private var scoreCache = [String: (MatchScore, Date)]()

// 2. Query result cache (5 minutes)
private let scoreCacheManager = QueryCache<[MatchScore]>(ttl: 300)

// 3. Firestore cache collection (30 minutes)
// Periodically pre-compute scores for active users
```

### Database Optimization

**Add Firestore indexes for scoring queries**:
```json
{
  "collectionGroup": "users",
  "fields": [
    { "fieldPath": "geohash", "order": "ASCENDING" },
    { "fieldPath": "lastActive", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "users",
  "fields": [
    { "fieldPath": "eloRating", "order": "DESCENDING" },
    { "fieldPath": "isOnline", "order": "DESCENDING" }
  ]
}
```

### Monitoring

**Track algorithm performance**:
```swift
let start = Date()
let scores = matchingAlgorithm.calculateScores(...)
let duration = Date().timeIntervalSince(start)

AnalyticsManager.shared.logEvent(.matchingPerformance, parameters: [
    "duration_ms": duration * 1000,
    "candidates_scored": candidates.count,
    "average_score": scores.map(\.totalScore).average()
])
```

---

## Analytics & Insights

### Score Distribution Dashboard

**Admin Panel**: Show score distribution
- Histogram of match scores
- Breakdown by component
- Identify algorithm biases

### User Feedback Loop

**Feature**: "Why did I see this person?"
```swift
// Add to profile view
Button("Why this match?") {
    showMatchExplanation(score: matchScore)
}

// Explanation view
struct MatchExplanationView: View {
    let score: MatchScore

    var body: some View {
        VStack {
            Text("Match Score: \(Int(score.totalScore))%")

            ScoreBar(label: "Shared Interests", value: score.breakdown.interestSimilarity)
            ScoreBar(label: "Distance", value: score.breakdown.proximityScore)
            ScoreBar(label: "Activity", value: score.breakdown.activityScore)

            // Personalized message
            Text(generateExplanation(score))
        }
    }

    func generateExplanation(_ score: MatchScore) -> String {
        if score.breakdown.interestSimilarity > 70 {
            return "You both love \(topSharedInterests.joined(separator: ", "))!"
        } else if score.breakdown.proximityScore > 80 {
            return "They're just \(distanceKm)km away!"
        }
        // ... more conditions
    }
}
```

---

## Success Criteria

### Phase 1 (Foundation)
- ✅ All scoring functions implemented
- ✅ Unit tests passing (>90% coverage)
- ✅ Performance benchmarks met (<100ms per score)

### Phase 2 (Data Collection)
- ✅ Behavioral data collected for all users
- ✅ ELO ratings calculated
- ✅ Activity patterns tracked

### Phase 3 (Rollout)
- ✅ A/B test running
- ✅ 20%+ improvement in match quality
- ✅ No performance degradation
- ✅ Positive user feedback

### Phase 4 (ML Enhancement)
- ✅ ML model trained
- ✅ Prediction accuracy >70%
- ✅ Integrated with scoring system

---

## Rollback Plan

**If metrics regress**:
1. Immediately switch all traffic to control
2. Analyze where algorithm failed
3. Adjust weights or components
4. Re-run A/B test with fixes

**Rollback is safe**: Old algorithm still exists in codebase

---

**Document Owner**: Engineering Team
**Last Updated**: 2025-01-17
**Status**: Ready for implementation
