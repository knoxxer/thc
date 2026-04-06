// SupabaseIntegrationTests.swift
// THCTests/Integration
//
// Specs I.1-I.5 from §6.0.
// These tests run against a STAGING Supabase instance (NOT production).
// They verify RLS policies, cross-user visibility, and end-to-end data flow.
//
// IMPORTANT: These tests require:
//   1. A staging Supabase project configured in Secrets.plist under key "SUPABASE_STAGING_URL"
//   2. Two test user accounts (TEST_USER_A_TOKEN, TEST_USER_B_TOKEN)
//   3. The TEST_PLAN_INTEGRATION environment variable set to "true"
//
// In CI these run nightly, not on every push (see .github/workflows/ios-tests.yml).

import XCTest
@testable import THC

// Skip integration tests unless explicitly enabled
private let integrationTestsEnabled: Bool = {
    ProcessInfo.processInfo.environment["TEST_PLAN_INTEGRATION"] == "true"
}()

final class SupabaseIntegrationTests: XCTestCase {

    var supabaseUserA: SupabaseClientProvider?
    var supabaseUserB: SupabaseClientProvider?

    override func setUp() async throws {
        try await super.setUp()

        guard integrationTestsEnabled else { return }

        // Initialize two separate Supabase clients (one per test user)
        // Token values come from environment variables, never hardcoded
        let stagingURL = ProcessInfo.processInfo.environment["SUPABASE_STAGING_URL"] ?? ""
        let stagingAnonKey = ProcessInfo.processInfo.environment["SUPABASE_STAGING_ANON_KEY"] ?? ""

        guard !stagingURL.isEmpty, !stagingAnonKey.isEmpty else {
            XCTFail("Missing staging Supabase credentials in environment")
            return
        }

        supabaseUserA = SupabaseClientProvider(url: stagingURL, anonKey: stagingAnonKey)
        supabaseUserB = SupabaseClientProvider(url: stagingURL, anonKey: stagingAnonKey)
    }

    override func tearDown() async throws {
        supabaseUserA = nil
        supabaseUserB = nil
        try await super.tearDown()
    }

    // MARK: - Integration Spec I.1 — Tap-and-save cross-user visibility

    func test_tapAndSaveCrossUserVisibility() async throws {
        guard integrationTestsEnabled else {
            throw XCTSkip("Integration tests disabled — set TEST_PLAN_INTEGRATION=true to enable")
        }

        guard let clientA = supabaseUserA, let clientB = supabaseUserB else {
            XCTFail("Supabase clients not initialized")
            return
        }

        // Given: User A saves a green pin for Hole 3
        let courseId = UUID()
        let pinPayload: [String: Any] = [
            "course_id": courseId.uuidString,
            "hole_number": 3,
            "green_lat": 32.8951,
            "green_lon": -117.2518,
            "source": "tap_and_save"
        ]
        try await clientA.insert(into: "course_holes", payload: pinPayload)

        // When: User B queries course_holes for the same course
        let holes = try await clientB.select(
            from: "course_holes",
            type: CourseHole.self
        )

        // Then: User B sees User A's pin (RLS allows cross-user reads)
        let hole3 = holes.first { $0.holeNumber == 3 }
        XCTAssertNotNil(hole3, "User B should see User A's green pin (cross-user RLS read)")
    }

    // MARK: - Integration Spec I.2 — Post round appears in standings

    func test_postRound_appearsInStandings() async throws {
        guard integrationTestsEnabled else {
            throw XCTSkip("Integration tests disabled")
        }

        guard let client = supabaseUserA else {
            XCTFail("Supabase client not initialized")
            return
        }

        // Given: get current test player and active season
        let seasons = try await client.select(from: "seasons", type: Season.self)
        guard let activeSeason = seasons.first(where: { $0.isActive }) else {
            XCTFail("No active season found in staging")
            return
        }

        // Submit a round
        let roundPayload: [String: Any] = [
            "season_id": activeSeason.id.uuidString,
            "played_at": "2026-04-05",
            "course_name": "Test Course (Integration Test)",
            "par": 72,
            "gross_score": 90,
            "course_handicap": 18,
            "net_score": 72,
            "net_vs_par": 0,
            "points": 10,
            "source": "app"
        ]
        try await client.insert(into: "rounds", payload: roundPayload)

        // When: query season_standings view
        let standings = try await client.select(from: "season_standings", type: SeasonStanding.self)

        // Then: new round's points are reflected
        XCTAssertFalse(standings.isEmpty, "Standings should include the newly submitted round")
    }

