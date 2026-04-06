// MockCourseDataDependencies.swift
// THCTests/Mocks
//
// Lightweight mock implementations of the protocols injected into CourseDataService.
// These allow unit tests to control resolution order (cache → Supabase → OSM)
// without network access.

import Foundation
import CoreLocation
import Supabase
import AuthenticationServices
import Shared
@testable import THC

// MARK: - StubSupabaseClient
//
// Wraps a real SupabaseClient pointed at a loopback URL so the protocol
// conformance compiles. In unit tests all Supabase calls are wrapped in
// `try?` inside CourseDataService, so failures are handled gracefully.
// Tests that need real Supabase data belong in the Integration test suite.

final class StubSupabaseClient: SupabaseClientProviding, @unchecked Sendable {

    let client: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: "http://127.0.0.1:54321")!,
        supabaseKey: "test-anon-key"
    )

    var currentUser: User? {
        get async { nil }
    }

    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws {
        throw SupabaseConfigError.secretsFileNotFound
    }

    func signOut() async throws {}

    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in continuation.finish() }
    }
}

// MARK: - MockOverpassAPI

final class MockOverpassAPI: OverpassAPIProviding, @unchecked Sendable {

    /// Data to return from `fetchGolfFeatures`. Defaults to empty (no OSM data).
    var stubbedGolfData: OSMGolfData = .empty

    /// Error to throw from `fetchGolfFeatures` when set.
    var stubbedError: Error?

    var fetchCallCount: Int = 0
    var lastFetchCoordinate: (lat: Double, lon: Double)?

    func fetchGolfFeatures(lat: Double, lon: Double, radiusMeters: Int) async throws -> OSMGolfData {
        fetchCallCount += 1
        lastFetchCoordinate = (lat, lon)
        if let error = stubbedError { throw error }
        return stubbedGolfData
    }

    func fetchCourseByOSMId(_ osmId: String) async throws -> OSMGolfData? {
        if let error = stubbedError { throw error }
        return stubbedGolfData.greens.isEmpty ? nil : stubbedGolfData
    }
}

// MARK: - MockGolfCourseAPIClient

final class MockGolfCourseAPIClient: GolfCourseAPIProviding, @unchecked Sendable {

    /// Results returned by `searchCourses`. Defaults to empty.
    var stubbedSearchResults: [GolfCourseAPIResult] = []

    /// Error to throw from `searchCourses` when set.
    var stubbedSearchError: Error?

    var searchCallCount: Int = 0
    var lastSearchQuery: String?

    func searchCourses(query: String) async throws -> [GolfCourseAPIResult] {
        searchCallCount += 1
        lastSearchQuery = query
        if let error = stubbedSearchError { throw error }
        return stubbedSearchResults
    }

    func getCourse(id: Int) async throws -> GolfCourseAPIDetail? {
        return nil
    }
}

// MARK: - MockOfflineStorage

/// An in-memory OfflineStorageProviding that does not require SwiftData.
/// Suitable for CourseDataService unit tests where the test controls
/// exactly what the cache returns.
final class MockOfflineStorage: OfflineStorageProviding, @unchecked Sendable {

    private var cachedCourses: [UUID: CachedCourse] = [:]
    private var rounds: [LocalRound] = []
    var holeScoreSaveCallCount: Int = 0

    // MARK: - Stubbing

    func stubCourse(_ course: CachedCourse) {
        cachedCourses[course.id] = course
    }

    func clearCache() {
        cachedCourses.removeAll()
    }

    // MARK: - OfflineStorageProviding

    func saveRound(_ round: LocalRound) throws {
        rounds.append(round)
    }

    func unsyncedRounds() throws -> [LocalRound] {
        rounds.filter { !$0.syncedToSupabase }
    }

    func markRoundSynced(_ id: UUID) throws {
        rounds.first { $0.id == id }?.syncedToSupabase = true
    }

    func cacheCourse(_ course: CourseData, holes: [CourseHole]) throws {
        let cachedHoles = holes.map { hole in
            CachedHole(
                id: hole.id,
                holeNumber: hole.holeNumber,
                par: hole.par,
                greenLat: hole.greenLat,
                greenLon: hole.greenLon,
                greenPolygonJSON: nil,
                teeLat: hole.teeLat,
                teeLon: hole.teeLon,
                source: hole.source
            )
        }
        let cached = CachedCourse(
            id: course.id,
            name: course.name,
            lat: course.lat,
            lon: course.lon,
            par: course.par,
            holeCount: course.holeCount,
            holes: cachedHoles,
            lastFetched: Date()
        )
        cachedCourses[course.id] = cached
    }

    func getCachedCourse(id: UUID) -> CachedCourse? {
        cachedCourses[id]
    }

    func getNearbyCachedCourses(lat: Double, lon: Double, radiusKm: Double) -> [CachedCourse] {
        let radiusMeters = radiusKm * 1000
        return cachedCourses.values.filter { course in
            let dLat = (course.lat - lat) * .pi / 180
            let dLon = (course.lon - lon) * .pi / 180
            let a = sin(dLat / 2) * sin(dLat / 2)
                + cos(lat * .pi / 180) * cos(course.lat * .pi / 180)
                * sin(dLon / 2) * sin(dLon / 2)
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            return 6_371_000.0 * c <= radiusMeters
        }
    }

    func saveHoleScore(_ score: LocalHoleScore, roundId: UUID) throws {
        holeScoreSaveCallCount += 1
    }
}
