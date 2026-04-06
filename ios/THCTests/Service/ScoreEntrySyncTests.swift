// ScoreEntrySyncTests.swift
// THCTests/Service
//
// All 7 specs from M5.5 including sync interruption (2.4.16).
// Tests compile but fail (red) until SyncService is implemented (M5.6).

import XCTest
import SwiftData
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
        offlineStorage = OfflineStorage(modelContainer: container)
        syncService = SyncService(supabase: mockSupabase, offlineStorage: offlineStorage)
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
        XCTAssertEqual(mockSupabase.insertCalls.count, 0,
                       "Supabase insert should NOT be called during offline save")
    }

    // MARK: - Sync on reconnect: uploads to Supabase

    func test_syncOnReconnect_uploadsToSupabase() async throws {
        // Given: one round in SwiftData with syncStatus = .pending; network now available
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 1)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: Supabase insert called exactly once; round.syncStatus = .synced
        XCTAssertEqual(synced, 1, "One round should have been synced")
        XCTAssertEqual(mockSupabase.insertCalls.filter { $0.table == "rounds" }.count, 1,
                       "Exactly one insert into rounds table expected")
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 0,
                       "Round should be marked synced after upload")
    }

    // MARK: - §2.4.16 Sync interrupted by app background: no half-synced state

    func test_syncInterrupted_byAppBackground_noHalfSyncedState() async throws {
        // Given: round being uploaded; OS backgrounds the app mid-upload
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // Simulate upload interruption via Task cancellation
        let uploadTask = Task {
            try await syncService.syncPendingRounds()
        }
        uploadTask.cancel()

        // Wait a moment for cancellation to propagate
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // When: app resumes and sync runs again
        let synced = try await syncService.syncPendingRounds()

        // Then: round is either fully synced or still pending (no half-synced state)
        let unsyncedAfter = try offlineStorage.unsyncedRounds()
        let totalInserts = mockSupabase.insertCalls.filter { $0.table == "rounds" }.count

        // Either: synced on second attempt with exactly one insert total
        // Or: still pending (insert not attempted yet) with zero inserts
        XCTAssertTrue(
            (synced == 1 && totalInserts == 1 && unsyncedAfter.isEmpty) ||
            (synced == 0 && totalInserts == 0 && unsyncedAfter.count == 1),
            "After interrupted sync + retry: round must be either fully synced or still pending. " +
            "Got: synced=\(synced), inserts=\(totalInserts), unsynced=\(unsyncedAfter.count)"
        )

        // No duplicate: at most 1 insert
        XCTAssertLessThanOrEqual(totalInserts, 1, "No duplicate inserts allowed after interruption")
    }

    // MARK: - Dedup: same round not inserted twice (online)

    func test_dedupOnline_sameRoundNotInsertedTwice() async throws {
        // Given: round with same player_id + played_at + course_name + gross_score already in Supabase
        let round = makeLocalRound()
        try offlineStorage.saveRound(round)

        // Stub Supabase to return the "existing" row on dedup check
        mockSupabase.stubbedResponses["rounds"] = .success([makeSupabaseRound(matching: round)])

        // When: sync attempts to upload
        let synced = try await syncService.syncPendingRounds()

        // Then: no duplicate insert; existing record recognized
        XCTAssertEqual(mockSupabase.insertCalls.filter { $0.table == "rounds" }.count, 0,
                       "Should not re-insert a round that already exists in Supabase")
        // Round should still be marked synced (it exists upstream)
        XCTAssertEqual(try offlineStorage.unsyncedRounds().count, 0,
                       "Round should be marked synced after dedup check confirms it exists")
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
        XCTAssertEqual(mockSupabase.insertCalls.count, 0,
                       "Supabase insert must NOT be called for already-synced rounds")
    }

    // MARK: - Per-hole stats: optional, round saves without them

    func test_perHoleStatsOptional_roundSavesWithoutThem() async throws {
        // Given: round with no hole-level stats
        let round = makeLocalRound()
        round.holeScores = []
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: round saves successfully; no hole_scores rows inserted
        XCTAssertEqual(synced, 1, "Round should sync successfully without hole stats")
        let holeScoreInserts = mockSupabase.insertCalls.filter { $0.table == "hole_scores" }
        XCTAssertEqual(holeScoreInserts.count, 0, "No hole_scores rows when optional stats not provided")
    }

    // MARK: - Per-hole stats: when provided, hole_scores rows are created

    func test_perHoleStatsProvided_holeScoreRowsCreated() async throws {
        // Given: round with per-hole stats for 18 holes
        let round = makeLocalRound()
        round.holeScores = (1...18).map { i in
            let score = LocalHoleScore()
            score.id = UUID()
            score.holeNumber = i
            score.strokes = 4
            score.putts = 2
            score.fairwayHit = "hit"
            score.greenInRegulation = true
            return score
        }
        try offlineStorage.saveRound(round)

        // When
        let synced = try await syncService.syncPendingRounds()

        // Then: one hole_scores row inserted per hole
        XCTAssertEqual(synced, 1, "Round should sync")
        let holeScoreInserts = mockSupabase.insertCalls.filter { $0.table == "hole_scores" }
        XCTAssertEqual(holeScoreInserts.count, 18,
                       "18 hole_scores rows should be inserted when per-hole stats are provided")
    }

    // MARK: - Helpers

    private var counter = 0
    private func makeLocalRound() -> LocalRound {
        counter += 1
        let round = LocalRound()
        round.id = UUID()
        round.playerId = UUID()
        round.seasonId = UUID()
        round.playedAt = "2026-04-05"
        round.courseName = "Test Course \(counter)"
        round.par = 72
        round.grossScore = 90
        round.courseHandicap = 18
        round.points = 10
        round.source = "app"
        round.syncedToSupabase = false
        round.holeScores = []
        round.createdAt = Date()
        return round
    }

    private func makeSupabaseRound(matching local: LocalRound) -> Round {
        Round(
            id: UUID(),
            playerId: local.playerId,
            seasonId: local.seasonId,
            playedAt: local.playedAt,
            courseName: local.courseName,
            teeName: nil,
            courseRating: nil,
            slopeRating: nil,
            par: local.par,
            grossScore: local.grossScore,
            courseHandicap: local.courseHandicap,
            netScore: local.grossScore - local.courseHandicap,
            netVsPar: (local.grossScore - local.courseHandicap) - local.par,
            points: local.points,
            ghinScoreId: nil,
            source: "app",
            enteredBy: nil,
            createdAt: Date()
        )
    }
}
