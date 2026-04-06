// TapAndSaveTests.swift
// THCTests/Unit
//
// All 7 specs from §2.5.
// Uses MockTapAndSavePersistence to intercept Supabase calls without a real backend.
// SwiftData is exercised via an in-memory ModelContainer for offline/cache tests.

import XCTest
import SwiftData
import CoreLocation
import Shared
@testable import THC

final class TapAndSaveTests: XCTestCase {

    var mockPersistence: MockTapAndSavePersistence!
    var container: ModelContainer!
    var service: TapAndSaveService!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockTapAndSavePersistence()
        container = try TestModelContainer.create()
        service = TapAndSaveService(
            persistence: mockPersistence,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - §2.5.1 Save new green pin

    func test_saveNewGreenPin_insertsToSupabase() async throws {
        // Given: user taps at a coordinate and confirms
        let coordinate = CLLocationCoordinate2D(latitude: 32.8951, longitude: -117.2518)
        let courseID = UUID()
        let holeNumber = 3
        let savedBy = UUID()

        // When
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: holeNumber,
            greenLat: coordinate.latitude,
            greenLon: coordinate.longitude,
            savedBy: savedBy
        )

        // Then: one upsert to course_holes with correct fields
        XCTAssertEqual(mockPersistence.upsertCalls.count, 1, "One upsert to course_holes expected")
        let upsert = mockPersistence.upsertCalls.first!
        XCTAssertEqual(upsert.table, "course_holes")
        XCTAssertEqual(upsert.payload.holeNumber, holeNumber)
        XCTAssertEqual(upsert.payload.source, "tap_and_save")
        XCTAssertEqual(upsert.payload.greenLat, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(upsert.payload.greenLon, coordinate.longitude, accuracy: 0.0001)
    }

    // MARK: - §2.5.2 Fetch green pin saved by another user

    func test_fetchGreenPin_savedByAnotherUser() async throws {
        // Given: Supabase has a pin for Hole 3 saved by another user
        let courseID = UUID()
        let expectedHole = CourseHole.fixture(holeNumber: 3, courseId: courseID, source: "tap_and_save")
        mockPersistence.stubbedHoles = [expectedHole]

        // When: fetch holes for the same course
        let holes = try await service.fetchCourseHoles(courseID: courseID)

        // Then: pin is returned and distances can be computed
        XCTAssertFalse(holes.isEmpty, "Should return the pin saved by another user")
        XCTAssertEqual(holes.first?.holeNumber, 3)
        XCTAssertNotNil(holes.first?.greenLat, "Green lat should be present")
        XCTAssertNotNil(holes.first?.greenLon, "Green lon should be present")
    }

    // MARK: - §2.5.3 Overwrite existing green pin

    func test_overwriteExistingGreenPin_replacesOld() async throws {
        // Given: a pin already exists for Hole 3
        let courseID = UUID()
        let oldCoordinate = CLLocationCoordinate2D(latitude: 32.8951, longitude: -117.2518)
        let newCoordinate = CLLocationCoordinate2D(latitude: 32.8955, longitude: -117.2512)
        let savedBy = UUID()

        // Save original pin
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 3,
            greenLat: oldCoordinate.latitude,
            greenLon: oldCoordinate.longitude,
            savedBy: savedBy
        )
        let firstCount = mockPersistence.upsertCalls.count
        XCTAssertEqual(firstCount, 1)

        // When: user saves a different coordinate for the same hole
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 3,
            greenLat: newCoordinate.latitude,
            greenLon: newCoordinate.longitude,
            savedBy: savedBy
        )

