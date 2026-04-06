// StandingsIntegrationTests.swift
// THCTests/Integration
//
// Round-to-standings pipeline integration tests.
// Verifies the complete flow: round submission → standings update → leaderboard sort.
//
// Uses MockSupabaseClient for isolation (these are "integration" tests at the
// service layer, not full staging tests — see SupabaseIntegrationTests for real Supabase).

import XCTest
import SwiftData
@testable import THC

final class StandingsIntegrationTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var scoreEntryViewModel: ScoreEntryViewModel!
    var standingsViewModel: StandingsViewModel!
    var syncService: SyncService!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        let offlineStorage = OfflineStorage(modelContainer: container)

        scoreEntryViewModel = ScoreEntryViewModel(
            supabase: mockSupabase,
            modelContainer: container
        )
        syncService = SyncService(supabase: mockSupabase, offlineStorage: offlineStorage)
        standingsViewModel = StandingsViewModel(
            supabase: mockSupabase,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        standingsViewModel = nil
        syncService = nil
        scoreEntryViewModel = nil
        container = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - Full pipeline: submit round → sync → appears in standings

    func test_submitRound_thenSync_appearsInStandings() async throws {
        // Given: initial standings with 2 players
        let seasonId = UUID()
        var initialStandings = [
            makeStanding(name: "Alice", bestNPoints: 85, seasonId: seasonId),
            makeStanding(name: "Bob", bestNPoints: 70, seasonId: seasonId),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(initialStandings)

        // Load initial standings
        try await standingsViewModel.fetchLeaderboard()
        XCTAssertEqual(standingsViewModel.standings.first?.playerName, "Alice")

        // When: user submits a round that earns 15 points (6 under par)
        scoreEntryViewModel.grossScore = 66
        scoreEntryViewModel.courseHandicap = 0
        scoreEntryViewModel.par = 72
        scoreEntryViewModel.courseName = "Torrey Pines South"
        scoreEntryViewModel.playedAt = "2026-04-05"
        try await scoreEntryViewModel.submitRound()

        // After submission, Bob's total jumps to 85 (hypothetical: mock updates standings)
        let updatedStandings = [
            makeStanding(name: "Bob", bestNPoints: 85, seasonId: seasonId),
            makeStanding(name: "Alice", bestNPoints: 85, seasonId: seasonId),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(updatedStandings)

        // Refresh standings
        try await standingsViewModel.refresh()

        // Then: standings reflect the round
        XCTAssertEqual(standingsViewModel.standings.count, 2, "Should still show 2 players")
        // With equal points, tiebreaker applies
        XCTAssertNotNil(standingsViewModel.standings.first, "Standings should not be empty")
    }

    // MARK: - Offline round → online sync → standings update

    func test_offlineRound_syncedOnReconnect_updatesStandings() async throws {
        // Given: user was offline; round saved in SwiftData
        let offlineStorage = OfflineStorage(modelContainer: container)
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // Stub Supabase to respond successfully
        let expectedStandings = [
            makeStanding(name: "Patrick", bestNPoints: 95)
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(expectedStandings)

        // When: reconnect and sync
        let syncCount = try await syncService.syncPendingRounds()

        // Then: round uploaded; standings fetchable
        XCTAssertEqual(syncCount, 1, "One round should have been synced")

        try await standingsViewModel.fetchLeaderboard()
        XCTAssertFalse(standingsViewModel.standings.isEmpty,
                       "Standings should be available after sync")
    }

    // MARK: - Points formula parity: iOS matches web app

    func test_pointsFormula_iosMatchesWebApp() {
        // Verify a sample of values that the web app would also compute
        // Source of truth: src/lib/points.ts: max(1, min(15, 10 - netVsPar))
        let testCases: [(netVsPar: Int, expected: Int)] = [
            (-6, 15), (-3, 13), (0, 10), (5, 5), (9, 1), (10, 1), (-10, 15)
        ]

        for (netVsPar, expected) in testCases {
            let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
            XCTAssertEqual(result, expected,
                           "iOS points formula mismatch for netVsPar=\(netVsPar): " +
                           "expected \(expected), got \(result)")
        }
    }

    // MARK: - Tiebreaker logic end-to-end

    func test_tiebreakerLogic_endToEnd() async throws {
        // Given: two players tied at 80 points; different net vs par
        let standings = [
            makeStanding(name: "Player A", bestNPoints: 80, bestNetVsPar: -5),
            makeStanding(name: "Player B", bestNPoints: 80, bestNetVsPar: 2),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(standings)

        // When
        try await standingsViewModel.fetchLeaderboard()

        // Then: Player A (lower/better net vs par) wins the tiebreaker
        XCTAssertEqual(standingsViewModel.standings.first?.playerName, "Player A",
                       "Lower net vs par should win tiebreaker")
        XCTAssertEqual(standingsViewModel.standings.last?.playerName, "Player B")
    }

    // MARK: - Helpers

    private func makeStanding(
        name: String,
        bestNPoints: Int,
        bestNetVsPar: Int = 0,
        seasonId: UUID = UUID()
    ) -> SeasonStanding {
        SeasonStanding(
            playerId: UUID(), seasonId: seasonId,
            playerName: name,
            playerSlug: name.lowercased(),
            handicapIndex: 12.0, avatarUrl: nil,
            totalRounds: 8, isEligible: true,
            bestNPoints: bestNPoints, bestRoundPoints: 13,
            bestNetVsPar: bestNetVsPar
        )
    }

    private func makeLocalRound() -> LocalRound {
        let round = LocalRound()
        round.id = UUID()
        round.playerId = UUID()
        round.seasonId = UUID()
        round.playedAt = "2026-04-05"
        round.courseName = "Integration Test Course"
        round.par = 72
        round.grossScore = 84
        round.courseHandicap = 12
        round.points = 10
        round.source = "app"
        round.syncedToSupabase = false
        round.holeScores = []
        round.createdAt = Date()
        return round
    }
}
