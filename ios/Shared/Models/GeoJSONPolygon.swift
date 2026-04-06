import Foundation

/// A GeoJSON Polygon geometry, as stored in Supabase JSONB columns.
///
/// The `coordinates` array follows the GeoJSON spec:
///   - Outer ring first, then optional hole rings.
///   - Each position is `[longitude, latitude]` (lon before lat).
///
/// Example:
/// ```json
/// {
///   "type": "Polygon",
///   "coordinates": [[[-117.1, 32.7], [-117.2, 32.7], [-117.15, 32.8], [-117.1, 32.7]]]
/// }
/// ```
public struct GeoJSONPolygon: Codable, Sendable {
    /// Always "Polygon".
    public let type: String
    /// `[ring][vertex][lon_or_lat]` -- positions are `[longitude, latitude]`.
    public let coordinates: [[[Double]]]

    public init(type: String, coordinates: [[[Double]]]) {
        self.type = type
        self.coordinates = coordinates
    }
}
