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

// MARK: - Implementation

final class SyncService: SyncServiceProviding, @unchecked Sendable {
    private let supabase: SupabaseClientProviding
    private let storage: OfflineStorageProviding

    init(supabase: SupabaseClientProviding, storage: OfflineStorageProviding) {
        self.supabase = supabase
        self.storage = storage
    }

    // MARK: - Round Sync

    func syncPendingRounds() async throws -> Int {
        let pending = try storage.unsyncedRounds()
        guard !pending.isEmpty else { return 0 }

        var successCount = 0
        for localRound in pending {
            do {
                try await uploadRound(localRound)
                try storage.markRoundSynced(localRound.id)
                successCount += 1
            } catch {
                // Log and continue — a failure on one round should not block the others.
                // The round remains unsynced and will be retried on the next call.
                print("[SyncService] Failed to sync round \(localRound.id): \(error)")
            }
        }
        return successCount
    }

    // MARK: - Fetch

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

    // MARK: - Private Upload Logic

    private func uploadRound(_ local: LocalRound) async throws {
        // Dedup check 1: use the local UUID as primary key — if a row with this id
        // already exists in Supabase the upsert is a no-op.
        //
        // Dedup check 2: composite fallback for rounds originally entered manually or
        // via GHIN that may have been assigned a different UUID.
        // Before inserting, query for (player_id, played_at, course_name, gross_score).

        let duplicate = try await findDuplicate(local)
        if duplicate {
            // The round already exists in Supabase — just mark it synced locally.
            return
        }

        let payload = RoundInsertPayload(from: local)
        try await supabase.client
            .from("rounds")
            .upsert(payload, onConflict: "id")
            .execute()

        // Upload associated hole scores if any.
        if !local.holeScores.isEmpty {
            try await uploadHoleScores(local.holeScores, roundId: local.id)
        }
    }

    private func findDuplicate(_ local: LocalRound) async throws -> Bool {
        // Composite check: (player_id, played_at, course_name, gross_score).
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

    private func uploadHoleScores(_ scores: [LocalHoleScore], roundId: UUID) async throws {
        let payloads = scores.map { HoleScoreInsertPayload(from: $0, roundId: roundId) }
        try await supabase.client
            .from("hole_scores")
            .upsert(payloads, onConflict: "id")
            .execute()
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
