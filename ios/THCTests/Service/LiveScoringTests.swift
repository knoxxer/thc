// LiveScoringTests.swift
// THCTests/Service
//
// All 5 specs from M9.1.
// Tests compile but fail (red) until RoundManager live scoring is implemented (M9.2).

import XCTest
import SwiftData
import Shared
@testable import THC

final class LiveScoringTests: XCTestCase {

    var mockSupabase: StubSupabaseClient!
    var container: ModelContainer!
    var roundManager: RoundManager!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = StubSupabaseClient()
        container = try TestModelContainer.create()

        let locationManager = LocationManager(clManager: MockCLLocationManager())
        let context = ModelContext(container)
        let offlineStorage = OfflineStorage(context: context)
        let syncService = SyncService(supabase: mockSupabase, storage: offlineStorage)

        roundManager = RoundManager(
            courseDetail: CourseDetail.fixture(),
            player: Player.fixture(),
            season: Season.fixture(),
            locationManager: locationManager,
            offlineStorage: offlineStorage,
            syncService: syncService,
            liveRoundBroadcaster: MockLiveRoundBroadcaster()
        )

        await roundManager.startRound()
    }

    override func tearDown() async throws {
        roundManager = nil
        container = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - Score persists to holeScores

    func test_scoreRecorded_persistsToHoleScores() async throws {
        // Given: active round
        roundManager.goToHole(3)

        // When
        await roundManager.recordHoleScore(
            RoundManager.HoleScoreEntry(strokes: 5, putts: 2, fairwayHit: "left", greenInRegulation: false)
        )

        // Then: hole 3 score persisted
        XCTAssertEqual(roundManager.holeScores[3]?.strokes, 5)
        XCTAssertEqual(roundManager.holeScores[3]?.putts, 2)
        XCTAssertEqual(roundManager.holeScores[3]?.fairwayHit, "left")
        XCTAssertEqual(roundManager.holeScores[3]?.greenInRegulation, false)
    }

    // MARK: - Running total matches sum

    func test_runningTotal_matchesSumOfHoleScores() async {
        // Given: 3 holes scored on a par-4 course
        // hole 1 = 4 (even), hole 2 = 3 (-1), hole 3 = 5 (+1) = 0 total
        roundManager.goToHole(1)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))
        roundManager.goToHole(2)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 3))
        roundManager.goToHole(3)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 5))

        // Then
        if case .active(_, let score) = roundManager.state {
            XCTAssertEqual(score, 0, "Running total for 4+3+5 on par 4+4+4 course = 0")
        } else {
            XCTFail("Expected .active state")
        }
    }

    // MARK: - Optional stats saved when provided

    func test_optionalStats_putsFIRGIR_savedWhenProvided() async throws {
        // Given: optional stats provided
        let entry = RoundManager.HoleScoreEntry(
            strokes: 4,
            putts: 2,
            fairwayHit: "hit",
            greenInRegulation: true
        )

        // When
        await roundManager.recordHoleScore(entry)

        // Then: all optional stats saved
        let score = roundManager.holeScores[1]
        XCTAssertEqual(score?.putts, 2, "Putts should be saved")
        XCTAssertEqual(score?.fairwayHit, "hit", "FIR should be saved")
        XCTAssertEqual(score?.greenInRegulation, true, "GIR should be saved")
    }

    // MARK: - Optional stats nil when not provided

    func test_optionalStats_nilWhenNotProvided() async {
        // Given: only required field (strokes)
        let entry = RoundManager.HoleScoreEntry(
            strokes: 4,
            putts: nil,
            fairwayHit: nil,
            greenInRegulation: nil
        )

        // When
        await roundManager.recordHoleScore(entry)

        // Then: optional fields are nil
        let score = roundManager.holeScores[1]
        XCTAssertNil(score?.putts, "Putts should be nil when not provided")
        XCTAssertNil(score?.fairwayHit, "FIR should be nil when not provided")
        XCTAssertNil(score?.greenInRegulation, "GIR should be nil when not provided")
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

private extension CourseDetail {
    static func fixture() -> CourseDetail {
        let courseId = UUID()
        let holes: [CourseHole] = (1...18).map { i in
            let greenLat = 32.8900 + Double(i) * 0.002
            let greenLon = -117.2500 - Double(i) * 0.002
            let teeLat = 32.8910 + Double(i) * 0.002
            let teeLon = -117.2510 - Double(i) * 0.002
            return CourseHole(
                id: UUID(), courseId: courseId, holeNumber: i,
                par: 4, yardage: 380, handicap: i,
                greenLat: greenLat, greenLon: greenLon,
                greenPolygon: nil,
                teeLat: teeLat, teeLon: teeLon,
                source: "tap_and_save", savedBy: nil,
                createdAt: Date(), updatedAt: Date()
            )
        }
        return CourseDetail(
            course: CourseData(id: courseId, golfcourseapiId: nil, name: "Test",
                               clubName: nil, address: nil, lat: 32.899, lon: -117.251,
                               holeCount: 18, par: 72, osmId: nil, hasGreenData: false,
                               createdAt: Date(), updatedAt: Date()),
            holes: holes, dataSource: .tapAndSave
        )
    }
}
