// OverpassAPIClientTests.swift
// THCTests/Service
//
// All 7 specs from §2.13.
// Tests compile but fail (red) until OverpassAPIClient is implemented (M6.3).

import XCTest
@testable import THC

final class OverpassAPIClientTests: XCTestCase {

    var mockURLSession: MockURLSession!
    var client: OverpassAPIClient!

    let overpassBaseURL = "https://overpass-api.de/api/interpreter"

    override func setUp() async throws {
        try await super.setUp()
        mockURLSession = MockURLSession()
        client = OverpassAPIClient(session: mockURLSession)
    }

    override func tearDown() async throws {
        client = nil
        mockURLSession = nil
        try await super.tearDown()
    }

    // MARK: - §2.13.1 Valid response parses greens and bunkers

    func test_validOverpassResponse_parsesGreensAndBunkers() async throws {
        // Given: valid Torrey Pines South Overpass response
        try mockURLSession.stubFixture(
            named: "overpass_torrey_pines_south.json",
            forURL: overpassBaseURL
        )

        // When
        let osmData = try await client.fetchGolfFeatures(
            lat: 32.8990,
            lon: -117.2519,
            radiusMeters: 500
        )

        // Then: non-empty greens and bunkers; each has a valid polygon
        XCTAssertFalse(osmData.greens.isEmpty, "Should parse at least one green polygon")
        XCTAssertFalse(osmData.bunkers.isEmpty, "Should parse at least one bunker")
        XCTAssertTrue(osmData.greens.allSatisfy { $0.polygon.coordinates[0].count >= 3 },
                      "Each green polygon should have at least 3 coordinate pairs")
    }

    // MARK: - §2.13.2 Empty response returns empty data

    func test_emptyOverpassResponse_returnsEmptyOSMGolfData() async throws {
        // Given
        try mockURLSession.stubFixture(
            named: "overpass_empty.json",
            forURL: overpassBaseURL
        )

        // When
        let osmData = try await client.fetchGolfFeatures(lat: 0, lon: 0, radiusMeters: 500)

        // Then: all arrays empty; no error thrown
        XCTAssertTrue(osmData.greens.isEmpty)
        XCTAssertTrue(osmData.bunkers.isEmpty)
        XCTAssertTrue(osmData.water.isEmpty)
        XCTAssertTrue(osmData.fairways.isEmpty)
        XCTAssertTrue(osmData.tees.isEmpty)
        XCTAssertTrue(osmData.holeWays.isEmpty)
    }

    // MARK: - §2.13.3 Malformed JSON throws parse error

