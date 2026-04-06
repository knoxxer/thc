import Foundation
import CoreLocation
import Shared

// MARK: - Protocol

/// Injectable interface for OpenStreetMap Overpass API queries.
protocol OverpassAPIProviding: Sendable {
    /// Query OSM for golf features (greens, bunkers, fairways, tees, holes, water)
    /// within `radiusMeters` of the given coordinate.
    func fetchGolfFeatures(
        lat: Double,
        lon: Double,
        radiusMeters: Int
    ) async throws -> OSMGolfData

    /// Query OSM for a specific course by its OSM relation or way ID.
    func fetchCourseByOSMId(_ osmId: String) async throws -> OSMGolfData?
}

// MARK: - Data Types

struct OSMGolfData: Sendable {
    let greens: [OSMGolfFeature]
    let bunkers: [OSMGolfFeature]
    let water: [OSMGolfFeature]
    let fairways: [OSMGolfFeature]
    let tees: [OSMGolfFeature]
    let holeWays: [OSMHoleWay]

    static let empty = OSMGolfData(
        greens: [], bunkers: [], water: [], fairways: [], tees: [], holeWays: []
    )
}

struct OSMGolfFeature: Sendable {
    let osmId: String
    let polygon: GeoJSONPolygon
    let center: CLLocationCoordinate2D
    /// Raw OSM tags, e.g. `["ref": "7"]` for hole number.
    let tags: [String: String]
}

struct OSMHoleWay: Sendable {
    let osmId: String
    /// Parsed from the `ref` OSM tag, nil if absent or non-numeric.
    let holeNumber: Int?
    /// Ordered tee-to-green coordinate sequence.
    let points: [CLLocationCoordinate2D]
}

// MARK: - Errors

enum OverpassAPIError: LocalizedError {
    case requestFailed(Int)
    case parseError(String)
    case malformedPolygon(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let status):
            return "Overpass API request failed with HTTP \(status)."
        case .parseError(let detail):
            return "Failed to parse Overpass JSON response: \(detail)"
        case .malformedPolygon(let osmId):
            return "OSM feature \(osmId) has fewer than 3 coordinate points — cannot form a polygon."
        }
    }
}

// MARK: - Implementation

/// Protocol abstracting URLSession for testability.
protocol URLSessionDataProviding: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataProviding {}

final class OverpassAPIClient: OverpassAPIProviding, @unchecked Sendable {
    private static let endpoint = "https://overpass-api.de/api/interpreter"

    private let session: URLSessionDataProviding

    /// Injectable URLSession for testing — defaults to the shared session.
    init(session: URLSessionDataProviding = URLSession.shared) {
        self.session = session
    }

    // MARK: - OverpassAPIProviding

    func fetchGolfFeatures(lat: Double, lon: Double, radiusMeters: Int) async throws -> OSMGolfData {
        let query = buildGolfQuery(lat: lat, lon: lon, radius: radiusMeters)
        return try await executeQuery(query)
    }

    func fetchCourseByOSMId(_ osmId: String) async throws -> OSMGolfData? {
        // Fix #16: Validate osmId to prevent Overpass QL injection.
        let osmIdPattern = /^[0-9]+$/
        guard osmId.wholeMatch(of: osmIdPattern) != nil else {
            throw OverpassAPIError.parseError("Invalid OSM ID: must be numeric")
        }

        let query = buildOSMIdQuery(osmId: osmId)
        let result = try await executeQuery(query)
        let isEmpty = result.greens.isEmpty
            && result.bunkers.isEmpty
            && result.fairways.isEmpty
            && result.tees.isEmpty
            && result.holeWays.isEmpty
        return isEmpty ? nil : result
    }

    // MARK: - Query Building

    private func buildGolfQuery(lat: Double, lon: Double, radius: Int) -> String {
        // Use "out geom;" to embed geometry directly on each way element.
        // This avoids the two-step node-lookup pattern and reduces response size.
        """
        [out:json][timeout:30];
        (
          way["golf"="green"](around:\(radius),\(lat),\(lon));
          way["golf"="bunker"](around:\(radius),\(lat),\(lon));
          way["golf"="fairway"](around:\(radius),\(lat),\(lon));
          way["golf"="tee"](around:\(radius),\(lat),\(lon));
          way["golf"="hole"](around:\(radius),\(lat),\(lon));
          way["natural"="water"](around:\(radius),\(lat),\(lon));
        );
        out geom;
        """
    }

    private func buildOSMIdQuery(osmId: String) -> String {
        // Store the relation in a named set (.r) before converting to an area,
        // then use the area set (.course) to filter ways. This is the correct
        // Overpass QL two-step pattern for area-based queries from a relation ID.
        """
        [out:json][timeout:30];
        rel(\(osmId))->.r;
        map_to_area.r->.course;
        (
          way["golf"="green"](area.course);
          way["golf"="bunker"](area.course);
          way["golf"="fairway"](area.course);
          way["golf"="tee"](area.course);
          way["golf"="hole"](area.course);
          way["natural"="water"](area.course);
        );
        out geom;
        """
    }

    // MARK: - HTTP Execution

