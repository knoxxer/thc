import Foundation

/// Mirrors the `seasons` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct Season: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let startsAt: Date
    public let endsAt: Date
    public let isActive: Bool
    /// Minimum rounds a player must complete to be eligible for the season title.
    public let minRounds: Int
    /// Only the top N rounds per player count toward their season score (best-of-N).
    public let topNRounds: Int
    public let createdAt: Date

    public init(
        id: UUID, name: String, startsAt: Date, endsAt: Date,
        isActive: Bool, minRounds: Int, topNRounds: Int, createdAt: Date
    ) {
        self.id = id; self.name = name; self.startsAt = startsAt; self.endsAt = endsAt
        self.isActive = isActive; self.minRounds = minRounds; self.topNRounds = topNRounds
        self.createdAt = createdAt
    }
}
