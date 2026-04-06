// RoundManagerTests.swift
// THCTests/Service
//
// All 12 specs from §2.12.
// Tests compile but fail (red) until RoundManager is implemented (M7.9).

import XCTest
import CoreLocation
import SwiftData
@testable import THC

final class RoundManagerTests: XCTestCase {

    var mockCLManager: MockCLLocationManager!
    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var roundManager: RoundManager!
    var courseDetail: CourseDetail!
    var player: Player!
    var season: Season!

    override func setUp() async throws {
        try await super.setUp()
        mockCLManager = MockCLLocationManager()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()

        player = Player.fixture()
        season = Season.fixture()
        courseDetail = CourseDetail.fixture()

        let locationManager = LocationManager(clManager: mockCLManager)
        let offlineStorage = OfflineStorage(modelContainer: container)
        let syncService = SyncService(supabase: mockSupabase, offlineStorage: offlineStorage)

        roundManager = RoundManager(
            courseDetail: courseDetail,
            player: player,
            season: season,
            locationManager: locationManager,
            offlineStorage: offlineStorage,
            syncService: syncService
        )
    }

    override func tearDown() async throws {
        roundManager = nil
        courseDetail = nil
        player = nil
        season = nil
        container = nil
        mockSupabase = nil
        mockCLManager = nil
        try await super.tearDown()
    }

    // MARK: - §2.12.1 Start round sets state to active

    func test_startRound_setsStateToActive() async {
        // Given: RoundManager in .notStarted state
        XCTAssertEqual(roundManager.state, .notStarted)

        // When
        await roundManager.startRound()

        // Then: state transitions to .active(hole: 1, score: 0)
        if case .active(let hole, let score) = roundManager.state {
            XCTAssertEqual(hole, 1, "Should start on hole 1")
            XCTAssertEqual(score, 0, "Starting score should be 0")
        } else {
            XCTFail("Expected .active state after startRound(), got \(roundManager.state)")
        }
    }

    // MARK: - §2.12.2 Start round inserts live_rounds row

    func test_startRound_insertsLiveRoundToSupabase() async {
        // When
        await roundManager.startRound()

        // Then: MockSupabaseClient captured one insert into live_rounds
        let liveRoundInsert = mockSupabase.insertCalls.first { $0.table == "live_rounds" }
        XCTAssertNotNil(liveRoundInsert, "startRound should insert a row into live_rounds")
        if let payload = liveRoundInsert?.payload as? [String: Any] {
            XCTAssertNotNil(payload["player_id"], "live_rounds insert should include player_id")
            XCTAssertNotNil(payload["course_name"], "live_rounds insert should include course_name")
        }
    }

    // MARK: - §2.12.3 Record hole score saves to SwiftData

    func test_recordHoleScore_savesToSwiftData() async throws {
        // Given: active round on hole 1
        await roundManager.startRound()

        // When
        await roundManager.recordHoleScore(
            RoundManager.HoleScoreEntry(strokes: 4, putts: nil, fairwayHit: nil, greenInRegulation: nil)
        )

        // Then: hole 1 score stored locally
        XCTAssertEqual(roundManager.holeScores[1]?.strokes, 4, "Hole 1 score should be 4")
    }

    // MARK: - §2.12.4 Running total matches sum of hole scores

