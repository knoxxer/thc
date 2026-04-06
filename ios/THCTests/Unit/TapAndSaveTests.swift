// TapAndSaveTests.swift
// THCTests/Unit
//
// All 7 specs from §2.5.
// Tests compile but fail (red) until TapAndSave service logic is implemented (M7.6).

import XCTest
import SwiftData
import CoreLocation
@testable import THC

final class TapAndSaveTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var service: TapAndSaveService!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        service = TapAndSaveService(
            supabase: mockSupabase,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        mockSupabase = nil
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

        // Then: Supabase upsert into course_holes with correct fields
        XCTAssertEqual(mockSupabase.upsertCalls.count, 1, "One upsert to course_holes expected")
        let upsert = mockSupabase.upsertCalls.first!
        XCTAssertEqual(upsert.table, "course_holes")
        if let payload = upsert.payload as? [String: Any] {
            XCTAssertEqual(payload["hole_number"] as? Int, holeNumber)
            XCTAssertEqual(payload["source"] as? String, "tap_and_save")
            XCTAssertEqual(payload["green_lat"] as? Double, coordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(payload["green_lon"] as? Double, coordinate.longitude, accuracy: 0.0001)
        }
    }

    // MARK: - §2.5.2 Fetch green pin saved by another user

    func test_fetchGreenPin_savedByAnotherUser() async throws {
        // Given: Supabase has a pin for Hole 3 saved by user B
        let courseID = UUID()
        let expectedHole = CourseHole.fixture(holeNumber: 3, courseId: courseID, source: "tap_and_save")
        mockSupabase.stubbedResponses["course_holes"] = .success([expectedHole])

        // When: user A fetches holes for the same course
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
        mockSupabase.upsertCalls.removeAll()

        // When: user saves a different coordinate for the same hole
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 3,
            greenLat: newCoordinate.latitude,
            greenLon: newCoordinate.longitude,
            savedBy: savedBy
        )

        // Then: upsert (not insert) is called — ensures exactly one row for course+hole
        XCTAssertEqual(mockSupabase.upsertCalls.count, 1, "Overwrite should use upsert, not insert")
        XCTAssertEqual(mockSupabase.insertCalls.count, 0, "Should not insert a duplicate row")
    }

    // MARK: - §2.5.4 Green pin persists across app restarts

    func test_greenPinPersistsAcrossRestart() async throws {
        // Given: green pin is saved in both Supabase and SwiftData
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

        // When: simulate app restart by creating new service with same SwiftData container
        // (network is offline — only local cache available)
        let offlineService = TapAndSaveService(
            supabase: mockSupabase,
            modelContainer: container,
            networkAvailable: false
        )

        // Then: pin is loadable from SwiftData
        let localHoles = try offlineService.getCachedHoles(courseID: courseID)
        XCTAssertFalse(localHoles.isEmpty, "Green pin should persist in SwiftData across restart")
        XCTAssertEqual(localHoles.first?.holeNumber, 5)
    }

    // MARK: - §2.5.5 Save fails offline: queues in SwiftData

    func test_saveFailsOffline_queuesInSwiftData() async throws {
        // Given: network is unavailable
        mockSupabase.upsertError = URLError(.notConnectedToInternet)
        let courseID = UUID()
        let savedBy = UUID()

        // When: user tries to save a green pin
        try await service.saveGreenPin(
            courseId: courseID,
            holeNumber: 7,
            greenLat: 32.8951,
            greenLon: -117.2518,
            savedBy: savedBy
        )

        // Then: pin queued locally with syncStatus = .pending; no crash
        let pendingPins = try service.getPendingPins()
        XCTAssertFalse(pendingPins.isEmpty, "Offline pin should be queued in SwiftData with pending status")
    }

    // MARK: - §2.5.6 Tap-for-distance (no save intent)

    func test_tapForDistance_noSupabaseCall() {
        // Given: user taps any coordinate without intending to save
        let userLocation = CLLocationCoordinate2D(latitude: 32.9010, longitude: -117.2530)
        let tappedLocation = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)

        // When
        let distance = service.instantDistance(from: userLocation, to: tappedLocation)

        // Then: correct Haversine distance; no Supabase call
        XCTAssertGreaterThan(distance, 0, "Distance should be positive")
        XCTAssertEqual(mockSupabase.insertCalls.count, 0, "Tap-for-distance must not call Supabase insert")
        XCTAssertEqual(mockSupabase.upsertCalls.count, 0, "Tap-for-distance must not call Supabase upsert")
    }

    // MARK: - §2.5.7 All 18 greens saved: updates has_green_data

    func test_allEighteenGreensSaved_updatesHasGreenData() async throws {
        // Given: user saves pins for all 18 holes
        let courseID = UUID()
        let savedBy = UUID()

        for holeNumber in 1...18 {
            try await service.saveGreenPin(
                courseId: courseID,
                holeNumber: holeNumber,
                greenLat: 32.8900 + Double(holeNumber) * 0.001,
                greenLon: -117.2500 - Double(holeNumber) * 0.001,
                savedBy: savedBy
            )
        }

        // Then: an update to course_data.has_green_data = true is made
        let hasGreenDataUpdate = mockSupabase.updateCalls.first {
            $0.table == "course_data"
        }
        XCTAssertNotNil(hasGreenDataUpdate, "Saving all 18 greens should update has_green_data on course_data")
        if let payload = hasGreenDataUpdate?.payload as? [String: Any] {
            XCTAssertEqual(payload["has_green_data"] as? Bool, true)
        }
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
