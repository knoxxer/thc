import Foundation

// MARK: - WatchRoundState

/// Snapshot of round state sent from iPhone to Apple Watch via WatchConnectivity.
///
/// Transmitted via `transferUserInfo` (guaranteed delivery) on round start
/// and via `sendMessage` on hole advance when phone is reachable.
public struct WatchRoundState: Codable, Sendable {
    /// Human-readable course name displayed on the watch.
    public let courseName: String
    /// Current hole number (1-indexed).
    public let currentHole: Int
    /// Par for the current hole.
    public let par: Int
    /// Green center latitude. Nil for courses with no green data.
    public let greenLat: Double?
    /// Green center longitude. Nil for courses with no green data.
    public let greenLon: Double?
    /// JSON-encoded `GeoJSONPolygon`. Nil for tap-and-save (center-only) greens.
    public let greenPolygonJSON: Data?
    /// Name of the next hazard to carry (e.g., "Water Hazard").
    public let nextHazardName: String?
    /// Distance in yards to carry the next hazard.
    public let nextHazardCarry: Double?
    /// Scores entered so far: hole number -> stroke count.
    public let holeScores: [Int: Int]

    public init(
        courseName: String, currentHole: Int, par: Int,
        greenLat: Double?, greenLon: Double?, greenPolygonJSON: Data?,
        nextHazardName: String?, nextHazardCarry: Double?, holeScores: [Int: Int]
    ) {
        self.courseName = courseName; self.currentHole = currentHole; self.par = par
        self.greenLat = greenLat; self.greenLon = greenLon
        self.greenPolygonJSON = greenPolygonJSON
        self.nextHazardName = nextHazardName; self.nextHazardCarry = nextHazardCarry
        self.holeScores = holeScores
    }
}

// MARK: - WatchScoreEntry

/// A single hole score sent from Apple Watch to iPhone via WatchConnectivity.
///
/// Sent via `sendMessage` when reachable; falls back to `transferUserInfo`
/// for guaranteed delivery when the phone is unreachable.
public struct WatchScoreEntry: Codable, Sendable {
    /// The hole number (1-indexed).
    public let holeNumber: Int
    /// Total strokes for the hole.
    public let strokes: Int

    public init(holeNumber: Int, strokes: Int) {
        self.holeNumber = holeNumber
        self.strokes = strokes
    }
}

// MARK: - PhoneConnectivityServiceProviding

/// Protocol for the watch-side WatchConnectivity service.
///
/// Conformed to by `PhoneConnectivityService` in the THCWatch target.
/// Defined in Shared so iOS tests can mock the watch side.
public protocol PhoneConnectivityServiceProviding: AnyObject {
    /// Publishes round state received from the phone.
    var courseData: AsyncStream<WatchRoundState> { get }

    /// Send a hole score to the paired iPhone.
    func sendScore(_ entry: WatchScoreEntry) throws
}
