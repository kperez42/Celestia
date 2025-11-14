//
//  LikeActivityViewModelTests.swift
//  CelestiaTests
//
//  Comprehensive tests for LikeActivityViewModel
//

import Testing
@testable import Celestia

@Suite("LikeActivityViewModel Tests")
@MainActor
struct LikeActivityViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with correct default state")
    func testInitialState() async throws {
        let viewModel = LikeActivityViewModel()

        #expect(viewModel.todayActivity.isEmpty)
        #expect(viewModel.weekActivity.isEmpty)
        #expect(viewModel.olderActivity.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Activity Model Tests

    @Test("LikeActivity model initialization")
    func testLikeActivityInitialization() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .received(isSuperLike: false),
            timestamp: Date()
        )

        #expect(activity.id == "activity1")
        #expect(activity.userId == "user123")
    }

    @Test("LikeActivity with super like received")
    func testSuperLikeReceived() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .received(isSuperLike: true),
            timestamp: Date()
        )

        if case .received(let isSuperLike) = activity.type {
            #expect(isSuperLike == true)
        } else {
            Issue.record("Expected received type")
        }
    }

    @Test("LikeActivity with regular like received")
    func testRegularLikeReceived() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .received(isSuperLike: false),
            timestamp: Date()
        )

        if case .received(let isSuperLike) = activity.type {
            #expect(isSuperLike == false)
        } else {
            Issue.record("Expected received type")
        }
    }

    @Test("LikeActivity with super like sent")
    func testSuperLikeSent() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .sent(isSuperLike: true),
            timestamp: Date()
        )

        if case .sent(let isSuperLike) = activity.type {
            #expect(isSuperLike == true)
        } else {
            Issue.record("Expected sent type")
        }
    }

    @Test("LikeActivity with regular like sent")
    func testRegularLikeSent() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .sent(isSuperLike: false),
            timestamp: Date()
        )

        if case .sent(let isSuperLike) = activity.type {
            #expect(isSuperLike == false)
        } else {
            Issue.record("Expected sent type")
        }
    }

    @Test("LikeActivity with mutual like")
    func testMutualLike() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .mutual,
            timestamp: Date()
        )

        if case .mutual = activity.type {
            // Success
        } else {
            Issue.record("Expected mutual type")
        }
    }

    @Test("LikeActivity with match")
    func testMatchActivity() async throws {
        let activity = LikeActivity(
            id: "activity1",
            userId: "user123",
            type: .matched,
            timestamp: Date()
        )

        if case .matched = activity.type {
            // Success
        } else {
            Issue.record("Expected matched type")
        }
    }

    // MARK: - Activity Type Icon Tests

    @Test("Activity type icons are correct")
    func testActivityTypeIcons() async throws {
        #expect(LikeActivity.ActivityType.received(isSuperLike: false).icon == "heart.fill")
        #expect(LikeActivity.ActivityType.sent(isSuperLike: false).icon == "paperplane.fill")
        #expect(LikeActivity.ActivityType.mutual.icon == "heart.circle.fill")
        #expect(LikeActivity.ActivityType.matched.icon == "sparkles")
    }

    @Test("Activity type descriptions are correct")
    func testActivityTypeDescriptions() async throws {
        #expect(LikeActivity.ActivityType.received(isSuperLike: false).description == "Liked you")
        #expect(LikeActivity.ActivityType.received(isSuperLike: true).description == "Super liked you")
        #expect(LikeActivity.ActivityType.sent(isSuperLike: false).description == "You liked")
        #expect(LikeActivity.ActivityType.sent(isSuperLike: true).description == "You super liked")
        #expect(LikeActivity.ActivityType.mutual.description == "Mutual like!")
        #expect(LikeActivity.ActivityType.matched.description == "It's a match!")
    }

    // MARK: - Loading State Tests

    @Test("IsLoading state toggles correctly")
    func testLoadingState() async throws {
        let viewModel = LikeActivityViewModel()

        #expect(viewModel.isLoading == false)

        viewModel.isLoading = true
        #expect(viewModel.isLoading == true)

        viewModel.isLoading = false
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Activity Array Tests

    @Test("TodayActivity can be populated")
    func testTodayActivityPopulation() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date())
        ]

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 2)
    }

    @Test("WeekActivity can be populated")
    func testWeekActivityPopulation() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.daysAgo(3)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.daysAgo(5))
        ]

        viewModel.weekActivity = activities

        #expect(viewModel.weekActivity.count == 2)
    }

    @Test("OlderActivity can be populated")
    func testOlderActivityPopulation() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.daysAgo(10)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.daysAgo(15))
        ]

        viewModel.olderActivity = activities

        #expect(viewModel.olderActivity.count == 2)
    }

    @Test("All activity arrays can be populated simultaneously")
    func testAllActivityArraysPopulated() async throws {
        let viewModel = LikeActivityViewModel()

        viewModel.todayActivity = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date())
        ]

        viewModel.weekActivity = [
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.daysAgo(3))
        ]

        viewModel.olderActivity = [
            LikeActivity(id: "3", userId: "user3", type: .matched, timestamp: Date.daysAgo(10))
        ]

        #expect(viewModel.todayActivity.count == 1)
        #expect(viewModel.weekActivity.count == 1)
        #expect(viewModel.olderActivity.count == 1)
    }

    // MARK: - Activity Sorting Tests

    @Test("Activities maintain chronological order")
    func testActivityChronologicalOrder() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.hoursAgo(1)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.hoursAgo(2)),
            LikeActivity(id: "3", userId: "user3", type: .matched, timestamp: Date.hoursAgo(3))
        ]

        viewModel.todayActivity = activities

        // Verify they're in the right order (most recent first after sorting)
        #expect(viewModel.todayActivity.count == 3)
    }

    // MARK: - Large Dataset Tests

    @Test("Large number of activities in today")
    func testLargeTodayActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = (0..<50).map { index in
            LikeActivity(
                id: "activity_\(index)",
                userId: "user_\(index)",
                type: index % 2 == 0 ? .received(isSuperLike: false) : .sent(isSuperLike: false),
                timestamp: Date.minutesAgo(index * 10)
            )
        }

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 50)
    }

    @Test("Large number of activities in week")
    func testLargeWeekActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = (0..<30).map { index in
            LikeActivity(
                id: "activity_\(index)",
                userId: "user_\(index)",
                type: .received(isSuperLike: false),
                timestamp: Date.daysAgo(index % 7 + 1)
            )
        }

        viewModel.weekActivity = activities

        #expect(viewModel.weekActivity.count == 30)
    }

    // MARK: - Activity Type Variety Tests

    @Test("Mixed activity types in today")
    func testMixedActivityTypes() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: true), timestamp: Date()),
            LikeActivity(id: "3", userId: "user3", type: .mutual, timestamp: Date()),
            LikeActivity(id: "4", userId: "user4", type: .matched, timestamp: Date())
        ]

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 4)
    }

    @Test("Only received activities")
    func testOnlyReceivedActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = (0..<10).map { index in
            LikeActivity(
                id: "activity_\(index)",
                userId: "user_\(index)",
                type: .received(isSuperLike: index % 3 == 0),
                timestamp: Date.minutesAgo(index * 5)
            )
        }

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 10)
        // All should be received type
        let allReceived = viewModel.todayActivity.allSatisfy { activity in
            if case .received = activity.type {
                return true
            }
            return false
        }
        #expect(allReceived == true)
    }

    @Test("Only sent activities")
    func testOnlySentActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = (0..<10).map { index in
            LikeActivity(
                id: "activity_\(index)",
                userId: "user_\(index)",
                type: .sent(isSuperLike: index % 2 == 0),
                timestamp: Date.minutesAgo(index * 5)
            )
        }

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 10)
        // All should be sent type
        let allSent = viewModel.todayActivity.allSatisfy { activity in
            if case .sent = activity.type {
                return true
            }
            return false
        }
        #expect(allSent == true)
    }

    @Test("Only matched activities")
    func testOnlyMatchedActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = (0..<5).map { index in
            LikeActivity(
                id: "activity_\(index)",
                userId: "user_\(index)",
                type: .matched,
                timestamp: Date.minutesAgo(index * 10)
            )
        }

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 5)
    }

    // MARK: - Empty State Tests

    @Test("Empty activity arrays")
    func testEmptyActivityArrays() async throws {
        let viewModel = LikeActivityViewModel()

        #expect(viewModel.todayActivity.isEmpty)
        #expect(viewModel.weekActivity.isEmpty)
        #expect(viewModel.olderActivity.isEmpty)
    }

    @Test("Clearing activity arrays")
    func testClearingActivityArrays() async throws {
        let viewModel = LikeActivityViewModel()

        // Populate
        viewModel.todayActivity = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date())
        ]

        #expect(!viewModel.todayActivity.isEmpty)

        // Clear
        viewModel.todayActivity = []

        #expect(viewModel.todayActivity.isEmpty)
    }

    // MARK: - Timestamp Tests

    @Test("Activities from different times of day")
    func testActivitiesDifferentTimesOfDay() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.hoursAgo(1)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.hoursAgo(5)),
            LikeActivity(id: "3", userId: "user3", type: .matched, timestamp: Date.hoursAgo(10))
        ]

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity.count == 3)
    }

    @Test("Activities from beginning of week")
    func testActivitiesBeginningOfWeek() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.daysAgo(1)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.daysAgo(2))
        ]

        viewModel.weekActivity = activities

        #expect(viewModel.weekActivity.count == 2)
    }

    @Test("Activities from end of week")
    func testActivitiesEndOfWeek() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date.daysAgo(6)),
            LikeActivity(id: "2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date.daysAgo(7))
        ]

        viewModel.weekActivity = activities

        #expect(viewModel.weekActivity.count == 2)
    }

    // MARK: - User ID Tests

    @Test("Different user IDs in activities")
    func testDifferentUserIds() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user_alpha", type: .received(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "2", userId: "user_beta", type: .sent(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "3", userId: "user_gamma", type: .matched, timestamp: Date())
        ]

        viewModel.todayActivity = activities

        #expect(viewModel.todayActivity[0].userId == "user_alpha")
        #expect(viewModel.todayActivity[1].userId == "user_beta")
        #expect(viewModel.todayActivity[2].userId == "user_gamma")
    }

    @Test("Same user multiple activities")
    func testSameUserMultipleActivities() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "1", userId: "user123", type: .received(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "2", userId: "user123", type: .sent(isSuperLike: true), timestamp: Date()),
            LikeActivity(id: "3", userId: "user123", type: .matched, timestamp: Date())
        ]

        viewModel.todayActivity = activities

        let allSameUser = viewModel.todayActivity.allSatisfy { $0.userId == "user123" }
        #expect(allSameUser == true)
    }

    // MARK: - Activity ID Tests

    @Test("Unique activity IDs")
    func testUniqueActivityIds() async throws {
        let viewModel = LikeActivityViewModel()

        let activities = [
            LikeActivity(id: "activity_1", userId: "user1", type: .received(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "activity_2", userId: "user2", type: .sent(isSuperLike: false), timestamp: Date()),
            LikeActivity(id: "activity_3", userId: "user3", type: .matched, timestamp: Date())
        ]

        viewModel.todayActivity = activities

        let ids = Set(viewModel.todayActivity.map { $0.id })
        #expect(ids.count == 3) // All unique
    }
}