        // Then: second upsert was called (onConflict = "course_id,hole_number" ensures one row)
        XCTAssertEqual(mockPersistence.upsertCalls.count, 2,
                       "Overwrite should use upsert — two upsert calls total, one per save")
        // Only one hole should exist in the stub (upsert semantics)
        XCTAssertEqual(mockPersistence.stubbedHoles.filter { $0.holeNumber == 3 }.count, 1,
                       "Upsert should result in exactly one row for hole 3")
        XCTAssertEqual(mockPersistence.stubbedHoles.first?.greenLat ?? 0,
                       newCoordinate.latitude, accuracy: 0.0001,
                       "Latest coordinate should replace the old one")
    }

    // MARK: - §2.5.4 Green pin persists across app restarts

    func test_greenPinPersistsAcrossRestart() async throws {
        // Given: green pin is saved to both Supabase and SwiftData
        let courseID = UUID()
        let coordinate = CLLocationCoordinate2D(latitude: 32.8951, longitude: -117.2518)
        let savedBy = UUID()

        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 5,
            greenLat: coordinate.latitude,
            greenLon: coordinate.longitude,
            savedBy: savedBy
        )

        // When: simulate app restart by creating a new service with the same ModelContainer
        // (network is offline — only local SwiftData cache available)
        let offlineService = TapAndSaveService(
            persistence: mockPersistence,
            modelContainer: container
        )

        // Then: pin is loadable from SwiftData
        let localHoles = try offlineService.getCachedHoles(courseID: courseID)
        XCTAssertFalse(localHoles.isEmpty, "Green pin should persist in SwiftData across restart")
        XCTAssertEqual(localHoles.first?.holeNumber, 5)
        XCTAssertEqual(localHoles.first?.greenLat ?? 0, coordinate.latitude, accuracy: 0.0001)
    }

    // MARK: - §2.5.5 Save fails offline: queues in SwiftData

    func test_saveFailsOffline_queuesInSwiftData() async throws {
        // Given: network is unavailable — next upsert will throw
        mockPersistence.upsertError = URLError(.notConnectedToInternet)
        let courseID = UUID()
        let savedBy = UUID()

        // When: user tries to save a green pin (upsert throws → caught internally)
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 7,
            greenLat: 32.8951,
            greenLon: -117.2518,
            savedBy: savedBy
        )

        // Then: pin queued locally with syncStatus = pending; no crash; no throw propagated
        let pendingPins = try service.getPendingPins()
        XCTAssertFalse(pendingPins.isEmpty,
                       "Offline pin should be queued in SwiftData with pending status")
        XCTAssertEqual(pendingPins.first?.holeNumber, 7)
        XCTAssertTrue(pendingPins.first?.isPendingSync ?? false,
                      "Queued pin should have source = 'tap_and_save_pending'")
    }

    // MARK: - §2.5.6 Tap-for-distance (no save intent)

    func test_tapForDistance_noSupabaseCall() {
        // Given: user taps any coordinate without intending to save
        let userLocation = CLLocationCoordinate2D(latitude: 32.9010, longitude: -117.2530)
        let tappedLocation = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)

        // When
        let distance = service.instantDistance(from: userLocation, to: tappedLocation)

        // Then: correct Haversine distance; no persistence calls
        XCTAssertGreaterThan(distance, 0, "Distance should be positive")
        XCTAssertEqual(mockPersistence.upsertCalls.count, 0,
                       "Tap-for-distance must not call persistence upsert")
        XCTAssertEqual(mockPersistence.updateCalls.count, 0,
                       "Tap-for-distance must not call persistence update")
    }

    // MARK: - §2.5.7 All 18 greens saved: updates has_green_data

    func test_allEighteenGreensSaved_updatesHasGreenData() async throws {
        // Given: course has 18 holes; configure stub to expose holeCount = 18
        let courseID = UUID()
        let savedBy = UUID()
        mockPersistence.stubbedHoleCount = 18

        for holeNumber in 1...18 {
            try await service.saveGreenPin(
                courseId: courseID,
                holeNumber: holeNumber,
                greenLat: 32.8900 + Double(holeNumber) * 0.001,
                greenLon: -117.2500 - Double(holeNumber) * 0.001,
                savedBy: savedBy
            )
        }

        // Then: markCourseHasGreenData was called at some point
        let hasGreenDataUpdate = mockPersistence.updateCalls.first {
            $0.table == "course_data"
        }
        XCTAssertNotNil(hasGreenDataUpdate,
                        "Saving all 18 greens should trigger markCourseHasGreenData")
        XCTAssertEqual(hasGreenDataUpdate?.payload["has_green_data"] as? Bool, true)
    }
}

// MARK: - Fixtures

private extension CourseHole {
    static func fixture(holeNumber: Int, courseId: UUID, source: String) -> CourseHole {
        CourseHole(
            id: UUID(),
            courseId: courseId,
            holeNumber: holeNumber,
            par: 4,
            yardage: 380,
            handicap: 7,
            greenLat: 32.8951,
            greenLon: -117.2518,
            greenPolygon: nil,
            teeLat: 32.8964,
            teeLon: -117.2528,
            source: source,
            savedBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
