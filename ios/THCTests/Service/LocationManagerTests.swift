// LocationManagerTests.swift
// THCTests/Service
//
// All 9 specs from §2.6.
// Tests compile but fail (red) until LocationManager is implemented (M7.8).

import XCTest
import CoreLocation
@testable import THC

final class LocationManagerTests: XCTestCase {

    var mockCLManager: MockCLLocationManager!
    var locationManager: LocationManager!

    override func setUp() async throws {
        try await super.setUp()
        mockCLManager = MockCLLocationManager()
        locationManager = LocationManager(clManager: mockCLManager)
    }

    override func tearDown() async throws {
        locationManager = nil
        mockCLManager = nil
        try await super.tearDown()
    }

    // MARK: - §2.6.1 Tracking starts with best accuracy

    func test_trackingStartsWithBestAccuracy() {
        // When
        locationManager.startRoundTracking()

        // Then: CLLocationManager.startUpdatingLocation called
        XCTAssertEqual(mockCLManager.startUpdatingLocationCallCount, 1,
                       "startUpdatingLocation should be called exactly once")
        XCTAssertEqual(mockCLManager.desiredAccuracy, kCLLocationAccuracyBest,
                       "desiredAccuracy should be set to kCLLocationAccuracyBest")
        XCTAssertTrue(mockCLManager.allowsBackgroundLocationUpdates,
                      "allowsBackgroundLocationUpdates should be true during round")
    }

    // MARK: - §2.6.2 Tracking stops on round end

    func test_trackingStopsOnRoundEnd() {
        // Given
        locationManager.startRoundTracking()

        // When
        locationManager.stopRoundTracking()

        // Then
        XCTAssertEqual(mockCLManager.stopUpdatingLocationCallCount, 1,
                       "stopUpdatingLocation should be called exactly once")
        XCTAssertFalse(mockCLManager.allowsBackgroundLocationUpdates,
                       "allowsBackgroundLocationUpdates should be false after round ends")
    }

    // MARK: - §2.6.3 Battery optimization: polling reduces when stationary

    func test_stationaryReducesPolling() {
        // Given: LocationManager is tracking
        locationManager.startRoundTracking()

        // Simulate user stationary for 30+ seconds (speed < 2 mph / 0.9 m/s)
        let stationaryLocations = MockCLLocationManager.stationaryOnFairway
        // Manually fire location updates via delegate to simulate stationary period
        for location in stationaryLocations {
            locationManager.locationManager(
                CLLocationManager(),
                didUpdateLocations: [location]
            )
        }

        // Then: distanceFilter = 10m (reduced polling)
        XCTAssertEqual(mockCLManager.distanceFilter, 10.0,
                       "Should reduce polling to distanceFilter=10m when stationary")
    }

    // MARK: - §2.6.4 Battery optimization: polling resumes when moving

