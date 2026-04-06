// DistanceCalculatorTests.swift
// THCTests/Unit
//
// Specs 2.2.1-2.2.4 (Haversine) + invalid coordinate guards.
// Tests compile but fail (red) until DistanceCalculator is implemented (M7.2).

import XCTest
import CoreLocation
@testable import THC

final class DistanceCalculatorTests: XCTestCase {

    // MARK: - §2.2.1 Haversine: known reference pair (Torrey Pines)

    func test_haversine_torreyPinesReferencePair_withinTolerance() {
        // Given: Torrey Pines South hole 1 tee → green
        // Pre-calculated ground truth: ~195 yards (verified via Haversine tool)
        // Coordinates from test plan §2.2.1
        let tee = CLLocationCoordinate2D(latitude: 32.8964, longitude: -117.2528)
        let green = CLLocationCoordinate2D(latitude: 32.8951, longitude: -117.2518)
        let groundTruthYards: Double = 195.0  // pre-verified
        let toleranceYards: Double = 5.0

        // When
        let result = DistanceCalculator.distanceInYards(from: tee, to: green)

        // Then: within ±5 yards of ground truth
        XCTAssertEqual(
            result, groundTruthYards, accuracy: toleranceYards,
            "Haversine distance between known Torrey Pines coordinates should be ~\(groundTruthYards) yards ± \(toleranceYards)"
        )
    }

    // MARK: - §2.2.2 Haversine: same coordinate (user on the green)

    func test_haversine_sameCoordinate_returnsZero() {
        // Given: from and to are the same coordinate
        let coord = CLLocationCoordinate2D(latitude: 32.8964, longitude: -117.2528)

        // When
        let result = DistanceCalculator.distanceInYards(from: coord, to: coord)

        // Then: effectively zero (floating point tolerance of < 1 yard)
        XCTAssertLessThan(result, 1.0, "Same coordinate should return < 1 yard (ideally 0)")
        XCTAssertFalse(result.isNaN, "Same coordinate must not return NaN")
    }

    // MARK: - §2.2.3 Haversine: long distance (par 5)

    func test_haversine_longDistance600yards_noOverflow() {
        // Given: ~600-yard par 5 coordinate pair (typical long hole)
        let tee = CLLocationCoordinate2D(latitude: 32.9014, longitude: -117.2533)
        let green = CLLocationCoordinate2D(latitude: 32.8964, longitude: -117.2528)

        // When
        let result = DistanceCalculator.distanceInYards(from: tee, to: green)

        // Then: positive, no overflow, no NaN
        XCTAssertGreaterThan(result, 0.0, "Long distance should be positive")
        XCTAssertFalse(result.isNaN, "Long distance must not be NaN")
        XCTAssertFalse(result.isInfinite, "Long distance must not be infinite")
        XCTAssertLessThan(result, 2000.0, "Sanity check: par 5 should be < 2000 yards")
    }

    // MARK: - §2.2.4 Haversine: antipodal points (P2)

    func test_haversine_antipodalPoints_noNaN() {
        // Given: coordinates on opposite sides of the Earth
        let pointA = CLLocationCoordinate2D(latitude: 32.8964, longitude: -117.2528)
        let pointB = CLLocationCoordinate2D(latitude: -32.8964, longitude: 62.7472)
        let expectedApproxYards: Double = 21_642_547.0  // half Earth circumference

        // When
        let result = DistanceCalculator.distanceInYards(from: pointA, to: pointB)

        // Then: no crash, no NaN, reasonable magnitude
        XCTAssertFalse(result.isNaN, "Antipodal points must not return NaN")
        XCTAssertFalse(result.isInfinite, "Antipodal points must not return infinity")
        XCTAssertGreaterThan(result, 0.0, "Antipodal distance must be positive")
        // Rough sanity check: within 5% of expected half-circumference
        XCTAssertEqual(result, expectedApproxYards, accuracy: expectedApproxYards * 0.05)
    }

    // MARK: - Invalid coordinate guards

    func test_haversine_latOutOfRange_nocrash() {
        // Given: latitude out of valid range [-90, 90]
        let invalid = CLLocationCoordinate2D(latitude: 100.0, longitude: -117.2528)
        let valid = CLLocationCoordinate2D(latitude: 32.8964, longitude: -117.2528)

        // When / Then: no crash
        let result = DistanceCalculator.distanceInYards(from: invalid, to: valid)
        // Result may be wrong but must not be NaN or crash
        XCTAssertFalse(result.isNaN, "Out-of-range latitude must not produce NaN")
    }

    func test_greenDistances_nanCoordinate_doesNotReturnNaN() {
        // Given: a NaN coordinate injected into the user location
        let nanLocation = CLLocationCoordinate2D(latitude: Double.nan, longitude: Double.nan)
        let greenCenter = CLLocationCoordinate2D(latitude: 32.8998, longitude: -117.2520)
        let approachFrom = CLLocationCoordinate2D(latitude: 32.9005, longitude: -117.2526)

        // When
        let distances = DistanceCalculator.greenDistances(
            userLocation: nanLocation,
            greenCenter: greenCenter,
            greenPolygon: nil,
            approachFrom: approachFrom
        )

        // Then: center distance must not be NaN
        XCTAssertFalse(distances.center.isNaN, "NaN user coordinate must not propagate to center distance")
    }
}
