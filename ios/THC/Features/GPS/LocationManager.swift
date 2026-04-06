import Foundation
import CoreLocation
import Observation

// MARK: - CLLocationManager Protocol (Fix #3: testability)

/// Protocol abstracting CLLocationManager so tests can inject a mock.
protocol CLLocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var activityType: CLActivityType { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var allowsBackgroundLocationUpdates: Bool { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: CLLocationManaging {}

/// CoreLocation wrapper with battery optimization for active rounds.
///
/// Battery optimization strategy:
/// - `kCLLocationAccuracyBest` + no distance filter when moving (speed > 0.9 m/s)
/// - `kCLLocationAccuracyNearestTenMeters` + 10m distance filter when stationary
/// - Background location updates enabled during active round
/// - `activityType = .fitness` for GPS filtering appropriate for walking
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    // MARK: - Public State

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isTracking: Bool = false

    var coordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }

    // MARK: - AsyncStream

    /// Each continuation is tracked by a unique ID so termination only removes
    /// the specific stream that ended (Fix #6).
    var locationUpdates: AsyncStream<CLLocation> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let id = UUID()
            self.continuationQueue.sync {
                self.locationContinuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.continuationQueue.sync {
                    _ = self?.locationContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    // MARK: - Private

    private let clManager: CLLocationManaging
    /// Keyed by a unique ID so individual terminations don't remove other continuations (Fix #6).
    private var locationContinuations: [UUID: AsyncStream<CLLocation>.Continuation] = [:]
    /// Serializes access to `locationContinuations` (Fix #6).
    private let continuationQueue = DispatchQueue(label: "com.thc.locationContinuations")

    // Speed threshold: 0.9 m/s ≈ 2 mph
    private let movingSpeedThreshold: Double = 0.9

    // MARK: - Init

    /// Pass a mock `CLLocationManaging` for testing, or use the default `CLLocationManager`.
    init(clManager: CLLocationManaging = CLLocationManager()) {
        self.clManager = clManager
        super.init()
        self.clManager.delegate = self
        self.clManager.activityType = .fitness
        authorizationStatus = self.clManager.authorizationStatus
    }

    // MARK: - Tracking Control

    /// Start continuous GPS tracking for an active round.
    /// Requests always-on authorization for background updates.
    func startRoundTracking() {
        guard !isTracking else { return }

        // Request authorization if needed
        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            clManager.requestAlwaysAuthorization()
        default:
            break
        }

        // Start with best accuracy
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = kCLDistanceFilterNone
        clManager.allowsBackgroundLocationUpdates = true
        clManager.pausesLocationUpdatesAutomatically = false
        clManager.startUpdatingLocation()
        isTracking = true
    }

    /// Stop GPS tracking (round ended or no active round in background).
    func stopRoundTracking() {
        guard isTracking else { return }
        clManager.stopUpdatingLocation()
        clManager.allowsBackgroundLocationUpdates = false
        isTracking = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // Battery optimization: throttle when stationary
        adjustAccuracy(for: location)

        // Persist for background refresh (Fix #10)
        LocationCache.save(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // Notify all subscribers (synchronized, Fix #6)
        let continuations = continuationQueue.sync { Array(locationContinuations.values) }
        for continuation in continuations {
            continuation.yield(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal. GPS signal loss is expected in canyons / tree-lined fairways.
        // The app shows "Searching..." and resumes on reconnect.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // If authorization was just granted while tracking was requested, start
        if isTracking && (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - Battery Optimization

    /// Switch GPS accuracy based on movement speed.
    ///
    /// Moving (>0.9 m/s ≈ 2 mph): `kCLLocationAccuracyBest` + no distance filter.
    /// Stationary: `kCLLocationAccuracyNearestTenMeters` + 10 m distance filter.
    /// This cuts GPS power draw by ~40% when standing on the tee or green.
    private func adjustAccuracy(for location: CLLocation) {
        // speed is -1 when unavailable; treat as stationary
        let speed = max(location.speed, 0)
        let isMoving = speed > movingSpeedThreshold

        if isMoving {
            if clManager.desiredAccuracy != kCLLocationAccuracyBest {
                clManager.desiredAccuracy = kCLLocationAccuracyBest
                clManager.distanceFilter = kCLDistanceFilterNone
            }
        } else {
            if clManager.desiredAccuracy != kCLLocationAccuracyNearestTenMeters {
                clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                clManager.distanceFilter = 10
            }
        }
    }
}
