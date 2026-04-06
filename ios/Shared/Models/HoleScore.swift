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

    public init(
        id: UUID, roundId: UUID, holeNumber: Int, strokes: Int,
        putts: Int?, fairwayHit: String?, greenInRegulation: Bool?, createdAt: Date
    ) {
        self.id = id; self.roundId = roundId; self.holeNumber = holeNumber
        self.strokes = strokes; self.putts = putts; self.fairwayHit = fairwayHit
        self.greenInRegulation = greenInRegulation; self.createdAt = createdAt
    }
}
