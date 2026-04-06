import SwiftUI
import CoreLocation
import Shared

/// Displays front/center/back distances to the green plus the next hazard carry distance.
/// Uses phone-provided GPS data when available; falls back to IndependentGPSService.
struct HoleDistanceView: View {
    let roundState: WatchRoundState
    @ObservedObject var gpsService: IndependentGPSService
    @ObservedObject var connectivityService: PhoneConnectivityService

    private var distances: GreenDistances? {
        guard
            let lat = roundState.greenLat,
            let lon = roundState.greenLon,
            let userLocation = userCoordinate
        else { return nil }

        let greenCenter = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let polygon: GeoJSONPolygon? = roundState.greenPolygonJSON.flatMap {
            try? JSONDecoder().decode(GeoJSONPolygon.self, from: $0)
        }

        return DistanceCalculator.greenDistances(
            userLocation: userLocation,
            greenCenter: greenCenter,
            greenPolygon: polygon,
            approachFrom: userCoordinate ?? greenCenter
        )
    }

    private var userCoordinate: CLLocationCoordinate2D? {
        if let loc = gpsService.currentLocation {
            return loc.coordinate
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            distanceCards

            if let hazardName = roundState.nextHazardName,
               let hazardCarry = roundState.nextHazardCarry {
                hazardRow(name: hazardName, carry: hazardCarry)
            }

            if userCoordinate == nil {
                Text("Waiting for GPS...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Distance Cards

    @ViewBuilder
    private var distanceCards: some View {
        HStack(spacing: 4) {
            distanceCard(
                label: "Front",
                yards: distances?.front,
                color: .yellow
            )
            distanceCard(
                label: "Center",
                yards: distances?.center,
                color: .green,
                isCenter: true
            )
            distanceCard(
                label: "Back",
                yards: distances?.back,
                color: .orange
            )
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func distanceCard(
        label: String,
        yards: Double?,
        color: Color,
        isCenter: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let yards = yards {
                Text("\(Int(yards.rounded()))")
                    .font(isCenter ? .title2 : .title3)
                    .fontWeight(isCenter ? .black : .bold)
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
            } else {
                Text("--")
                    .font(isCenter ? .title2 : .title3)
                    .fontWeight(isCenter ? .black : .bold)
                    .foregroundStyle(.secondary)
            }

            Text("yds")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
        )
    }

    // MARK: - Hazard Row

    @ViewBuilder
    private func hazardRow(name: String, carry: Double) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)

            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text("\(Int(carry.rounded())) yds")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.10))
        )
    }
}

#Preview {
    let state = WatchRoundState(
        courseName: "Torrey Pines South",
        currentHole: 7,
        par: 4,
        greenLat: 32.8974,
        greenLon: -117.2511,
        greenPolygonJSON: nil,
        nextHazardName: "Water Hazard",
        nextHazardCarry: 187,
        holeScores: [:]
    )

    HoleDistanceView(
        roundState: state,
        gpsService: IndependentGPSService(),
        connectivityService: PhoneConnectivityService()
    )
    .padding()
}
