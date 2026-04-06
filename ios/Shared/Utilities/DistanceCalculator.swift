import CoreLocation
import Foundation

// MARK: - Result Types

/// Front, center, and back distances to a green along the approach line.
public struct GreenDistances: Sendable {
    /// Yards to the front edge of the green. Nil when no polygon is available.
    public let front: Double?
    /// Yards to the center of the green.
    public let center: Double
    /// Yards to the back edge of the green. Nil when no polygon is available.
    public let back: Double?

    public init(front: Double?, center: Double, back: Double?) {
        self.front = front
        self.center = center
        self.back = back
    }
}

/// Display-ready hazard information with name and distances in yards.
public struct HazardInfo: Sendable {
    public let name: String
    public let frontEdge: Double
    public let carry: Double

    public init(name: String, frontEdge: Double, carry: Double) {
        self.name = name
        self.frontEdge = frontEdge
        self.carry = carry
    }
}

/// Near and far edge distances to a hazard polygon.
public struct HazardDistances: Sendable {
    /// Yards to the nearest edge of the hazard (carry to clear the front).
    public let frontEdge: Double
    /// Yards to the farthest edge of the hazard (to fully carry it).
    public let carry: Double

    public init(frontEdge: Double, carry: Double) {
        self.frontEdge = frontEdge
        self.carry = carry
    }
}

// MARK: - DistanceCalculator

/// Geospatial math utilities: Haversine distance, green/hazard edge distances,
/// and layup point calculation.
public enum DistanceCalculator {

    // MARK: - Constants

    private static let earthRadiusMeters: Double = 6_371_000
    private static let metersPerYard: Double = 0.9144

    // MARK: - Core Distance

    /// Distance in yards between two coordinates using the Haversine formula.
    ///
    /// Returns 0 if either coordinate contains NaN or out-of-range values.
    public static func distanceInYards(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        distanceInMeters(from: from, to: to) / metersPerYard
    }

    /// Distance in meters between two coordinates using the Haversine formula.
    ///
    /// Returns 0 if either coordinate contains NaN or out-of-range values.
    public static func distanceInMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        guard isValid(from), isValid(to) else { return 0 }

        let lat1 = from.latitude.toRadians
        let lat2 = to.latitude.toRadians
        let dLat = (to.latitude - from.latitude).toRadians
        let dLon = (to.longitude - from.longitude).toRadians

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    // MARK: - Green Distances

    /// Front/center/back distances to a green polygon along the approach line.
    public static func greenDistances(
        userLocation: CLLocationCoordinate2D,
        greenCenter: CLLocationCoordinate2D,
        greenPolygon: GeoJSONPolygon?,
        approachFrom: CLLocationCoordinate2D
    ) -> GreenDistances {
        let center = distanceInYards(from: userLocation, to: greenCenter)

        guard let polygon = greenPolygon,
              isValid(userLocation),
              isValid(greenCenter),
              isValid(approachFrom)
        else {
            return GreenDistances(front: nil, center: center, back: nil)
        }

        // Build a unit vector in the approach direction (approachFrom → greenCenter) in
        // a locally-flat coordinate system. Longitude degrees are scaled by cos(lat)
        // to approximate equal-distance units on both axes near the green.
        let axisLat = greenCenter.latitude - approachFrom.latitude
        let cosLat = cos(greenCenter.latitude.toRadians)
        let axisLon = (greenCenter.longitude - approachFrom.longitude) * cosLat
        let axisLen = sqrt(axisLat * axisLat + axisLon * axisLon)
        guard axisLen > 0 else {
            // approachFrom == greenCenter: no valid axis, fall back to center-only.
            return GreenDistances(front: nil, center: center, back: nil)
        }
        let unitLat = axisLat / axisLen
        let unitLon = axisLon / axisLen

        // Project each polygon vertex onto the approach axis. Negative projection = front
        // of green (toward the player); positive = back of green (away from the player).
        let ring = polygon.coordinates.first ?? []
        var minProjection = Double.infinity
        var maxProjection = -Double.infinity

        for position in ring {
            guard position.count >= 2 else { continue }
            let vLon = position[0]
            let vLat = position[1]
            guard !vLon.isNaN, !vLat.isNaN else { continue }

            let dLat = vLat - greenCenter.latitude
            let dLon = (vLon - greenCenter.longitude) * cosLat
            let projection = dLat * unitLat + dLon * unitLon
            minProjection = min(minProjection, projection)
            maxProjection = max(maxProjection, projection)
        }

        guard minProjection.isFinite, maxProjection.isFinite else {
            return GreenDistances(front: nil, center: center, back: nil)
        }

        // Convert degree-scaled projections back to meters using the standard
        // 111,139 m/degree approximation (accurate to <0.1% within ±85° latitude).
        let metersPerDegreeLat = 111_139.0
        let frontOffsetMeters = abs(minProjection) * metersPerDegreeLat
        let backOffsetMeters  = abs(maxProjection) * metersPerDegreeLat

        let frontYards = center - (frontOffsetMeters / metersPerYard)
        let backYards  = center + (backOffsetMeters  / metersPerYard)

        return GreenDistances(
            front: max(0, frontYards),
            center: center,
            back: max(0, backYards)
        )
    }

