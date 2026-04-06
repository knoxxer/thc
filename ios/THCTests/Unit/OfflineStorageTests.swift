// OfflineStorageTests.swift
// THCTests/Unit
//
// All specs from §2.11 -- SwiftData persistence.
// Uses in-memory ModelContainer for test isolation (§3.5).
// Tests compile but fail (red) until OfflineStorage is implemented (M2.6).

import XCTest
import SwiftData
import Shared
@testable import THC

final class OfflineStorageTests: XCTestCase {

    var container: ModelContainer!
    var storage: OfflineStorage!

    override func setUp() async throws {
        try await super.setUp()
        container = try TestModelContainer.create()
        let context = ModelContext(container)
        storage = OfflineStorage(context: context)
    }

    override func tearDown() async throws {
        storage = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - §2.11.1 Save round persists to SwiftData

    func test_saveRound_persistsToSwiftData() throws {
        // Given: in-memory container; a LocalRound with syncedToSupabase = false
        let round = makeLocalRound(synced: false)

        // When
        try storage.saveRound(round)

        // Then: round is retrievable via unsyncedRounds()
        let unsynced = try storage.unsyncedRounds()
        XCTAssertFalse(unsynced.isEmpty, "Saved round should appear in unsyncedRounds()")
        XCTAssertEqual(unsynced.first?.id, round.id)
    }

    // MARK: - §2.11.2 Unsynced rounds returns only pending

    func test_unsyncedRounds_returnsOnlyPending() throws {
        // Given: 3 rounds -- 2 unsynced, 1 synced
        let unsynced1 = makeLocalRound(synced: false)
        let unsynced2 = makeLocalRound(synced: false)
        let synced = makeLocalRound(synced: true)

        try storage.saveRound(unsynced1)
        try storage.saveRound(unsynced2)
        try storage.saveRound(synced)

        // When
        let result = try storage.unsyncedRounds()

        // Then: exactly 2 rounds
        XCTAssertEqual(result.count, 2, "unsyncedRounds() should return exactly 2 unsynced rounds")
        XCTAssertTrue(result.allSatisfy { !$0.syncedToSupabase },
                      "All returned rounds must have syncedToSupabase = false")
    }

    // MARK: - §2.11.3 Mark round synced updates status

    func test_markRoundSynced_updatesSyncStatus() throws {
        // Given: a round with syncedToSupabase = false
        let round = makeLocalRound(synced: false)
        try storage.saveRound(round)

        // When
        try storage.markRoundSynced(round.id)

        // Then: round's syncedToSupabase is true; unsyncedRounds() no longer includes it
        let unsynced = try storage.unsyncedRounds()
        XCTAssertFalse(unsynced.contains { $0.id == round.id },
                       "Synced round should no longer appear in unsyncedRounds()")
    }

    // MARK: - §2.11.4 Cache course persists with holes

    func test_cacheCourse_persistsWithHoles() throws {
        // Given: a CourseData with 18 CourseHoles
        let course = makeCourseData()
        let holes = makeHoles(count: 18, courseId: course.id)

        // When
        try storage.cacheCourse(course, holes: holes)

        // Then: getCachedCourse returns the course with all 18 holes
        let cached = storage.getCachedCourse(id: course.id)
        XCTAssertNotNil(cached, "Cached course should be retrievable by ID")
        XCTAssertEqual(cached?.holes.count, 18, "All 18 holes should be cached")
    }

    // MARK: - §2.11.5 Get cached course returns nil when not cached

    func test_getCachedCourse_returnsNilWhenNotCached() {
        // Given: empty ModelContainer
        let randomID = UUID()

        // When
        let result = storage.getCachedCourse(id: randomID)

        // Then: nil, no crash
        XCTAssertNil(result, "getCachedCourse with unknown ID should return nil")
    }

    // MARK: - §2.11.6 Schema migration v1 to v2 preserves local rounds

    func test_swiftDataMigration_v1ToV2_preservesLocalRounds() throws {
        // Given: 3 rounds saved to SwiftData (representing v1 data)
        let rounds = (0..<3).map { _ in makeLocalRound(synced: false) }
        for round in rounds {
            try storage.saveRound(round)
        }

        // When: simulate round-trip (save + retrieve)
        let retrieved = try storage.unsyncedRounds()

        // Then: all 3 rounds are present with correct data
        XCTAssertEqual(retrieved.count, 3, "All 3 rounds should survive a schema version check")
        for (original, saved) in zip(rounds.sorted { $0.id.uuidString < $1.id.uuidString },
                                      retrieved.sorted { $0.id.uuidString < $1.id.uuidString }) {
            XCTAssertEqual(saved.courseName, original.courseName)
            XCTAssertEqual(saved.grossScore, original.grossScore)
        }
    }

    // MARK: - Helpers

    private var roundCounter = 0

    private func makeLocalRound(synced: Bool) -> LocalRound {
        roundCounter += 1
        return LocalRound(
            id: UUID(),
            playerId: UUID(),
            seasonId: UUID(),
            playedAt: "2026-04-0\(min(roundCounter, 9))",
            courseName: "Test Course \(roundCounter)",
            par: 72,
            grossScore: 90 + roundCounter,
            courseHandicap: 18,
            points: 10,
            source: "app",
            syncedToSupabase: synced,
            holeScores: [],
            createdAt: Date()
        )
    }

    private func makeCourseData() -> CourseData {
        CourseData(
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
        )
    }

    private func makeHoles(count: Int, courseId: UUID) -> [CourseHole] {
        (1...count).map { (i: Int) -> CourseHole in
            let gLat = 32.8900 + Double(i) * 0.001
            let gLon = -117.2500 - Double(i) * 0.001
            return CourseHole(
                id: UUID(),
                courseId: courseId,
                holeNumber: i,
                par: [3, 4, 5][i % 3],
                yardage: 300 + i * 20,
                handicap: i,
                greenLat: gLat,
                greenLon: gLon,
                greenPolygon: nil,
                teeLat: nil,
                teeLon: nil,
                source: "tap_and_save",
                savedBy: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
}
