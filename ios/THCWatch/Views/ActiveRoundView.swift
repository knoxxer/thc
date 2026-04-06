import SwiftUI
import WatchKit
import Shared

/// Main view during an active round. Shows current hole, par, and distances to green.
/// Displays "No active round" when idle.
struct ActiveRoundView: View {
    @Environment(PhoneConnectivityService.self) private var connectivityService
    @Environment(IndependentGPSService.self) private var gpsService

    @State private var showScoreEntry = false
    @State private var showStandings = false
    @State private var showBatteryWarning = false

    private var roundState: WatchRoundState? {
        connectivityService.currentRoundState
    }

    var body: some View {
        Group {
            if let state = roundState {
                activeRoundContent(state: state)
            } else {
                idleContent
            }
        }
        .onAppear {
            checkBatteryLevel()
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        }
        .sheet(isPresented: $showScoreEntry) {
            if let state = roundState {
                QuickScoreView(holeNumber: state.currentHole, par: state.par)
                    .environment(connectivityService)
            }
        }
        .sheet(isPresented: $showStandings) {
            StandingsGlanceView()
                .environment(connectivityService)
        }
        .alert("Low Battery", isPresented: $showBatteryWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Watch battery below 30%. GPS tracking may be affected.")
        }
    }

    // MARK: - Active Round Content

    @ViewBuilder
    private func activeRoundContent(state: WatchRoundState) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                holeHeader(state: state)

                HoleDistanceView(
                    roundState: state,
                    gpsService: gpsService,
                    connectivityService: connectivityService
                )

                actionButtons
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Hole \(state.currentHole)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func holeHeader(state: WatchRoundState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.courseName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Par \(state.par)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Hole")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(state.currentHole)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button {
                showScoreEntry = true
            } label: {
                Label("Score", systemImage: "pencil")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)

            Button {
                showStandings = true
            } label: {
                Label("Standings", systemImage: "list.number")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    // MARK: - Idle Content

    private var idleContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("No Active Round")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Start a round on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showStandings = true
            } label: {
                Text("Standings")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding()
        .sheet(isPresented: $showStandings) {
            StandingsGlanceView()
                .environment(connectivityService)
        }
    }

    // MARK: - Battery Monitoring

    private func checkBatteryLevel() {
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        let level = WKInterfaceDevice.current().batteryLevel
        if level > 0 && level <= 0.30 {
            showBatteryWarning = true
        }
    }
}

#Preview {
    NavigationStack {
        ActiveRoundView()
            .environment(PhoneConnectivityService())
            .environment(IndependentGPSService())
    }
}
