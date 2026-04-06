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
    public let isEligible: Bool
    public let bestNPoints: Int
    public let bestRoundPoints: Int
    public let bestNetVsPar: Int
}
