# THC iOS App — Implementation Plan

This document breaks the iOS golf GPS app into discrete, testable modules with clear interfaces, a dependency-aware build order, exact backend SQL, and integration specifications. It is written so that a developer can pick up any module and implement it against well-defined contracts.

---

## Table of Contents

1. [Module Breakdown](#1-module-breakdown)
2. [Implementation Order](#2-implementation-order)
3. [Shared Code Strategy](#3-shared-code-strategy)
4. [Backend Changes](#4-backend-changes)
5. [Integration Points](#5-integration-points)
6. [Risk Mitigations](#6-risk-mitigations)

---

## 1. Module Breakdown

### Module 1: SupabaseClient

**Purpose:** Single point of contact for Supabase auth and data operations. Wraps the `supabase-swift` SDK with THC-specific configuration.

**Public Interface:**

```swift
// THC/Services/SupabaseClientProvider.swift  (iOS-only — watch uses WatchConnectivity)

protocol SupabaseClientProviding: Sendable {
    var client: SupabaseClient { get }

    /// Current authenticated user, nil if signed out.
    var currentUser: User? { get async }

    /// Sign in with Google via ASWebAuthenticationSession.
    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws -> Session

    /// Sign out and clear local session.
    func signOut() async throws

    /// Observe auth state changes.
    func authStateChanges() -> AsyncStream<AuthChangeEvent>
}
```

**Dependencies:** None (leaf module).

**Supabase Tables/RLS:** All tables via the anon key. RLS policies enforce per-user access.

**Key Types:**

```swift
// No custom types — uses Supabase SDK's User, Session, AuthChangeEvent.
```

**Notes:**
- The existing web app uses `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`. The iOS app uses the same values, stored in a `Secrets.plist` excluded from git (loaded at runtime, never compiled into the binary).
- Token refresh is handled automatically by the Supabase Swift SDK's `autoRefreshToken` option. The SDK stores the refresh token in Keychain. A 4-5 hour round will trigger at least one silent refresh — this is handled by the SDK, not our code.

---

### Module 2: AuthManager

**Purpose:** Manages the full auth lifecycle — login UI trigger, session persistence, mapping Supabase `auth.users` to `players` rows.

**Public Interface:**

```swift
// THC/Features/Auth/AuthManager.swift

@Observable
final class AuthManager {
    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(Player)
        case notAPlayer  // authenticated but no matching players row
    }

    private(set) var state: AuthState = .loading

    init(supabase: SupabaseClientProviding)

    func signIn(presenting anchor: ASPresentationAnchor) async
    func signOut() async
}
```

**Dependencies:** SupabaseClient, `Player` model.

**Supabase Tables/RLS:**
- Reads `players` (filtered by `email = auth.jwt() ->> 'email'`).
- Existing RLS: players are readable by all authenticated users.

**Key Types:** Uses `Player` from Shared/Models.

---

### Module 3: Models (Shared)

**Purpose:** All data models shared between iOS and watchOS. Includes both Supabase-backed `Codable` structs and SwiftData `@Model` classes for local persistence.

**Public Interface:**

```swift
// Shared/Models/Player.swift
struct Player: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let displayName: String    // maps to display_name
    let slug: String
    let email: String?
    let ghinNumber: String?    // maps to ghin_number
    let handicapIndex: Double? // maps to handicap_index
    let handicapUpdatedAt: Date? // maps to handicap_updated_at
    let avatarUrl: String?     // maps to avatar_url
    let isActive: Bool         // maps to is_active
    let role: String           // "admin" | "contributor"
    let authUserId: String?    // maps to auth_user_id
    let createdAt: Date        // maps to created_at
}

// Shared/Models/Season.swift
struct Season: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let startsAt: Date         // maps to starts_at
    let endsAt: Date           // maps to ends_at
    let isActive: Bool         // maps to is_active
    let minRounds: Int         // maps to min_rounds
    let topNRounds: Int        // maps to top_n_rounds
    let createdAt: Date
}

// Shared/Models/Round.swift
struct Round: Codable, Identifiable, Sendable {
    let id: UUID
    let playerId: UUID         // maps to player_id
    let seasonId: UUID         // maps to season_id
    let playedAt: String       // date string "YYYY-MM-DD"
    let courseName: String     // maps to course_name
    let teeName: String?       // maps to tee_name
    let courseRating: Double?   // maps to course_rating
    let slopeRating: Double?   // maps to slope_rating
    let par: Int
    let grossScore: Int        // maps to gross_score
    let courseHandicap: Int     // maps to course_handicap
    let netScore: Int          // maps to net_score
    let netVsPar: Int          // maps to net_vs_par
    let points: Int?
    let ghinScoreId: String?   // maps to ghin_score_id
    let source: String         // "manual" | "ghin" | "app"
    let enteredBy: String?     // maps to entered_by
    let createdAt: Date
}

// Shared/Models/SeasonStanding.swift
struct SeasonStanding: Codable, Identifiable, Sendable {
    var id: UUID { playerId }  // use player_id as identity
    let playerId: UUID
    let seasonId: UUID
    let playerName: String
    let playerSlug: String
    let handicapIndex: Double?
    let avatarUrl: String?
    let totalRounds: Int
    let isEligible: Bool
    let bestNPoints: Int       // maps to best_n_points
    let bestRoundPoints: Int   // maps to best_round_points
    let bestNetVsPar: Int      // maps to best_net_vs_par
}

// Shared/Models/CourseData.swift  (NEW)
struct CourseData: Codable, Identifiable, Sendable {
    let id: UUID
    let golfcourseapiId: Int?   // maps to golfcourseapi_id
    let name: String
    let clubName: String?       // maps to club_name
    let address: String?
    let lat: Double
    let lon: Double
    let holeCount: Int          // maps to hole_count
    let par: Int
    let osmId: String?          // maps to osm_id
    let hasGreenData: Bool      // maps to has_green_data
    let createdAt: Date
    let updatedAt: Date
}

// Shared/Models/CourseHole.swift  (NEW)
struct CourseHole: Codable, Identifiable, Sendable {
    let id: UUID
    let courseId: UUID          // maps to course_id
    let holeNumber: Int        // maps to hole_number
    let par: Int
    let yardage: Int?
    let handicap: Int?         // stroke index
    let greenLat: Double?      // maps to green_lat
    let greenLon: Double?      // maps to green_lon
    let greenPolygon: GeoJSONPolygon?  // maps to green_polygon
    let teeLat: Double?        // maps to tee_lat
    let teeLon: Double?        // maps to tee_lon
    let source: String         // "osm" | "tap_and_save"
    let savedBy: UUID?         // maps to saved_by
    let createdAt: Date
    let updatedAt: Date
}

// Shared/Models/GeoJSONPolygon.swift  (NEW)
struct GeoJSONPolygon: Codable, Sendable {
    let type: String           // "Polygon"
    let coordinates: [[[Double]]]  // [[[lon, lat], ...]]
}

// Shared/Models/HoleScore.swift  (NEW)
struct HoleScore: Codable, Identifiable, Sendable {
    let id: UUID
    let roundId: UUID          // maps to round_id
    let holeNumber: Int        // maps to hole_number
    let strokes: Int
    let putts: Int?
    let fairwayHit: String?    // maps to fairway_hit: "hit" | "left" | "right" | "na"
    let greenInRegulation: Bool?  // maps to green_in_regulation
    let createdAt: Date
}

// Shared/Models/LiveRound.swift  (NEW)
struct LiveRound: Codable, Identifiable, Sendable {
    let id: UUID
    let playerId: UUID         // maps to player_id
    let courseDataId: UUID?    // maps to course_data_id
    let courseName: String     // maps to course_name
    let currentHole: Int       // maps to current_hole
    let thruHole: Int          // maps to thru_hole
    let currentScore: Int      // maps to current_score (strokes relative to par)
    let startedAt: Date        // maps to started_at
    let updatedAt: Date
}

// Shared/Models/RoundReaction.swift  (NEW)
struct RoundReaction: Codable, Identifiable, Sendable {
    let id: UUID
    let roundId: UUID          // maps to round_id
    let playerId: UUID         // maps to player_id
    let emoji: String          // reaction emoji or short code
    let comment: String?
    let createdAt: Date
}
```

**Dependencies:** None (leaf module).

**Supabase Tables:** All of the above map 1:1 to Supabase tables. Column name mapping uses `keyDecodingStrategy: .convertFromSnakeCase` on the JSONDecoder configured in SupabaseClient.

---

### Module 4: PointsCalculator (Shared)

**Purpose:** Port of `src/lib/points.ts`. Must produce identical output.

**Public Interface:**

```swift
// Shared/PointsCalculator.swift

enum PointsCalculator {
    /// Calculate points for a round based on net score vs par.
    /// Net par (0) = 10 points. Each stroke under adds 1, each over loses 1.
    /// Floor of 1, ceiling of 15.
    static func calculatePoints(netVsPar: Int) -> Int
}
```

**Dependencies:** None.

**Key Invariant:** `calculatePoints(netVsPar: 0) == 10`, `calculatePoints(netVsPar: -6) == 15` (capped), `calculatePoints(netVsPar: 10) == 1` (floored).

---

### Module 5: DistanceCalculator (Shared)

**Purpose:** All geospatial math — Haversine distance, front/center/back of green relative to line of play, hazard carry/front distances, layup point calculation.

**Public Interface:**

```swift
// Shared/Utilities/DistanceCalculator.swift

import CoreLocation

enum DistanceCalculator {
    /// Distance in yards between two coordinates using the Haversine formula.
    static func distanceInYards(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double

    /// Distance in meters between two coordinates.
    static func distanceInMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double

    /// Front/center/back distances to a green polygon along the approach line.
    /// approachFrom: the direction of approach (previous point on the hole way,
    ///               or user position if no hole way).
    /// Returns nil for front/back if the hole has no polygon (tap-and-save center only).
    static func greenDistances(
        userLocation: CLLocationCoordinate2D,
        greenCenter: CLLocationCoordinate2D,
        greenPolygon: GeoJSONPolygon?,
        approachFrom: CLLocationCoordinate2D
    ) -> GreenDistances

    /// Distance to the nearest and farthest edges of a polygon from the user.
    static func hazardDistances(
        userLocation: CLLocationCoordinate2D,
        hazardPolygon: GeoJSONPolygon
    ) -> HazardDistances

    /// Point along a line at a specific yardage from a target (e.g., 100y from green).
    static func layupPoint(
        from: CLLocationCoordinate2D,
        toward: CLLocationCoordinate2D,
        yardsFromTarget: Double
    ) -> CLLocationCoordinate2D
}

struct GreenDistances: Sendable {
    let front: Double?       // yards, nil if no polygon
    let center: Double       // yards
    let back: Double?        // yards, nil if no polygon
}

struct HazardDistances: Sendable {
    let frontEdge: Double    // yards to nearest edge
    let carry: Double        // yards to far edge (to clear it)
}
```

**Dependencies:** `GeoJSONPolygon` from Models.

---

### Module 6: OfflineStorage

**Purpose:** SwiftData persistence for offline rounds, cached course data, and local score entry. Handles sync to Supabase on reconnect.

**Public Interface:**

```swift
// THC/Services/OfflineStorage.swift

import SwiftData

@Model
final class LocalRound {
    var id: UUID
    var playerId: UUID
    var seasonId: UUID
    var playedAt: String
    var courseName: String
    var par: Int
    var grossScore: Int
    var courseHandicap: Int
    var points: Int
    var source: String              // always "app"
    var syncedToSupabase: Bool      // false until confirmed uploaded
    var holeScores: [LocalHoleScore]
    var createdAt: Date
}

@Model
final class LocalHoleScore {
    var id: UUID
    var holeNumber: Int
    var strokes: Int
    var putts: Int?
    var fairwayHit: String?
    var greenInRegulation: Bool?
}

@Model
final class CachedCourse {
    var id: UUID                    // matches course_data.id
    var name: String
    var lat: Double
    var lon: Double
    var par: Int
    var holeCount: Int
    var holes: [CachedHole]
    var lastFetched: Date
}

@Model
final class CachedHole {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var greenLat: Double?
    var greenLon: Double?
    var greenPolygonJSON: Data?     // serialized GeoJSONPolygon
    var teeLat: Double?
    var teeLon: Double?
    var source: String
}

protocol OfflineStorageProviding {
    // Rounds
    func saveRound(_ round: LocalRound) throws
    func unsyncedRounds() throws -> [LocalRound]
    func markRoundSynced(_ id: UUID) throws

    // Courses
    func cacheCourse(_ course: CourseData, holes: [CourseHole]) throws
    func getCachedCourse(id: UUID) -> CachedCourse?
    func getNearbyCachedCourses(lat: Double, lon: Double, radiusKm: Double) -> [CachedCourse]

    // Hole scores
    func saveHoleScore(_ score: LocalHoleScore, roundId: UUID) throws
}
```

**Dependencies:** Models module.

**SwiftData Schema Version:** v1 from day one. All `@Model` classes include a `static var schemaVersion` for future migration.

---

### Module 7: SyncService

**Purpose:** Bidirectional sync between SwiftData and Supabase. Uploads local rounds, downloads standings updates.

**Public Interface:**

```swift
// THC/Services/SyncService.swift

protocol SyncServiceProviding {
    /// Upload all unsynced local rounds to Supabase.
    /// Returns count of successfully synced rounds.
    func syncPendingRounds() async throws -> Int

    /// Fetch latest standings from Supabase.
    func fetchStandings(seasonId: UUID) async throws -> [SeasonStanding]

    /// Fetch all rounds for a player in a season.
    func fetchPlayerRounds(playerId: UUID, seasonId: UUID) async throws -> [Round]

    /// Fetch active season.
    func fetchActiveSeason() async throws -> Season?
}
```

**Dependencies:** SupabaseClient, OfflineStorage, PointsCalculator, Models.

**Supabase Tables/RLS:**
- Inserts into `rounds` (RLS: `auth.uid() = entered_by` or via player matching).
- Reads `season_standings` view, `rounds`, `seasons`.
- Inserts into `hole_scores` (RLS: round must belong to the authenticated player).

**Deduplication:** Before inserting a round, check `rounds` for an existing row with the same `player_id + played_at + course_name + gross_score`. This prevents double-posts from retry after network failure.

---

### Module 8: CourseDataService

**Purpose:** Multi-source course data resolution. Checks OSM first, then Supabase tap-and-save pins, and uses GolfCourseAPI for metadata search.

**Public Interface:**

```swift
// THC/Services/CourseDataService.swift

protocol CourseDataServiceProviding {
    /// Search courses by name via GolfCourseAPI.
    func searchCourses(query: String) async throws -> [CourseSearchResult]

    /// Get full course data (holes, greens) for a course.
    /// Resolution order: local cache -> Supabase tap-and-save -> OSM Overpass.
    /// Note: The feature spec says "check OSM first" but cache-first is correct
    /// for performance — OSM Overpass has 2-10s latency.
    func getCourseDetail(courseId: UUID) async throws -> CourseDetail?

    /// Find courses near a location.
    func nearbyCourses(lat: Double, lon: Double, radiusKm: Double) async throws -> [CourseData]

    /// Save a tap-and-save green pin. Writes to Supabase and local cache.
    func saveGreenPin(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        savedBy: UUID
    ) async throws

    /// Pre-fetch OSM data for courses within radius. Called on app launch.
    func prefetchNearbyCourses(lat: Double, lon: Double, radiusKm: Double) async
}

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
    case osm           // full polygons from OpenStreetMap
    case tapAndSave    // center-only pins from user contributions
    case metadataOnly  // GolfCourseAPI info, no green coordinates
}
```

**Dependencies:** OverpassAPIClient, GolfCourseAPIClient, SupabaseClient, OfflineStorage.

**Supabase Tables/RLS:**
- Reads/writes `course_data`, `course_holes`.
- RLS: all authenticated users can read. All authenticated users can insert/update (trusted 10-user group).

---

### Module 9: OverpassAPIClient

**Purpose:** Queries OpenStreetMap Overpass API for golf course geometry data.

**Public Interface:**

```swift
// THC/Services/OverpassAPIClient.swift

protocol OverpassAPIProviding {
    /// Query OSM for golf features near a coordinate.
    /// Returns greens, bunkers, water hazards, fairways, tee boxes, hole ways.
    func fetchGolfFeatures(
        lat: Double,
        lon: Double,
        radiusMeters: Int
    ) async throws -> OSMGolfData

    /// Query OSM for a specific course by OSM relation/way ID.
    func fetchCourseByOSMId(_ osmId: String) async throws -> OSMGolfData?
}

struct OSMGolfData: Sendable {
    let greens: [OSMGolfFeature]      // golf=green
    let bunkers: [OSMGolfFeature]     // golf=bunker
    let water: [OSMGolfFeature]       // natural=water within golf area
    let fairways: [OSMGolfFeature]    // golf=fairway
    let tees: [OSMGolfFeature]        // golf=tee
    let holeWays: [OSMHoleWay]        // golf=hole (line of play)
}

struct OSMGolfFeature: Sendable {
    let osmId: String
    let polygon: GeoJSONPolygon       // exterior ring
    let center: CLLocationCoordinate2D
    let tags: [String: String]        // e.g., ["ref": "7"] for hole number
}

struct OSMHoleWay: Sendable {
    let osmId: String
    let holeNumber: Int?              // from ref tag
    let points: [CLLocationCoordinate2D]  // ordered tee-to-green
}
```

**Dependencies:** Models (GeoJSONPolygon).

**Overpass Query Template:**

```
[out:json][timeout:30];
(
  way["golf"="green"](around:{radius},{lat},{lon});
  way["golf"="bunker"](around:{radius},{lat},{lon});
  way["golf"="fairway"](around:{radius},{lat},{lon});
  way["golf"="tee"](around:{radius},{lat},{lon});
  way["golf"="hole"](around:{radius},{lat},{lon});
  way["natural"="water"](around:{radius},{lat},{lon});
);
out body;
>;
out skel qt;
```

---

### Module 10: GolfCourseAPIClient

**Purpose:** Queries GolfCourseAPI.com for course metadata (name, par, tees, ratings).

**Public Interface:**

```swift
// THC/Services/GolfCourseAPIClient.swift

protocol GolfCourseAPIProviding {
    /// Search courses by name.
    func searchCourses(query: String) async throws -> [GolfCourseAPIResult]

    /// Get course detail by GolfCourseAPI ID.
    func getCourse(id: Int) async throws -> GolfCourseAPIDetail?
}

struct GolfCourseAPIResult: Codable, Sendable {
    let id: Int
    let clubName: String
    let courseName: String
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct GolfCourseAPIDetail: Codable, Sendable {
    let id: Int
    let clubName: String
    let courseName: String
    let holes: Int
    let par: Int
    let tees: [GolfCourseAPITee]
    let scorecard: [GolfCourseAPIHole]
}

struct GolfCourseAPITee: Codable, Sendable {
    let teeName: String
    let courseRating: Double
    let slopeRating: Int
    let totalYardage: Int
}

struct GolfCourseAPIHole: Codable, Sendable {
    let holeNumber: Int
    let par: Int
    let yardage: Int       // for a given tee
    let handicap: Int      // stroke index
}
```

**Dependencies:** None (leaf module).

**Rate Limiting:** The free tier allows 300 requests/day. The client must track request count in `UserDefaults` with a daily reset and return cached results when the limit is approached (above 250).

**API Key:** Fetched from Supabase `app_config` table at launch, not compiled into the binary. Cached in Keychain.

---

### Module 11: LocationManager

**Purpose:** CoreLocation wrapper for continuous GPS during rounds with battery optimization.

**Public Interface:**

```swift
// THC/Features/GPS/LocationManager.swift

import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isTracking: Bool = false

    /// Start continuous GPS tracking for an active round.
    func startRoundTracking()

    /// Stop tracking (round ended or app backgrounded with no active round).
    func stopRoundTracking()

    /// Current coordinate, convenience accessor.
    var coordinate: CLLocationCoordinate2D? { get }

    /// Stream of location updates for reactive UI.
    var locationUpdates: AsyncStream<CLLocation> { get }
}
```

**Dependencies:** None (Apple framework only).

**Battery Optimization:**
- `desiredAccuracy = kCLLocationAccuracyBest` while moving (speed > 0.9 m/s ~2mph).
- `desiredAccuracy = kCLLocationAccuracyNearestTenMeters` + `distanceFilter = 10` when stationary.
- `allowsBackgroundLocationUpdates = true` during active round.
- `activityType = .fitness` for optimized GPS filtering.

---

### Module 12: RoundManager

**Purpose:** Orchestrates an active round — hole progression, auto-advance, score accumulation, live round broadcasting.

**Public Interface:**

```swift
// THC/Features/GPS/RoundManager.swift

@Observable
final class RoundManager {
    enum RoundState: Equatable {
        case notStarted
        case active(hole: Int, score: Int)   // current hole, total strokes vs par
        case finished
    }

    private(set) var state: RoundState = .notStarted
    private(set) var currentHole: Int = 1
    private(set) var courseDetail: CourseDetail?
    private(set) var holeScores: [Int: HoleScoreEntry] = [:]  // hole number -> entry

    struct HoleScoreEntry {
        var strokes: Int
        var putts: Int?
        var fairwayHit: String?
        var greenInRegulation: Bool?
    }

    init(
        courseDetail: CourseDetail,
        player: Player,
        season: Season,
        locationManager: LocationManager,
        offlineStorage: OfflineStorageProviding,
        syncService: SyncServiceProviding
    )

    /// Start the round. Begins GPS tracking and live round broadcasting.
    func startRound() async

    /// Record score for current hole and advance.
    func recordHoleScore(_ entry: HoleScoreEntry) async

    /// Manually advance to a specific hole (override auto-advance).
    func goToHole(_ number: Int)

    /// End the round. Saves to SwiftData, syncs to Supabase, stops GPS.
    func finishRound() async throws -> LocalRound

    /// Current green distances from user position.
    func currentGreenDistances() -> GreenDistances?

    /// Distances to hazards on current hole.
    func currentHazardDistances() -> [HazardInfo]

    /// Distance from user to any arbitrary coordinate (tap-for-distance).
    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> Double
}

struct HazardInfo: Sendable {
    let name: String            // "Water", "Bunker"
    let frontEdge: Double       // yards
    let carry: Double           // yards
}
```

**Dependencies:** LocationManager, CourseDataService, DistanceCalculator, OfflineStorage, SyncService, Models.

**Auto-advance Logic:**
1. After a hole score is recorded, watch for the user's location to move within 30 yards of the next hole's tee box.
2. If no tee box coordinates exist, advance when the user moves more than 50 yards from the current green.
3. Manual override always available.

**Live Round Broadcasting:**
- On `startRound()`, insert a row into `live_rounds`.
- On each `recordHoleScore()`, update the `live_rounds` row with `current_hole`, `thru_hole`, `current_score`.
- On `finishRound()`, delete the `live_rounds` row.

---

### Module 13: WatchSyncService

**Purpose:** WatchConnectivity bridge between iPhone and Apple Watch.

**Public Interface:**

```swift
// THC/Services/WatchSyncService.swift  (iPhone side)

protocol WatchSyncServiceProviding {
    /// Send course data to watch (guaranteed delivery via transferUserInfo).
    func sendCourseToWatch(_ course: CourseDetail) throws

    /// Send current round state to watch.
    func sendRoundStateToWatch(_ state: WatchRoundState) throws

    /// Receive score entries from watch.
    var watchScoreEntries: AsyncStream<WatchScoreEntry> { get }
}

struct WatchRoundState: Codable, Sendable {
    let courseName: String
    let currentHole: Int
    let par: Int
    let greenLat: Double?
    let greenLon: Double?
    let greenPolygonJSON: Data?
    let nextHazardName: String?
    let nextHazardCarry: Double?
    let holeScores: [Int: Int]   // hole -> strokes
}

struct WatchScoreEntry: Codable, Sendable {
    let holeNumber: Int
    let strokes: Int
}

// THCWatch/Services/PhoneConnectivityService.swift  (Watch side)

protocol PhoneConnectivityServiceProviding {
    /// Course data received from phone.
    var courseData: AsyncStream<WatchRoundState> { get }

    /// Send a score entry to phone.
    func sendScore(_ entry: WatchScoreEntry) throws
}
```

**Dependencies:** Models.

**Protocol Choice:**
- `transferUserInfo` for course data (queued, guaranteed, survives app termination).
- `sendMessage` for live score updates when both apps are reachable (low latency).
- `updateApplicationContext` for standings data (latest-value-wins).

---

### Module 14: StandingsViewModel

**Purpose:** Drives the leaderboard and player detail views.

**Public Interface:**

```swift
// THC/Features/Standings/StandingsViewModel.swift

@Observable
final class StandingsViewModel {
    private(set) var season: Season?
    private(set) var standings: [SeasonStanding] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    init(syncService: SyncServiceProviding)

    func load() async
    func refresh() async
    func playerRounds(playerId: UUID) async -> [Round]
}
```

**Dependencies:** SyncService.

---

### Module 15: ScoreEntryViewModel

**Purpose:** Drives both live scoring (on-course) and post-round score entry.

**Public Interface:**

```swift
// THC/Features/Scoring/ScoreEntryViewModel.swift

@Observable
final class ScoreEntryViewModel {
    // Post-round entry fields
    var playedAt: Date = .now
    var courseName: String = ""
    var par: Int = 72
    var grossScore: Int?
    var courseHandicap: Int?

    // Computed
    var netScore: Int? { get }
    var netVsPar: Int? { get }
    var points: Int? { get }

    var canSubmit: Bool { get }
    private(set) var isSubmitting: Bool = false
    private(set) var submitResult: SubmitResult?

    enum SubmitResult {
        case success(points: Int)
        case error(String)
    }

    init(
        player: Player,
        season: Season,
        offlineStorage: OfflineStorageProviding,
        syncService: SyncServiceProviding
    )

    func submitPostRound() async
}
```

**Dependencies:** PointsCalculator, OfflineStorage, SyncService, Models.

---

### Module 16: CourseSetupViewModel

**Purpose:** Course search, selection, auto-detection, and tap-and-save coordination.

**Public Interface:**

```swift
// THC/Features/CourseSetup/CourseSetupViewModel.swift

@Observable
final class CourseSetupViewModel {
    private(set) var searchResults: [CourseSearchResult] = []
    private(set) var nearbyCourses: [CourseData] = []
    private(set) var detectedCourse: CourseData?
    private(set) var selectedCourse: CourseDetail?
    private(set) var isSearching: Bool = false

    init(
        courseDataService: CourseDataServiceProviding,
        locationManager: LocationManager
    )

    func search(query: String) async
    func selectCourse(_ result: CourseSearchResult) async throws -> CourseDetail
    func detectNearbyCourse() async
    func saveGreenPin(holeNumber: Int, lat: Double, lon: Double) async throws
}
```

**Dependencies:** CourseDataService, LocationManager.

**Auto-detect Logic:**
1. On view appear, fetch `nearbyCourses` within 2km of current location.
2. If exactly one course is within 500m, set `detectedCourse` and prompt "Start round at X?"
3. If multiple courses within 500m (resort scenario), show picker.

---

### Module 17: SocialService

**Purpose:** Live round feed, reactions, and push notification registration.

**Public Interface:**

```swift
// THC/Services/SocialService.swift

protocol SocialServiceProviding {
    /// Subscribe to live rounds (Supabase Realtime).
    func liveRoundsFeed() -> AsyncStream<[LiveRound]>

    /// Post a reaction on a round.
    func reactToRound(roundId: UUID, emoji: String, comment: String?) async throws

    /// Fetch reactions for a round.
    func getReactions(roundId: UUID) async throws -> [RoundReaction]

    /// Register for push notifications (APNS token -> Supabase).
    func registerForPushNotifications(deviceToken: Data) async throws
}
```

**Dependencies:** SupabaseClient, Models.

**Supabase Tables/RLS:**
- Subscribes to `live_rounds` via Supabase Realtime (all authenticated users can see all live rounds).
- Reads/writes `round_reactions` (any authenticated user can react; reactions are readable by all).

---

### Module 18: ShareCardGenerator

**Purpose:** Renders a shareable image of a round scorecard.

**Public Interface:**

```swift
// THC/Features/Standings/ShareCardGenerator.swift

enum ShareCardGenerator {
    /// Generate a shareable scorecard image for a completed round.
    static func generateImage(
        player: Player,
        round: Round,
        holeScores: [HoleScore]?
    ) -> UIImage
}
```

**Dependencies:** Models. Uses SwiftUI `ImageRenderer`.

---

## 2. Implementation Order

### Dependency Graph

```
                    Models (M3)           PointsCalculator (M4)
                   /    |    \                    |
                  /     |     \                   |
    SupabaseClient(M1)  |   DistanceCalc(M5)     |
         |              |        |                |
    AuthManager(M2)     |        |                |
         |              |        |                |
    OfflineStorage(M6)--+        |                |
         |                       |                |
    SyncService(M7)--------------+----------------+
         |              |
    GolfCourseAPI(M10)  OverpassAPI(M9)
         |              |
    CourseDataSvc(M8)---+
         |
    LocationMgr(M11)
         |         \
    RoundMgr(M12)   CourseSetupVM(M16)
         |
    WatchSync(M13)
         |
    StandingsVM(M14)  ScoreEntryVM(M15)  SocialSvc(M17)  ShareCard(M18)
```

### Build Phases

**Phase 1 — Foundation (Weeks 1-2)**
Can be built in parallel by separate developers:

| Track A (Data Layer) | Track B (Core Logic) |
|---|---|
| M3: Models | M4: PointsCalculator |
| M1: SupabaseClient | M5: DistanceCalculator |
| M2: AuthManager | |
| M6: OfflineStorage | |

Then sequentially:
- M7: SyncService (depends on M1, M3, M4, M6)
- M14: StandingsViewModel (depends on M7)
- M15: ScoreEntryViewModel (depends on M4, M6, M7)

Deliverable: working app with login, standings view, and post-round score entry.

**Phase 2 — Course Data (Weeks 3-4)**
Can be built in parallel:

| Track A | Track B |
|---|---|
| M9: OverpassAPIClient | M10: GolfCourseAPIClient |

Then sequentially:
- M8: CourseDataService (depends on M9, M10, M1, M6)
- M16: CourseSetupViewModel (depends on M8, M11)

**Phase 3 — GPS Core (Weeks 5-8)**
Sequential:
1. M11: LocationManager
2. M12: RoundManager (depends on M5, M8, M11, M6, M7)
3. GPS views (HoleOverviewView, DistanceOverlay, HazardDistanceView, TapAndSaveView)

**Phase 4 — Apple Watch (Weeks 9-10)**
Sequential:
1. M13: WatchSyncService
2. Watch views (ActiveRoundView, HoleDistanceView, QuickScoreView, StandingsGlanceView)
3. THCComplication

**Phase 5 — Social + Polish (Weeks 11-13)**
Can be built in parallel:

| Track A | Track B |
|---|---|
| M17: SocialService | M18: ShareCardGenerator |
| LiveRoundFeedView | ShareCardView |
| Round reactions UI | BGAppRefreshTask |
| Push notifications | Shot tracking (stretch) |

### Critical Path

```
M3 -> M1 -> M6 -> M7 -> M8 -> M11 -> M12 -> M13
```

This is the longest sequential chain. Everything else branches off this spine.

---

## 3. Shared Code Strategy

### Shared/ (iOS + watchOS)

Everything in `Shared/` compiles into both targets:

| File | Rationale |
|---|---|
| `Models/*.swift` (all model structs) | Both targets decode the same Supabase data |
| `PointsCalculator.swift` | Watch needs to compute points for quick display |
| `DistanceCalculator.swift` | Watch computes distances independently when phone is away |
| `GeoJSONPolygon.swift` | Used by DistanceCalculator |
| `Constants.swift` | Supabase URL, table names, max points, etc. |

### iOS-Only

| Module | Rationale |
|---|---|
| AuthManager | Google OAuth uses ASWebAuthenticationSession (iOS only) |
| OfflineStorage (SwiftData models) | Watch uses a simpler local store; SwiftData @Model classes are iOS target |
| CourseDataService, OverpassAPIClient, GolfCourseAPIClient | Course data resolution is phone-side; watch receives via WatchConnectivity |
| RoundManager | Full round orchestration is phone-side |
| SyncService | Supabase sync is phone-side |
| All iOS views | SwiftUI views in THC/Features/ |
| WatchSyncService (iPhone side) | WatchConnectivity session delegate on iPhone |
| SocialService | Realtime subscriptions are phone-side |
| ShareCardGenerator | Uses UIImage, iOS only |
| LocationManager | Watch has its own IndependentGPSService |

### watchOS-Only

| Module | Rationale |
|---|---|
| PhoneConnectivityService | WatchConnectivity receiver on watch side |
| IndependentGPSService | Standalone CLLocationManager for when phone is not nearby |
| All watch views | SwiftUI views in THCWatch/Views/ |
| THCComplication | WidgetKit complication, watchOS target only |

### Target Membership Summary

```
Shared/
  Models/             -> iOS + watchOS
  PointsCalculator    -> iOS + watchOS
  DistanceCalculator  -> iOS + watchOS
  Constants           -> iOS + watchOS

THC/ (iOS only)
  App/
  Features/
  Services/

THCWatch/ (watchOS only)
  Views/
  Services/
  Complications/
```

---

## 4. Backend Changes

All SQL below is written for Supabase (PostgreSQL 15+). The existing schema has tables: `players`, `seasons`, `rounds`, and a view `season_standings`.

### 4.1 Modify Existing Tables

```sql
-- Allow "app" as a source value for rounds posted from the iOS app.
-- The existing column is text with no constraint, so no ALTER is needed.
-- However, add a check constraint for safety going forward:
ALTER TABLE rounds
  ADD CONSTRAINT rounds_source_check
  CHECK (source IN ('manual', 'ghin', 'app'));

-- Add net_score and net_vs_par as computed/stored columns if they don't exist.
-- Based on the web app types.ts, these columns already exist in the schema.
-- Verify with: SELECT column_name FROM information_schema.columns WHERE table_name = 'rounds';
```

### 4.2 New Tables

```sql
-- ============================================================
-- Prerequisites: enable required extensions
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- course_data: Course metadata (seeded from GolfCourseAPI)
-- ============================================================
CREATE TABLE course_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  golfcourseapi_id int UNIQUE,
  name text NOT NULL,
  club_name text,
  address text,
  lat double precision NOT NULL,
  lon double precision NOT NULL,
  hole_count int NOT NULL DEFAULT 18,
  par int NOT NULL DEFAULT 72,
  osm_id text,
  has_green_data boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_course_data_location ON course_data USING gist (
  ll_to_earth(lat, lon)
);
-- Note: requires earthdistance extension. If not available, use:
CREATE INDEX idx_course_data_lat_lon ON course_data (lat, lon);
CREATE INDEX idx_course_data_name ON course_data USING gin (name gin_trgm_ops);
-- Note: requires pg_trgm extension for fuzzy name search.

-- RLS: all authenticated users can read; all authenticated users can insert/update.
ALTER TABLE course_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read course_data"
  ON course_data FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert course_data"
  ON course_data FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update course_data"
  ON course_data FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);


-- ============================================================
-- course_holes: Per-hole data (from OSM or tap-and-save)
-- ============================================================
CREATE TABLE course_holes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES course_data(id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  par int NOT NULL CHECK (par BETWEEN 3 AND 6),
  yardage int,
  handicap int CHECK (handicap BETWEEN 1 AND 18),
  green_lat double precision,
  green_lon double precision,
  green_polygon jsonb,
  tee_lat double precision,
  tee_lon double precision,
  source text NOT NULL CHECK (source IN ('osm', 'tap_and_save')),
  saved_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, hole_number)
);

CREATE INDEX idx_course_holes_course ON course_holes (course_id);

ALTER TABLE course_holes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read course_holes"
  ON course_holes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert course_holes"
  ON course_holes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update course_holes"
  ON course_holes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete course_holes"
  ON course_holes FOR DELETE
  TO authenticated
  USING (true);


-- ============================================================
-- hole_scores: Optional per-hole stats linked to rounds
-- ============================================================
CREATE TABLE hole_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  strokes int NOT NULL CHECK (strokes BETWEEN 1 AND 20),
  putts int CHECK (putts BETWEEN 0 AND 10),
  fairway_hit text CHECK (fairway_hit IN ('hit', 'left', 'right', 'na')),
  green_in_regulation boolean,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_id, hole_number)
);

CREATE INDEX idx_hole_scores_round ON hole_scores (round_id);

ALTER TABLE hole_scores ENABLE ROW LEVEL SECURITY;

-- Players can read their own hole scores; all authenticated can read all (small group).
CREATE POLICY "Authenticated users can read hole_scores"
  ON hole_scores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert hole_scores"
  ON hole_scores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rounds r
      JOIN players p ON r.player_id = p.id
      WHERE r.id = round_id
        AND p.auth_user_id = auth.uid()::text
    )
  );


-- ============================================================
-- live_rounds: Active round state for live feed (ephemeral)
-- ============================================================
CREATE TABLE live_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  course_data_id uuid REFERENCES course_data(id),
  course_name text NOT NULL,
  current_hole int NOT NULL DEFAULT 1,
  thru_hole int NOT NULL DEFAULT 0,
  current_score int NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id)  -- one active round per player
);

ALTER TABLE live_rounds ENABLE ROW LEVEL SECURITY;

-- All authenticated can read (see your friends' live rounds).
CREATE POLICY "Authenticated users can read live_rounds"
  ON live_rounds FOR SELECT
  TO authenticated
  USING (true);

-- Only the player themselves can insert/update/delete their live round.
CREATE POLICY "Players can manage own live_rounds"
  ON live_rounds FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

-- Enable Realtime for live_rounds.
ALTER PUBLICATION supabase_realtime ADD TABLE live_rounds;


-- ============================================================
-- round_reactions: Social reactions/comments on posted rounds
-- ============================================================
CREATE TABLE round_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_id, player_id, emoji)  -- one reaction type per player per round
);

CREATE INDEX idx_round_reactions_round ON round_reactions (round_id);

ALTER TABLE round_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read round_reactions"
  ON round_reactions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Players can insert own reactions"
  ON round_reactions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

CREATE POLICY "Players can delete own reactions"
  ON round_reactions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );


-- ============================================================
-- app_config: Runtime configuration (API keys, feature flags)
-- ============================================================
CREATE TABLE app_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Seed with GolfCourseAPI key (so it's not in the app binary).
INSERT INTO app_config (key, value) VALUES
  ('golfcourseapi_key', 'YOUR_KEY_HERE');

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read app_config"
  ON app_config FOR SELECT
  TO authenticated
  USING (true);

-- Only service role can write to app_config (no client writes).


-- ============================================================
-- Cleanup function: delete stale live_rounds older than 12 hours
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_stale_live_rounds()
RETURNS void AS $$
BEGIN
  DELETE FROM live_rounds
  WHERE updated_at < now() - interval '12 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule via pg_cron (if available) or call from a Supabase Edge Function.
-- SELECT cron.schedule('cleanup-live-rounds', '0 */6 * * *', 'SELECT cleanup_stale_live_rounds()');
```

### 4.3 Extensions Required

```sql
-- For fuzzy course name search:
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- For geographic distance queries (optional, can use Haversine in app instead):
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
```

### 4.4 Trigger for updated_at

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER course_data_updated_at
  BEFORE UPDATE ON course_data
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER course_holes_updated_at
  BEFORE UPDATE ON course_holes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER live_rounds_updated_at
  BEFORE UPDATE ON live_rounds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

---

## 5. Integration Points

### 5.1 Supabase

| Module | Operation | Table(s) | Method |
|---|---|---|---|
| AuthManager | Read | `players` | `.from("players").select("*").eq("email", email).single()` |
| SyncService | Read | `seasons` | `.from("seasons").select("*").eq("is_active", true).single()` |
| SyncService | Read | `season_standings` | `.from("season_standings").select("*").eq("season_id", id)` |
| SyncService | Read | `rounds` | `.from("rounds").select("*").eq("player_id", id).eq("season_id", id)` |
| SyncService | Insert | `rounds` | `.from("rounds").insert(roundData)` with `source: "app"` |
| SyncService | Insert | `hole_scores` | `.from("hole_scores").insert(holeScoreData)` |
| CourseDataService | Read/Write | `course_data` | Search by name, nearby, or by ID |
| CourseDataService | Read/Write | `course_holes` | Fetch holes for a course, save tap-and-save pins |
| RoundManager | Insert/Update/Delete | `live_rounds` | Lifecycle of active round |
| SocialService | Subscribe | `live_rounds` | Supabase Realtime: `channel.on(.postgres_changes, ...)` |
| SocialService | Read/Write | `round_reactions` | Fetch and post reactions |
| GolfCourseAPIClient | Read | `app_config` | Fetch API key at launch |

**Supabase Swift SDK Configuration:**

```swift
let client = SupabaseClient(
    supabaseURL: URL(string: Constants.supabaseURL)!,
    supabaseKey: Constants.supabaseAnonKey,
    options: .init(
        auth: .init(
            flowType: .pkce,
            redirectURL: URL(string: "com.thc.app://auth-callback"),
            autoRefreshToken: true,
            persistSession: true
        ),
        global: .init(
            headers: ["x-client-info": "thc-ios/1.0"]
        )
    )
)
```

### 5.2 OpenStreetMap / Overpass API

| Integration | Detail |
|---|---|
| Endpoint | `https://overpass-api.de/api/interpreter` (public, no auth) |
| Method | POST with `data=` body containing the Overpass QL query |
| Response | JSON with `elements` array containing nodes, ways, relations |
| Rate Limit | No hard limit, but courtesy: max 2 concurrent requests, 10s between bursts |
| Caching | Responses cached in SwiftData. Golf course geometry changes rarely (yearly at most). Cache TTL: 30 days. |
| Error Handling | Overpass returns HTTP 429 on overuse. Back off exponentially. Fall back to cached data or tap-and-save. |

**Coordinate Extraction:**

Ways in Overpass responses reference node IDs. A second pass resolves node IDs to lat/lon from the `out skel` data. The `OverpassAPIClient` handles this resolution internally and returns `GeoJSONPolygon` objects with resolved coordinates.

### 5.3 GolfCourseAPI.com

| Integration | Detail |
|---|---|
| Base URL | `https://api.golfcourseapi.com/v1` |
| Auth | `Authorization: Key {api_key}` header |
| Search | `GET /search?name={query}` |
| Detail | `GET /courses/{id}` |
| Rate Limit | 300 requests/day (free tier) |
| Caching | Course metadata cached in SwiftData indefinitely (courses don't change). Only search results are transient. |
| Key Storage | Fetched from `app_config` table, cached in Keychain. |

### 5.4 CoreLocation

| Integration | Detail |
|---|---|
| Authorization | Request `.authorizedWhenInUse` on first launch. Request `.authorizedAlways` when starting first round (for background tracking). |
| Accuracy | `kCLLocationAccuracyBest` during active play, reduced when stationary. |
| Background | `allowsBackgroundLocationUpdates = true`, `showsBackgroundLocationIndicator = true` during active round. |
| Info.plist Keys | `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: location`. |
| watchOS | Independent `CLLocationManager` on watch when phone is not reachable. Watch requests `.authorizedWhenInUse` only. |

### 5.5 MapKit

| Integration | Detail |
|---|---|
| Map Style | Satellite imagery (`.imagery`) for hole overview — greens are visible as dark circles. |
| Overlays | `MKPolygon` for green shapes, bunkers, water hazards (from OSM data). |
| Annotations | Pin for green center, hazard labels with distances, layup markers. |
| Tap Gesture | `MKMapView` tap -> convert to coordinate -> show distance from user + option to save as green. |
| iOS 17+ | Use `Map` SwiftUI view with `MapInteractionModes` for tap handling. |

### 5.6 WatchConnectivity

| Direction | Method | Data | Rationale |
|---|---|---|---|
| Phone -> Watch | `transferUserInfo` | Course detail (holes, greens, hazards) | Guaranteed delivery, survives app termination |
| Phone -> Watch | `updateApplicationContext` | Standings data | Latest-value-wins, good for infrequent updates |
| Phone -> Watch | `sendMessage` | Live distance updates when connected | Low latency, but only when both apps are active |
| Watch -> Phone | `sendMessage` | Score entries | Low latency; fall back to `transferUserInfo` if phone unreachable |

---

## 6. Risk Mitigations

### Risk: OSM Data Gaps

**Architectural Decision:** The `CourseDataService` implements a tiered resolution strategy that never blocks the user.

1. Check SwiftData cache first (sub-millisecond).
2. Check Supabase `course_holes` for tap-and-save pins (fast).
3. Query Overpass API for OSM data (2-10s, only on first encounter).
4. If none of the above yields green coordinates, the user is immediately placed on the satellite map with tap-for-distance capability.

The `CourseDetail.dataSource` enum makes the data tier explicit so the UI can adapt (show "Tap green to save" prompt for `metadataOnly` courses, show front/back distances for `osm` courses).

### Risk: Overpass API Latency (2-10s)

**Architectural Decision:** Pre-fetch on app launch, not on arrival at the course.

- `AppDelegate.applicationDidBecomeActive` triggers `CourseDataService.prefetchNearbyCourses(radiusKm: 50)`.
- This runs in a background task (`BGAppRefreshTask` with identifier `com.thc.course-prefetch`).
- If the user selects a course manually from search, its OSM data is fetched and cached immediately.
- The `getCourseDetail` method always checks SwiftData cache before hitting the network.

### Risk: Apple Watch Battery Drain

**Architectural Decision:** The watch is a secondary display, not the primary GPS device.

- When the phone is reachable, the watch receives distances from the phone via `sendMessage` — zero GPS usage on watch.
- `IndependentGPSService` only activates when `WCSession.isReachable == false`.
- When independent GPS is active, reduce update frequency: `distanceFilter = 5` meters (about 5 yards, sufficient for golf distance display).
- Show a battery warning banner in `ActiveRoundView` when `WKInterfaceDevice.current().batteryLevel < 0.30`.

### Risk: Offline Play (No Cell Signal)

**Architectural Decision:** Local-first architecture. SwiftData is the source of truth during a round.

- All score entries write to `LocalRound` in SwiftData immediately.
- Course data is pre-cached in SwiftData before the round starts (required — the app blocks round start if no course data is cached and no network is available).
- `SyncService.syncPendingRounds()` runs: (a) when the app enters foreground, (b) on explicit pull-to-refresh, (c) via `BGAppRefreshTask`.
- The `live_rounds` table is best-effort — if offline, live round updates queue locally and post when connectivity returns. Friends simply won't see the live feed for that round.

### Risk: Auth Token Expiry Mid-Round

**Architectural Decision:** The Supabase Swift SDK handles token refresh automatically via its `autoRefreshToken` configuration. The SDK stores the refresh token in Keychain and refreshes the access token when it detects expiry. No custom code needed.

Additionally, because all scoring writes go to SwiftData first, an auth failure during a round does not lose data. The sync happens later when the token is valid.

### Risk: WatchConnectivity Message Drops

**Architectural Decision:** Use the right WatchConnectivity API for each data type.

- Course data uses `transferUserInfo` — this is queued by the OS and guaranteed to deliver, even if the watch app is not running when the transfer is initiated.
- Standings use `updateApplicationContext` — the OS delivers the latest context when the watch app activates.
- Only live distance updates use `sendMessage`, which requires both apps to be active. If the message fails (phone not reachable), the watch falls back to its own `IndependentGPSService`.
- Score entries from watch use `sendMessage` with a fallback: if `WCSession.isReachable == false`, save locally on the watch and transfer via `transferUserInfo` when reconnected.

### Risk: SwiftData Schema Migration

**Architectural Decision:** Version the schema from day one.

```swift
enum THCSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        LocalRound.self,
        LocalHoleScore.self,
        CachedCourse.self,
        CachedHole.self,
    ]
}
```

All `@Model` classes are defined within the versioned schema. When the schema changes, a new version is created with a `SchemaMigrationPlan` that maps old models to new ones. This is set up in Phase 1 even though no migrations exist yet — the cost is zero and the benefit is avoiding a painful retrofit.

### Risk: Tap-and-Save Accuracy

**Architectural Decision:** Allow any user to overwrite any green pin, and show the contributor.

- The `course_holes.saved_by` column records who set the pin.
- If a green pin looks wrong, any of the 10 users can re-tap to correct it. The `UNIQUE (course_id, hole_number)` constraint with an `ON CONFLICT DO UPDATE` upsert makes this safe.
- Satellite imagery on a 6.7" iPhone screen provides roughly 5-10 yard accuracy when tapping a green — acceptable for recreational play.
- Future improvement: allow tapping multiple points to define a rough green outline (front edge, center, back edge) instead of a single center point.

### Risk: GolfCourseAPI Rate Limit

**Architectural Decision:** Aggressive caching + request counting.

- Every GolfCourseAPI response is cached in SwiftData by `golfcourseapi_id`.
- The `GolfCourseAPIClient` tracks daily request count in `UserDefaults` with a key like `golfcourseapi_requests_2026-04-05`.
- When count exceeds 250, search results come from the local SwiftData cache only (fuzzy match on `name`).
- Course detail fetches are exempt from the soft limit (they are rare and high-value), but hard-capped at 290.

---

## Appendix A: File-to-Module Mapping

| File Path | Module | Target |
|---|---|---|
| `Shared/Models/*.swift` | M3: Models | iOS + watchOS |
| `Shared/PointsCalculator.swift` | M4: PointsCalculator | iOS + watchOS |
| `Shared/Utilities/DistanceCalculator.swift` | M5: DistanceCalculator | iOS + watchOS |
| `Shared/Constants.swift` | (shared config) | iOS + watchOS |
| `THC/Services/SupabaseClient.swift` | M1: SupabaseClient | iOS |
| `THC/Features/Auth/AuthManager.swift` | M2: AuthManager | iOS |
| `THC/Services/OfflineStorage.swift` | M6: OfflineStorage | iOS |
| `THC/Services/SyncService.swift` | M7: SyncService | iOS |
| `THC/Services/CourseDataService.swift` | M8: CourseDataService | iOS |
| `THC/Services/OverpassAPIClient.swift` | M9: OverpassAPIClient | iOS |
| `THC/Services/GolfCourseAPIClient.swift` | M10: GolfCourseAPIClient | iOS |
| `THC/Features/GPS/LocationManager.swift` | M11: LocationManager | iOS |
| `THC/Features/GPS/RoundManager.swift` | M12: RoundManager | iOS |
| `THC/Services/WatchSyncService.swift` | M13: WatchSyncService | iOS |
| `THC/Features/Standings/StandingsViewModel.swift` | M14: StandingsViewModel | iOS |
| `THC/Features/Scoring/ScoreEntryViewModel.swift` | M15: ScoreEntryViewModel | iOS |
| `THC/Features/CourseSetup/CourseSetupViewModel.swift` | M16: CourseSetupViewModel | iOS |
| `THC/Services/SocialService.swift` | M17: SocialService | iOS |
| `THC/Features/Standings/ShareCardGenerator.swift` | M18: ShareCardGenerator | iOS |
| `THCWatch/Services/PhoneConnectivityService.swift` | M13 (watch side) | watchOS |
| `THCWatch/Services/IndependentGPSService.swift` | (watch GPS) | watchOS |

## Appendix B: Test Matrix

| Module | Test File | Key Test Cases |
|---|---|---|
| M4: PointsCalculator | `PointsCalculatorTests.swift` | Even par -> 10, -6 -> 15, +10 -> 1, +15 -> 1 |
| M5: DistanceCalculator | `DistanceCalculatorTests.swift` | Haversine known pairs, front/back with polygon, center-only without polygon, on-green -> ~0, 500+ yards -> no overflow |
| M7: SyncService | `ScoreEntryTests.swift` | Net score calc, offline save, online sync, dedup |
| M8: CourseDataService | `CourseDataServiceTests.swift` | OSM course -> polygons, tap-and-save -> centers, no data -> nil, both -> prefer OSM, rate limit handling |
| M8: CourseDataService | `TapAndSaveTests.swift` | Save pin, fetch by all users, re-tap overwrites, persists in cache |
| M12: RoundManager | (integration) | Auto-advance by GPS proximity, manual hole override, finish round -> data persisted |
