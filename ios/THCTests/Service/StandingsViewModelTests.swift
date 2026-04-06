// StandingsViewModelTests.swift
// THCTests/Service
//
// All 7 specs from §2.9.
// Tests compile but fail (red) until StandingsViewModel is implemented (M4.3).

import XCTest
import SwiftData
@testable import THC

final class StandingsViewModelTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var viewModel: StandingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        viewModel = StandingsViewModel(
            supabase: mockSupabase,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        container = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - §2.9.1 Leaderboard sorts by best_n_points descending

    func test_leaderboardSortsByBestNPointsDescending() async throws {
        // Given: 4 players with best_n_points: [45, 62, 38, 50]
        let standings = [
            makeStanding(name: "Alice", bestNPoints: 45),
            makeStanding(name: "Bob", bestNPoints: 62),
            makeStanding(name: "Carol", bestNPoints: 38),
            makeStanding(name: "Dave", bestNPoints: 50),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(standings)

        // When
        try await viewModel.fetchLeaderboard()

        // Then: ordered [62, 50, 45, 38]; rank = index + 1
        let sorted = viewModel.standings
        XCTAssertEqual(sorted.count, 4)
        XCTAssertEqual(sorted[0].playerName, "Bob", "Bob (62 pts) should be rank 1")
        XCTAssertEqual(sorted[1].playerName, "Dave", "Dave (50 pts) should be rank 2")
        XCTAssertEqual(sorted[2].playerName, "Alice", "Alice (45 pts) should be rank 3")
        XCTAssertEqual(sorted[3].playerName, "Carol", "Carol (38 pts) should be rank 4")
    }

    // MARK: - §2.9.2 Tiebreaker: lower best net vs par wins

    func test_tiebreakerLowerNetVsParWins() async throws {
        // Given: both players have 50 best_n_points; A has bestNetVsPar = -2, B has +1
        let standings = [
            makeStanding(name: "Player A", bestNPoints: 50, bestNetVsPar: -2),
            makeStanding(name: "Player B", bestNPoints: 50, bestNetVsPar: 1),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(standings)

        // When
        try await viewModel.fetchLeaderboard()

        // Then: Player A ranks above Player B (lower net vs par is better)
        XCTAssertEqual(viewModel.standings.first?.playerName, "Player A",
                       "Player A should rank higher due to better net vs par tiebreaker")
    }

    // MARK: - §2.9.3 Ineligible players ranked separately

    func test_ineligiblePlayersRankedSeparately() async throws {
        // Given: min_rounds = 5; one player has only 3 rounds
        let eligiblePlayer = makeStanding(name: "Eligible", bestNPoints: 60, totalRounds: 8, isEligible: true)
        let ineligiblePlayer = makeStanding(name: "Ineligible", bestNPoints: 70, totalRounds: 3, isEligible: false)
        mockSupabase.stubbedResponses["season_standings"] = .success([eligiblePlayer, ineligiblePlayer])

        // When
        try await viewModel.fetchLeaderboard()

        // Then: ineligible player in separate list; eligible player in main ranking
        XCTAssertFalse(viewModel.ineligibleStandings.isEmpty,
                       "Ineligible player should appear in ineligibleStandings, not main list")
        XCTAssertFalse(viewModel.standings.contains { !$0.isEligible },
                       "Main standings should only contain eligible players")
    }

    // MARK: - §2.9.4 Best N rounds sum (top 10 of 15)

    func test_bestNRoundsSummedCorrectly() {
        // Given: player has 15 rounds; top 10 should sum to a known value
        // Points: [10, 8, 12, 7, 9, 11, 6, 10, 13, 5, 9, 8, 11, 7, 10]
        // Top 10 sorted desc: [13, 12, 11, 11, 10, 10, 10, 9, 9, 8] = 103
        let allRoundPoints = [10, 8, 12, 7, 9, 11, 6, 10, 13, 5, 9, 8, 11, 7, 10]
        let topN = 10
        let expectedSum = allRoundPoints.sorted(by: >).prefix(topN).reduce(0, +)

        // When
        let computed = StandingsViewModel.computeBestNPoints(
            roundPoints: allRoundPoints,
            topN: topN
        )

        // Then
        XCTAssertEqual(computed, expectedSum,
                       "Best N points should sum the top \(topN) rounds: expected \(expectedSum)")
        // Verify against the spec's stated answer
        XCTAssertEqual(computed, 103, "Spec says top-10 of the given 15 rounds = 103")
    }

    // MARK: - §2.9.5 Pull-to-refresh fetches fresh data

    func test_pullToRefreshFetchesFreshData() async throws {
        // Given: standings cached; new round submitted by another user
        let initialStandings = [makeStanding(name: "Alice", bestNPoints: 50)]
        mockSupabase.stubbedResponses["season_standings"] = .success(initialStandings)
        try await viewModel.fetchLeaderboard()
        XCTAssertEqual(viewModel.standings.count, 1)

        // When: user pulls to refresh; new player appears
        let updatedStandings = [
            makeStanding(name: "Alice", bestNPoints: 50),
            makeStanding(name: "New Player", bestNPoints: 65),
        ]
        mockSupabase.stubbedResponses["season_standings"] = .success(updatedStandings)
        try await viewModel.refresh()

        // Then: standings update to reflect the new round
        XCTAssertEqual(viewModel.standings.count, 2, "Pull-to-refresh should fetch and show new player")
        XCTAssertEqual(viewModel.standings.first?.playerName, "New Player",
                       "New leader should be at top after refresh")
    }

    // MARK: - §2.9.6 Offline: cached standings displayed

    func test_offlineCachedStandingsDisplayed() async throws {
        // Given: standings fetched and cached; now network is offline
        let standings = [makeStanding(name: "Alice", bestNPoints: 50)]
        mockSupabase.stubbedResponses["season_standings"] = .success(standings)
        try await viewModel.fetchLeaderboard()

        // Simulate offline
        mockSupabase.stubbedResponses["season_standings"] = .failure(URLError(.notConnectedToInternet))

        // When: fetch attempted again
        try await viewModel.fetchLeaderboard()

        // Then: cached data displayed; no crash
        XCTAssertFalse(viewModel.standings.isEmpty, "Cached standings should display when offline")
        XCTAssertNotNil(viewModel.lastUpdatedAt, "Should show 'Last updated' timestamp")
    }

    // MARK: - §2.9.7 Player profile: rounds sorted by played_at descending

    func test_playerRoundsSortedByPlayedAtDescending() async throws {
        // Given: player has rounds on 3 dates
        let playerId = UUID()
        let rounds = [
            makeRound(playedAt: "2026-01-15", playerId: playerId),
            makeRound(playedAt: "2026-03-01", playerId: playerId),
            makeRound(playedAt: "2026-02-20", playerId: playerId),
        ]
        mockSupabase.stubbedResponses["rounds"] = .success(rounds)

        // When
        try await viewModel.fetchPlayerRounds(playerId: playerId)

        // Then: rounds in descending order
        let sorted = viewModel.playerRounds
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].playedAt, "2026-03-01", "Most recent round should be first")
        XCTAssertEqual(sorted[1].playedAt, "2026-02-20")
        XCTAssertEqual(sorted[2].playedAt, "2026-01-15", "Oldest round should be last")
    }

    // MARK: - Helpers

    private func makeStanding(
        name: String,
        bestNPoints: Int,
        bestNetVsPar: Int = 0,
        totalRounds: Int = 8,
        isEligible: Bool = true
    ) -> SeasonStanding {
        SeasonStanding(
            playerId: UUID(),
            seasonId: UUID(),
            playerName: name,
            playerSlug: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            handicapIndex: 12.0,
            avatarUrl: nil,
            totalRounds: totalRounds,
            isEligible: isEligible,
            bestNPoints: bestNPoints,
            bestRoundPoints: 13,
            bestNetVsPar: bestNetVsPar
        )
    }

    private func makeRound(playedAt: String, playerId: UUID) -> Round {
        Round(
            id: UUID(),
            playerId: playerId,
            seasonId: UUID(),
            playedAt: playedAt,
            courseName: "Test Course",
            teeName: nil,
            courseRating: nil,
            slopeRating: nil,
            par: 72,
            grossScore: 90,
            courseHandicap: 18,
            netScore: 72,
            netVsPar: 0,
            points: 10,
            ghinScoreId: nil,
            source: "app",
            enteredBy: nil,
            createdAt: Date()
        )
    }
}
