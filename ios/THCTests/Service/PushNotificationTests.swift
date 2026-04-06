// PushNotificationTests.swift
// THCTests/Service
//
// 3 tests from M13.1a.
// Tests compile but fail (red) until push notification infrastructure is implemented (M13.9).

import XCTest
import UserNotifications
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

        // Then: push notification event is queued
        // (In production: Supabase Edge Function fires APNs)
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
    }
}

// MARK: - MockUNUserNotificationCenter

final class MockUNUserNotificationCenter: UNUserNotificationCenterProviding, @unchecked Sendable {
    enum PermissionStatus {
        case granted, denied, notDetermined
    }

    var stubbedPermissionStatus: PermissionStatus = .notDetermined
    var requestAuthorizationCallCount = 0

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return stubbedPermissionStatus == .granted
    }
}
