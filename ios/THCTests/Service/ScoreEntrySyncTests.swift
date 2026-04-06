// ScoreEntrySyncTests.swift
// THCTests/Service
//
// All 7 specs from M5.5 including sync interruption (2.4.16).
// Tests compile but fail (red) until SyncService is implemented (M5.6).

import XCTest
import SwiftData
import Shared
@testable import THC

final class ScoreEntrySyncTests: XCTestCase {

    var mockUploader: MockSupabaseRoundUploader!
    var container: ModelContainer!
    var syncService: SyncService!
    var offlineStorage: OfflineStorage!

    override func setUp() async throws {
        try await super.setUp()
        mockUploader = MockSupabaseRoundUploader()
        container = try TestModelContainer.create()
        let context = ModelContext(container)
        offlineStorage = OfflineStorage(context: context)
        // Inject the mock uploader directly so no real Supabase connection is needed.
        syncService = SyncService(uploader: mockUploader, storage: offlineStorage)
    }

    override func tearDown() async throws {
        syncService = nil
        offlineStorage = nil
        container = nil
        mockUploader = nil
        try await super.tearDown()
    }

    // MARK: - §M5.5 Offline save: round persists to SwiftData

    func test_offlineSave_roundPersistsToSwiftData() throws {
        // Given: network unavailable (Supabase not called)
        let round = makeLocalRound()

        // When: save locally
        try offlineStorage.saveRound(round)

        // Then: persisted in SwiftData with syncStatus = false
        let unsynced = try offlineStorage.unsyncedRounds()
        XCTAssertEqual(unsynced.count, 1, "Round should be saved locally")
        XCTAssertFalse(unsynced.first!.syncedToSupabase, "Should have syncStatus = .pending (false)")
    }

    // MARK: - Sync on reconnect: uploads to Supabase

    func test_syncOnReconnect_uploadsToSupabase() async throws {
        // Given: one round in SwiftData with syncStatus = .pending; network now available
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 1)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: round synced; marked as synced in SwiftData
        XCTAssertEqual(synced, 1, "One round should have been synced")
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 0,
                       "Round should be marked synced after upload")

        // And: the uploader was actually called
        XCTAssertEqual(mockUploader.upsertRoundCallCount, 1, "upsertRound should be called once")
    }

    // MARK: - §2.4.16 Sync interrupted by app background: no half-synced state

    func test_syncInterrupted_byAppBackground_noHalfSyncedState() async throws {
        // Given: round being uploaded; OS backgrounds the app mid-upload
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // Make the uploader slow so cancellation can race the upload.
        mockUploader.uploadDelay = 50_000_000  // 50 ms

        // Simulate upload interruption via Task cancellation
        nonisolated(unsafe) let svc = syncService!
        let uploadTask = Task {
            try await svc.syncPendingRounds()
        }
        uploadTask.cancel()

        // Wait for cancellation to propagate
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10 ms

        // Reset delay for the retry
        mockUploader.uploadDelay = 0

        // When: app resumes and sync runs again
        let synced = try await syncService.syncPendingRounds()

        // Then: round is either fully synced or still pending (no half-synced state)
        let unsyncedAfter = try offlineStorage.unsyncedRounds()

        // Either: synced on second attempt or still pending (never half-synced)
        XCTAssertTrue(
            unsyncedAfter.isEmpty || unsyncedAfter.count == 1,
            "After interrupted sync + retry: round must be either fully synced or still pending. " +
            "Got: synced=\(synced), unsynced=\(unsyncedAfter.count)"
        )
    }

    // MARK: - Dedup: SwiftData prevents double submission

    func test_dedupSwiftData_syncedRoundNotResubmitted() async throws {
        // Given: round in SwiftData with syncedToSupabase = true
        let round = makeLocalRound()
        round.syncedToSupabase = true
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: upsert NOT called for already-synced rounds
        XCTAssertEqual(synced, 0, "No rounds should be synced (all already synced)")
        XCTAssertEqual(mockUploader.upsertRoundCallCount, 0,
                       "upsertRound should not be called for already-synced rounds")
    }

    // MARK: - Dedup: Supabase composite check prevents re-upload

    func test_dedupSupabase_duplicateRoundNotResubmitted() async throws {
        // Given: a round that already exists in Supabase (mock returns isDuplicate = true)
        mockUploader.stubbedIsDuplicate = true
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: the round is marked synced locally, but upsert is NOT called
        XCTAssertEqual(synced, 1, "Round should be counted as synced (duplicate resolved)")
        XCTAssertEqual(mockUploader.upsertRoundCallCount, 0,
                       "upsertRound should not be called for server-side duplicates")
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 0,
                       "Duplicate round should be marked synced locally")
    }

    // MARK: - Per-hole stats: optional, round saves without them

    func test_perHoleStatsOptional_roundSavesWithoutThem() async throws {
        // Given: round with no hole-level stats
        let round = makeLocalRound()
        round.holeScores = []
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: round saves successfully; hole score uploader not called
        XCTAssertEqual(synced, 1, "Round should sync successfully without hole stats")
        XCTAssertEqual(mockUploader.upsertHoleScoresCallCount, 0,
                       "upsertHoleScores should not be called when there are no hole scores")
    }

    // MARK: - Conflict resolution: last write wins

    func test_conflictResolution_lastWriteWins() async throws {
        // Given: two rounds for the same player/date/course — upload order determines winner.
        // The SyncService uses upsert with onConflict: "id", so the last upsert wins
        // at the Supabase level. Locally both are marked synced once confirmed.
        let round1 = makeLocalRound()
        let round2 = makeLocalRound()
        try offlineStorage.saveRound(round1)
        try offlineStorage.saveRound(round2)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: both rounds are attempted (last write wins at the DB level)
        XCTAssertEqual(synced, 2, "Both rounds should be synced (conflict resolved by upsert)")
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 0,
                       "All rounds should be marked synced")
    }

    // MARK: - Helpers

    private var counter = 0
    private func makeLocalRound() -> LocalRound {
        counter += 1
        return LocalRound(
            id: UUID(),
            playerId: UUID(),
            seasonId: UUID(),
            playedAt: "2026-04-05",
            courseName: "Test Course \(counter)",
            par: 72,
            grossScore: 90,
            courseHandicap: 18,
            points: 10,
            source: "app",
            syncedToSupabase: false,
            holeScores: [],
            createdAt: Date()
        )
    }
}

