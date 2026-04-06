import Foundation
import CoreLocation
import WatchConnectivity
import Combine
import Shared

/// Standalone GPS service for Apple Watch.
///
/// Activates CoreLocation on the watch when `WCSession.isReachable = false`
/// (phone is not nearby or not responding). Calculates distances using
/// `DistanceCalculator` from the Shared framework.
final class IndependentGPSService: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    /// Most recent device location. Nil until first fix is obtained.
    @Published private(set) var currentLocation: CLLocation?

    /// True when the GPS service is actively tracking.
    @Published private(set) var isTracking: Bool = false

    /// Authorization status for CoreLocation.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// True when the watch cannot reach the paired phone.
    @Published private(set) var isPhoneUnreachable: Bool = false

    // MARK: - Distance Outputs

    /// Latest green distances computed from `currentLocation` and the provided green target.
    @Published private(set) var greenDistances: GreenDistances?

    // MARK: - Private

    private let locationManager: CLLocationManager
    private var greenTarget: GreenTarget?

    // Reduce GPS polling frequency when the user is stationary (< 2 mph).
    // Apple Watch GPS burns ~30-50% battery per 18 holes at full rate.
    private static let stationarySpeedThresholdMPS: Double = 0.9 // ~2 mph

    // MARK: - Init

    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0  // meters
        observeReachability()
    }

    // MARK: - Public API

    /// Set the current green target for distance calculations.
    func setGreenTarget(
        center: CLLocationCoordinate2D,
        polygon: GeoJSONPolygon?,
        approachFrom: CLLocationCoordinate2D? = nil
    ) {
        self.greenTarget = GreenTarget(
            center: center,
            polygon: polygon,
            approachFrom: approachFrom
        )
        recalculateDistances()
    }

    /// Explicitly start standalone GPS tracking.
    func startTracking() {
        guard !isTracking else { return }
        requestAuthorizationIfNeeded()
        locationManager.startUpdatingLocation()
        isTracking = true
    }

    /// Stop GPS tracking to conserve battery.
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }

    // MARK: - Private

    private func observeReachability() {
        // Poll reachability state — WCSession does not have a delegate on watchOS
        // so we check at activation and rely on PhoneConnectivityService to
        // publish changes via `sessionReachabilityDidChange`.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReachabilityChange),
            name: .watchPhoneReachabilityChanged,
            object: nil
        )
    }

    @objc private func handleReachabilityChange(_ notification: Notification) {
        let isReachable = notification.userInfo?["isReachable"] as? Bool ?? false
        isPhoneUnreachable = !isReachable

        if isPhoneUnreachable {
            startTracking()
        } else {
            // Phone is back — stop independent GPS to save battery if we have
            // a live feed from the phone.
            stopTracking()
        }
    }

    private func requestAuthorizationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            break
        }
    }

    private func recalculateDistances() {
        guard
            let location = currentLocation,
            let target = greenTarget
        else {
            greenDistances = nil
            return
        }

        let userCoord = location.coordinate
        let approachFrom = target.approachFrom ?? userCoord

        greenDistances = DistanceCalculator.greenDistances(
            userLocation: userCoord,
            greenCenter: target.center,
            greenPolygon: target.polygon,
            approachFrom: approachFrom
        )
    }

    private func adjustLocationAccuracy(for location: CLLocation) {
        // Reduce polling frequency when stationary to preserve battery.
        let speedMPS = location.speed
        if speedMPS >= 0 && speedMPS < Self.stationarySpeedThresholdMPS {
            // User is stationary — reduce frequency
            locationManager.distanceFilter = 20.0  // meters
        } else {
            // User is moving — restore sensitivity
            locationManager.distanceFilter = 5.0  // meters
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension IndependentGPSService: CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latest = locations.last else { return }

        // Discard stale fixes older than 10 seconds.
        let age = -latest.timestamp.timeIntervalSinceNow
        guard age < 10.0 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = latest
            self?.adjustLocationAccuracy(for: latest)
            self?.recalculateDistances()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking || isPhoneUnreachable {
                locationManager.startUpdatingLocation()
                isTracking = true
            }
        case .denied, .restricted:
            stopTracking()
        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Log non-fatal — GPS failures are transient on the course.
        // Views display "--" distances when currentLocation is nil.
        if let clError = error as? CLError, clError.code == .denied {
            stopTracking()
        }
    }
}

// MARK: - Supporting Types

private struct GreenTarget {
    let center: CLLocationCoordinate2D
    let polygon: GeoJSONPolygon?
    let approachFrom: CLLocationCoordinate2D?
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted by PhoneConnectivityService when reachability changes.
    static let watchPhoneReachabilityChanged = Notification.Name(
        "com.thc.watchPhoneReachabilityChanged"
    )
}
