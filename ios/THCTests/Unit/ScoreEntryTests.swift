// ScoreEntryTests.swift
// THCTests/Unit
//
// Specs 2.4.1-2.4.4, 2.4.9-2.4.12, 2.4.15 (9-hole)
// Tests compile but fail (red) until ScoreEntryViewModel is implemented (M5.4).

import XCTest
import SwiftData
@testable import THC

final class ScoreEntryTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var viewModel: ScoreEntryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        viewModel = ScoreEntryViewModel(
            supabase: mockSupabase,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        container = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - §2.4.1 Net score calculation

    func test_netScoreCalculation_gross95handicap18_returns77() {
        // Given
        let gross = 95
        let courseHandicap = 18
        // When
        let net = viewModel.calculateNetScore(gross: gross, courseHandicap: courseHandicap)
        // Then
        XCTAssertEqual(net, 77, "Net = gross (\(gross)) - handicap (\(courseHandicap)) = 77")
    }

    // MARK: - §2.4.2 Net vs par calculation

    func test_netVsParCalculation_net77par72_returnsPlus5() {
        // Given
        let net = 77
        let par = 72
        // When
        let netVsPar = viewModel.calculateNetVsPar(net: net, par: par)
        // Then
        XCTAssertEqual(netVsPar, 5, "Net vs par = net (\(net)) - par (\(par)) = +5")
    }

    // MARK: - §2.4.3 Points from net vs par (+5)

    func test_pointsFromNetVsPar_plus5_returns5() {
        // Given: netVsPar = +5
        let netVsPar = 5
        // When: delegation to PointsCalculator
        let points = viewModel.calculatePoints(netVsPar: netVsPar)
        // Then
        XCTAssertEqual(points, 5, "netVsPar=+5 should yield 5 points via PointsCalculator")
    }

    // MARK: - §2.4.4 Full flow: even par yields 10 points

    func test_fullFlow_gross90handicap18par72_returns10points() async throws {
        // Given: gross=90, handicap=18, par=72 → net=72, netVsPar=0, points=10
        viewModel.grossScore = 90
        viewModel.courseHandicap = 18
        viewModel.par = 72
        viewModel.courseName = "Torrey Pines South"
        viewModel.playedAt = "2026-04-05"

        // When: trigger full calculation
        try await viewModel.validateAndCalculate()

        // Then
        XCTAssertEqual(viewModel.netScore, 72, "Net should be 72")
        XCTAssertEqual(viewModel.netVsPar, 0, "Net vs par should be 0 (even)")
        XCTAssertEqual(viewModel.points, 10, "Even par should yield exactly 10 points")
    }

    // MARK: - §2.4.9 Validation: gross score required

    func test_validationRejectsNoGrossScore() async {
        // Given: no gross score entered
        viewModel.grossScore = nil
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = 18
        viewModel.playedAt = "2026-04-05"

        // When / Then: submitRound throws missingRequiredField(.grossScore)
        do {
            try await viewModel.submitRound()
            XCTFail("Expected ScoreEntryError.missingRequiredField to be thrown")
        } catch ScoreEntryError.missingRequiredField(let field) {
            XCTAssertEqual(field, .grossScore)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // No persistence should have occurred
        XCTAssertEqual(mockSupabase.insertCalls.count, 0, "No insert should occur on validation failure")
    }

    // MARK: - §2.4.10 Validation: course name required

    func test_validationRejectsEmptyCourseName() async {
        // Given: empty course name
        viewModel.grossScore = 90
        viewModel.courseName = ""
        viewModel.par = 72
        viewModel.courseHandicap = 18
        viewModel.playedAt = "2026-04-05"

        // When / Then
        do {
            try await viewModel.submitRound()
            XCTFail("Expected ScoreEntryError.missingRequiredField to be thrown")
        } catch ScoreEntryError.missingRequiredField(let field) {
            XCTAssertEqual(field, .courseName)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §2.4.11 Validation: courseHandicap must be non-negative

    func test_validationRejectsNegativeCourseHandicap() async {
        // Given: negative courseHandicap
        viewModel.grossScore = 90
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = -3
        viewModel.playedAt = "2026-04-05"

        // When / Then
        do {
            try await viewModel.submitRound()
            XCTFail("Expected ScoreEntryError.invalidCourseHandicap to be thrown")
        } catch ScoreEntryError.invalidCourseHandicap {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §2.4.12 Source field: app-submitted round has source = "app"

    func test_sourceFieldIsApp() async throws {
        // Given: a valid round submitted via the iOS app
        viewModel.grossScore = 90
        viewModel.courseName = "Test Course"
        viewModel.par = 72
        viewModel.courseHandicap = 18
        viewModel.playedAt = "2026-04-05"

        // When
        try await viewModel.submitRound()

        // Then: the Supabase insert payload must have source = "app"
        XCTAssertEqual(mockSupabase.insertCalls.count, 1, "Exactly one insert should occur")
        let insertCall = mockSupabase.insertCalls.first!
        XCTAssertEqual(insertCall.table, "rounds")
        if let payload = insertCall.payload as? [String: Any] {
            XCTAssertEqual(payload["source"] as? String, "app",
                           "iOS app-submitted rounds must have source = \"app\"")
        } else {
            XCTFail("Insert payload should be a dictionary")
        }
    }

    // MARK: - §2.4.15 Nine-hole round calculation

    func test_nineHoleRound_par36_calculatesCorrectly() async throws {
        // Given: 9-hole round: gross=45, handicap=9, par=36
        viewModel.grossScore = 45
        viewModel.courseHandicap = 9
        viewModel.par = 36
        viewModel.courseName = "Local Muni Front 9"
        viewModel.playedAt = "2026-04-05"

        // When
        try await viewModel.validateAndCalculate()

        // Then: net=36, netVsPar=0, points=10
        XCTAssertEqual(viewModel.netScore, 36, "Net = 45 - 9 = 36")
        XCTAssertEqual(viewModel.netVsPar, 0, "Net vs par = 36 - 36 = 0")
        XCTAssertEqual(viewModel.points, 10, "Even par = 10 points")
    }
}
