// HazardDistanceTests.swift
// THCTests/Unit
//
// Specs 2.2.8-2.2.11: hazard carry distance, hazard front edge,
// layup target coordinate, dogleg distance.
// Tests compile but fail (red) until hazard/layup logic is implemented (M10.2).

import XCTest
import CoreLocation
@testable import THC

final class HazardDistanceTests: XCTestCase {

    // MARK: - §2.2.8 Hazard carry distance (far edge)

    func test_hazardCarryDistance_farEdge_withinTolerance() {
        // Given: a bunker polygon positioned 140–155 yards from the user
        // User is standing at the tee
        let userLocation = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)

        // Bunker polygon: near edge ~140 yards away, far edge ~155 yards away
        // Constructed to be on the approach line (due south of user)
        let bunkerPolygon = GeoJSONPolygon(
            type: "Polygon",
            coordinates: [[
                [-117.2533, 32.8885],  // near-left (~140 yards)
                [-117.2530, 32.8885],  // near-right
                [-117.2530, 32.8872],  // far-right (~155 yards)
                [-117.2533, 32.8872],  // far-left
                [-117.2533, 32.8885],  // close
            ]]
        )

        // When
        let distances = DistanceCalculator.hazardDistances(
            userLocation: userLocation,
            hazardPolygon: bunkerPolygon
        )

        // Then: carry ≈ 155 yards (far edge) ± 5 yards
        XCTAssertEqual(distances.carry, 155.0, accuracy: 5.0,
                       "Carry distance to far edge should be ~155 yards")
        XCTAssertGreaterThan(distances.carry, distances.frontEdge,
                             "Carry distance must be greater than front edge distance")
    }

    // MARK: - §2.2.9 Hazard front distance (near edge)

    func test_hazardFrontDistance_nearEdge_withinTolerance() {
        // Given: same bunker polygon 140–155 yards
        let userLocation = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)

        let bunkerPolygon = GeoJSONPolygon(
            type: "Polygon",
            coordinates: [[
                [-117.2533, 32.8885],
                [-117.2530, 32.8885],
                [-117.2530, 32.8872],
                [-117.2533, 32.8872],
                [-117.2533, 32.8885],
            ]]
        )

        // When
        let distances = DistanceCalculator.hazardDistances(
            userLocation: userLocation,
            hazardPolygon: bunkerPolygon
        )

        // Then: front edge ≈ 140 yards (near edge) ± 5 yards
        XCTAssertEqual(distances.frontEdge, 140.0, accuracy: 5.0,
                       "Front edge distance should be ~140 yards")
        XCTAssertLessThan(distances.frontEdge, distances.carry,
                          "Front edge must be less than carry distance")
    }

    // MARK: - §2.2.10 Layup target: 100 yards from green

    func test_layupTarget_100yardsFromGreen_correctCoordinate() {
        // Given: user at tee, green center known, target = 100 yards from green
        let userPosition = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)
        let greenCenter = CLLocationCoordinate2D(latitude: 32.8990, longitude: -117.2519)
        let targetYardsFromGreen: Double = 100.0

        // When
        let layupCoord = DistanceCalculator.layupPoint(
            from: userPosition,
            toward: greenCenter,
            yardsFromTarget: targetYardsFromGreen
        )

        // Then: the returned coordinate is exactly 100 yards from green center (±1 yard)
        let distanceToGreen = DistanceCalculator.distanceInYards(from: layupCoord, to: greenCenter)
        XCTAssertEqual(distanceToGreen, targetYardsFromGreen, accuracy: 1.0,
                       "Layup coordinate should be exactly 100 yards from green center")

        // Also verify it's on the approach line (between user and green)
        let totalDistance = DistanceCalculator.distanceInYards(from: userPosition, to: greenCenter)
        let distanceFromUser = DistanceCalculator.distanceInYards(from: userPosition, to: layupCoord)
        XCTAssertLessThan(distanceFromUser, totalDistance,
                          "Layup point should be between user and green")
    }

    // MARK: - §2.2.11 Dogleg: distance to bend point

    func test_doglegDistance_toBendPoint_correct() {
        // Given: a hole way with 3+ points that bends 45 degrees
        // Tee → midpoint (bend) → green
        let userPosition = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)
        let bendPoint = CLLocationCoordinate2D(latitude: 32.9000, longitude: -117.2520)
        let greenEnd = CLLocationCoordinate2D(latitude: 32.8990, longitude: -117.2505)

        let holeWay = OSMHoleWay(
            osmId: "way/123456",
            holeNumber: 1,
            points: [
                userPosition,  // tee (starting point)
                bendPoint,     // dogleg bend
                greenEnd       // green end
            ]
        )

        // When
        let distanceToBend = DistanceCalculator.doglegDistance(
            holeWay: holeWay,
            userPosition: userPosition
        )

        // Then: returns Haversine distance from user to the bend point
        let expectedDistance = DistanceCalculator.distanceInYards(from: userPosition, to: bendPoint)
        XCTAssertEqual(distanceToBend, expectedDistance, accuracy: 1.0,
                       "Dogleg distance should be Haversine from user to bend point, not to green")
    }

    // MARK: - Front/back green with polygon

    func test_frontBackGreen_withPolygonAndHoleWay_frontLessThanBack() {
        // §2.2.5
        let userLocation = CLLocationCoordinate2D(latitude: 32.9010, longitude: -117.2530)
        let greenCenter = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)
        let approachFrom = CLLocationCoordinate2D(latitude: 32.9005, longitude: -117.2526)

        // Small polygon around the green center
        let greenPolygon = GeoJSONPolygon(
            type: "Polygon",
            coordinates: [[
                [-117.2522, 32.9000],
                [-117.2518, 32.9000],
                [-117.2518, 32.8996],
                [-117.2522, 32.8996],
                [-117.2522, 32.9000],
            ]]
        )

        // When
        let distances = DistanceCalculator.greenDistances(
            userLocation: userLocation,
            greenCenter: greenCenter,
            greenPolygon: greenPolygon,
            approachFrom: approachFrom
        )

        // Then: front < center < back; all differ by at least 1 yard
        XCTAssertNotNil(distances.front)
        XCTAssertNotNil(distances.back)
        XCTAssertLessThan(distances.front!, distances.center,
                          "Front of green must be closer than center")
        XCTAssertGreaterThan(distances.back!, distances.center,
                             "Back of green must be farther than center")
        XCTAssertGreaterThan(distances.center - distances.front!, 1.0,
                             "Front and center should differ by at least 1 yard")
        XCTAssertGreaterThan(distances.back! - distances.center, 1.0,
                             "Center and back should differ by at least 1 yard")
    }

    func test_frontBackGreen_noPolygon_returnsNilFrontBack() {
        // §2.2.7 — tap-and-save course (center only)
        let userLocation = CLLocationCoordinate2D(latitude: 32.9010, longitude: -117.2530)
        let greenCenter = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)
        let approachFrom = CLLocationCoordinate2D(latitude: 32.9005, longitude: -117.2526)

        // When
        let distances = DistanceCalculator.greenDistances(
            userLocation: userLocation,
            greenCenter: greenCenter,
            greenPolygon: nil,
            approachFrom: approachFrom
        )

        // Then: front and back are nil; center is valid
        XCTAssertNil(distances.front, "No polygon → front should be nil")
        XCTAssertNil(distances.back, "No polygon → back should be nil")
        XCTAssertGreaterThan(distances.center, 0, "Center distance should be valid")
        XCTAssertFalse(distances.center.isNaN)
    }
}
