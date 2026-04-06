import Foundation

/// Mirrors the `course_data` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct CourseData: Codable, Identifiable, Sendable {
    public let id: UUID
    public let golfcourseapiId: Int?
    public let name: String
    public let clubName: String?
    public let address: String?
    public let lat: Double
    public let lon: Double
    public let holeCount: Int
    public let par: Int
    public let osmId: String?
    public let hasGreenData: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID, golfcourseapiId: Int?, name: String, clubName: String?,
        address: String?, lat: Double, lon: Double, holeCount: Int, par: Int,
        osmId: String?, hasGreenData: Bool, createdAt: Date, updatedAt: Date
    ) {
        self.id = id; self.golfcourseapiId = golfcourseapiId; self.name = name
        self.clubName = clubName; self.address = address; self.lat = lat
        self.lon = lon; self.holeCount = holeCount; self.par = par
        self.osmId = osmId; self.hasGreenData = hasGreenData
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