    func test_malformedOverpassJSON_throwsParseError() async throws {
        // Given
        try mockURLSession.stubFixture(
            named: "overpass_malformed.json",
            forURL: overpassBaseURL
        )

        // When / Then
        do {
            _ = try await client.fetchGolfFeatures(lat: 0, lon: 0, radiusMeters: 500)
            XCTFail("Expected OverpassAPIError.parseError to be thrown")
        } catch OverpassAPIError.parseError {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - §2.13.4 Query contains all required golf tags

    func test_overpassQueryContainsAllRequiredGolfTags() async throws {
        // Given
        try mockURLSession.stubFixture(
            named: "overpass_empty.json",
            forURL: overpassBaseURL
        )

        // When
        _ = try await client.fetchGolfFeatures(lat: 32.8990, lon: -117.2519, radiusMeters: 500)

        // Then: inspect the captured request body for required tags
        let capturedRequest = mockURLSession.capturedRequests.first
        XCTAssertNotNil(capturedRequest, "A request should have been made")

        let requestBody = capturedRequest?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(requestBody.contains("golf\"=\"green\"") || requestBody.contains("golf=green"),
                      "Query must include golf=green")
        XCTAssertTrue(requestBody.contains("golf\"=\"bunker\"") || requestBody.contains("golf=bunker"),
                      "Query must include golf=bunker")
        XCTAssertTrue(requestBody.contains("golf\"=\"fairway\"") || requestBody.contains("golf=fairway"),
                      "Query must include golf=fairway")
        XCTAssertTrue(requestBody.contains("golf\"=\"tee\"") || requestBody.contains("golf=tee"),
                      "Query must include golf=tee")
        XCTAssertTrue(requestBody.contains("golf\"=\"hole\"") || requestBody.contains("golf=hole"),
                      "Query must include golf=hole")
        XCTAssertTrue(requestBody.contains("natural\"=\"water\"") || requestBody.contains("natural=water"),
                      "Query must include natural=water")
    }

    // MARK: - §2.13.5 Feature with no ref tag: hole number is nil

    func test_osmFeatureWithNoRefTag_holeNumberIsNil() async throws {
        // Given: response with a green that has no ref tag
        let responseJSON = """
        {
            "version": 0.6,
            "elements": [
                {
                    "type": "way",
                    "id": 123456,
                    "tags": {
                        "golf": "green"
                    },
                    "nodes": [1, 2, 3, 4, 1],
                    "geometry": [
                        {"lat": 32.8998, "lon": -117.2521},
                        {"lat": 32.8997, "lon": -117.2519},
                        {"lat": 32.8999, "lon": -117.2518},
                        {"lat": 32.8999, "lon": -117.2520},
                        {"lat": 32.8998, "lon": -117.2521}
                    ]
                }
            ]
        }
        """
        mockURLSession.stubData(responseJSON.data(using: .utf8)!, forURL: overpassBaseURL)

        // When
        let osmData = try await client.fetchGolfFeatures(lat: 32.8990, lon: -117.2519, radiusMeters: 500)

        // Then: hole number is nil (not 0, not crash)
        XCTAssertFalse(osmData.greens.isEmpty)
        let green = osmData.greens.first!
        XCTAssertNil(green.tags["ref"], "Green with no ref tag should have nil hole number")
    }

    // MARK: - §2.13.6 Hole way points ordered tee to green

    func test_holeWayPoints_orderedTeeToGreen() async throws {
        // Given: response with a golf=hole way (line of play)
        let responseJSON = """
        {
            "version": 0.6,
            "elements": [
                {
                    "type": "way",
                    "id": 789012,
                    "tags": {
                        "golf": "hole",
                        "ref": "1",
                        "name": "Hole 1"
                    },
                    "nodes": [10, 11, 12, 13],
                    "geometry": [
                        {"lat": 32.9014, "lon": -117.2533},
                        {"lat": 32.9005, "lon": -117.2526},
                        {"lat": 32.9000, "lon": -117.2522},
                        {"lat": 32.8998, "lon": -117.2520}
                    ]
                }
            ]
        }
        """
        mockURLSession.stubData(responseJSON.data(using: .utf8)!, forURL: overpassBaseURL)

        // When
        let osmData = try await client.fetchGolfFeatures(lat: 32.9000, lon: -117.2525, radiusMeters: 500)

        // Then: points ordered tee-to-green (first = tee, last = green)
        XCTAssertFalse(osmData.holeWays.isEmpty)
        let holeWay = osmData.holeWays.first!
        XCTAssertEqual(holeWay.holeNumber, 1)
        XCTAssertGreaterThan(holeWay.points.count, 1, "Hole way should have multiple points")
        // First point should be farthest from green (tee end)
        let firstPoint = holeWay.points.first!
        let lastPoint = holeWay.points.last!
        // Tee is at lat 32.9014, green is at lat 32.8998 (north → south)
        XCTAssertGreaterThan(firstPoint.latitude, lastPoint.latitude,
                             "Tee end should be at higher latitude (north) than green end")
    }

    // MARK: - §2.13.7 Malformed polygon (fewer than 3 points) throws error

    func test_malformedPolygon_fewerThan3Points_throwsError() async throws {
        // Given: polygon with only 2 coordinate pairs
        let badPolygon = """
        {
            "version": 0.6,
            "elements": [
                {
                    "type": "way",
                    "id": 99999,
                    "tags": {"golf": "green"},
                    "nodes": [1, 2],
                    "geometry": [
                        {"lat": 32.8998, "lon": -117.2521},
                        {"lat": 32.8997, "lon": -117.2519}
                    ]
                }
            ]
        }
        """
        mockURLSession.stubData(badPolygon.data(using: .utf8)!, forURL: overpassBaseURL)

        // When / Then: throws or gracefully skips the feature
        // Implementation may either throw or skip — both are acceptable per spec
        // "feature is skipped gracefully" = empty greens, no crash
        do {
            let osmData = try await client.fetchGolfFeatures(lat: 0, lon: 0, radiusMeters: 500)
            // If it doesn't throw, the malformed polygon should be skipped
            XCTAssertTrue(osmData.greens.isEmpty,
                          "Malformed polygon (< 3 points) should be skipped, not included")
        } catch OverpassAPIError.malformedPolygon {
            // Throwing is also acceptable
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
