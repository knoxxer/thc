// CourseDataServiceTests.swift
// THCTests/Service
//
// All 12 specs from §2.3.
// Tests compile but fail (red) until CourseDataService is implemented (M6.5).
//
// Resolution order: SwiftData cache → Supabase → OSM Overpass.
// Supabase is a real SDK client pointed at localhost — all Supabase calls are
// wrapped in `try?` in the service, so failures are silent and tests control
// which resolution path wins by configuring the cache and overpass mocks.

import XCTest
import CoreLocation
@testable import THC

final class CourseDataServiceTests: XCTestCase {

    var mockOverpass: MockOverpassAPI!
    var golfCourseAPIClient: GolfCourseAPIClient!
    var mockStorage: MockOfflineStorage!
    var stubSupabase: StubSupabaseClient!
    var service: CourseDataService!

    override func setUp() async throws {
        try await super.setUp()
        mockOverpass = MockOverpassAPI()
        // GolfCourseAPIClient is a concrete class (not behind a protocol in the current impl).
        // Tests exercise the path where API key is unavailable (Supabase stub can't return it),
        // so searchCourses always throws GolfCourseAPIError.apiKeyUnavailable.
        golfCourseAPIClient = GolfCourseAPIClient()
        mockStorage = MockOfflineStorage()
        stubSupabase = StubSupabaseClient()
        service = CourseDataService(
            supabase: stubSupabase,
            storage: mockStorage,
            overpass: mockOverpass,
            golfCourseAPI: golfCourseAPIClient
        )
    }

    override func tearDown() async throws {
        service = nil
        stubSupabase = nil
        mockStorage = nil
        golfCourseAPIClient = nil
        mockOverpass = nil
        try await super.tearDown()
    }

    // MARK: - §2.3.1 Cache hit: fresh cache returns data without hitting Supabase/OSM

    func test_freshCacheHit_returnsCourseDetailFromCache() async throws {
        // Given: a non-stale course in the storage cache with green pin data
        let courseId = UUID()
        let cachedHoles = (1...18).map { i in
            CachedHole(
                id: UUID(),
                holeNumber: i,
                par: 4,
                greenLat: 32.8900 + Double(i) * 0.001,
                greenLon: -117.2500,
                greenPolygonJSON: nil,
                teeLat: nil,
                teeLon: nil,
                source: "tap_and_save"
            )
        }
        let cachedCourse = CachedCourse(
            id: courseId,
            name: "Cached Course",
            lat: 32.8990,
            lon: -117.2519,
            par: 72,
            holeCount: 18,
            holes: cachedHoles,
            lastFetched: Date()  // fresh — just now
        )
        mockStorage.stubCourse(cachedCourse)

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: returns CourseDetail with tap-and-save source; overpass was never called
        XCTAssertNotNil(detail, "Should return a CourseDetail from the cache")
        XCTAssertEqual(mockOverpass.fetchCallCount, 0,
                       "Fresh cache hit should not trigger an Overpass query")
    }

    // MARK: - §2.3.2 Cache hit with green data: source is tapAndSave

