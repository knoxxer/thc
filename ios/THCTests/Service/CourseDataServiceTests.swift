// CourseDataServiceTests.swift
// THCTests/Service
//
// All 12 specs from §2.3.
// Tests compile but fail (red) until CourseDataService is implemented (M6.5).

import XCTest
import CoreLocation
import SwiftData
@testable import THC

final class CourseDataServiceTests: XCTestCase {

    var mockURLSession: MockURLSession!
    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var service: CourseDataService!

    override func setUp() async throws {
        try await super.setUp()
        mockURLSession = MockURLSession()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        service = CourseDataService(
            urlSession: mockURLSession,
            supabase: mockSupabase,
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        mockSupabase = nil
        mockURLSession = nil
        try await super.tearDown()
    }

    // MARK: - §2.3.1 OSM path: course has OSM data

    func test_courseWithOSMData_returnsPolygonsWithSourceOSM() async throws {
        // Given: Overpass API mock returns valid OSM response with green polygons
        try mockURLSession.stubFixture(
            named: "overpass_torrey_pines_south.json",
            forURL: "https://overpass-api.de/api/interpreter"
        )
        let courseId = UUID()

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: returns CourseDetail with source = .osm, non-nil green polygons
        XCTAssertNotNil(detail, "Should return a CourseDetail for an OSM-mapped course")
        XCTAssertEqual(detail?.dataSource, .osm, "Data source should be .osm")
        XCTAssertFalse(detail?.holes.isEmpty ?? true, "Should have at least one hole with polygon")
    }

    // MARK: - §2.3.2 OSM path: course lacks OSM data, tap-and-save exists

    func test_courseWithTapAndSaveOnly_returnsCenterPoints() async throws {
        // Given: Overpass returns empty; Supabase has tap-and-save pins
        try mockURLSession.stubFixture(
            named: "overpass_empty.json",
            forURL: "https://overpass-api.de/api/interpreter"
        )
        let courseId = UUID()
        let tapAndSaveHoles = (1...18).map { holeNumber in
            CourseHole(
                id: UUID(),
                courseId: courseId,
                holeNumber: holeNumber,
                par: 4,
                yardage: nil,
                handicap: nil,
                greenLat: 32.8900 + Double(holeNumber) * 0.001,
                greenLon: -117.2500,
                greenPolygon: nil,
                teeLat: nil,
                teeLon: nil,
                source: "tap_and_save",
                savedBy: UUID(),
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        mockSupabase.stubbedResponses["course_holes"] = .success(tapAndSaveHoles)

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: source = .tapAndSave, holes have greenCenter, nil polygon
        XCTAssertEqual(detail?.dataSource, .tapAndSave)
        XCTAssertTrue(detail?.holes.allSatisfy { $0.greenPolygon == nil } ?? false,
                      "Tap-and-save holes should have nil polygon")
        XCTAssertTrue(detail?.holes.allSatisfy { $0.greenLat != nil } ?? false,
                      "Tap-and-save holes should have greenLat")
    }

    // MARK: - §2.3.3 Fallback: OSM preferred over tap-and-save

    func test_bothOSMAndTapAndSave_prefersOSM() async throws {
        // Given: both Overpass and Supabase return data
        try mockURLSession.stubFixture(
            named: "overpass_torrey_pines_south.json",
            forURL: "https://overpass-api.de/api/interpreter"
        )
        let courseId = UUID()
        mockSupabase.stubbedResponses["course_holes"] = .success([
            CourseHole(id: UUID(), courseId: courseId, holeNumber: 1, par: 4,
                       yardage: nil, handicap: nil,
                       greenLat: 32.8951, greenLon: -117.2518, greenPolygon: nil,
                       teeLat: nil, teeLon: nil, source: "tap_and_save",
                       savedBy: UUID(), createdAt: Date(), updatedAt: Date())
        ])

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: OSM data wins; source = .osm
        XCTAssertEqual(detail?.dataSource, .osm, "OSM should be preferred over tap-and-save")
    }

    // MARK: - §2.3.4 Fallback: no OSM, no tap-and-save

    func test_noOSMNoTapAndSave_returnsNilTriggersFlow() async throws {
        // Given: both sources return empty
        try mockURLSession.stubFixture(
            named: "overpass_empty.json",
            forURL: "https://overpass-api.de/api/interpreter"
        )
        mockSupabase.stubbedResponses["course_holes"] = .success([CourseHole]())
        let courseId = UUID()

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: source = .metadataOnly; triggers tap-and-save UI
        XCTAssertEqual(detail?.dataSource, .metadataOnly,
                       "No data should result in .metadataOnly source")
    }

    // MARK: - §2.3.5 GolfCourseAPI search returns course metadata

    func test_golfCourseAPISearch_returnsCourseMetadata() async throws {
        // Given: GolfCourseAPI mock returns course metadata
        try mockURLSession.stubFixture(
            named: "golfcourseapi_search_torrey.json",
            forURL: "https://api.golfcourseapi.com/v1/courses"
        )

        // When
        let results = try await service.searchCourses(query: "Torrey")

        // Then: results contain Torrey Pines South with correct metadata
        XCTAssertFalse(results.isEmpty, "Search should return at least one result")
        let torrey = results.first { $0.name.contains("Torrey") }
        XCTAssertNotNil(torrey, "Should find Torrey Pines in search results")
    }

    // MARK: - §2.3.6 GolfCourseAPI: rate limit error (HTTP 429)

    func test_golfCourseAPIRateLimit_returnsGracefulError() async throws {
        // Given: GolfCourseAPI mock returns HTTP 429
        try mockURLSession.stubFixture(
            named: "golfcourseapi_429.json",
            forURL: "https://api.golfcourseapi.com/v1/courses",
            statusCode: 429
        )

        // When / Then: throws CourseDataError.rateLimited; no crash
        do {
            _ = try await service.searchCourses(query: "Torrey")
            XCTFail("Expected CourseDataError.rateLimited to be thrown")
        } catch CourseDataError.rateLimited {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - §2.3.7 Overpass timeout falls to tap-and-save

    func test_overpassTimeout_fallsToTapAndSave() async throws {
        // Given: Overpass throws URLError.timedOut; Supabase has tap-and-save pins
        mockURLSession.stubbedErrors["https://overpass-api.de/api/interpreter"] = URLError(.timedOut)
        let courseId = UUID()
        let tapAndSaveHoles = [
            CourseHole(id: UUID(), courseId: courseId, holeNumber: 1, par: 4,
                       yardage: nil, handicap: nil,
                       greenLat: 32.8951, greenLon: -117.2518, greenPolygon: nil,
                       teeLat: nil, teeLon: nil, source: "tap_and_save",
                       savedBy: UUID(), createdAt: Date(), updatedAt: Date())
        ]
        mockSupabase.stubbedResponses["course_holes"] = .success(tapAndSaveHoles)

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: OSM path fails gracefully; falls back to tap-and-save
        XCTAssertEqual(detail?.dataSource, .tapAndSave,
                       "Overpass timeout should fall back to tap-and-save")
    }

    // MARK: - §2.3.8 SwiftData cache hit: no network call

    func test_swiftDataCacheHit_noNetworkCall() async throws {
        // Given: course already cached in SwiftData with updatedAt < 7 days ago
        let courseId = UUID()
        let freshCourse = CourseData(
            id: courseId,
            golfcourseapiId: nil,
            name: "Cached Course",
            clubName: nil,
            address: nil,
            lat: 32.8990,
            lon: -117.2519,
            holeCount: 18,
            par: 72,
            osmId: nil,
            hasGreenData: false,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600)  // 1 hour ago
        )
        try OfflineStorage(modelContainer: container).cacheCourse(freshCourse, holes: [])

        // When
        _ = try await service.getCourseDetail(courseId: courseId)

        // Then: no network call made
        XCTAssertEqual(mockURLSession.capturedRequests.count, 0,
                       "Cache hit should not trigger any network requests")
    }

    // MARK: - §2.3.9 SwiftData cache miss: stale cache forces refresh

    func test_swiftDataCacheStale_forcesRefresh() async throws {
        // Given: course in SwiftData with updatedAt >= 7 days ago (stale)
        let courseId = UUID()
        let staleCourse = CourseData(
            id: courseId,
            golfcourseapiId: nil,
            name: "Stale Course",
            clubName: nil,
            address: nil,
            lat: 32.8990,
            lon: -117.2519,
            holeCount: 18,
            par: 72,
            osmId: nil,
            hasGreenData: false,
            createdAt: Date().addingTimeInterval(-8 * 24 * 3600),
            updatedAt: Date().addingTimeInterval(-8 * 24 * 3600)  // 8 days ago
        )
        try OfflineStorage(modelContainer: container).cacheCourse(staleCourse, holes: [])
        try mockURLSession.stubFixture(
            named: "overpass_empty.json",
            forURL: "https://overpass-api.de/api/interpreter"
        )

        // When
        _ = try await service.getCourseDetail(courseId: courseId)

        // Then: network call is made to refresh
        XCTAssertGreaterThan(mockURLSession.capturedRequests.count, 0,
                             "Stale cache should trigger a network refresh request")
    }

    // MARK: - §2.3.10 Auto-detect: user within 500m

    func test_autoDetect_within500m_returnsCourse() async throws {
        // Given: user at Torrey Pines area; Supabase returns course within 500m
        let userLocation = CLLocationCoordinate2D(latitude: 32.8990, longitude: -117.2519)
        let torrey = CourseData(
            id: UUID(),
            golfcourseapiId: nil,
            name: "Torrey Pines South",
            clubName: nil,
            address: nil,
            lat: 32.8990,
            lon: -117.2519,
            holeCount: 18,
            par: 72,
            osmId: nil,
            hasGreenData: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        mockSupabase.stubbedResponses["course_data"] = .success([torrey])

        // When
        let detected = try await service.nearbyCourses(
            lat: userLocation.latitude,
            lon: userLocation.longitude,
            radiusKm: 0.5
        )

        // Then: returns the course
        XCTAssertFalse(detected.isEmpty, "Should detect Torrey Pines when within 500m")
        XCTAssertEqual(detected.first?.name, "Torrey Pines South")
    }

    // MARK: - §2.3.11 Auto-detect: user not near any course

    func test_autoDetect_notNearAnyCourse_returnsNil() async throws {
        // Given: user in the middle of the ocean
        mockSupabase.stubbedResponses["course_data"] = .success([CourseData]())

        // When
        let detected = try await service.nearbyCourses(
            lat: 0.0,
            lon: 0.0,
            radiusKm: 0.5
        )

        // Then: returns empty; no crash
        XCTAssertTrue(detected.isEmpty, "No courses should be detected in the middle of the ocean")
    }

    // MARK: - §2.3.12 Auto-detect: multiple courses within 500m

    func test_autoDetect_multipleCoursesWithin500m_returnsAll() async throws {
        // Given: 3 courses within 500m (resort scenario)
        let courses = (1...3).map { i in
            CourseData(
                id: UUID(),
                golfcourseapiId: nil,
                name: "Resort Course \(i)",
                clubName: nil,
                address: nil,
                lat: 32.8990 + Double(i) * 0.001,
                lon: -117.2519,
                holeCount: 18,
                par: 72,
                osmId: nil,
                hasGreenData: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        mockSupabase.stubbedResponses["course_data"] = .success(courses)

        // When
        let detected = try await service.nearbyCourses(
            lat: 32.8990,
            lon: -117.2519,
            radiusKm: 0.5
        )

        // Then: all 3 courses returned; caller should show picker
        XCTAssertEqual(detected.count, 3, "All 3 courses within 500m should be returned")
    }
}
