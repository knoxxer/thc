import SwiftUI
import MapKit
import CoreLocation
import Shared

/// Satellite MapKit view where users tap the green to save its GPS coordinates.
///
/// First-round flow:
/// 1. Shows satellite imagery of the current hole area.
/// 2. User taps the green (clearly visible as a dark circle on satellite).
/// 3. App prompts "Save as Hole X green?" — user confirms.
/// 4. Pin is saved to Supabase via CourseDataService (all 10 users benefit).
struct TapAndSaveView: View {
    let courseDetail: CourseDetail
    let currentHole: Int
    let savedBy: UUID
    let onSaved: (CLLocationCoordinate2D) -> Void

    @State private var viewModel: CourseSetupViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var showSaveConfirmation: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var savedPin: CLLocationCoordinate2D?

    init(
        courseDetail: CourseDetail,
        currentHole: Int,
        savedBy: UUID,
        courseDataService: CourseDataServiceProviding,
        locationManager: LocationManager,
        onSaved: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        self.courseDetail = courseDetail
        self.currentHole = currentHole
        self.savedBy = savedBy
        self.onSaved = onSaved

        _viewModel = State(initialValue: CourseSetupViewModel(
            courseDataService: courseDataService,
            locationManager: locationManager
        ))

        // Center map on current hole's tee if available, else course center
        let center: CLLocationCoordinate2D
        if let hole = courseDetail.holes.first(where: { $0.holeNumber == currentHole }),
           let tLat = hole.teeLat, let tLon = hole.teeLon {
            center = CLLocationCoordinate2D(latitude: tLat, longitude: tLon)
        } else {
            center = CLLocationCoordinate2D(
                latitude: courseDetail.course.lat,
                longitude: courseDetail.course.lon
            )
        }

        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView
            overlayControls
        }
        .navigationTitle("Tap Green — Hole \(currentHole)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Save as Hole \(currentHole) Green?",
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save Green Location") {
                Task { await savePin() }
            }
            Button("Cancel", role: .cancel) {
                tappedCoordinate = nil
            }
        } message: {
            if let coord = tappedCoordinate {
                Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
            }
        }
        .alert("Save Failed", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Map

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                // User location
                UserAnnotation()

                // Previously saved pin for this hole
                if let coord = savedPin ?? existingGreenCoord {
                    Annotation("Green", coordinate: coord) {
                        Image(systemName: "flag.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .shadow(radius: 3)
                    }
                }

                // Tapped (pending) pin
                if let tapped = tappedCoordinate {
                    Annotation("Tap", coordinate: tapped) {
                        Image(systemName: "mappin")
                            .font(.title)
                            .foregroundStyle(.red)
                            .shadow(radius: 3)
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    tappedCoordinate = coord
                    showSaveConfirmation = true
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack(spacing: 0) {
            // Instructions banner
            if savedPin == nil && existingGreenCoord == nil {
                instructionBanner
            } else {
                savedBanner
            }
        }
        .padding(.bottom, 32)
    }

    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.white)
            Text("Tap the center of the green on the map")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.95))
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    private var savedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Green saved for hole \(currentHole)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.95))
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var existingGreenCoord: CLLocationCoordinate2D? {
        guard let hole = courseDetail.holes.first(where: { $0.holeNumber == currentHole }),
              let lat = hole.greenLat, let lon = hole.greenLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func savePin() async {
        guard let coord = tappedCoordinate else { return }
        isSaving = true
        do {
            try await viewModel.saveGreenPin(
                holeNumber: currentHole,
                lat: coord.latitude,
                lon: coord.longitude,
                savedBy: savedBy
            )
            savedPin = coord
            tappedCoordinate = nil
            onSaved(coord)
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
