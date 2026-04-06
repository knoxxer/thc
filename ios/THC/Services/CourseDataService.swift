import Foundation
import CoreLocation
import Shared

// MARK: - Protocol

/// Multi-source course data resolution service.
/// Resolution order: SwiftData cache → Supabase tap-and-save → OSM Overpass.
/// Cache-first is intentional: Overpass has 2-10s latency; we use it only as a
/// last resort and then persist the result to both Supabase and SwiftData.
protocol CourseDataServiceProviding: Sendable {
    /// Search for courses by name via GolfCourseAPI.
    func searchCourses(query: String) async throws -> [CourseSearchResult]

    /// Resolve full course data (holes, greens) for a course ID.
    func getCourseDetail(courseId: UUID) async throws -> CourseDetail?

    /// Find courses near a coordinate.
    func nearbyCourses(lat: Double, lon: Double, radiusKm: Double) async throws -> [CourseData]

    /// Save a tap-and-save green pin. Upserts to Supabase and updates SwiftData cache.
    func saveGreenPin(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        savedBy: UUID
    ) async throws

    /// Pre-fetch OSM data for courses within `radiusKm`. Called on app launch.
    func prefetchNearbyCourses(lat: Double, lon: Double, radiusKm: Double) async

    /// Upsert a course from a search result into `course_data` by `golfcourseapi_id`
    /// and return the Supabase UUID. If the course already exists, returns its existing ID.
    func getOrCreateCourse(from result: CourseSearchResult) async throws -> UUID
}

// MARK: - Supporting Types

struct CourseSearchResult: Sendable {
    let golfcourseapiId: Int
    let name: String
    let clubName: String?
    let address: String?
    let lat: Double?
    let lon: Double?
    let holeCount: Int
    let par: Int
}

struct CourseDetail: Sendable {
    let course: CourseData
    let holes: [CourseHole]
    let dataSource: CourseDataSource
}

enum CourseDataSource: Sendable {
    case osm
    case tapAndSave
    case metadataOnly
}

// MARK: - Errors

enum CourseDataServiceError: LocalizedError {
    case noDataFound(UUID)
    case greenPinSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDataFound(let id):
            return "No course data found for ID \(id) in cache, Supabase, or OSM."
        case .greenPinSaveFailed(let detail):
            return "Failed to save green pin: \(detail)"
        }
    }
}

// MARK: - Cache TTL

private let cacheTTLSeconds: TimeInterval = 7 * 24 * 60 * 60  // 7 days
private let nearbyAutoDetectMeters: Double = 500
private let prefetchRadiusKm: Double = 50

// MARK: - Implementation

final class CourseDataService: CourseDataServiceProviding, @unchecked Sendable {
    private let supabase: SupabaseClientProviding
    private let storage: OfflineStorageProviding
    private let overpass: OverpassAPIProviding
    private let golfCourseAPI: GolfCourseAPIClient

    /// Whether the GolfCourseAPI key has been fetched and configured.
    private var apiKeyConfigured = false

    init(
        supabase: SupabaseClientProviding,
        storage: OfflineStorageProviding,
        overpass: OverpassAPIProviding,
        golfCourseAPI: GolfCourseAPIClient
    ) {
        self.supabase = supabase
        self.storage = storage
        self.overpass = overpass
        self.golfCourseAPI = golfCourseAPI
    }

    // MARK: - API Key Lazy Init

    /// Fetches the GolfCourseAPI key from the `app_config` table on first use
    /// and configures the client. Subsequent calls are no-ops.
    private func ensureAPIKeyConfigured() async throws {
        guard !apiKeyConfigured else { return }

        struct AppConfigRow: Decodable {
            let value: String
        }

        let rows: [AppConfigRow] = try await supabase.client
            .from("app_config")
            .select("value")
            .eq("key", value: "golfcourseapi_key")
            .limit(1)
            .execute()
            .value

        guard let key = rows.first?.value, !key.isEmpty, key != "YOUR_KEY_HERE" else {
            throw GolfCourseAPIError.apiKeyUnavailable
        }

        golfCourseAPI.configure(apiKey: key)
        apiKeyConfigured = true
    }

    // MARK: - CourseDataServiceProviding

