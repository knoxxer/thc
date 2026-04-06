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
}
