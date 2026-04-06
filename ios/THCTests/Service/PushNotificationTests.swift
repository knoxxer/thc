// PushNotificationTests.swift
// THCTests/Service
//
// 3 tests from M13.1a.
// Tests compile but fail (red) until push notification infrastructure is implemented (M13.9).

import XCTest
@testable import THC

final class PushNotificationTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var mockNotificationCenter: MockUNUserNotificationCenter!
    var pushService: PushNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        mockNotificationCenter = MockUNUserNotificationCenter()
        pushService = PushNotificationService(
            supabase: mockSupabase,
            notificationCenter: mockNotificationCenter
        )
    }

    override func tearDown() async throws {
        pushService = nil
        mockNotificationCenter = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - M13.1a — Player takes first place triggers push to others

    func test_playerTakesFirstPlace_triggersPushToOthers() async throws {
        // Given: standings event where a player vaults to rank 1
        let event = StandingsChangeEvent(
            previousRank: 3,
            newRank: 1,
            playerId: UUID(),
            playerName: "Patrick Sun"
        )

        // When
        try await pushService.handleStandingsChange(event)

        // Then: push notification is queued for other top players
        // (In production: Supabase Edge Function fires APNs.
        //  In tests: verify the event was forwarded to the push infrastructure.)
        let notificationInsert = mockSupabase.insertCalls.first {
            $0.table == "push_events" || $0.table == "notification_queue"
        }
        XCTAssertNotNil(notificationInsert,
                        "Taking first place should queue a push notification event")
    }

    // MARK: - M13.1a — Eligibility approaching triggers reminder push

    func test_eligibilityApproaching_triggersReminderPush() async throws {
        // Given: player has 4 rounds (needs 1 more for eligibility, threshold = min_rounds - 1)
        let playerId = UUID()
        let eligibilityEvent = EligibilityEvent(
            playerId: playerId,
            currentRounds: 4,
            minRounds: 5
        )

        // When
        try await pushService.handleEligibilityApproaching(eligibilityEvent)

        // Then: reminder push queued
        let notificationInsert = mockSupabase.insertCalls.first {
            $0.table == "push_events" || $0.table == "notification_queue"
        }
        XCTAssertNotNil(notificationInsert,
                        "Approaching eligibility should trigger a reminder push notification")
    }

    // MARK: - M13.1a — Push permission denied: no crash

    func test_pushPermissionDenied_noCrash() async {
        // Given: push notification permission is denied
        mockNotificationCenter.stubbedPermissionStatus = .denied

        // When: try to register for push
        // Then: no crash, no hang, graceful handling
        await pushService.requestPushPermissions()

        XCTAssertFalse(pushService.isPushEnabled,
                       "isPushEnabled should be false when permission is denied")
        // No exception thrown, no app hang — verified by test completing
    }
}

// MARK: - Supporting Types

struct StandingsChangeEvent {
    let previousRank: Int
    let newRank: Int
    let playerId: UUID
    let playerName: String
}

struct EligibilityEvent {
    let playerId: UUID
    let currentRounds: Int
    let minRounds: Int
}

// MARK: - MockUNUserNotificationCenter

protocol UNUserNotificationCenterProviding {
    func requestAuthorization(options: Any) async throws -> Bool
}

final class MockUNUserNotificationCenter: UNUserNotificationCenterProviding {
    enum PermissionStatus {
        case granted, denied, notDetermined
    }

    var stubbedPermissionStatus: PermissionStatus = .notDetermined
    var requestAuthorizationCallCount = 0

    func requestAuthorization(options: Any) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return stubbedPermissionStatus == .granted
    }
}