    func searchCourses(query: String) async throws -> [CourseSearchResult] {
        try await ensureAPIKeyConfigured()
        let results = try await golfCourseAPI.searchCourses(query: query)
        return results.map { item in
            CourseSearchResult(
                golfcourseapiId: item.id,
                name: item.courseName,
                clubName: item.clubName,
                address: [item.city, item.state, item.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                    .nilIfEmpty(),
                lat: item.latitude,
                lon: item.longitude,
                holeCount: 18,  // API does not return this in search — use 18 as default
                par: 72
            )
        }
    }

    func getCourseDetail(courseId: UUID) async throws -> CourseDetail? {
        // 1. SwiftData cache — fastest, no network.
        if let cached = storage.getCachedCourse(id: courseId), !cached.isStale(ttl: cacheTTLSeconds) {
            return courseDetailFromCache(cached)
        }

        // 2. Supabase — tap-and-save pins, previously fetched OSM data saved to DB.
        if let supabaseDetail = try? await fetchFromSupabase(courseId: courseId) {
            try? storage.cacheCourse(supabaseDetail.course, holes: supabaseDetail.holes)
            return supabaseDetail
        }

        // 3. OSM Overpass — last resort, can be slow (2–10s).
        if let cached = storage.getCachedCourse(id: courseId) {
            // We have a stale cache entry — use it to get the course coordinates
            // for the Overpass query.
            if let osmDetail = try? await fetchFromOSM(
                lat: cached.lat,
                lon: cached.lon,
                courseId: courseId
            ) {
                // Persist to Supabase so the next user benefits.
                try? await saveHolesToSupabase(osmDetail.holes, courseId: courseId)
                try? storage.cacheCourse(osmDetail.course, holes: osmDetail.holes)
                return osmDetail
            }
        }

        return nil
    }

    func nearbyCourses(lat: Double, lon: Double, radiusKm: Double) async throws -> [CourseData] {
        // Return SwiftData cached courses first for instant results.
        let cached = storage.getNearbyCachedCourses(lat: lat, lon: lon, radiusKm: radiusKm)
        if !cached.isEmpty {
            return cached.map { courseDataFromCache($0) }
        }

        // Fall through to Supabase earthdistance query.
        return try await fetchNearbyFromSupabase(lat: lat, lon: lon, radiusKm: radiusKm)
    }

    func saveGreenPin(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        savedBy: UUID
    ) async throws {
        let payload = GreenPinUpsertPayload(
            courseId: courseId,
            holeNumber: holeNumber,
            greenLat: greenLat,
            greenLon: greenLon,
            source: "tap_and_save",
            savedBy: savedBy
        )

        try await supabase.client
            .from("course_holes")
            .upsert(payload, onConflict: "course_id,hole_number")
            .execute()

        // Update the local cache if we have this course cached.
        if let cached = storage.getCachedCourse(id: courseId) {
            // Invalidate the cache so the next fetch pulls fresh data from Supabase.
            // The simplest approach is to re-cache with updated values.
            let updatedHoles = cached.holes.map { hole -> CachedHole in
                guard hole.holeNumber == holeNumber else { return hole }
                return CachedHole(
                    id: hole.id,
                    holeNumber: hole.holeNumber,
                    par: hole.par,
                    greenLat: greenLat,
                    greenLon: greenLon,
                    greenPolygonJSON: nil,  // tap-and-save is center-only, no polygon
                    teeLat: hole.teeLat,
                    teeLon: hole.teeLon,
                    source: "tap_and_save"
                )
            }

            // Build a minimal CourseData so we can call cacheCourse.
            let courseData = courseDataFromCache(cached)
            let courseHoles = updatedHoles.map { courseHoleFromCachedHole($0, courseId: courseId) }
            try? storage.cacheCourse(courseData, holes: courseHoles)
        }

        // Check whether all holes now have pins — if so update has_green_data on course_data.
        try await updateHasGreenDataIfComplete(courseId: courseId)
    }

    func getOrCreateCourse(from result: CourseSearchResult) async throws -> UUID {
        // Check if a course with this golfcourseapi_id already exists.
        let existing: [CourseData] = try await supabase.client
            .from("course_data")
            .select()
            .eq("golfcourseapi_id", value: result.golfcourseapiId)
            .limit(1)
            .execute()
            .value

        if let course = existing.first {
            return course.id
        }

        // Insert a new course row.
        let newId = UUID()
        let payload = CourseDataInsertPayload(
            id: newId,
            golfcourseapiId: result.golfcourseapiId,
            name: result.name,
            clubName: result.clubName,
            address: result.address,
            lat: result.lat ?? 0,
            lon: result.lon ?? 0,
            holeCount: result.holeCount,
            par: result.par
        )
        try await supabase.client
            .from("course_data")
            .insert(payload)
            .execute()

        return newId
    }

    func prefetchNearbyCourses(lat: Double, lon: Double, radiusKm: Double) async {
        guard let nearby = try? await fetchNearbyFromSupabase(
            lat: lat, lon: lon, radiusKm: prefetchRadiusKm
        ) else { return }

        // Cache Supabase data for each nearby course. Fire-and-forget.
        for course in nearby {
            guard storage.getCachedCourse(id: course.id) == nil else { continue }
            if let detail = try? await fetchFromSupabase(courseId: course.id) {
                try? storage.cacheCourse(detail.course, holes: detail.holes)
            }
        }
    }

    // MARK: - Private Fetch Helpers

    private func fetchFromSupabase(courseId: UUID) async throws -> CourseDetail? {
        let courseIdString = courseId.uuidString.lowercased()

        let courses: [CourseData] = try await supabase.client
            .from("course_data")
            .select()
            .eq("id", value: courseIdString)
            .limit(1)
            .execute()
            .value

        guard let course = courses.first else { return nil }

        let holes: [CourseHole] = try await supabase.client
            .from("course_holes")
            .select()
            .eq("course_id", value: courseIdString)
            .order("hole_number")
            .execute()
            .value

        let hasGreenData = holes.contains { $0.greenLat != nil }
        let source: CourseDataSource = hasGreenData ? .tapAndSave : .metadataOnly
        return CourseDetail(course: course, holes: holes, dataSource: source)
    }

    private func fetchFromOSM(lat: Double, lon: Double, courseId: UUID) async throws -> CourseDetail? {
        // Use a 1km radius centered on the course — large enough to capture all holes.
        let osmData = try await overpass.fetchGolfFeatures(lat: lat, lon: lon, radiusMeters: 1000)

        guard !osmData.greens.isEmpty else { return nil }

        // Build synthetic CourseData and CourseHole records from OSM features.
        // OSM data doesn't carry the Supabase course UUID, so we must already have
        // a course row to attach holes to.
        guard let courses: [CourseData] = try? await supabase.client
            .from("course_data")
            .select()
            .eq("id", value: courseId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value,
              let course = courses.first
        else { return nil }

        // Try to fetch real per-hole pars from GolfCourseAPI if the course has an API ID (Fix #13).
        var apiScorecard: [Int: GolfCourseAPIHole] = [:]
        if let apiId = course.golfcourseapiId {
            if let detail = try? await golfCourseAPI.getCourse(id: apiId) {
                for hole in detail.scorecard {
                    apiScorecard[hole.holeNumber] = hole
                }
            }
        }

        var holes: [CourseHole] = []
        for green in osmData.greens {
            let holeNumber = green.tags["ref"].flatMap(Int.init) ?? holes.count + 1
            let holeWay = osmData.holeWays.first { $0.holeNumber == holeNumber }
            let teeLat = holeWay?.points.first?.latitude
            let teeLon = holeWay?.points.first?.longitude

            // Use real par from GolfCourseAPI; default to 0 (unknown) if unavailable (Fix #13).
            let par = apiScorecard[holeNumber]?.par ?? 0
            let yardage = apiScorecard[holeNumber]?.yardage
            let handicap = apiScorecard[holeNumber]?.handicap

            let hole = CourseHole(
                id: UUID(),
                courseId: courseId,
                holeNumber: holeNumber,
                par: par,
                yardage: yardage,
                handicap: handicap,
                greenLat: green.center.latitude,
                greenLon: green.center.longitude,
                greenPolygon: green.polygon,
                teeLat: teeLat,
                teeLon: teeLon,
                source: "osm",
                savedBy: nil,
                createdAt: .now,
                updatedAt: .now
            )
            holes.append(hole)
        }

        return CourseDetail(course: course, holes: holes, dataSource: .osm)
    }

    private func fetchNearbyFromSupabase(lat: Double, lon: Double, radiusKm: Double) async throws -> [CourseData] {
        // Fetch all courses and filter by distance in memory.
        // For a 10-user app with a small course dataset, this is adequate.
        let allCourses: [CourseData] = try await supabase.client
            .from("course_data")
            .select()
            .execute()
            .value
        let radiusMeters = radiusKm * 1000
        return allCourses.filter { course in
            let dLat = (course.lat - lat) * .pi / 180
            let dLon = (course.lon - lon) * .pi / 180
            let a = sin(dLat / 2) * sin(dLat / 2)
                + cos(lat * .pi / 180) * cos(course.lat * .pi / 180)
                * sin(dLon / 2) * sin(dLon / 2)
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            let distMeters = 6_371_000.0 * c
            return distMeters <= radiusMeters
        }
    }

    // MARK: - Green Pin Helpers

    private func saveHolesToSupabase(_ holes: [CourseHole], courseId: UUID) async throws {
        let payloads = holes.map { hole in
            GreenPinUpsertPayload(
                courseId: courseId,
                holeNumber: hole.holeNumber,
                greenLat: hole.greenLat ?? 0,
                greenLon: hole.greenLon ?? 0,
                source: hole.source,
                savedBy: hole.savedBy
            )
        }
        guard !payloads.isEmpty else { return }
        try await supabase.client
            .from("course_holes")
            .upsert(payloads, onConflict: "course_id,hole_number")
            .execute()
    }

    private func updateHasGreenDataIfComplete(courseId: UUID) async throws {
        let courseIdString = courseId.uuidString.lowercased()
        let holes: [CourseHole] = try await supabase.client
            .from("course_holes")
            .select()
            .eq("course_id", value: courseIdString)
            .execute()
            .value

        let courses: [CourseData] = try await supabase.client
            .from("course_data")
            .select("hole_count")
            .eq("id", value: courseIdString)
            .limit(1)
            .execute()
            .value

        guard let course = courses.first else { return }
        let holesWithPins = holes.filter { $0.greenLat != nil }.count
        let allPinsSaved = holesWithPins >= course.holeCount

        if allPinsSaved {
            try await supabase.client
                .from("course_data")
                .update(["has_green_data": true])
                .eq("id", value: courseIdString)
                .execute()
        }
    }

    // MARK: - Type Conversion Helpers

    private func courseDetailFromCache(_ cached: CachedCourse) -> CourseDetail {
        let course = courseDataFromCache(cached)
        let holes = cached.holes.map { courseHoleFromCachedHole($0, courseId: cached.id) }
        let hasGreenData = holes.contains { $0.greenLat != nil }
        let source: CourseDataSource = hasGreenData ? .tapAndSave : .metadataOnly
        return CourseDetail(course: course, holes: holes, dataSource: source)
    }

    private func courseDataFromCache(_ cached: CachedCourse) -> CourseData {
        CourseData(
            id: cached.id,
            golfcourseapiId: nil,
            name: cached.name,
            clubName: nil,
            address: nil,
            lat: cached.lat,
            lon: cached.lon,
            holeCount: cached.holeCount,
            par: cached.par,
            osmId: nil,
            hasGreenData: cached.holes.contains { $0.greenLat != nil },
            createdAt: cached.lastFetched,
            updatedAt: cached.lastFetched
        )
    }

    private func courseHoleFromCachedHole(_ h: CachedHole, courseId: UUID) -> CourseHole {
        CourseHole(
            id: h.id,
            courseId: courseId,
            holeNumber: h.holeNumber,
            par: h.par,
            yardage: nil,
            handicap: nil,
            greenLat: h.greenLat,
            greenLon: h.greenLon,
            greenPolygon: h.greenPolygon,
            teeLat: h.teeLat,
            teeLon: h.teeLon,
            source: h.source,
            savedBy: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

// MARK: - Supabase Payloads

private struct CourseDataInsertPayload: Encodable {
    let id: String
    let golfcourseapiId: Int
    let name: String
    let clubName: String?
    let address: String?
    let lat: Double
    let lon: Double
    let holeCount: Int
    let par: Int

    init(
        id: UUID, golfcourseapiId: Int, name: String, clubName: String?,
        address: String?, lat: Double, lon: Double, holeCount: Int, par: Int
    ) {
        self.id = id.uuidString.lowercased()
        self.golfcourseapiId = golfcourseapiId
        self.name = name
        self.clubName = clubName
        self.address = address
        self.lat = lat
        self.lon = lon
        self.holeCount = holeCount
        self.par = par
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case golfcourseapiId = "golfcourseapi_id"
        case name
        case clubName = "club_name"
        case address
        case lat, lon
        case holeCount = "hole_count"
        case par
    }
}

private struct GreenPinUpsertPayload: Encodable {
    let courseId: String
    let holeNumber: Int
    let greenLat: Double
    let greenLon: Double
    let source: String
    let savedBy: String?

    init(courseId: UUID, holeNumber: Int, greenLat: Double, greenLon: Double, source: String, savedBy: UUID?) {
        self.courseId = courseId.uuidString.lowercased()
        self.holeNumber = holeNumber
        self.greenLat = greenLat
        self.greenLon = greenLon
        self.source = source
        self.savedBy = savedBy?.uuidString.lowercased()
    }

    private enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case holeNumber = "hole_number"
        case greenLat = "green_lat"
        case greenLon = "green_lon"
        case source
        case savedBy = "saved_by"
    }
}

// MARK: - String Helper

private extension String {
    func nilIfEmpty() -> String? {
        isEmpty ? nil : self
    }
}
