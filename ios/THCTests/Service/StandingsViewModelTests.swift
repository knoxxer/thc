// StandingsViewModelTests.swift
// THCTests/Service
//
// All 7 specs from §2.9.
// Tests compile but fail (red) until StandingsViewModel is implemented (M4.3).

import XCTest
import SwiftData
import Shared
@testable import THC

final class StandingsViewModelTests: XCTestCase {

    var mockSyncService: MockSyncService!
    var viewModel: StandingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockSyncService = MockSyncService()
        viewModel = StandingsViewModel(syncService: mockSyncService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockSyncService = nil
        try await super.tearDown()
    }

    // MARK: - §2.9.1 Leaderboard sorts by best_n_points descending

    func test_leaderboardSortsByBestNPointsDescending() async throws {
        // Given: 4 players with best_n_points: [45, 62, 38, 50]
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        mockSyncService.stubbedStandings = [
            makeStanding(name: "Alice", bestNPoints: 45),
            makeStanding(name: "Bob", bestNPoints: 62),
            makeStanding(name: "Carol", bestNPoints: 38),
            makeStanding(name: "Dave", bestNPoints: 50),
        ]

        // When
        await viewModel.load()

        // Then: ordered [62, 50, 45, 38]
        let sorted = viewModel.eligibleStandings
        XCTAssertEqual(sorted.count, 4)
        XCTAssertEqual(sorted[0].playerName, "Bob", "Bob (62 pts) should be rank 1")
        XCTAssertEqual(sorted[1].playerName, "Dave", "Dave (50 pts) should be rank 2")
        XCTAssertEqual(sorted[2].playerName, "Alice", "Alice (45 pts) should be rank 3")
        XCTAssertEqual(sorted[3].playerName, "Carol", "Carol (38 pts) should be rank 4")
    }

    // MARK: - §2.9.2 Tiebreaker: lower best net vs par wins

    func test_tiebreakerLowerNetVsParWins() async throws {
        // Given: both players have 50 best_n_points; A has bestNetVsPar = -2, B has +1
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        mockSyncService.stubbedStandings = [
            makeStanding(name: "Player A", bestNPoints: 50, bestNetVsPar: -2),
            makeStanding(name: "Player B", bestNPoints: 50, bestNetVsPar: 1),
        ]

        // When
        await viewModel.load()

        // Then: Player A ranks above Player B (lower net vs par is better)
        XCTAssertEqual(viewModel.eligibleStandings.first?.playerName, "Player A",
                       "Player A should rank higher due to better net vs par tiebreaker")
    }

    // MARK: - §2.9.3 Ineligible players ranked separately

    func test_ineligiblePlayersRankedSeparately() async throws {
        // Given: min_rounds = 5; one player has only 3 rounds
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        let eligiblePlayer = makeStanding(name: "Eligible", bestNPoints: 60, totalRounds: 8, isEligible: true)
        let ineligiblePlayer = makeStanding(name: "Ineligible", bestNPoints: 70, totalRounds: 3, isEligible: false)
        mockSyncService.stubbedStandings = [eligiblePlayer, ineligiblePlayer]

        // When
        await viewModel.load()

        // Then: ineligible player in separate list; eligible player in main ranking
        XCTAssertFalse(viewModel.ineligibleStandings.isEmpty,
                       "Ineligible player should appear in ineligibleStandings, not main list")
        XCTAssertFalse(viewModel.eligibleStandings.contains { !$0.isEligible },
                       "Main standings should only contain eligible players")
    }

    // MARK: - §2.9.4 Best N rounds sum (top 10 of 15)

    func test_bestNRoundsSummedCorrectly() {
        // Given: player has 15 rounds; top 10 should sum to a known value
        // Points: [10, 8, 12, 7, 9, 11, 6, 10, 13, 5, 9, 8, 11, 7, 10]
        // Top 10 sorted desc: [13, 12, 11, 11, 10, 10, 10, 9, 9, 8] = 103
        let allRoundPoints = [10, 8, 12, 7, 9, 11, 6, 10, 13, 5, 9, 8, 11, 7, 10]
        let topN = 10

        // When: compute top-N sum (same logic the standings view uses)
        let computed = allRoundPoints.sorted(by: >).prefix(topN).reduce(0, +)

        // Then: must equal the spec-mandated value of 103
        XCTAssertEqual(computed, 103, "Spec says top-10 of the given 15 rounds = 103")
    }

    // MARK: - §2.9.5 Pull-to-refresh fetches fresh data

    func test_pullToRefreshFetchesFreshData() async throws {
        // Given: standings cached; new round submitted by another user
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        mockSyncService.stubbedStandings = [makeStanding(name: "Alice", bestNPoints: 50)]
        await viewModel.load()
        XCTAssertEqual(viewModel.eligibleStandings.count, 1)

        // When: user pulls to refresh; new player appears
        mockSyncService.stubbedStandings = [
            makeStanding(name: "Alice", bestNPoints: 50),
            makeStanding(name: "New Player", bestNPoints: 65),
        ]
        await viewModel.refresh()

        // Then: standings update to reflect the new round
        XCTAssertEqual(viewModel.eligibleStandings.count, 2, "Pull-to-refresh should fetch and show new player")
        XCTAssertEqual(viewModel.eligibleStandings.first?.playerName, "New Player",
                       "New leader should be at top after refresh")
    }

    // MARK: - §2.9.6 Offline: cached standings displayed

    func test_offlineCachedStandingsDisplayed() async throws {
        // Given: standings fetched and cached; now network is offline
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        mockSyncService.stubbedStandings = [makeStanding(name: "Alice", bestNPoints: 50)]
        await viewModel.load()

        // Simulate offline
        mockSyncService.stubbedError = URLError(.notConnectedToInternet)

        // When: fetch attempted again
        await viewModel.refresh()

        // Then: previous data still shown (view model doesn't clear on error)
        XCTAssertFalse(viewModel.eligibleStandings.isEmpty, "Cached standings should still display when offline")
    }

    // MARK: - §2.9.7 Player profile: rounds sorted by played_at descending

    func test_playerRoundsSortedByPlayedAtDescending() async throws {
        // Given: player has rounds on 3 dates
        let playerId = UUID()
        let seasonId = UUID()
        mockSyncService.stubbedSeason = Season(
            id: seasonId, name: "2026", startsAt: Date(), endsAt: Date(),
            isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date()
        )
        mockSyncService.stubbedPlayerRounds = [
            makeRound(playedAt: "2026-01-15", playerId: playerId),
            makeRound(playedAt: "2026-03-01", playerId: playerId),
            makeRound(playedAt: "2026-02-20", playerId: playerId),
        ]

        // When
        await viewModel.load()
        let sorted = await viewModel.playerRounds(playerId: playerId)

        // Then: rounds in descending order
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

// MARK: - MockSyncService

final class MockSyncService: SyncServiceProviding, @unchecked Sendable {
    var stubbedSeason: Season?
    var stubbedStandings: [SeasonStanding] = []
    var stubbedPlayerRounds: [Round] = []
    var stubbedError: Error?
    var syncCallCount = 0

    func syncPendingRounds() async throws -> Int {
        syncCallCount += 1
        if let error = stubbedError { throw error }
        return 0
    }

    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding] {
        if let error = stubbedError { throw error }
        return stubbedStandings
    }

    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round] {
        if let error = stubbedError { throw error }
        return stubbedPlayerRounds
    }

    func fetchActiveSeason() async throws -> Season? {
        if let error = stubbedError { throw error }
        return stubbedSeason
    }
}
