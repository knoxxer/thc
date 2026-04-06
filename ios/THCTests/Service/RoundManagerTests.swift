// RoundManagerTests.swift
// THCTests/Service
//
// All 12 specs from §2.12.
// Tests compile but fail (red) until RoundManager is implemented (M7.9).

import XCTest
import CoreLocation
import SwiftData
import Shared
@testable import THC

final class RoundManagerTests: XCTestCase {

    var mockCLManager: MockCLLocationManager!
    var mockSupabase: StubSupabaseClient!
    var mockBroadcaster: MockLiveRoundBroadcaster!
    var container: ModelContainer!
    var roundManager: RoundManager!
    var courseDetail: CourseDetail!
    var player: Player!
    var season: Season!

    override func setUp() async throws {
        try await super.setUp()
        mockCLManager = MockCLLocationManager()
        mockSupabase = StubSupabaseClient()
        mockBroadcaster = MockLiveRoundBroadcaster()
        container = try TestModelContainer.create()

        player = Player.fixture()
        season = Season.fixture()
        courseDetail = CourseDetail.fixture()

        let locationManager = LocationManager(clManager: mockCLManager)
        let context = ModelContext(container)
        let offlineStorage = OfflineStorage(context: context)
        let syncService = SyncService(supabase: mockSupabase, storage: offlineStorage)

        roundManager = RoundManager(
            courseDetail: courseDetail,
            player: player,
            season: season,
            locationManager: locationManager,
            offlineStorage: offlineStorage,
            syncService: syncService,
            liveRoundBroadcaster: mockBroadcaster
        )
    }

    override func tearDown() async throws {
        roundManager = nil
        courseDetail = nil
        player = nil
        season = nil
        container = nil
        mockSupabase = nil
        mockBroadcaster = nil
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

    // MARK: - §2.12.2 Start round broadcasts live round and starts GPS

    func test_startRound_broadcastsLiveRoundAndStartsGPS() async {
        // When
        await roundManager.startRound()

        // Then: LocationManager.startRoundTracking was called (CLManager started)
        XCTAssertEqual(mockCLManager.startUpdatingLocationCallCount, 1,
                       "startRound should start GPS tracking")

        // And: live round broadcaster received startLiveRound call
        XCTAssertEqual(mockBroadcaster.startCalls.count, 1,
                       "startRound should call startLiveRound on the broadcaster")
        XCTAssertEqual(mockBroadcaster.startCalls.first?.courseName, "Test Course")
    }

    // MARK: - §2.12.3 Record hole score saves to holeScores

    func test_recordHoleScore_savesToHoleScores() async throws {
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
        // Given: active round; record hole 5 score so auto-advance is eligible
        await roundManager.startRound()
        roundManager.goToHole(5)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 4))

        // Hole 6 tee from the fixture
        let hole6 = courseDetail.holes[5]  // index 5 = hole 6
        guard let teeLat = hole6.teeLat, let teeLon = hole6.teeLon else {
            XCTFail("Fixture must include tee coordinates for hole 6")
            return
        }

