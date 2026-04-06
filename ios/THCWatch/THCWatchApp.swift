import SwiftUI
import WatchConnectivity
import Shared

@main
struct THCWatchApp: App {
    @StateObject private var connectivityService = PhoneConnectivityService()
    @StateObject private var gpsService = IndependentGPSService()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ActiveRoundView()
                    .environmentObject(connectivityService)
                    .environmentObject(gpsService)
            }
        }
    }
}
