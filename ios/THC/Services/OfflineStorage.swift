import Foundation
import SwiftData
import CoreLocation
import Shared

// MARK: - SwiftData Models

/// Persisted round awaiting sync to Supabase, or already synced.
/// Schema version: v1.
@Model
final class LocalRound {
    /// Local UUID used as the primary key when inserting into Supabase.
    var id: UUID
    var playerId: UUID
    var seasonId: UUID
    /// Date string "YYYY-MM-DD" — same format as `Round.playedAt`.
    var playedAt: String
    var courseName: String
    var par: Int
    var grossScore: Int
    var courseHandicap: Int
    var points: Int
    /// Always "app" for iOS-submitted rounds.
    var source: String
    /// False until the round has been successfully confirmed uploaded to Supabase.
    var syncedToSupabase: Bool
    var holeScores: [LocalHoleScore]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        playerId: UUID,
        seasonId: UUID,
        playedAt: String,
        courseName: String,
        par: Int,
        grossScore: Int,
        courseHandicap: Int,
        points: Int,
        source: String = "app",
        syncedToSupabase: Bool = false,
        holeScores: [LocalHoleScore] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.playerId = playerId
        self.seasonId = seasonId
        self.playedAt = playedAt
        self.courseName = courseName
        self.par = par
        self.grossScore = grossScore
        self.courseHandicap = courseHandicap
        self.points = points
        self.source = source
        self.syncedToSupabase = syncedToSupabase
        self.holeScores = holeScores
        self.createdAt = createdAt
    }
}

/// Per-hole score stored alongside a `LocalRound`.
@Model
final class LocalHoleScore {
    var id: UUID
    var holeNumber: Int
    var strokes: Int
    var putts: Int?
    /// "hit" | "left" | "right" | "na"
    var fairwayHit: String?
    var greenInRegulation: Bool?

    init(
        id: UUID = UUID(),
        holeNumber: Int,
        strokes: Int,
        putts: Int? = nil,
        fairwayHit: String? = nil,
        greenInRegulation: Bool? = nil
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.strokes = strokes
        self.putts = putts
        self.fairwayHit = fairwayHit
        self.greenInRegulation = greenInRegulation
    }
}

/// Cached course metadata for offline use.
@Model
final class CachedCourse {
    /// Matches `course_data.id` in Supabase.
    var id: UUID
    var name: String
    var lat: Double
    var lon: Double
    var par: Int
    var holeCount: Int
    var holes: [CachedHole]
    var lastFetched: Date

    init(
        id: UUID,
        name: String,
        lat: Double,
        lon: Double,
        par: Int,
        holeCount: Int,
        holes: [CachedHole] = [],
        lastFetched: Date = .now
    ) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
        self.par = par
        self.holeCount = holeCount
        self.holes = holes
        self.lastFetched = lastFetched
    }

    /// Whether the cached entry is older than the given time-to-live interval.
    func isStale(ttl: TimeInterval = 7 * 24 * 60 * 60) -> Bool {
        Date.now.timeIntervalSince(lastFetched) > ttl
    }
}

/// Cached per-hole data for a `CachedCourse`.
@Model
final class CachedHole {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var greenLat: Double?
    var greenLon: Double?
    /// Serialized `GeoJSONPolygon` — stored as raw JSON Data to avoid embedding
    /// a nested Codable type inside a SwiftData @Model graph.
    var greenPolygonJSON: Data?
    var teeLat: Double?
    var teeLon: Double?
    /// "osm" | "tap_and_save"
    var source: String

    init(
        id: UUID,
        holeNumber: Int,
        par: Int,
        greenLat: Double? = nil,
        greenLon: Double? = nil,
        greenPolygonJSON: Data? = nil,
        teeLat: Double? = nil,
        teeLon: Double? = nil,
        source: String
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.par = par
        self.greenLat = greenLat
        self.greenLon = greenLon
        self.greenPolygonJSON = greenPolygonJSON
        self.teeLat = teeLat
        self.teeLon = teeLon
        self.source = source
    }

    /// Decodes `greenPolygonJSON` into a typed `GeoJSONPolygon`, if present.
    var greenPolygon: GeoJSONPolygon? {
        guard let data = greenPolygonJSON else { return nil }
        return try? JSONDecoder().decode(GeoJSONPolygon.self, from: data)
    }
}

// MARK: - Schema

/// Current schema version — bump this and add a migration when the model shape changes.
enum OfflineStorageSchema {
    static let v1 = Schema(
        [LocalRound.self, LocalHoleScore.self, CachedCourse.self, CachedHole.self],
        version: Schema.Version(1, 0, 0)
    )

