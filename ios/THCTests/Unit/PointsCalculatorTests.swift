// PointsCalculatorTests.swift
// THCTests/Unit
//
// All 11 specs from §2.1. Tests the Swift port of src/lib/points.ts.
// Formula: max(1, min(15, 10 - netVsPar))
// All tests compile but fail (red) until PointsCalculator is implemented (M5.2).

import XCTest
import Shared
@testable import THC

final class PointsCalculatorTests: XCTestCase {

    // MARK: - §2.1.1 Boundary: maximum cap

    func test_sixUnderPar_returns15() {
        // Given: netVsPar = -6 (6 under par)
        let netVsPar = -6
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 15, "6 under par should return 15 points (ceiling)")
    }

    // MARK: - §2.1.2 Boundary: above maximum (ceiling holds)

    func test_tenUnderPar_returnsCeiling15() {
        // Given: netVsPar = -10 (10 under par)
        let netVsPar = -10
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then: must return 15, not 20
        XCTAssertEqual(result, 15, "10 under par should return 15 (ceiling holds, not 20)")
    }

    // MARK: - §2.1.3 Near ceiling

    func test_threeUnderPar_returns13() {
        // Given: netVsPar = -3
        let netVsPar = -3
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 13)
    }

    // MARK: - §2.1.4 Exact baseline (even par)

    func test_evenPar_returns10() {
        // Given: netVsPar = 0
        let netVsPar = 0
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then: even par always = 10 points
        XCTAssertEqual(result, 10, "Even par (0) should return exactly 10 points")
    }

    // MARK: - §2.1.5 Positive net vs par

    func test_fiveOverPar_returns5() {
        // Given: netVsPar = +5
        let netVsPar = 5
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 5)
    }

    // MARK: - §2.1.6 Boundary: minimum cap

    func test_nineOverPar_returns1() {
        // Given: netVsPar = +9 (9 over par)
        let netVsPar = 9
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 1, "9 over par should return 1 point (floor)")
    }

    // MARK: - §2.1.7 Boundary: below minimum (floor holds)

    func test_tenOverPar_returnsFloor1() {
        // Given: netVsPar = +10
        let netVsPar = 10
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then: must return 1, not 0
        XCTAssertEqual(result, 1, "10 over par should return 1 (floor holds, not 0)")
    }

    // MARK: - §2.1.8 Far below minimum (floor holds at extreme)

    func test_fifteenOverPar_returnsFloor1() {
        // Given: netVsPar = +15
        let netVsPar = 15
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 1, "15 over par should return 1 (extreme floor)")
    }

    // MARK: - §2.1.9 One under par

    func test_oneUnderPar_returns11() {
        // Given: netVsPar = -1
        let netVsPar = -1
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 11)
    }

    // MARK: - §2.1.10 One over par

    func test_oneOverPar_returns9() {
        // Given: netVsPar = +1
        let netVsPar = 1
        // When
        let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(result, 9)
    }

    // MARK: - §2.1.11 Table-driven exhaustive range

    func test_exhaustiveRange_neg20to20_allInBounds() {
        // Given: netVsPar values from -20 to +20
        // Then: no result outside [1, 15] is acceptable
        for netVsPar in -20...20 {
            let result = PointsCalculator.calculatePoints(netVsPar: netVsPar)
            XCTAssertGreaterThanOrEqual(
                result, 1,
                "netVsPar=\(netVsPar) produced \(result), below floor of 1"
            )
            XCTAssertLessThanOrEqual(
                result, 15,
                "netVsPar=\(netVsPar) produced \(result), above ceiling of 15"
            )
        }
    }
}