    func test_movementResumesPolling() {
        // Given: was stationary (reduced polling)
        locationManager.startRoundTracking()
        for location in MockCLLocationManager.stationaryOnFairway {
            locationManager.locationManager(CLLocationManager(), didUpdateLocations: [location])
        }

        // When: user starts moving (speed > 0.9 m/s)
        let movingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2521),
            altitude: 30,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 180,
            speed: 2.0,  // 2 m/s > threshold
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [movingLocation])

        // Then: reverts to continuous updates / best accuracy
        XCTAssertEqual(mockCLManager.desiredAccuracy, kCLLocationAccuracyBest,
                       "Should revert to best accuracy when user starts moving")
        XCTAssertEqual(mockCLManager.distanceFilter, kCLDistanceFilterNone,
                       "Should revert to continuous updates when moving")
    }

    // MARK: - §2.6.5 Auto-advance: proximity to next tee

    func test_autoAdvance_nearNextTee() {
        // Given: current hole = 5; hole 6 tee at known coordinate
        let hole6Tee = CLLocationCoordinate2D(latitude: 32.8970, longitude: -117.2505)
        let courseDetail = CourseDetail.fixture(nextTeeCoordinate: hole6Tee, forHole: 6)
        locationManager.configure(courseDetail: courseDetail, currentHole: 5)

        var holeChanged = false
        locationManager.onHoleChange = { from, to in
            XCTAssertEqual(from, 5)
            XCTAssertEqual(to, 6)
            holeChanged = true
        }

        // When: user moves within 30m of hole 6 tee
        let nearTeeLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 32.8970, longitude: -117.2505),
            altitude: 30,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 1.0,
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [nearTeeLocation])

        // Then: currentHole advances to 6
        XCTAssertTrue(holeChanged, "onHoleChange should be called when approaching next tee")
    }

    // MARK: - §2.6.6 No false advance when on the green

    func test_noFalseAdvance_onGreenNearNextTee() {
        // Given: user on hole 5 green, which is adjacent to hole 6 tee area
        let hole5GreenCenter = CLLocationCoordinate2D(latitude: 32.8972, longitude: -117.2507)
        let hole6Tee = CLLocationCoordinate2D(latitude: 32.8970, longitude: -117.2505)
        let courseDetail = CourseDetail.fixture(
            currentGreenCoordinate: hole5GreenCenter,
            nextTeeCoordinate: hole6Tee,
            forHole: 6
        )
        locationManager.configure(courseDetail: courseDetail, currentHole: 5)
        locationManager.markCurrentHoleInProgress()  // indicate score not yet entered

        var holeChanged = false
        locationManager.onHoleChange = { _, _ in holeChanged = true }

        // When: user is on hole 5 green (near hole 6 tee, but round not finished for hole 5)
        let onGreenLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 32.8972, longitude: -117.2507),
            altitude: 27,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0.0,  // stationary on green
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [onGreenLocation])

        // Then: currentHole does NOT advance
        XCTAssertFalse(holeChanged,
                       "Should NOT advance hole while user is on current hole green without completing the hole")
    }

    // MARK: - §2.6.7 Background resume: valid location

    func test_foregroundResume_validLocation() {
        // Given: was tracking when backgrounded; user walked 200 yards
        locationManager.startRoundTracking()
        let startLocation = CLLocation(latitude: 32.9014, longitude: -117.2533)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [startLocation])

        // When: app returns to foreground with new location
        let newLocation = CLLocation(latitude: 32.8998, longitude: -117.2520)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [newLocation])

        // Then: current location is updated; no stale distance
        XCTAssertNotNil(locationManager.currentLocation)
        XCTAssertEqual(locationManager.currentLocation?.coordinate.latitude,
                       newLocation.coordinate.latitude,
                       accuracy: 0.0001)
    }

    // MARK: - §2.6.8 Permission denied: graceful degradation

    func test_permissionDenied_gracefulDegradation() {
        // Given: permission denied
        let deniedManager = MockCLLocationManager.permissionDenied
        let manager = LocationManager(clManager: deniedManager)

        var receivedError = false
        manager.onPermissionDenied = {
            receivedError = true
        }

        // When
        manager.startRoundTracking()

        // Then: error state published; no crash
        XCTAssertTrue(receivedError, "Permission denied should trigger error callback")
        XCTAssertFalse(manager.isTracking, "Should not be tracking when permission is denied")
    }
}

// MARK: - CourseDetail fixture

private extension CourseDetail {
    static func fixture(
        nextTeeCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 32.8970, longitude: -117.2505),
        currentGreenCoordinate: CLLocationCoordinate2D? = nil,
        forHole: Int = 2
    ) -> CourseDetail {
        // Minimal CourseDetail with enough hole data to test auto-advance
        let holes = (1...18).map { i in
            CourseHole(
                id: UUID(),
                courseId: UUID(),
                holeNumber: i,
                par: 4,
                yardage: 380,
                handicap: i,
                greenLat: i == forHole - 1 ? currentGreenCoordinate?.latitude : nil,
                greenLon: i == forHole - 1 ? currentGreenCoordinate?.longitude : nil,
                greenPolygon: nil,
                teeLat: i == forHole ? nextTeeCoordinate.latitude : nil,
                teeLon: i == forHole ? nextTeeCoordinate.longitude : nil,
                source: "tap_and_save",
                savedBy: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        return CourseDetail(
            course: CourseData(
                id: UUID(),
                golfcourseapiId: nil,
                name: "Test Course",
                clubName: nil,
                address: nil,
                lat: 32.8990,
                lon: -117.2519,
                holeCount: 18,
                par: 72,
                osmId: nil,
                hasGreenData: false,
                createdAt: Date(),
                updatedAt: Date()
            ),
            holes: holes,
            dataSource: .tapAndSave
        )
    }
}