    private func executeQuery(_ query: String) async throws -> OSMGolfData {
        var request = URLRequest(url: URL(string: Self.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Percent-encode only the QL query value so that the `=`, `[`, `]`,
        // and `;` characters in the Overpass QL are transmitted correctly.
        // `.urlQueryAllowed` retains `=` and `&` (unsafe here), so we use
        // `.urlHostAllowed` on the value portion which encodes those characters.
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            ?? query
        request.httpBody = "data=\(encodedQuery)".data(using: .utf8)
        request.timeoutInterval = 35

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw OverpassAPIError.requestFailed(http.statusCode)
        }

        return try parseOverpassJSON(data)
    }

    // MARK: - JSON Parsing

    private func parseOverpassJSON(_ data: Data) throws -> OSMGolfData {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = root["elements"] as? [[String: Any]]
        else {
            throw OverpassAPIError.parseError("Root 'elements' array missing or malformed")
        }

        // First pass: build a node coordinate lookup table.
        // Used when the response uses the full (non-geometry) format where ways
        // carry only node IDs and geometry is provided via separate "node" elements.
        var nodeCoords: [Int64: CLLocationCoordinate2D] = [:]
        for element in elements {
            guard let type = element["type"] as? String, type == "node",
                  let lat = element["lat"] as? Double,
                  let lon = element["lon"] as? Double
            else { continue }
            // JSONSerialization vends JSON integers as Int (not Int64) on all
            // Apple platforms, so we must cast through Int before widening.
            let nodeId: Int64
            if let i64 = element["id"] as? Int64 {
                nodeId = i64
            } else if let i = element["id"] as? Int {
                nodeId = Int64(i)
            } else {
                continue
            }
            nodeCoords[nodeId] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        // Second pass: parse ways.
        var greens: [OSMGolfFeature] = []
        var bunkers: [OSMGolfFeature] = []
        var water: [OSMGolfFeature] = []
        var fairways: [OSMGolfFeature] = []
        var tees: [OSMGolfFeature] = []
        var holeWays: [OSMHoleWay] = []

        for element in elements {
            guard let type = element["type"] as? String, type == "way"
            else { continue }

            // Accept both Int and Int64 for the same reason as node IDs above.
            let wayId: Int64
            if let i64 = element["id"] as? Int64 {
                wayId = i64
            } else if let i = element["id"] as? Int {
                wayId = Int64(i)
            } else {
                continue
            }

            let tags = element["tags"] as? [String: String] ?? [:]

            // Resolve coordinates. Two Overpass response shapes are supported:
            //
            // 1. Geometry format ("out geom;" or "out body;" with ">"):
            //    Each way element contains a "geometry" array of {"lat":…,"lon":…} dicts.
            //    This is what the Overpass Turbo default and most compact queries return.
            //
            // 2. Full-node format ("out body; >; out skel qt;"):
            //    Geometry is provided via separate "node" elements whose IDs are
            //    referenced in the way's "nodes" array. Used in raw Overpass exports.
            //
            // We prefer inline geometry when present; fall back to the node lookup table.
            let coords: [CLLocationCoordinate2D]
            if let geometry = element["geometry"] as? [[String: Any]], !geometry.isEmpty {
                coords = geometry.compactMap { entry -> CLLocationCoordinate2D? in
                    guard let lat = entry["lat"] as? Double,
                          let lon = entry["lon"] as? Double
                    else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            } else {
                // Fall back to node lookup.
                let rawNodeIds = element["nodes"] as? [Any] ?? []
                let nodeIds: [Int64] = rawNodeIds.compactMap { raw -> Int64? in
                    if let i64 = raw as? Int64 { return i64 }
                    if let i   = raw as? Int   { return Int64(i) }
                    return nil
                }
                coords = nodeIds.compactMap { nodeCoords[$0] }
            }

            let golf = tags["golf"]
            let natural = tags["natural"]

            if golf == "hole" {
                // Hole ways are linestrings — no polygon needed, just ordered points.
                guard !coords.isEmpty else { continue }
                let holeNumber = tags["ref"].flatMap(Int.init)
                let way = OSMHoleWay(
                    osmId: String(wayId),
                    holeNumber: holeNumber,
                    points: coords
                )
                holeWays.append(way)
                continue
            }

            // All other features require a valid closed polygon (≥3 points).
            guard coords.count >= 3 else {
                // Defensive: skip malformed features rather than throwing so one
                // bad element doesn't break the entire course load.
                print("[OverpassAPIClient] Skipping way \(wayId) — fewer than 3 coords.")
                continue
            }

            let polygon = buildPolygon(from: coords)
            let center = centroid(of: coords)
            let osmIdString = String(wayId)

            let feature = OSMGolfFeature(
                osmId: osmIdString,
                polygon: polygon,
                center: center,
                tags: tags
            )

            switch (golf, natural) {
            case ("green", _):
                greens.append(feature)
            case ("bunker", _):
                bunkers.append(feature)
            case ("fairway", _):
                fairways.append(feature)
            case ("tee", _):
                tees.append(feature)
            case (_, "water"):
                water.append(feature)
            default:
                break
            }
        }

        return OSMGolfData(
            greens: greens,
            bunkers: bunkers,
            water: water,
            fairways: fairways,
            tees: tees,
            holeWays: holeWays
        )
    }

    // MARK: - Geometry Helpers

    private func buildPolygon(from coords: [CLLocationCoordinate2D]) -> GeoJSONPolygon {
        var ring = coords.map { [$0.longitude, $0.latitude] }
        // Ensure the ring is closed (first == last).
        if let first = ring.first, let last = ring.last, first != last {
            ring.append(first)
        }
        return GeoJSONPolygon(type: "Polygon", coordinates: [ring])
    }

    private func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Double Array Equality (for ring closure check)

private func == (lhs: [Double], rhs: [Double]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 == $1 }
}
