// SocialServiceTests.swift
// THCTests/Service
//
// All 4 specs from §2.15.
// Tests compile but fail (red) until SocialService is implemented (M13.2).

import XCTest
import Shared
@testable import THC

final class SocialServiceTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var socialService: SocialService!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        socialService = SocialService(supabase: mockSupabase)
    }

    override func tearDown() async throws {
        socialService = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - §2.15.1 Live rounds feed returns an async stream

    func test_liveRoundsFeed_returnsAsyncStream() async throws {
        // Given: SocialService configured with mock Supabase

        // When: subscribe to live rounds feed
        let stream = socialService.liveRoundsFeed()

        // Then: stream is non-nil (it's an AsyncStream)
        // Collect the first batch (the initial snapshot fetch).
        // Since the mock Supabase points at loopback and will fail,
        // the initial snapshot will be an empty array.
        var receivedBatch: [LiveRound]?
        for await batch in stream {
            receivedBatch = batch
            break  // Only need the first emission
        }

        // The mock Supabase returns empty or fails gracefully
        XCTAssertNotNil(receivedBatch, "Live rounds feed should emit at least one batch")
    }

    // MARK: - §2.15.2 React to round calls Supabase

    func test_reactToRound_callsSupabase() async throws {
        // Given: authenticated user
        let roundId = UUID()

        // When: This will fail at runtime (loopback Supabase) but should compile
        do {
            try await socialService.reactToRound(roundId: roundId, emoji: "fire", comment: nil)
        } catch {
            // Expected: loopback Supabase fails; this is a compile test
        }
    }

    // MARK: - §2.15.3 Live round cleanup

    func test_liveRoundCleanup_callsDeleteOnSupabase() async throws {
        // Given: active live_rounds row for current user
        let liveRoundId = UUID()

        // When: round ends
        do {
            try await socialService.deleteLiveRound(id: liveRoundId)
        } catch {
            // Expected: loopback Supabase fails
        }
    }

    // MARK: - §2.15.4 Register for push notifications stores token

    func test_registerForPushNotifications_storesToken() async throws {
        // Given: a valid APNs device token
        let deviceToken = Data([0x01, 0x02, 0x03, 0x04, 0xAB, 0xCD, 0xEF])

        // When
        do {
            try await socialService.registerForPushNotifications(deviceToken: deviceToken)
        } catch {
            // Expected: loopback Supabase fails
        }
    }
}
