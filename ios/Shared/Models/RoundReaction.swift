import Foundation

/// Mirrors the `round_reactions` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct RoundReaction: Codable, Identifiable, Sendable {
    public let id: UUID
    public let roundId: UUID
    public let playerId: UUID
    /// Reaction emoji or short code (e.g. "fire", "clap").
    public let emoji: String
    public let comment: String?
    public let createdAt: Date

    public init(
        id: UUID, roundId: UUID, playerId: UUID,
        emoji: String, comment: String?, createdAt: Date
    ) {
        self.id = id; self.roundId = roundId; self.playerId = playerId
        self.emoji = emoji; self.comment = comment; self.createdAt = createdAt
    }
}
