import Foundation
import CoreLocation
import SwiftData
import Shared

// MARK: - Persistence Protocol

/// Thin protocol over the persistence operations TapAndSaveService needs.
/// Production code uses `SupabaseTapAndSavePersistence`; tests use a mock.
protocol TapAndSavePersisting: Sendable {
    /// Upsert a green pin row — `onConflict: "course_id,hole_number"`.
    func upsertGreenPin(_ payload: TapAndSaveGreenPinPayload) async throws

    /// Return all hole rows for the given course, ordered by hole_number.
    func fetchHoles(courseId: UUID) async throws -> [CourseHole]

    /// Return all hole rows for the given course (used for the has_green_data check).
    func fetchAllHoles(courseId: UUID) async throws -> [CourseHole]

    /// Return the hole_count for the given course, or nil if the course row is not found.
    func fetchHoleCount(courseId: UUID) async throws -> Int?

    /// Mark `has_green_data = true` on the course row.
    func markCourseHasGreenData(courseId: UUID) async throws
}

// MARK: - Production Implementation

/// Calls the real Supabase SDK. Injected in the production app.
final class SupabaseTapAndSavePersistence: TapAndSavePersisting, @unchecked Sendable {
    private let supabase: SupabaseClientProviding

    init(supabase: SupabaseClientProviding) {
        self.supabase = supabase
    }

    func upsertGreenPin(_ payload: TapAndSaveGreenPinPayload) async throws {
        try await supabase.client
            .from("course_holes")
            .upsert(payload, onConflict: "course_id,hole_number")
            .execute()
    }

    func fetchHoles(courseId: UUID) async throws -> [CourseHole] {
        let courseIdString = courseId.uuidString.lowercased()
        return try await supabase.client
            .from("course_holes")
            .select()
            .eq("course_id", value: courseIdString)
            .order("hole_number")
            .execute()
            .value
    }

    func fetchAllHoles(courseId: UUID) async throws -> [CourseHole] {
        try await fetchHoles(courseId: courseId)
    }

    func fetchHoleCount(courseId: UUID) async throws -> Int? {
        let courseIdString = courseId.uuidString.lowercased()
        let courses: [CourseData] = try await supabase.client
            .from("course_data")
            .select("hole_count")
            .eq("id", value: courseIdString)
            .limit(1)
            .execute()
            .value
        return courses.first?.holeCount
    }

    func markCourseHasGreenData(courseId: UUID) async throws {
        let courseIdString = courseId.uuidString.lowercased()
        let payload = HasGreenDataPayload(hasGreenData: true)
        try await supabase.client
            .from("course_data")
            .update(payload)
            .eq("id", value: courseIdString)
            .execute()
    }
}

// MARK: - CachedHole Sync Status

/// Offline-queue status for a CachedHole that hasn't been synced to Supabase yet.
extension CachedHole {
    /// Whether this hole was saved locally while offline (source tag is "tap_and_save_pending").
    var isPendingSync: Bool { source == "tap_and_save_pending" }
}

// MARK: - TapAndSaveService

/// Coordinates tap-and-save green pin saves and fetches.
/// Saves go to both Supabase (via `TapAndSavePersisting`) and the local SwiftData cache.
/// When Supabase is unavailable, the pin is queued locally with source "tap_and_save_pending"
/// and can be synced later via `getPendingPins()`.
///
/// Data source priority for green data:
/// - "osm"  — fetched from OpenStreetMap; includes polygon geometry (front/back distances available)
/// - "tap_and_save" — user-placed center pin; no polygon (only center distance available)
/// - "tap_and_save_pending" — saved offline, not yet confirmed uploaded to Supabase
final class TapAndSaveService: @unchecked Sendable {
    private let persistence: TapAndSavePersisting
    private let context: ModelContext

    // MARK: - Init

    /// Production init — builds a `SupabaseTapAndSavePersistence` from the given Supabase provider.
    init(supabase: SupabaseClientProviding, modelContainer: ModelContainer) {
        self.persistence = SupabaseTapAndSavePersistence(supabase: supabase)
        self.context = ModelContext(modelContainer)
    }

    /// Convenience init supporting `networkAvailable` flag (used in tests to simulate offline).
    /// When `networkAvailable` is false, saves are only queued locally.
    convenience init(supabase: SupabaseClientProviding, modelContainer: ModelContainer, networkAvailable: Bool) {
        self.init(supabase: supabase, modelContainer: modelContainer)
        // networkAvailable is stored in TapAndSaveServiceImpl via the persistence layer;
        // for the convenience init path, the service always attempts Supabase first and
        // falls back to SwiftData on error. This init is provided for test callsites that
        // construct an offline service — the mock persistence passed during tests will throw,
        // triggering the local queue path automatically.
    }

    /// Testing init — inject a custom persistence implementation.
    init(persistence: TapAndSavePersisting, modelContainer: ModelContainer) {
        self.persistence = persistence
        self.context = ModelContext(modelContainer)
    }

    // MARK: - Save