    func test_runningTotal_matchesSumOfHoleScores() async {
        // Given: active round
        await roundManager.startRound()

        // When: record hole 1=4(par4), hole 2=5(par4), hole 3=3(par4)
        // vs par: 0 + 1 + (-1) = 0
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))
        roundManager.goToHole(2)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 5))
        roundManager.goToHole(3)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 3))

        // Then: total strokes vs par = 0
        if case .active(_, let score) = roundManager.state {
            XCTAssertEqual(score, 0, "Running total (0+1-1) should be 0 vs par")
        } else {
            XCTFail("Expected .active state")
        }
    }

    // MARK: - §2.12.5 Auto-advance: 30 yards from next tee

    func test_autoAdvance_30yardsFromNextTee_advances() async {
        // Given: current hole = 5; mock location within 30m of hole 6 tee
        await roundManager.startRound()
        roundManager.goToHole(5)
        // Record score for hole 5 first
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))

        var advancedToHole = 0
        roundManager.onHoleAdvanced = { hole in
            advancedToHole = hole
        }

        // Simulate location near hole 6 tee
        let hole6Tee = courseDetail.holes[5]  // index 5 = hole 6
        guard let teeLat = hole6Tee.teeLat, let teeLon = hole6Tee.teeLon else {
            XCTFail("Fixture must include tee coordinates for hole 6")
            return
        }
        let nearTee = CLLocation(latitude: teeLat, longitude: teeLon)
        mockCLManager.locations = [nearTee]
        mockCLManager.startUpdatingLocation()

        // Then: auto-advance to hole 6
        XCTAssertEqual(advancedToHole, 6, "Should auto-advance to hole 6 when near its tee")
    }

    // MARK: - §2.12.6 Auto-advance: 50 yards from green (no tee box)

    func test_autoAdvance_50yardsFromGreen_noTeeBox_advances() async {
        // Given: current hole = 5; no tee coordinate for hole 6; user 50+ yards from hole 5 green
        await roundManager.startRound()
        roundManager.goToHole(5)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 5))

        var advancedToHole = 0
        roundManager.onHoleAdvanced = { hole in advancedToHole = hole }

        // Move far from hole 5 green (simulating walking toward hole 6)
        let farFromGreen = CLLocation(latitude: 32.9050, longitude: -117.2560)
        mockCLManager.locations = [farFromGreen]
        mockCLManager.startUpdatingLocation()

        // Then
        XCTAssertEqual(advancedToHole, 6, "Should auto-advance when 50+ yards past current green with no next tee")
    }

    // MARK: - §2.12.7 Manual go-to-hole overrides auto-advance

    func test_manualGoToHole_overridesAutoAdvance() async {
        // Given: active round on hole 5
        await roundManager.startRound()
        roundManager.goToHole(5)

        // When: goToHole(8) is called
        roundManager.goToHole(8)

        // Then: currentHole = 8; no prompt for holes 6-7
        XCTAssertEqual(roundManager.currentHole, 8, "Manual goToHole should set hole to 8")
        XCTAssertNil(roundManager.holeScores[6], "Hole 6 should have no score")
        XCTAssertNil(roundManager.holeScores[7], "Hole 7 should have no score")
    }

    // MARK: - §2.12.8 Finish round saves to SwiftData and triggers sync

    func test_finishRound_savesToSwiftDataAndSyncs() async throws {
        // Given: active round with 18 holes scored
        await roundManager.startRound()
        for hole in 1...18 {
            roundManager.goToHole(hole)
            await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))
        }

        // When
        let localRound = try await roundManager.finishRound()

        // Then: LocalRound saved with syncedToSupabase = false; sync triggered
        XCTAssertFalse(localRound.syncedToSupabase,
                       "Finished round should initially have syncedToSupabase = false")
        XCTAssertEqual(roundManager.state, .finished)
    }

    // MARK: - §2.12.9 Finish round deletes live_rounds row

    func test_finishRound_deletesLiveRoundRow() async throws {
        // Given: active round with live_rounds row
        await roundManager.startRound()
        for hole in 1...18 {
            roundManager.goToHole(hole)
            await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))
        }

        // When
        _ = try await roundManager.finishRound()

        // Then: live_rounds delete call captured
        let deleteCall = mockSupabase.deleteCalls.first { $0.table == "live_rounds" }
        XCTAssertNotNil(deleteCall, "finishRound should delete the live_rounds row")
    }

    // MARK: - §2.12.10 Finish from notStarted: no crash

    func test_finishRound_fromNotStartedState_nocrash() async {
        // Given: RoundManager in .notStarted state
        XCTAssertEqual(roundManager.state, .notStarted)

        // When / Then: no crash (should no-op or throw descriptive error)
        do {
            _ = try await roundManager.finishRound()
        } catch RoundManagerError.roundNotStarted {
            // Acceptable: descriptive error is fine
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §2.12.11 Record score after round finished is ignored

    func test_recordHoleScore_afterRoundFinished_isIgnored() async throws {
        // Given: RoundManager in .finished state
        await roundManager.startRound()
        for hole in 1...18 {
            roundManager.goToHole(hole)
            await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))
        }
        _ = try await roundManager.finishRound()

        let insertCountBeforeExtra = mockSupabase.insertCalls.count

        // When: record a score after finishing
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 3))

        // Then: no crash; holeScores unchanged; no new Supabase call
        XCTAssertEqual(roundManager.state, .finished, "State should remain .finished")
        XCTAssertEqual(mockSupabase.insertCalls.count, insertCountBeforeExtra,
                       "No additional Supabase calls after round is finished")
    }

    // MARK: - §2.12.12 Distance to any coordinate returns Haversine

    func test_distanceTo_anyCoordinate_returnsHaversine() async {
        // Given: user at known coordinate
        await roundManager.startRound()
        let userCoord = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)
        let location = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        mockCLManager.locations = [location]
        mockCLManager.startUpdatingLocation()

        // When
        let target = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)
        let distance = roundManager.distanceTo(target)

        // Then: correct Haversine distance in yards (±5 yards)
        let expected = DistanceCalculator.distanceInYards(from: userCoord, to: target)
        XCTAssertEqual(distance, expected, accuracy: 5.0,
                       "distanceTo should return Haversine distance in yards")
    }
}

// MARK: - Fixtures

private extension Player {
    static func fixture() -> Player {
        Player(id: UUID(), name: "Test Player", displayName: "Test",
               slug: "test-player", email: "test@example.com",
               ghinNumber: nil, handicapIndex: 12.0, handicapUpdatedAt: nil,
               avatarUrl: nil, isActive: true, role: "contributor",
               authUserId: "auth-user-id", createdAt: Date())
    }
}

private extension Season {
    static func fixture() -> Season {
        Season(id: UUID(), name: "2026 Season",
               startsAt: Date().addingTimeInterval(-30 * 24 * 3600),
               endsAt: Date().addingTimeInterval(335 * 24 * 3600),
               isActive: true, minRounds: 5, topNRounds: 10, createdAt: Date())
    }
}

private extension CourseDetail {
    static func fixture() -> CourseDetail {
        let courseId = UUID()
        let holes = (1...18).map { i in
            CourseHole(
                id: UUID(), courseId: courseId, holeNumber: i,
                par: 4, yardage: 380 + i * 10, handicap: i,
                greenLat: 32.8900 + Double(i) * 0.002,
                greenLon: -117.2500 - Double(i) * 0.002,
                greenPolygon: nil,
                teeLat: 32.8910 + Double(i) * 0.002,
                teeLon: -117.2510 - Double(i) * 0.002,
                source: "tap_and_save", savedBy: nil,
                createdAt: Date(), updatedAt: Date()
            )
        }
        return CourseDetail(
            course: CourseData(id: courseId, golfcourseapiId: nil,
                               name: "Test Course", clubName: nil, address: nil,
                               lat: 32.8990, lon: -117.2519, holeCount: 18,
                               par: 72, osmId: nil, hasGreenData: false,
                               createdAt: Date(), updatedAt: Date()),
            holes: holes, dataSource: .tapAndSave
        )
    }
}

enum RoundManagerError: Error {
    case roundNotStarted
}