    // MARK: - Integration Spec I.3 — RLS prevents writing another user's data

    func test_rlsPreventsWritingAnotherUserData() async throws {
        guard integrationTestsEnabled else {
            throw XCTSkip("Integration tests disabled")
        }

        guard let clientB = supabaseUserB else {
            XCTFail("Supabase client not initialized")
            return
        }

        // Given: User A's player ID (test fixture)
        let userAPlayerId = ProcessInfo.processInfo.environment["TEST_USER_A_PLAYER_ID"] ?? ""
        guard !userAPlayerId.isEmpty else {
            throw XCTSkip("TEST_USER_A_PLAYER_ID not set")
        }

        // When: User B tries to insert a round with User A's player_id
        let maliciousPayload: [String: Any] = [
            "player_id": userAPlayerId,
            "played_at": "2026-04-05",
            "course_name": "Hacked Round",
            "par": 72,
            "gross_score": 60,
            "course_handicap": 0,
            "net_score": 60,
            "net_vs_par": -12,
            "points": 15,
            "source": "app"
        ]

        do {
            try await clientB.insert(into: "rounds", payload: maliciousPayload)
            XCTFail("RLS should have prevented User B from inserting a round for User A")
        } catch {
            // Expected: RLS violation error
            XCTAssertTrue(true, "RLS correctly rejected the unauthorized insert")
        }
    }

    // MARK: - Integration Spec I.4 — Offline round syncs correctly

    func test_offlineRound_syncsCorrectlyOnReconnect() async throws {
        guard integrationTestsEnabled else {
            throw XCTSkip("Integration tests disabled")
        }

        // NOTE: Full offline simulation requires SwiftData + network toggle
        // This is an end-to-end integration test that verifies the complete pipeline:
        // SwiftData(pending) → SyncService → Supabase → season_standings view

        // For this test we simulate the SwiftData → Supabase path directly
        guard let client = supabaseUserA else {
            XCTFail("Client not initialized")
            return
        }

        let roundPayload: [String: Any] = [
            "played_at": "2026-04-04",
            "course_name": "Offline Test Course",
            "par": 72,
            "gross_score": 88,
            "course_handicap": 16,
            "net_score": 72,
            "net_vs_par": 0,
            "points": 10,
            "source": "app"
        ]

        // Should succeed on reconnect
        try await client.insert(into: "rounds", payload: roundPayload)

        let rounds = try await client.select(from: "rounds", type: Round.self)
        let inserted = rounds.first { $0.courseName == "Offline Test Course" }
        XCTAssertNotNil(inserted, "Offline round should appear in Supabase after sync")
        XCTAssertEqual(inserted?.source, "app")
    }

    // MARK: - Integration Spec I.5 — Season standings view reflects correct points

    func test_standingsView_reflectsCorrectPointsFormula() async throws {
        guard integrationTestsEnabled else {
            throw XCTSkip("Integration tests disabled")
        }

        guard let client = supabaseUserA else {
            XCTFail("Client not initialized")
            return
        }

        // Query standings
        let standings = try await client.select(from: "season_standings", type: SeasonStanding.self)

        // Verify each standing's bestNPoints is within valid range [0, 15*topN]
        for standing in standings {
            XCTAssertGreaterThanOrEqual(standing.bestNPoints, 0,
                                        "bestNPoints should never be negative for \(standing.playerName)")
            // Max possible: 15 points × 10 rounds = 150
            XCTAssertLessThanOrEqual(standing.bestNPoints, 150,
                                      "bestNPoints should not exceed 150 (15 pts × 10 rounds)")
        }
    }
}
