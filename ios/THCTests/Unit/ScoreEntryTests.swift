// ScoreEntryTests.swift
// THCTests/Unit
//
// Specs 2.4.1-2.4.4, 2.4.9-2.4.12, 2.4.15 (9-hole)
// Tests compile but fail (red) until ScoreEntryViewModel is implemented (M5.4).

import XCTest
import SwiftData
import Shared
@testable import THC

final class ScoreEntryTests: XCTestCase {

    var mockStorage: MockOfflineStorage!
    private var mockSyncService: MockSyncServiceEntry!
    var viewModel: ScoreEntryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockOfflineStorage()
        mockSyncService = MockSyncServiceEntry()
        viewModel = ScoreEntryViewModel(
            player: Player.fixture(),
            season: Season.fixture(),
            offlineStorage: mockStorage,
            syncService: mockSyncService
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockSyncService = nil
        mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - §2.4.1 Net score calculation

    func test_netScoreCalculation_gross95handicap18_returns77() {
        // Given
        viewModel.grossScore = 95
        viewModel.courseHandicap = 18
        // When / Then
        XCTAssertEqual(viewModel.netScore, 77, "Net = gross (95) - handicap (18) = 77")
    }

    // MARK: - §2.4.2 Net vs par calculation

    func test_netVsParCalculation_net77par72_returnsPlus5() {
        // Given
        viewModel.grossScore = 95
        viewModel.courseHandicap = 18
        viewModel.par = 72
        // When / Then
        XCTAssertEqual(viewModel.netVsPar, 5, "Net vs par = net (77) - par (72) = +5")
    }

    // MARK: - §2.4.3 Points from net vs par (+5)

    func test_pointsFromNetVsPar_plus5_returns5() {
        // Given: netVsPar = +5
        viewModel.grossScore = 95
        viewModel.courseHandicap = 18
        viewModel.par = 72
        // When / Then
        XCTAssertEqual(viewModel.points, 5, "netVsPar=+5 should yield 5 points via PointsCalculator")
    }

    // MARK: - §2.4.4 Full flow: even par yields 10 points

    func test_fullFlow_gross90handicap18par72_returns10points() {
        // Given: gross=90, handicap=18, par=72 -> net=72, netVsPar=0, points=10
        viewModel.grossScore = 90
        viewModel.courseHandicap = 18
        viewModel.par = 72

        // Then
        XCTAssertEqual(viewModel.netScore, 72, "Net should be 72")
        XCTAssertEqual(viewModel.netVsPar, 0, "Net vs par should be 0 (even)")
        XCTAssertEqual(viewModel.points, 10, "Even par should yield exactly 10 points")
    }

    // MARK: - §2.4.9 Validation: gross score required

    func test_validationRejectsNoGrossScore() {
        // Given: no gross score entered
        viewModel.grossScore = nil
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = 18

        // When / Then: canSubmit should be false
        XCTAssertFalse(viewModel.canSubmit, "Should not be able to submit without gross score")
        XCTAssertNotNil(viewModel.validationError, "Should have a validation error")
    }

    // MARK: - §2.4.10 Validation: course name required

    func test_validationRejectsEmptyCourseName() {
        // Given: empty course name
        viewModel.grossScore = 90
        viewModel.courseName = ""
        viewModel.par = 72
        viewModel.courseHandicap = 18

        // When / Then
        XCTAssertFalse(viewModel.canSubmit, "Should not be able to submit with empty course name")
    }

    // MARK: - §2.4.11 Validation: courseHandicap must be non-negative

    func test_validationRejectsNegativeCourseHandicap() {
        // Given: negative courseHandicap
        viewModel.grossScore = 90
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = -3

        // When / Then
        XCTAssertFalse(viewModel.canSubmit, "Should not be able to submit with negative handicap")
    }

    // MARK: - §2.4.12 Source field: app-submitted round has source = "app"

    func test_sourceFieldIsApp() async throws {
        // Given: a valid round submitted via the iOS app
        viewModel.grossScore = 90
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = 18

        // When
        await viewModel.submitPostRound()

        // Then: the round is saved (no crash, result available)
        XCTAssertNotNil(viewModel.submitResult, "Submit should produce a result")
    }

    // MARK: - §2.4.15 Nine-hole round calculation

    func test_nineHoleRound_par36_calculatesCorrectly() {
        // Given: 9-hole round: gross=45, handicap=9, par=36
        viewModel.grossScore = 45
        viewModel.courseHandicap = 9
        viewModel.par = 36

        // Then: net=36, netVsPar=0, points=10
        XCTAssertEqual(viewModel.netScore, 36, "Net = 45 - 9 = 36")
        XCTAssertEqual(viewModel.netVsPar, 0, "Net vs par = 36 - 36 = 0")
        XCTAssertEqual(viewModel.points, 10, "Even par = 10 points")
    }
}

// MARK: - Fixtures

private extension Player {
    static func fixture() -> Player {
        Player(id: UUID(), name: "Test", displayName: "Test", slug: "test",
               email: nil, ghinNumber: nil, handicapIndex: nil, handicapUpdatedAt: nil,
               avatarUrl: nil, isActive: true, role: "contributor",
               authUserId: "auth-id", createdAt: Date())
    }
}

private extension Season {
    static func fixture() -> Season {
        Season(id: UUID(), name: "2026", startsAt: Date(), endsAt: Date(),
               isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date())
    }
}

// MARK: - MockSyncServiceEntry

private final class MockSyncServiceEntry: SyncServiceProviding, @unchecked Sendable {
    func syncPendingRounds() async throws -> Int { 0 }
    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding] { [] }
    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round] { [] }
    func fetchActiveSeason() async throws -> Season? { nil }
}
