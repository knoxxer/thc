// SocialServiceTests.swift
// THCTests/Service
//
// All 4 specs from §2.15.
// Tests compile but fail (red) until SocialService is implemented (M13.2).

import XCTest
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

    // MARK: - §2.15.1 Live rounds feed receives realtime updates

    func test_liveRoundsFeed_receivesRealtimeUpdates() async throws {
        // Given: a MockSupabaseClient that can emit Realtime events
        let playerId = UUID()
        let liveRound = LiveRound(
            id: UUID(),
            playerId: playerId,
            courseDataId: UUID(),
            courseName: "Torrey Pines South",
            currentHole: 7,
            thruHole: 6,
            currentScore: -2,
            startedAt: Date().addingTimeInterval(-3600),
            updatedAt: Date()
        )
        mockSupabase.stubbedResponses["live_rounds"] = .success([liveRound])

        // When: subscribe to live rounds feed
        var receivedRound: LiveRound?
        let stream = socialService.liveRoundsFeed()

        // Simulate the mock emitting an event
        mockSupabase.simulateRealtimeInsert(table: "live_rounds", row: liveRound)

        // Collect the first item from the stream
        for await round in stream {
            receivedRound = round
            break  // Only need the first
        }

        // Then: stream yields a LiveRound with correct player and hole info
        XCTAssertNotNil(receivedRound, "Live rounds feed should yield the new round")
        XCTAssertEqual(receivedRound?.currentHole, 7)
        XCTAssertEqual(receivedRound?.courseName, "Torrey Pines South")
    }

    // MARK: - §2.15.2 React to round inserts reaction

    func test_reactToRound_insertsReaction() async throws {
        // Given: authenticated user
        let roundId = UUID()

        // When
        try await socialService.reactToRound(roundId: roundId, emoji: "🔥", comment: nil)

        // Then: insert into round_reactions with correct values
        XCTAssertEqual(mockSupabase.insertCalls.count, 1, "One insert expected")
        let insert = mockSupabase.insertCalls.first!
        XCTAssertEqual(insert.table, "round_reactions")
        if let payload = insert.payload as? [String: Any] {
            XCTAssertEqual(payload["round_id"] as? UUID, roundId)
            XCTAssertEqual(payload["emoji"] as? String, "🔥")
        }
    }

    // MARK: - §2.15.3 Live round cleanup after round ends

    func test_liveRoundCleanup_afterRoundEnds() async throws {
        // Given: active live_rounds row for current user
        let liveRoundId = UUID()

        // When: round ends
        try await socialService.cleanupLiveRound(id: liveRoundId)

        // Then: live_rounds row is deleted
        let deleteCall = mockSupabase.deleteCalls.first { $0.table == "live_rounds" }
        XCTAssertNotNil(deleteCall, "Live round row should be deleted when round ends")
    }

    // MARK: - §2.15.4 Register for push notifications stores token

    func test_registerForPushNotifications_storesToken() async throws {
        // Given: a valid APNs device token
        let deviceToken = Data([0x01, 0x02, 0x03, 0x04, 0xAB, 0xCD, 0xEF])

        // When
        try await socialService.registerForPushNotifications(deviceToken: deviceToken)

        // Then: token stored in Supabase; no error
        let insertCall = mockSupabase.insertCalls.first { $0.table == "device_tokens" }
            ?? mockSupabase.upsertCalls.first.flatMap { $0.table == "device_tokens" ? $0 : nil }.map {
                MockSupabaseClient.InsertCall(table: "device_tokens", payload: $0.payload)
            }

        // Allow either insert or upsert (implementation detail)
        let writeCall = mockSupabase.insertCalls.first(where: { $0.table == "device_tokens" })
                     ?? {
                         mockSupabase.upsertCalls.first(where: { $0.table == "device_tokens" })
                             .map { MockSupabaseClient.InsertCall(table: $0.table, payload: $0.payload) }
                     }()

        XCTAssertNotNil(writeCall, "Device token should be stored in Supabase")
    }
}

// MARK: - MockSupabaseClient Realtime extension

extension MockSupabaseClient {
    /// Simulate a Realtime INSERT event for a given table row.
    func simulateRealtimeInsert<T: Codable>(table: String, row: T) {
        // In real implementation, this would trigger the Realtime subscription callback.
        // For testing, services should expose a handler the mock can invoke.
    }
}
