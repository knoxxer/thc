import Foundation
import Supabase
import Shared

// MARK: - Protocol

/// Bidirectional sync between SwiftData and Supabase.
protocol SyncServiceProviding: Sendable {
    /// Upload all unsynced `LocalRound`s to Supabase.
    /// Returns the count of successfully synced rounds.
    func syncPendingRounds() async throws -> Int

    /// Fetch the current standings for a season from the `season_standings` view.
    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding]

    /// Fetch all rounds for a specific player and season.
    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round]

    /// Fetch the active season (the one with `is_active = true`).
    func fetchActiveSeason() async throws -> Season?
}

// MARK: - Round Upload Protocol

/// Abstracts the Supabase network calls for round uploads so that
/// `SyncService` can be tested without a live Supabase connection.
protocol SupabaseRoundUploading: Sendable {
    /// Returns `true` if a matching round already exists in Supabase
    /// (composite key: player_id + played_at + course_name + gross_score).
    func findDuplicate(for local: LocalRound) async throws -> Bool

    /// Upsert the round row into Supabase. Idempotent via `onConflict: "id"`.
    func upsertRound(_ local: LocalRound) async throws

    /// Upsert all hole score rows for a round.
    func upsertHoleScores(_ scores: [LocalHoleScore], roundId: UUID) async throws

    /// Fetch the current standings for a season.
    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding]

    /// Fetch all rounds for a player/season.
    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round]

    /// Fetch the active season.
    func fetchActiveSeason() async throws -> Season?
}

// MARK: - Implementation

final class SyncService: SyncServiceProviding, @unchecked Sendable {
    private let uploader: SupabaseRoundUploading
    private let storage: OfflineStorageProviding

    /// Convenience initialiser used in production — wraps a `SupabaseClientProviding`.
    convenience init(supabase: SupabaseClientProviding, storage: OfflineStorageProviding) {
        self.init(uploader: LiveSupabaseRoundUploader(supabase: supabase), storage: storage)
    }

    /// Designated initialiser — inject any `SupabaseRoundUploading` (real or mock).
    init(uploader: SupabaseRoundUploading, storage: OfflineStorageProviding) {
        self.uploader = uploader
        self.storage = storage
    }

    // MARK: - Round Sync

    func syncPendingRounds() async throws -> Int {
        let pending = try storage.unsyncedRounds()
        guard !pending.isEmpty else { return 0 }

        var successCount = 0
        for localRound in pending {
            // Respect cooperative cancellation: if the enclosing Task has been
            // cancelled (e.g. app backgrounded), stop processing further rounds.
            // Any round not yet marked synced stays in the pending queue and will
            // be retried on the next sync — no half-synced state is possible.
            try Task.checkCancellation()

            do {
                let isDuplicate = try await uploader.findDuplicate(for: localRound)
                if !isDuplicate {
                    try await uploader.upsertRound(localRound)
                    if !localRound.holeScores.isEmpty {
                        try await uploader.upsertHoleScores(localRound.holeScores, roundId: localRound.id)
                    }
                }
                // Mark synced only after confirmed upload (or confirmed duplicate).
                try storage.markRoundSynced(localRound.id)
                successCount += 1
            } catch is CancellationError {
                // Re-throw cancellation so the caller's Task propagates it correctly.
                throw CancellationError()
            } catch {
                // Log and continue — a failure on one round should not block others.
                // The round remains unsynced and will be retried on the next call.
                print("[SyncService] Failed to sync round \(localRound.id): \(error)")
            }
        }
        return successCount
    }

    // MARK: - Fetch (delegates to uploader)

    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding] {
        try await uploader.fetchStandings(seasonId: seasonId)
    }

    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round] {
        try await uploader.fetchPlayerRounds(playerId: playerId, seasonId: seasonId)
    }

    func fetchActiveSeason() async throws -> Season? {
        try await uploader.fetchActiveSeason()
    }
}

// MARK: - Live Supabase Implementation

/// Production implementation of `SupabaseRoundUploading` backed by a real Supabase client.
final class LiveSupabaseRoundUploader: SupabaseRoundUploading, @unchecked Sendable {
    private let supabase: SupabaseClientProviding

