import Foundation

/// Mirrors the `hole_scores` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct HoleScore: Codable, Identifiable, Sendable {
    public let id: UUID
    public let roundId: UUID
    public let holeNumber: Int
    public let strokes: Int
    public let putts: Int?
    /// "hit" | "left" | "right" | "na" -- nil when not tracked.
    public let fairwayHit: String?
    public let greenInRegulation: Bool?
    public let createdAt: Date
}
