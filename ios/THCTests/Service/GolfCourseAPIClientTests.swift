// GolfCourseAPIClientTests.swift
// THCTests/Service
//
// Tests for GolfCourseAPIClient — search, rate limiting, 429 handling.
// Uses MockURLSession and fixture JSON files; no live API calls.

import XCTest
@testable import THC

final class GolfCourseAPIClientTests: XCTestCase {

    var mockSession: MockURLSession!
    var client: GolfCourseAPIClient!

    let baseURL = "https://api.golfcourseapi.com/v1"
    let apiKey = "test-api-key-12345"

    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        // Use an isolated UserDefaults suite so rate-limit state doesn't bleed between tests.
        let defaults = UserDefaults(suiteName: "GolfCourseAPIClientTests-\(UUID())")!
        client = GolfCourseAPIClient(session: mockSession, defaults: defaults)
        client.configure(apiKey: apiKey)
    }

    override func tearDown() async throws {
        client = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - §3.1 Search returns parsed courses

    func test_searchCourses_torrey_returnsResults() async throws {
        // Given: stub the search fixture
        try mockSession.stubFixture(
            named: "golfcourseapi_search_torrey.json",
            forURL: "\(baseURL)/courses?search=Torrey"
        )

        // When
        let results = try await client.searchCourses(query: "Torrey")

        // Then: two Torrey Pines courses decoded
        XCTAssertEqual(results.count, 2, "Should parse both Torrey Pines courses")
        XCTAssertEqual(results[0].clubName, "Torrey Pines Golf Course")
        XCTAssertEqual(results[0].courseName, "South Course")
        XCTAssertEqual(results[0].id, 12345)
        XCTAssertEqual(results[1].courseName, "North Course")
    }

    // MARK: - §3.2 Search result contains location metadata

    func test_searchCourses_resultContainsLatLon() async throws {
        // Given
        try mockSession.stubFixture(
            named: "golfcourseapi_search_torrey.json",
            forURL: "\(baseURL)/courses?search=Torrey"
        )

        // When
        let results = try await client.searchCourses(query: "Torrey")

        // Then: lat/lon present
        XCTAssertNotNil(results.first?.latitude)
        XCTAssertNotNil(results.first?.longitude)
        XCTAssertEqual(results.first?.latitude ?? 0, 32.8990, accuracy: 0.001)
        XCTAssertEqual(results.first?.longitude ?? 0, -117.2519, accuracy: 0.001)
    }

    // MARK: - §3.3 Authorization header is set correctly

    func test_searchCourses_setsAuthorizationHeader() async throws {
        // Given
        try mockSession.stubFixture(
            named: "golfcourseapi_search_torrey.json",
            forURL: "\(baseURL)/courses?search=Torrey"
        )

        // When
        _ = try await client.searchCourses(query: "Torrey")

        // Then: Authorization header present with Bearer token
        let request = mockSession.capturedRequests.first
        XCTAssertNotNil(request, "A request should have been made")
        let authHeader = request?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer \(apiKey)",
                       "Authorization header must be 'Bearer <apiKey>'")
    }

    // MARK: - §3.4 HTTP 429 throws rateLimitExceeded

    func test_search_http429_throwsRateLimitExceeded() async throws {
        // Given: stub a 429 response with the fixture body
        try mockSession.stubFixture(
            named: "golfcourseapi_429.json",
            forURL: "\(baseURL)/courses?search=Torrey",
            statusCode: 429
        )

        // When / Then
        do {
            _ = try await client.searchCourses(query: "Torrey")
            XCTFail("Expected GolfCourseAPIError.rateLimitExceeded")
        } catch GolfCourseAPIError.rateLimitExceeded {
            // Correct — 429 maps to rateLimitExceeded
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §3.5 Missing API key throws apiKeyUnavailable

    func test_search_withoutAPIKey_throwsApiKeyUnavailable() async throws {
        // Given: fresh client with no configured API key
        let defaults = UserDefaults(suiteName: "GolfCourseAPIClientTests-nokey-\(UUID())")!
        let unconfiguredClient = GolfCourseAPIClient(session: mockSession, defaults: defaults)

        // When / Then
        do {
            _ = try await unconfiguredClient.searchCourses(query: "Torrey")
            XCTFail("Expected GolfCourseAPIError.apiKeyUnavailable")
        } catch GolfCourseAPIError.apiKeyUnavailable {
            // Correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - §3.6 Soft rate limit blocks requests before 250

    func test_softRateLimit_blocksAt250Requests() async throws {
        // Given: manually exhaust the soft limit via a fresh UserDefaults instance.
        let suiteName = "GolfCourseAPIClientTests-ratelimit-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        // Set today as the reset date and count to 250 (at the soft limit).
        defaults.set(Date.now, forKey: "com.thc.golfcourseapi.resetDate")
        defaults.set(250, forKey: "com.thc.golfcourseapi.dailyCount")

        let limitedClient = GolfCourseAPIClient(session: mockSession, defaults: defaults)
        limitedClient.configure(apiKey: apiKey)

        // When / Then: canMakeRequest is false at 250
        do {
            _ = try await limitedClient.searchCourses(query: "Any")
            XCTFail("Expected GolfCourseAPIError.rateLimitExceeded at soft limit")
        } catch GolfCourseAPIError.rateLimitExceeded {
            // Correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify no HTTP request was made (blocked before network call)
        XCTAssertTrue(mockSession.capturedRequests.isEmpty,
                      "Rate-limited requests must not make a network call")
    }

    // MARK: - §3.7 Malformed JSON throws parseError

    func test_search_malformedJSON_throwsParseError() async throws {
        // Given: response body is not valid JSON
        let badData = "this is not json".data(using: .utf8)!
        mockSession.stubData(badData, forURL: "\(baseURL)/courses?search=Torrey", statusCode: 200)

        // When / Then
        do {
            _ = try await client.searchCourses(query: "Torrey")
            XCTFail("Expected GolfCourseAPIError.parseError")
        } catch GolfCourseAPIError.parseError {
            // Correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
