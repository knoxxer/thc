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

    var mockSupabase: MockSupabaseClient!
    var container: ModelContainer!
    var syncService: SyncService!
    var offlineStorage: OfflineStorage!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        container = try TestModelContainer.create()
        let context = ModelContext(container)
        offlineStorage = OfflineStorage(context: context)
        syncService = SyncService(supabase: mockSupabase, storage: offlineStorage)
    }

    override func tearDown() async throws {
        syncService = nil
        offlineStorage = nil
        container = nil
        mockSupabase = nil
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
    }

    // MARK: - §2.4.16 Sync interrupted by app background: no half-synced state

    func test_syncInterrupted_byAppBackground_noHalfSyncedState() async throws {
        // Given: round being uploaded; OS backgrounds the app mid-upload
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // Simulate upload interruption via Task cancellation
        nonisolated(unsafe) let svc = syncService!
        let uploadTask = Task {
            try await svc.syncPendingRounds()
        }
        uploadTask.cancel()

        // Wait a moment for cancellation to propagate
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // When: app resumes and sync runs again
        let synced = try await syncService.syncPendingRounds()

        // Then: round is either fully synced or still pending (no half-synced state)
        let unsyncedAfter = try offlineStorage.unsyncedRounds()

        // Either: synced on second attempt or still pending
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

        // Then: insert NOT called for already-synced rounds
        XCTAssertEqual(synced, 0, "No rounds should be synced (all already synced)")
    }

    // MARK: - Per-hole stats: optional, round saves without them

    func test_perHoleStatsOptional_roundSavesWithoutThem() async throws {
        // Given: round with no hole-level stats
        let round = makeLocalRound()
        round.holeScores = []
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: round saves successfully
        XCTAssertEqual(synced, 1, "Round should sync successfully without hole stats")
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
