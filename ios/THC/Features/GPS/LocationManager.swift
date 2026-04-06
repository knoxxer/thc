import Foundation
import CoreLocation
import Observation

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

    var locationUpdates: AsyncStream<CLLocation> {
        AsyncStream { [weak self] continuation in
            self?.locationContinuations.append(continuation)
            continuation.onTermination = { [weak self] _ in
                self?.locationContinuations.removeAll(where: { _ in true })
            }
        }
    }

    // MARK: - Private

    private let clManager: CLLocationManager
    private var locationContinuations: [AsyncStream<CLLocation>.Continuation] = []

    // Speed threshold: 0.9 m/s ≈ 2 mph
    private let movingSpeedThreshold: Double = 0.9

    // MARK: - Init

    override init() {
        clManager = CLLocationManager()
        super.init()
        clManager.delegate = self
        clManager.activityType = .fitness
        authorizationStatus = clManager.authorizationStatus
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

        // Notify all subscribers
        for continuation in locationContinuations {
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