    static let current = v1
}

// MARK: - Protocol

/// Injectable interface for all offline persistence operations.
protocol OfflineStorageProviding: Sendable {
    // MARK: Rounds

    /// Save a new local round to SwiftData.
    func saveRound(_ round: LocalRound) throws

    /// Return all rounds where `syncedToSupabase == false`.
    func unsyncedRounds() throws -> [LocalRound]

    /// Mark a round as successfully uploaded to Supabase.
    func markRoundSynced(_ id: UUID) throws

    // MARK: Courses

    /// Cache a `CourseData` and its holes from Supabase/OSM.
    func cacheCourse(_ course: CourseData, holes: [CourseHole]) throws

    /// Return the cached course for a given ID, or nil if not present.
    func getCachedCourse(id: UUID) -> CachedCourse?

    /// Return all cached courses whose center is within `radiusKm` of the given coordinate.
    func getNearbyCachedCourses(lat: Double, lon: Double, radiusKm: Double) -> [CachedCourse]

    // MARK: Hole scores

    /// Append a hole score to an existing local round.
    func saveHoleScore(_ score: LocalHoleScore, roundId: UUID) throws
}

// MARK: - Implementation

/// SwiftData-backed offline storage.
/// Uses a single `ModelContext` that callers inject from the app's `ModelContainer`.
final class OfflineStorage: OfflineStorageProviding, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Rounds

    func saveRound(_ round: LocalRound) throws {
        context.insert(round)
        try context.save()
    }

    func unsyncedRounds() throws -> [LocalRound] {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.syncedToSupabase == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func markRoundSynced(_ id: UUID) throws {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.id == id }
        )
        guard let round = try context.fetch(descriptor).first else { return }
        round.syncedToSupabase = true
        try context.save()
    }

    // MARK: - Courses

    func cacheCourse(_ course: CourseData, holes: [CourseHole]) throws {
        // Remove stale cache entry for this course if one exists.
        let courseId = course.id
        let descriptor = FetchDescriptor<CachedCourse>(
            predicate: #Predicate { $0.id == courseId }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
        }

        let cachedHoles = holes.map { hole -> CachedHole in
            let polygonData: Data?
            if let polygon = hole.greenPolygon {
                polygonData = try? JSONEncoder().encode(polygon)
            } else {
                polygonData = nil
            }
            return CachedHole(
                id: hole.id,
                holeNumber: hole.holeNumber,
                par: hole.par,
                greenLat: hole.greenLat,
                greenLon: hole.greenLon,
                greenPolygonJSON: polygonData,
                teeLat: hole.teeLat,
                teeLon: hole.teeLon,
                source: hole.source
            )
        }

        let cached = CachedCourse(
            id: course.id,
            name: course.name,
            lat: course.lat,
            lon: course.lon,
            par: course.par,
            holeCount: course.holeCount,
            holes: cachedHoles,
            lastFetched: .now
        )
        context.insert(cached)
        try context.save()
    }

    func getCachedCourse(id: UUID) -> CachedCourse? {
        let descriptor = FetchDescriptor<CachedCourse>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    func getNearbyCachedCourses(lat: Double, lon: Double, radiusKm: Double) -> [CachedCourse] {
        // Fetch all cached courses and filter in memory — SwiftData does not expose
        // geospatial predicates. For ≤10 users this dataset is tiny.
        guard let all = try? context.fetch(FetchDescriptor<CachedCourse>()) else {
            return []
        }
        let radiusMeters = radiusKm * 1000
        return all.filter { course in
            // Fix #15: Use shared DistanceCalculator instead of duplicated haversine.
            let from = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let to = CLLocationCoordinate2D(latitude: course.lat, longitude: course.lon)
            let distanceMeters = DistanceCalculator.distanceInMeters(from: from, to: to)
            return distanceMeters <= radiusMeters
        }
    }

    // MARK: - Hole Scores

    func saveHoleScore(_ score: LocalHoleScore, roundId: UUID) throws {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.id == roundId }
        )
        guard let round = try context.fetch(descriptor).first else {
            throw OfflineStorageError.roundNotFound(roundId)
        }
        round.holeScores.append(score)
        try context.save()
    }

    // Fix #15: Removed duplicated haversineMeters — now uses DistanceCalculator.distanceInMeters.
}

// MARK: - Errors

enum OfflineStorageError: LocalizedError {
    case roundNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .roundNotFound(let id):
            return "LocalRound \(id) not found in SwiftData — cannot append hole score."
        }
    }
}
