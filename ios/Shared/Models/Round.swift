import Foundation

/// Mirrors the `rounds` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct Round: Codable, Identifiable, Sendable {
    public let id: UUID
    public let playerId: UUID
    public let seasonId: UUID
    /// Date string in "YYYY-MM-DD" format -- stored as a plain string to avoid
    /// timezone ambiguity when the server returns a date-only value.
    public let playedAt: String
    public let courseName: String
    public let teeName: String?
    public let courseRating: Double?
    public let slopeRating: Double?
    public let par: Int
    public let grossScore: Int
    public let courseHandicap: Int
    public let netScore: Int
    public let netVsPar: Int
    public let points: Int?
    public let ghinScoreId: String?
    /// "manual" | "ghin" | "app"
    public let source: String
    public let enteredBy: String?
    public let createdAt: Date

    public init(
        id: UUID, playerId: UUID, seasonId: UUID, playedAt: String,
        courseName: String, teeName: String?, courseRating: Double?,
        slopeRating: Double?, par: Int, grossScore: Int, courseHandicap: Int,
        netScore: Int, netVsPar: Int, points: Int?, ghinScoreId: String?,
        source: String, enteredBy: String?, createdAt: Date
    ) {
        self.id = id; self.playerId = playerId; self.seasonId = seasonId
        self.playedAt = playedAt; self.courseName = courseName; self.teeName = teeName
        self.courseRating = courseRating; self.slopeRating = slopeRating; self.par = par
        self.grossScore = grossScore; self.courseHandicap = courseHandicap
        self.netScore = netScore; self.netVsPar = netVsPar; self.points = points
        self.ghinScoreId = ghinScoreId; self.source = source; self.enteredBy = enteredBy
        self.createdAt = createdAt
    }
}