    // MARK: - Hazard Distances

    /// Distance to the nearest and farthest edges of a hazard polygon.
    public static func hazardDistances(
        userLocation: CLLocationCoordinate2D,
        hazardPolygon: GeoJSONPolygon
    ) -> HazardDistances {
        guard isValid(userLocation) else {
            return HazardDistances(frontEdge: 0, carry: 0)
        }

        let ring = hazardPolygon.coordinates.first ?? []
        var minYards = Double.infinity
        var maxYards = -Double.infinity

        for position in ring {
            guard position.count >= 2 else { continue }
            let vLon = position[0]
            let vLat = position[1]
            guard !vLon.isNaN, !vLat.isNaN else { continue }

            let vertex = CLLocationCoordinate2D(latitude: vLat, longitude: vLon)
            let yards = distanceInYards(from: userLocation, to: vertex)
            minYards = min(minYards, yards)
            maxYards = max(maxYards, yards)
        }

        let front = minYards.isFinite ? minYards : 0
        let carry = maxYards.isFinite ? maxYards : 0
        return HazardDistances(frontEdge: front, carry: max(front, carry))
    }

    // MARK: - Layup Point

    /// A coordinate along the line from -> toward that is yardsFromTarget
    /// yards short of toward.
    public static func layupPoint(
        from: CLLocationCoordinate2D,
        toward: CLLocationCoordinate2D,
        yardsFromTarget: Double
    ) -> CLLocationCoordinate2D {
        guard isValid(from), isValid(toward), yardsFromTarget >= 0 else {
            return toward
        }

        let totalYards = distanceInYards(from: from, to: toward)
        guard totalYards > 0 else { return toward }

        let fraction = max(0, (totalYards - yardsFromTarget) / totalYards)
        let lat = from.latitude  + fraction * (toward.latitude  - from.latitude)
        let lon = from.longitude + fraction * (toward.longitude - from.longitude)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Dogleg Distance

    /// Distance from the user's current position to the nearest bend point
    /// in a hole way polyline. If no bend is found, returns 0.
    public static func doglegDistance(
        wayPoints: [CLLocationCoordinate2D],
        userPosition: CLLocationCoordinate2D
    ) -> Double {
        // A "bend" is any interior point of the polyline (not first or last).
        // Return the distance to the nearest interior point.
        guard wayPoints.count >= 3 else { return 0 }
        let interiorPoints = wayPoints.dropFirst().dropLast()
        guard let nearest = interiorPoints.min(by: {
            distanceInYards(from: userPosition, to: $0) <
            distanceInYards(from: userPosition, to: $1)
        }) else { return 0 }
        return distanceInYards(from: userPosition, to: nearest)
    }

    // MARK: - Private Helpers

    private static func isValid(_ coord: CLLocationCoordinate2D) -> Bool {
        !coord.latitude.isNaN  && !coord.latitude.isInfinite  &&
        !coord.longitude.isNaN && !coord.longitude.isInfinite &&
        coord.latitude  >= -90  && coord.latitude  <= 90  &&
        coord.longitude >= -180 && coord.longitude <= 180
    }
}

// MARK: - Double Extension

private extension Double {
    var toRadians: Double { self * .pi / 180 }
}
