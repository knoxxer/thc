// LiveScoringTests.swift
// THCTests/Service
//
// All 5 specs from M9.1.
// Tests compile but fail (red) until RoundManager live scoring is implemented (M9.2).

import XCTest
import SwiftData
@testable import THC

final class LiveScoringTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var roundManager: RoundManager!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()

        let locationManager = LocationManager(clManager: MockCLLocationManager())
        let offlineStorage = OfflineStorage(modelContainer: container)
        let syncService = SyncService(supabase: mockSupabase, offlineStorage: offlineStorage)

        roundManager = RoundManager(
            courseDetail: CourseDetail.fixture(),
            player: Player.fixture(),
            season: Season.fixture(),
            locationManager: locationManager,
            offlineStorage: offlineStorage,
            syncService: syncService
        )

        await roundManager.startRound()
    }

    override func tearDown() async throws {
        roundManager = nil
        container = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - §M9.1 — auto-advance triggers at correct proximity

    func test_autoAdvanceTriggers_atCorrectProximity() {
        // Given: user moves to within 30m of next hole tee
        // This is tested more thoroughly in RoundManagerTests
        // Here we verify the live scoring path triggers it correctly
        roundManager.goToHole(1)

        var holeAdvanced = false
        roundManager.onHoleAdvanced = { _ in holeAdvanced = true }

        // Simulate movement to hole 2 tee proximity
        let hole2Tee = roundManager.courseDetail?.holes[1]
        if let lat = hole2Tee?.teeLat, let lon = hole2Tee?.teeLon {
            let location = CLLocation(latitude: lat, longitude: lon)
            // Trigger location update
            roundManager.handleLocationUpdate(location)
        }

        XCTAssertTrue(holeAdvanced, "Auto-advance should trigger at correct proximity to next tee")
    }

    // MARK: - Score persists to SwiftData

    func test_scoreRecorded_persistsToSwiftData() async throws {
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
        let score = roundManager.holeScores[roundManager.currentHole]
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
        let score = roundManager.holeScores[roundManager.currentHole]
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
        let holes = (1...18).map { i in
            CourseHole(id: UUID(), courseId: courseId, holeNumber: i,
                       par: 4, yardage: 380, handicap: i,
                       greenLat: 32.8900 + Double(i) * 0.002,
                       greenLon: -117.2500 - Double(i) * 0.002,
                       greenPolygon: nil,
                       teeLat: 32.8910 + Double(i) * 0.002,
                       teeLon: -117.2510 - Double(i) * 0.002,
                       source: "tap_and_save", savedBy: nil,
                       createdAt: Date(), updatedAt: Date())
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