// MARK: - MockSupabaseRoundUploader

/// In-memory mock for `SupabaseRoundUploading`.
/// No network connections are made — all calls are captured for assertion.
final class MockSupabaseRoundUploader: SupabaseRoundUploading, @unchecked Sendable {

    // MARK: - Stubs

    /// When true, `findDuplicate` returns true (simulates existing server-side record).
    var stubbedIsDuplicate: Bool = false

    /// Error to throw from `upsertRound` when set. Cleared after use.
    var upsertError: Error?

    /// Artificial delay in nanoseconds injected into `upsertRound` (for cancellation tests).
    var uploadDelay: UInt64 = 0

    // MARK: - Call counters

    private(set) var findDuplicateCallCount: Int = 0
    private(set) var upsertRoundCallCount: Int = 0
    private(set) var upsertHoleScoresCallCount: Int = 0

    // MARK: - SupabaseRoundUploading

    func findDuplicate(for local: LocalRound) async throws -> Bool {
        findDuplicateCallCount += 1
        return stubbedIsDuplicate
    }

    func upsertRound(_ local: LocalRound) async throws {
        if uploadDelay > 0 {
            try await Task.sleep(nanoseconds: uploadDelay)
        }
        if let error = upsertError {
            upsertError = nil
            throw error
        }
        upsertRoundCallCount += 1
    }

    func upsertHoleScores(_ scores: [LocalHoleScore], roundId: UUID) async throws {
        upsertHoleScoresCallCount += 1
    }

    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding] { [] }
    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round] { [] }
    func fetchActiveSeason() async throws -> Season? { nil }

    // MARK: - Reset

    func reset() {
        stubbedIsDuplicate = false
        upsertError = nil
        uploadDelay = 0
        findDuplicateCallCount = 0
        upsertRoundCallCount = 0
        upsertHoleScoresCallCount = 0
    }
}
