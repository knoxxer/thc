import Foundation

// MARK: - WKInterfaceDevice Protocol

protocol WKInterfaceDeviceProviding {
    var batteryLevel: Float { get }
    var isBatteryMonitoringEnabled: Bool { get set }
}

// MARK: - WatchBatteryMonitor

@Observable
final class WatchBatteryMonitor: @unchecked Sendable {
    private var device: WKInterfaceDeviceProviding

    /// Threshold below which the low-battery warning is shown.
    private let warningThreshold: Float = 0.30

    private(set) var showsLowBatteryWarning: Bool = false

    init(device: WKInterfaceDeviceProviding) {
        self.device = device
        self.device.isBatteryMonitoringEnabled = true
    }

    func checkBattery() {
        showsLowBatteryWarning = device.batteryLevel <= warningThreshold
    }
}
