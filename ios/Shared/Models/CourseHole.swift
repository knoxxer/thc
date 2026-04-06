import Foundation

/// Mirrors the `course_holes` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct CourseHole: Codable, Identifiable, Sendable {
    public let id: UUID
    public let courseId: UUID
    public let holeNumber: Int
    public let par: Int
    public let yardage: Int?
    /// Stroke index (handicap allocation for this hole).
    public let handicap: Int?
    public let greenLat: Double?
    public let greenLon: Double?
    /// GeoJSON polygon of the green boundary, stored as JSONB in Supabase.
    /// Nil when no polygon has been captured for this hole.
    public let greenPolygon: GeoJSONPolygon?
    public let teeLat: Double?
    public let teeLon: Double?
    /// "osm" | "tap_and_save"
    public let source: String
    public let savedBy: UUID?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID, courseId: UUID, holeNumber: Int, par: Int, yardage: Int?,
        handicap: Int?, greenLat: Double?, greenLon: Double?,
        greenPolygon: GeoJSONPolygon?, teeLat: Double?, teeLon: Double?,
        source: String, savedBy: UUID?, createdAt: Date, updatedAt: Date
    ) {
        self.id = id; self.courseId = courseId; self.holeNumber = holeNumber
        self.par = par; self.yardage = yardage; self.handicap = handicap
        self.greenLat = greenLat; self.greenLon = greenLon
        self.greenPolygon = greenPolygon; self.teeLat = teeLat; self.teeLon = teeLon
        self.source = source; self.savedBy = savedBy
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