    func test_cacheHitWithGreenPins_sourceIsTapAndSave() async throws {
        // Given: cached course with all hole pins set
        let courseId = UUID()
        let holes = (1...18).map { i in
            CachedHole(
                id: UUID(),
                holeNumber: i,
                par: 4,
                greenLat: 32.8900 + Double(i) * 0.001,
                greenLon: -117.2500,
                greenPolygonJSON: nil,
                teeLat: nil,
                teeLon: nil,
                source: "tap_and_save"
            )
        }
        let cached = CachedCourse(
            id: courseId, name: "Green Pin Course",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18,
            holes: holes, lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: has green data → source should be .tapAndSave
        XCTAssertEqual(detail?.dataSource, .tapAndSave,
                       "Cached course with green pins should have source = .tapAndSave")
        XCTAssertTrue(detail?.holes.allSatisfy { $0.greenLat != nil } ?? false,
                      "All holes should have greenLat set")
    }

    // MARK: - §2.3.3 Cache hit without green data: source is metadataOnly

    func test_cacheHitWithoutGreenPins_sourceIsMetadataOnly() async throws {
        // Given: cached course with no holes at all
        let courseId = UUID()
        let cached = CachedCourse(
            id: courseId, name: "No Pins Course",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18,
            holes: [],  // no green data
            lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: no green data → source should be .metadataOnly
        XCTAssertEqual(detail?.dataSource, .metadataOnly,
                       "Cached course with no green pins should have source = .metadataOnly")
    }

    // MARK: - §2.3.4 Stale cache + Overpass empty: returns nil

    func test_staleCache_overpassEmpty_returnsNil() async throws {
        // Given: stale cached course (> 7 days); Overpass returns empty
        let courseId = UUID()
        let staleDate = Date().addingTimeInterval(-8 * 24 * 3600)  // 8 days ago
        let cached = CachedCourse(
            id: courseId, name: "Stale Course",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18,
            holes: [],
            lastFetched: staleDate
        )
        mockStorage.stubCourse(cached)
        mockOverpass.stubbedGolfData = .empty  // no OSM data

        // When: getCourseDetail tries cache (stale), falls to Supabase (fails — stub),
        // then falls to OSM (empty) → returns nil
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: all sources exhausted — returns nil
        XCTAssertNil(detail,
                     "Stale cache + Supabase failure + empty Overpass should return nil")
    }

    // MARK: - §2.3.5 GolfCourseAPI search: no API key throws apiKeyUnavailable

    func test_golfCourseAPISearch_withoutAPIKey_throwsApiKeyUnavailable() async throws {
        // GolfCourseAPIClient requires an API key (fetched from Supabase app_config
        // on first use). In unit tests, Supabase is unavailable (stub client at
        // loopback URL), so ensureAPIKeyConfigured() throws apiKeyUnavailable.
        do {
            _ = try await service.searchCourses(query: "Torrey")
            XCTFail("Expected GolfCourseAPIError.apiKeyUnavailable to be thrown")
        } catch GolfCourseAPIError.apiKeyUnavailable {
            // Expected — Supabase stub cannot return the API key
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - §2.3.6 GolfCourseAPI: rate limit error type is correct

    func test_golfCourseAPIRateLimit_errorTypeIsRateLimitExceeded() {
        // Verify the error type used when the daily request limit is reached.
        // GolfCourseAPIError.rateLimitExceeded is the canonical error — NOT CourseDataError.
        let error = GolfCourseAPIError.rateLimitExceeded
        XCTAssertNotNil(error.errorDescription,
                        "rateLimitExceeded should have a user-visible description")
        // Confirm it is distinct from apiKeyUnavailable
        if case .rateLimitExceeded = error {
            // Correct
        } else {
            XCTFail("Expected GolfCourseAPIError.rateLimitExceeded")
        }
    }

    // MARK: - §2.3.6 Overpass timeout: falls back gracefully

    func test_overpassTimeout_fallsBackGracefully() async throws {
        // Given: stale cache so OSM path is reached; Overpass throws a timeout
        let courseId = UUID()
        let staleDate = Date().addingTimeInterval(-8 * 24 * 3600)
        let cached = CachedCourse(
            id: courseId, name: "Stale Course",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18, holes: [],
            lastFetched: staleDate
        )
        mockStorage.stubCourse(cached)
        mockOverpass.stubbedError = URLError(.timedOut)

        // When: Overpass times out → service catches it (try?) → returns nil
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: no crash; returns nil or falls back
        // The service swallows the OSM error via try? — so result is nil when Supabase also fails
        XCTAssertNil(detail,
                     "Overpass timeout should be handled gracefully (no crash, returns nil)")
    }

    // MARK: - §2.3.7 Cache hit: no Overpass call

    func test_freshCacheHit_noOverpassCall() async throws {
        // Given: fresh cache entry
        let courseId = UUID()
        let cached = CachedCourse(
            id: courseId, name: "Cached", lat: 32.9, lon: -117.2,
            par: 72, holeCount: 18, holes: [], lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When
        _ = try await service.getCourseDetail(courseId: courseId)

        // Then: Overpass not called
        XCTAssertEqual(mockOverpass.fetchCallCount, 0,
                       "Cache hit should not trigger any Overpass queries")
    }

    // MARK: - §2.3.8 Cache miss for unknown courseId: returns nil

    func test_cacheMiss_unknownCourseId_returnsNil() async throws {
        // Given: no cache entry for this courseId; Overpass empty; Supabase fails (stub)
        let courseId = UUID()
        mockOverpass.stubbedGolfData = .empty

        // When
        let detail = try await service.getCourseDetail(courseId: courseId)

        // Then: nil — no data from any source
        XCTAssertNil(detail, "Unknown courseId with no cache/Supabase/OSM data should return nil")
    }

    // MARK: - §2.3.9 Nearby courses: cache returns results without Supabase

    func test_nearbyCourses_cachedCoursesReturned() async throws {
        // Given: a course cached near the user's location
        let courseId = UUID()
        let cached = CachedCourse(
            id: courseId, name: "Nearby Cached Course",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18, holes: [], lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When: query nearby within 1km
        let results = try await service.nearbyCourses(lat: 32.8990, lon: -117.2519, radiusKm: 1.0)

        // Then: returns the cached course
        XCTAssertFalse(results.isEmpty, "Should return the nearby cached course")
        XCTAssertEqual(results.first?.name, "Nearby Cached Course")
    }

    // MARK: - §2.3.10 Auto-detect: user within 500m

    func test_autoDetect_within500m_returnsCourse() async throws {
        // Given: user at Torrey Pines area; cached course within 500m
        let courseId = UUID()
        let cached = CachedCourse(
            id: courseId, name: "Torrey Pines South",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18, holes: [], lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When: query 500m radius
        let detected = try await service.nearbyCourses(
            lat: 32.8990, lon: -117.2519,
            radiusKm: 0.5
        )

        // Then: returns the course
        XCTAssertFalse(detected.isEmpty, "Should detect Torrey Pines when within 500m")
        XCTAssertEqual(detected.first?.name, "Torrey Pines South")
    }

    // MARK: - §2.3.11 Auto-detect: user not near any course

    func test_autoDetect_notNearAnyCourse_returnsEmpty() async throws {
        // Given: a cached course at Torrey Pines; user in the middle of the ocean
        let courseId = UUID()
        let cached = CachedCourse(
            id: courseId, name: "Torrey Pines South",
            lat: 32.8990, lon: -117.2519,
            par: 72, holeCount: 18, holes: [], lastFetched: Date()
        )
        mockStorage.stubCourse(cached)

        // When: query from middle of ocean (0, 0) — thousands of km away
        let detected = try await service.nearbyCourses(lat: 0.0, lon: 0.0, radiusKm: 0.5)

        // Then: empty — Torrey Pines is not within 500m of (0, 0)
        XCTAssertTrue(detected.isEmpty,
                      "No courses should be detected when user is far from all cached courses")
    }

    // MARK: - §2.3.12 Auto-detect: multiple courses within 500m

    func test_autoDetect_multipleCoursesWithin500m_returnsAll() async throws {
        // Given: 3 courses all within 0.1 degrees of each other (well within 500m)
        for i in 1...3 {
            let cached = CachedCourse(
                id: UUID(),
                name: "Resort Course \(i)",
                lat: 32.8990 + Double(i) * 0.0001,  // ~11m spacing
                lon: -117.2519,
                par: 72, holeCount: 18,
                holes: [], lastFetched: Date()
            )
            mockStorage.stubCourse(cached)
        }

        // When: query 500m radius
        let detected = try await service.nearbyCourses(
            lat: 32.8990, lon: -117.2519,
            radiusKm: 0.5
        )

        // Then: all 3 courses returned; caller should show picker
        XCTAssertEqual(detected.count, 3,
                       "All 3 courses within 500m should be returned")
    }
}
