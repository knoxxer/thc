// MockCLLocationManager.swift
// THCTests/Mocks
//
// CLLocationManagerProtocol conformer that replays a deterministic sequence
// of CLLocation values synchronously. Allows unit tests to inject GPS data
// without hardware.
//
// Usage:
//   let mock = MockCLLocationManager()
//   mock.locations = approachingGreenSequence
//   mock.startUpdatingLocation()  // fires delegate immediately for each location

import CoreLocation
@testable import THC

// MARK: - Protocol (must be satisfied by both this mock and the real CLLocationManager)

protocol CLLocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var allowsBackgroundLocationUpdates: Bool { get set }
    var activityType: CLActivityType { get set }
    var authorizationStatus: CLAuthorizationStatus { get }

    func startUpdatingLocation()
    func stopUpdatingLocation()
    func requestAlwaysAuthorization()
    func requestWhenInUseAuthorization()
}

// MARK: - Mock

final class MockCLLocationManager: NSObject, CLLocationManagerProtocol {

    // MARK: - Configuration

    /// Location sequence to replay when startUpdatingLocation() is called.
    var locations: [CLLocation] = []

    /// Pre-configured authorization status returned to tests.
    var stubbedAuthorizationStatus: CLAuthorizationStatus = .authorizedAlways

    // MARK: - Captured state (assert on these in tests)

    var startUpdatingLocationCallCount: Int = 0
    var stopUpdatingLocationCallCount: Int = 0
    var requestAlwaysAuthorizationCallCount: Int = 0

    var lastSetAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var lastSetDistanceFilter: CLLocationDistance = kCLDistanceFilterNone
    var lastSetBackgroundUpdates: Bool = false

    // MARK: - CLLocationManagerProtocol

    weak var delegate: CLLocationManagerDelegate?

    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest {
        didSet { lastSetAccuracy = desiredAccuracy }
    }

    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone {
        didSet { lastSetDistanceFilter = distanceFilter }
    }

    var allowsBackgroundLocationUpdates: Bool = false {
        didSet { lastSetBackgroundUpdates = allowsBackgroundLocationUpdates }
    }

    var activityType: CLActivityType = .other

    var authorizationStatus: CLAuthorizationStatus {
        stubbedAuthorizationStatus
    }

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
        // Replay all locations synchronously
        for location in locations {
            delegate?.locationManager?(
                CLLocationManager(),  // real manager passed as context; implementations typically ignore it
                didUpdateLocations: [location]
            )
        }
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }

    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCallCount += 1
        // Fire delegate with pre-set status
        if stubbedAuthorizationStatus == .denied {
            delegate?.locationManagerDidChangeAuthorization?(
                CLLocationManager()
            )
        }
    }

    func requestWhenInUseAuthorization() {
        // No-op in tests
    }
}

// MARK: - Pre-built location sequences

extension MockCLLocationManager {

    /// Coordinates stepping toward hole 1 green at Torrey Pines South.
    static var approachingGreen: [CLLocation] {
        [
            CLLocation(latitude: 32.9010, longitude: -117.2530),  // tee box
            CLLocation(latitude: 32.9005, longitude: -117.2526),  // 200 yards out
            CLLocation(latitude: 32.9001, longitude: -117.2523),  // 100 yards out
            CLLocation(latitude: 32.8998, longitude: -117.2521),  // 50 yards out
            CLLocation(latitude: 32.8998, longitude: -117.2520),  // green center
        ]
    }

    /// Same coordinate repeated 10 times — simulates stationary user (< 2 mph).
    static var stationaryOnFairway: [CLLocation] {
        let coord = CLLocation(latitude: 32.9005, longitude: -117.2526)
        return Array(repeating: coord, count: 10)
    }

    /// Crosses from hole 5 territory to within 30m of hole 6 tee.
    static var crossingHoleBoundary: [CLLocation] {
        [
            CLLocation(latitude: 32.8975, longitude: -117.2510),  // hole 5 green
            CLLocation(latitude: 32.8972, longitude: -117.2508),  // walking
            CLLocation(latitude: 32.8970, longitude: -117.2505),  // hole 6 tee proximity
        ]
    }

    /// Scenario that ends in permission denied — fires delegate with .denied status.
    static var permissionDenied: MockCLLocationManager {
        let manager = MockCLLocationManager()
        manager.stubbedAuthorizationStatus = .denied
        return manager
    }
}