    init(supabase: SupabaseClientProviding) {
        self.supabase = supabase
    }

    func findDuplicate(for local: LocalRound) async throws -> Bool {
        // Composite dedup check: (player_id, played_at, course_name, gross_score).
        // Using the local UUID as primary key means upsert is idempotent, but this
        // composite check catches rounds entered via other paths with a different UUID.
        let playerIdString = local.playerId.uuidString.lowercased()
        let results: [Round] = try await supabase.client
            .from("rounds")
            .select("id")
            .eq("player_id", value: playerIdString)
            .eq("played_at", value: local.playedAt)
            .eq("course_name", value: local.courseName)
            .eq("gross_score", value: local.grossScore)
            .limit(1)
            .execute()
            .value
        return !results.isEmpty
    }

    func upsertRound(_ local: LocalRound) async throws {
        let payload = RoundInsertPayload(from: local)
        try await supabase.client
            .from("rounds")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    func upsertHoleScores(_ scores: [LocalHoleScore], roundId: UUID) async throws {
        let payloads = scores.map { HoleScoreInsertPayload(from: $0, roundId: roundId) }
        try await supabase.client
            .from("hole_scores")
            .upsert(payloads, onConflict: "id")
            .execute()
    }

    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding] {
        let seasonIdString = seasonId.uuidString.lowercased()
        return try await supabase.client
            .from("season_standings")
            .select()
            .eq("season_id", value: seasonIdString)
            .execute()
            .value
    }

    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round] {
        let playerIdString = playerId.uuidString.lowercased()
        let seasonIdString = seasonId.uuidString.lowercased()
        return try await supabase.client
            .from("rounds")
            .select()
            .eq("player_id", value: playerIdString)
            .eq("season_id", value: seasonIdString)
            .order("played_at", ascending: false)
            .execute()
            .value
    }

    func fetchActiveSeason() async throws -> Season? {
        let results: [Season] = try await supabase.client
            .from("seasons")
            .select()
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return results.first
    }
}

// MARK: - Insert Payloads

/// Encodable payload for inserting a round into Supabase.
/// Maps local Swift property names to snake_case column names.
private struct RoundInsertPayload: Encodable {
    let id: String
    let playerId: String
    let seasonId: String
    let playedAt: String
    let courseName: String
    let par: Int
    let grossScore: Int
    let courseHandicap: Int
    let netScore: Int
    let netVsPar: Int
    let points: Int
    let source: String

    init(from local: LocalRound) {
        let net = local.grossScore - local.courseHandicap
        let netVsPar = net - local.par
        self.id = local.id.uuidString.lowercased()
        self.playerId = local.playerId.uuidString.lowercased()
        self.seasonId = local.seasonId.uuidString.lowercased()
        self.playedAt = local.playedAt
        self.courseName = local.courseName
        self.par = local.par
        self.grossScore = local.grossScore
        self.courseHandicap = local.courseHandicap
        self.netScore = net
        self.netVsPar = netVsPar
        self.points = local.points
        self.source = "app"  // iOS-submitted rounds always carry source="app"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case seasonId = "season_id"
        case playedAt = "played_at"
        case courseName = "course_name"
        case par
        case grossScore = "gross_score"
        case courseHandicap = "course_handicap"
        case netScore = "net_score"
        case netVsPar = "net_vs_par"
        case points
        case source
    }
}

private struct HoleScoreInsertPayload: Encodable {
    let id: String
    let roundId: String
    let holeNumber: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: String?
    let greenInRegulation: Bool?

    init(from local: LocalHoleScore, roundId: UUID) {
        self.id = local.id.uuidString.lowercased()
        self.roundId = roundId.uuidString.lowercased()
        self.holeNumber = local.holeNumber
        self.strokes = local.strokes
        self.putts = local.putts
        self.fairwayHit = local.fairwayHit
        self.greenInRegulation = local.greenInRegulation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roundId = "round_id"
        case holeNumber = "hole_number"
        case strokes
        case putts
        case fairwayHit = "fairway_hit"
        case greenInRegulation = "green_in_regulation"
    }
}