        // When: inject a location right on hole 6 tee — within 27.4m threshold
        let nearTee = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: teeLat, longitude: teeLon),
            altitude: 30,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 1.0,
            timestamp: Date()
        )
        mockCLManager.locations = [nearTee]
        mockCLManager.startUpdatingLocation()

        // Yield to let the async locationTask process the update
        for _ in 0..<10 {
            await Task.yield()
        }

        // Then: currentHole advanced to 6
        XCTAssertEqual(roundManager.currentHole, 6,
                       "Should auto-advance to hole 6 when within 30 yards of its tee")
    }

    // MARK: - §2.12.6 Auto-advance: 50 yards from green (no tee box)

    func test_autoAdvance_50yardsFromGreen_noTeeBox_advances() async {
        // Given: current hole = 5; record score so auto-advance is eligible
        await roundManager.startRound()
        roundManager.goToHole(5)
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 5))

        // Build a course where hole 6 has no tee coordinates
        let courseId = UUID()
        var holes: [CourseHole] = (1...18).map { (i: Int) -> CourseHole in
            let gLat = 32.8900 + Double(i) * 0.002
            let gLon = -117.2500 - Double(i) * 0.002
            let tLat = 32.8910 + Double(i) * 0.002
            let tLon = -117.2510 - Double(i) * 0.002
            return CourseHole(
                id: UUID(), courseId: courseId, holeNumber: i,
                par: 4, yardage: 380 + i * 10, handicap: i,
                greenLat: gLat, greenLon: gLon, greenPolygon: nil,
                teeLat: tLat, teeLon: tLon,
                source: "tap_and_save", savedBy: nil,
                createdAt: Date(), updatedAt: Date()
            )
        }
        // Remove tee coordinates from hole 6 to force the green-distance path
        holes[5] = CourseHole(
            id: UUID(), courseId: courseId, holeNumber: 6,
            par: 4, yardage: 400, handicap: 6,
            greenLat: 32.8912, greenLon: -117.2512,
            greenPolygon: nil,
            teeLat: nil, teeLon: nil,  // no tee box
            source: "tap_and_save", savedBy: nil,
            createdAt: Date(), updatedAt: Date()
        )

        // Use a fresh RoundManager with this course layout
        let locationManager2 = LocationManager(clManager: mockCLManager)
        let context = ModelContext(container)
        let storage = OfflineStorage(context: context)
        let sync = SyncService(supabase: mockSupabase, storage: storage)
        let noTeeCourse = CourseDetail(
            course: CourseData(
                id: courseId, golfcourseapiId: nil,
                name: "No Tee Course", clubName: nil, address: nil,
                lat: 32.8990, lon: -117.2519, holeCount: 18,
                par: 72, osmId: nil, hasGreenData: false,
                createdAt: Date(), updatedAt: Date()
            ),
            holes: holes, dataSource: .tapAndSave
        )
        let rm2 = RoundManager(
            courseDetail: noTeeCourse,
            player: player, season: season,
            locationManager: locationManager2,
            offlineStorage: storage,
            syncService: sync,
            liveRoundBroadcaster: MockLiveRoundBroadcaster()
        )

        await rm2.startRound()
        rm2.goToHole(5)
        await rm2.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 5))

        // Hole 5 green is at (32.8910, -117.2510) per fixture
        // Move far from it: go > 45.7m away
        let farFromGreen = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 32.8960, longitude: -117.2560),
            altitude: 30, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 1.0, timestamp: Date()
        )
        mockCLManager.locations = [farFromGreen]
        mockCLManager.startUpdatingLocation()

        for _ in 0..<10 {
            await Task.yield()
        }

        // Then: auto-advanced to hole 6 via green-distance fallback
        XCTAssertEqual(rm2.currentHole, 6,
                       "Should auto-advance when 50+ yards past current green with no next tee")
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

    // MARK: - §2.12.8 Finish round sets state to finished

    func test_finishRound_setsStateToFinished() async throws {
        // Given: active round
        await roundManager.startRound()

        // When
        _ = try await roundManager.finishRound()

        // Then
        XCTAssertEqual(roundManager.state, .finished)
    }

    // MARK: - §2.12.9 Finish round stops GPS and deletes live round

    func test_finishRound_stopsGPSAndDeletesLiveRound() async throws {
        // Given: active round with GPS running
        await roundManager.startRound()
        XCTAssertEqual(mockCLManager.startUpdatingLocationCallCount, 1)
        XCTAssertEqual(mockBroadcaster.startCalls.count, 1)

        // When
        _ = try await roundManager.finishRound()

        // Then: GPS stopped
        XCTAssertEqual(mockCLManager.stopUpdatingLocationCallCount, 1,
                       "finishRound should stop GPS tracking")

        // And: live round deleted via broadcaster
        XCTAssertEqual(mockBroadcaster.deleteCalls.count, 1,
                       "finishRound should delete the live round via broadcaster")
    }

    // MARK: - §2.12.10 Finish from notStarted: throws roundNotStarted

    func test_finishRound_fromNotStartedState_throwsRoundNotStarted() async {
        // Given: RoundManager in .notStarted state
        XCTAssertEqual(roundManager.state, .notStarted)

        // When / Then: should throw RoundManagerError.roundNotStarted
        do {
            _ = try await roundManager.finishRound()
            XCTFail("Expected RoundManagerError.roundNotStarted to be thrown")
        } catch RoundManagerError.roundNotStarted {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §2.12.11 Record score after round finished is ignored

    func test_recordHoleScore_afterRoundFinished_isIgnored() async throws {
        // Given: RoundManager in .finished state
        await roundManager.startRound()
        _ = try await roundManager.finishRound()
        XCTAssertEqual(roundManager.state, .finished)

        let scoresBeforeExtra = roundManager.holeScores.count

        // When: record a score after finishing
        await roundManager.recordHoleScore(RoundManager.HoleScoreEntry(strokes: 3))

        // Then: no crash; holeScores unchanged (recordHoleScore guards on .active state)
        XCTAssertEqual(roundManager.state, .finished, "State should remain .finished")
        XCTAssertEqual(roundManager.holeScores.count, scoresBeforeExtra,
                       "No additional hole scores should be recorded after round is finished")
    }

    // MARK: - §2.12.12 Distance to any coordinate returns Haversine

    func test_distanceTo_anyCoordinate_returnsHaversine() async {
        // Given: user at known coordinate
        await roundManager.startRound()
        let userCoord = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)
        let location = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        mockCLManager.locations = [location]
        mockCLManager.startUpdatingLocation()

        // Allow the delegate callback to fire
        for _ in 0..<5 {
            await Task.yield()
        }

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
        let holes: [CourseHole] = (1...18).map { (i: Int) -> CourseHole in
            let gLat = 32.8900 + Double(i) * 0.002
            let gLon = -117.2500 - Double(i) * 0.002
            let tLat = 32.8910 + Double(i) * 0.002
            let tLon = -117.2510 - Double(i) * 0.002
            return CourseHole(
                id: UUID(), courseId: courseId, holeNumber: i,
                par: 4, yardage: 380 + i * 10, handicap: i,
                greenLat: gLat, greenLon: gLon, greenPolygon: nil,
                teeLat: tLat, teeLon: tLon,
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
