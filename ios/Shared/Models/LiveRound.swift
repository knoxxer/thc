import Foundation

/// Mirrors the `live_rounds` table in Supabase.
/// Tracks a round in progress for real-time GPS features.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct LiveRound: Codable, Identifiable, Sendable {
    public let id: UUID
    public let playerId: UUID
    public let courseDataId: UUID?
    public let courseName: String
    /// The hole the player is currently playing (1-indexed).
    public let currentHole: Int
    /// The last completed hole (0 = not started).
    public let thruHole: Int
    /// Running score relative to par (negative = under par).
    public let currentScore: Int
    public let startedAt: Date
    public let updatedAt: Date
}
