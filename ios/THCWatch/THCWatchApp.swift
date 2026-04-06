import SwiftUI
import WatchConnectivity
import Shared

@main
struct THCWatchApp: App {
    // Fix #20: Migrated from @StateObject/ObservableObject to @State/@Observable.
    @State private var connectivityService = PhoneConnectivityService()
    @State private var gpsService = IndependentGPSService()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ActiveRoundView()
                    .environment(connectivityService)
                    .environment(gpsService)
            }
        }
    }
}
