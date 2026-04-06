import SwiftUI
import MapKit
import CoreLocation
import Shared

/// Primary GPS screen during an active round.
///
/// Shows a satellite view of the current hole, user location pin,
/// green distance callout (front/center/back), hole info, and tap-for-distance.
struct HoleOverviewView: View {
    @Bindable var roundManager: RoundManager
    @Environment(LocationManager.self) private var locationManager

    let courseDataService: CourseDataServiceProviding
    let currentPlayerId: UUID

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var tapDistanceLabel: String?
    @State private var tapPoint: CLLocationCoordinate2D?
    @State private var showScoreEntry: Bool = false
    @State private var showTapAndSave: Bool = false

    private var currentHoleData: CourseHole? {
        guard case .active(let holeNum, _) = roundManager.state else { return nil }
        return roundManager.courseDetail?.holes.first { $0.holeNumber == holeNum }
    }

    private var greenCoord: CLLocationCoordinate2D? {
        guard let h = currentHoleData, let lat = h.greenLat, let lon = h.greenLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView
            distanceOverlay
        }
        .navigationTitle("Hole \(roundManager.currentHole)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { centerOnCurrentHole() }
        .onChange(of: roundManager.currentHole) { _, _ in
            withAnimation { centerOnCurrentHole() }
            tapDistanceLabel = nil
            tapPoint = nil
        }
        .sheet(isPresented: $showScoreEntry) {
            if roundManager.courseDetail != nil {
                NavigationStack {
                    LiveScoringView(roundManager: roundManager)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showScoreEntry = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showTapAndSave) {
            tapAndSaveSheet
        }
    }

    // MARK: - Map

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                // User location
                UserAnnotation()

                // Green pin
                if let green = greenCoord {
                    Annotation("Green", coordinate: green) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                            .shadow(radius: 3)
                    }
                }

                // Tap-for-distance pin
                if let tap = tapPoint {
                    Annotation("Distance", coordinate: tap) {
                        distancePinView
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .onTapGesture { screenPoint in
                handleMapTap(proxy: proxy, screenPoint: screenPoint)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var distancePinView: some View {
        VStack(spacing: 2) {
            if let label = tapDistanceLabel {
                Text(label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
            Image(systemName: "mappin")
                .foregroundStyle(.red)
                .font(.title2)
        }
    }

    // MARK: - Distance Overlay

    private var distanceOverlay: some View {
        DistanceOverlay(
            roundManager: roundManager,
            onScoreEntryTap: { showScoreEntry = true },
            onTapAndSaveTap: greenCoord == nil ? { showTapAndSave = true } : nil
        )
    }

    // MARK: - Tap-and-Save Sheet

    private var tapAndSaveSheet: some View {
        Group {
            if let detail = roundManager.courseDetail {
                NavigationStack {
                    TapAndSaveView(
                        courseDetail: detail,
                        currentHole: roundManager.currentHole,
                        savedBy: currentPlayerId,
                        courseDataService: courseDataService,
                        locationManager: locationManager
                    ) { _ in
                        showTapAndSave = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showTapAndSave = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                let prevHole = roundManager.currentHole - 1
                if prevHole >= 1 { roundManager.goToHole(prevHole) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(roundManager.currentHole <= 1)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                let total = roundManager.courseDetail?.holes.count ?? 18
                let nextHole = roundManager.currentHole + 1
                if nextHole <= total { roundManager.goToHole(nextHole) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(roundManager.currentHole >= (roundManager.courseDetail?.holes.count ?? 18))
        }
    }

    // MARK: - Helpers

    private func centerOnCurrentHole() {
        let holeData = currentHoleData
        let coord: CLLocationCoordinate2D

        if let green = greenCoord {
            coord = green
        } else if let tLat = holeData?.teeLat, let tLon = holeData?.teeLon {
            coord = CLLocationCoordinate2D(latitude: tLat, longitude: tLon)
        } else if let course = roundManager.courseDetail?.course {
            coord = CLLocationCoordinate2D(latitude: course.lat, longitude: course.lon)
        } else {
            return
        }

        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        ))
    }

    private func handleMapTap(proxy: MapProxy, screenPoint: CGPoint) {
        guard let coord = proxy.convert(screenPoint, from: .local) else { return }
        tapPoint = coord
        let distance = roundManager.distanceTo(coord)
        tapDistanceLabel = String(format: "%.0f yds", distance)
    }
}
