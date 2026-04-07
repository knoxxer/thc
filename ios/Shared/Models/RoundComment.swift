import Foundation

/// Mirrors the `round_comments` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct RoundComment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let roundId: UUID
    public let playerId: UUID
    public let body: String
    public let createdAt: Date

    public init(id: UUID, roundId: UUID, playerId: UUID, body: String, createdAt: Date) {
        self.id = id; self.roundId = roundId; self.playerId = playerId
        self.body = body; self.createdAt = createdAt
    }
}
