// WatchBatteryTests.swift
// THCTests/Service
//
// 2 tests from M12.1 — battery monitoring on Apple Watch.
// Tests compile but fail (red) until battery monitoring is implemented (M12.6).

import XCTest
@testable import THC

final class WatchBatteryTests: XCTestCase {

    var mockDevice: MockWKInterfaceDevice!
    var batteryMonitor: WatchBatteryMonitor!

    override func setUp() async throws {
        try await super.setUp()
        mockDevice = MockWKInterfaceDevice()
        batteryMonitor = WatchBatteryMonitor(device: mockDevice)
    }

    override func tearDown() async throws {
        batteryMonitor = nil
        mockDevice = nil
        try await super.tearDown()
    }

    // MARK: - M12.1 — Battery at 30% shows warning

    func test_batteryAt30Percent_showsWarning() {
        // Given: Apple Watch battery drops to exactly 30%
        mockDevice.stubbedBatteryLevel = 0.30

        // When
        batteryMonitor.checkBattery()

        // Then: low-battery warning is shown
        XCTAssertTrue(batteryMonitor.showsLowBatteryWarning,
                      "Battery at 30% should trigger low-battery warning")
    }

    // MARK: - M12.1 — Battery above 30% no warning

    func test_batteryAbove30Percent_noWarning() {
        // Given: battery at 75%
        mockDevice.stubbedBatteryLevel = 0.75

        // When
        batteryMonitor.checkBattery()

        // Then: no warning shown
        XCTAssertFalse(batteryMonitor.showsLowBatteryWarning,
                       "Battery above 30% should not show low-battery warning")
    }
}

// MARK: - Mock

final class MockWKInterfaceDevice: WKInterfaceDeviceProviding {
    var stubbedBatteryLevel: Float = 1.0
    var isBatteryMonitoringEnabled: Bool = false

    var batteryLevel: Float {
        stubbedBatteryLevel
    }
}