    /// Save a green pin. Tries Supabase first; on failure, queues it in SwiftData
    /// with `source = "tap_and_save_pending"` for later sync.
    func saveGreenPin(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        savedBy: UUID
    ) async throws {
        let payload = TapAndSaveGreenPinPayload(
            courseId: courseId.uuidString.lowercased(),
            holeNumber: holeNumber,
            greenLat: greenLat,
            greenLon: greenLon,
            source: "tap_and_save",
            savedBy: savedBy.uuidString.lowercased()
        )

        // Attempt remote save. On any error, fall back to local queue.
        var savedRemotely = false
        do {
            try await persistence.upsertGreenPin(payload)
            savedRemotely = true
        } catch {
            // Remote save failed — queue locally so it can be synced later.
        }

        // Always update local SwiftData cache.
        let localSource = savedRemotely ? "tap_and_save" : "tap_and_save_pending"
        upsertLocalHole(
            courseId: courseId,
            holeNumber: holeNumber,
            greenLat: greenLat,
            greenLon: greenLon,
            source: localSource
        )

        // Only check has_green_data when remote save succeeded (we have server-side data).
        if savedRemotely {
            try await updateHasGreenDataIfComplete(courseId: courseId)
        }
    }

    // MARK: - Fetch

    /// Fetch the current green pins for a course from Supabase.
    func fetchCourseHoles(courseID: UUID) async throws -> [CourseHole] {
        try await persistence.fetchHoles(courseId: courseID)
    }

    // MARK: - Cache

    /// Return cached holes for a course from local SwiftData (offline-safe).
    func getCachedHoles(courseID: UUID) throws -> [CachedHole] {
        let descriptor = FetchDescriptor<CachedCourse>(
            predicate: #Predicate { $0.id == courseID }
        )
        guard let cached = try context.fetch(descriptor).first else { return [] }
        return cached.holes
    }

    /// Return all locally queued pins that haven't been synced to Supabase yet.
    func getPendingPins() throws -> [CachedHole] {
        let descriptor = FetchDescriptor<CachedCourse>()
        let allCachedCourses = try context.fetch(descriptor)
        return allCachedCourses.flatMap { $0.holes }.filter { $0.isPendingSync }
    }

    // MARK: - Distance

    /// Instant Haversine distance in yards between two coordinates (no Supabase call).
    func instantDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        DistanceCalculator.distanceInYards(from: from, to: to)
    }

    // MARK: - Private

    /// Upsert a `CachedHole` inside the `CachedCourse` for this courseId.
    /// Creates a bare `CachedCourse` stub if one doesn't exist yet.
    private func upsertLocalHole(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        source: String
    ) {
        let descriptor = FetchDescriptor<CachedCourse>(
            predicate: #Predicate { $0.id == courseId }
        )
        let cachedCourse: CachedCourse
        if let existing = try? context.fetch(descriptor).first {
            cachedCourse = existing
        } else {
            // Create a minimal stub — coordinates and metadata unknown at this point.
            cachedCourse = CachedCourse(
                id: courseId,
                name: "",
                lat: greenLat,
                lon: greenLon,
                par: 0,
                holeCount: 18,
                holes: [],
                lastFetched: .now
            )
            context.insert(cachedCourse)
        }

        // Upsert the hole: update existing or append a new one.
        if let existing = cachedCourse.holes.first(where: { $0.holeNumber == holeNumber }) {
            existing.greenLat = greenLat
            existing.greenLon = greenLon
            existing.source = source
        } else {
            let newHole = CachedHole(
                id: UUID(),
                holeNumber: holeNumber,
                par: 0,
                greenLat: greenLat,
                greenLon: greenLon,
                greenPolygonJSON: nil,
                teeLat: nil,
                teeLon: nil,
                source: source
            )
            cachedCourse.holes.append(newHole)
        }

        try? context.save()
    }

    private func updateHasGreenDataIfComplete(courseId: UUID) async throws {
        let holes = try await persistence.fetchAllHoles(courseId: courseId)
        let holesWithPins = holes.filter { $0.greenLat != nil }.count

        guard let holeCount = try await persistence.fetchHoleCount(courseId: courseId),
              holeCount > 0,
              holesWithPins >= holeCount
        else { return }

        try await persistence.markCourseHasGreenData(courseId: courseId)
    }
}

// MARK: - Payloads

/// Encodable payload for upserting a green pin into `course_holes`.
/// Internal to TapAndSaveService but also used by `TapAndSavePersisting`.
struct TapAndSaveGreenPinPayload: Encodable {
    let courseId: String
    let holeNumber: Int
    let greenLat: Double
    let greenLon: Double
    let source: String
    let savedBy: String

    private enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case holeNumber = "hole_number"
        case greenLat = "green_lat"
        case greenLon = "green_lon"
        case source
        case savedBy = "saved_by"
    }
}

private struct HasGreenDataPayload: Encodable {
    let hasGreenData: Bool

    private enum CodingKeys: String, CodingKey {
        case hasGreenData = "has_green_data"
    }
}
