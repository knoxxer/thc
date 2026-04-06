import Foundation

/// Mirrors the `season_standings` view in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct SeasonStanding: Codable, Identifiable, Sendable {
    /// Uses `playerId` as the stable identity value.
    public var id: UUID { playerId }

    public let playerId: UUID
    public let seasonId: UUID
    public let playerName: String
    public let playerSlug: String
    public let handicapIndex: Double?
    public let avatarUrl: String?
    public let totalRounds: Int
    /// True when the player has completed at least `Season.minRounds` rounds.
    public let isEligible: Bool
    /// Sum of the player's top-N round point scores (the primary sort key for standings).
    public let bestNPoints: Int
    /// Points from the player's single best round (tiebreaker).
    public let bestRoundPoints: Int
    /// Net-vs-par from the player's best round (secondary tiebreaker).
    public let bestNetVsPar: Int

    public init(
        playerId: UUID, seasonId: UUID, playerName: String, playerSlug: String,
        handicapIndex: Double?, avatarUrl: String?, totalRounds: Int, isEligible: Bool,
        bestNPoints: Int, bestRoundPoints: Int, bestNetVsPar: Int
    ) {
        self.playerId = playerId; self.seasonId = seasonId; self.playerName = playerName
        self.playerSlug = playerSlug; self.handicapIndex = handicapIndex
        self.avatarUrl = avatarUrl; self.totalRounds = totalRounds; self.isEligible = isEligible
        self.bestNPoints = bestNPoints; self.bestRoundPoints = bestRoundPoints
        self.bestNetVsPar = bestNetVsPar
    }
}
