import Foundation

/// App-wide constants shared between iOS and watchOS targets.
public enum Constants {

    // MARK: - GPS / Auto-Advance

    /// Distance in meters to the next hole's tee within which the app
    /// automatically advances to that hole (~30 yards).
    public static let autoAdvanceThresholdMeters: Double = 27.4

    /// Distance in meters beyond which auto-advance triggers as a fallback
    /// when the player moves away from the previous green (~50 yards).
    public static let autoAdvanceFallbackMeters: Double = 45.7

    /// Speed in m/s below which the player is considered stationary.
    /// Used to debounce GPS updates and avoid spurious readings while walking slowly.
    public static let stationarySpeedThreshold: Double = 0.9

    // MARK: - Cache

    /// How long a cached course record is considered fresh before a background
    /// re-fetch is triggered (7 days).
    public static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    /// Radius in kilometres used when pre-fetching nearby courses on app launch.
    public static let nearbyCoursePrefetchRadiusKm: Double = 50

    // MARK: - Sync

    /// Maximum number of unsynced rounds to upload in a single batch.
    public static let syncBatchSize: Int = 20

    /// Seconds to wait before retrying a failed sync attempt.
    public static let syncRetryDelaySeconds: Double = 30

    // MARK: - Scoring

    /// Minimum points awarded for any round (floor of points formula).
    public static let minPoints: Int = 1

    /// Maximum points awarded for any round (ceiling of points formula).
    public static let maxPoints: Int = 15

    /// Net par gives this many points.
    public static let parPoints: Int = 10

    // MARK: - UI

    /// Maximum number of holes displayed in a "quick scorecard" summary.
    public static let scorecardMaxHoles: Int = 18
}
