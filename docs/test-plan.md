# THC iOS App — Comprehensive Test Plan
## Spec-Driven Development: Tests Written Before Implementation

**Date:** 2026-04-05
**Scope:** Native iOS + Apple Watch golf GPS app (Swift/SwiftUI/XCTest)
**Backend:** Existing Supabase instance (shared with Next.js web app)
**Source of truth for this plan:** `docs/ios-golf-gps-plan.md`

---

## Table of Contents

1. [Test Architecture](#1-test-architecture)
2. [Test Specifications by Module](#2-test-specifications-by-module)
3. [Mock Strategy](#3-mock-strategy)
4. [GPX Test File Specs](#4-gpx-test-file-specs)
5. [Test Execution Strategy](#5-test-execution-strategy)
6. [Existing Pattern Carry-Overs](#6-existing-pattern-carry-overs)

---

## 1. Test Architecture

### Layer Overview

```
THCTests/                          ← XCTest target (unit + service)
├── Unit/
│   ├── PointsCalculatorTests.swift
│   ├── DistanceCalculatorTests.swift
│   ├── ScoreEntryTests.swift
│   └── TapAndSaveTests.swift
├── Service/                       ← service layer with mocked I/O
│   ├── CourseDataServiceTests.swift
│   ├── LocationManagerTests.swift
│   ├── WatchConnectivityTests.swift
│   └── AuthManagerTests.swift
├── Integration/                   ← real Supabase staging, real HTTP
│   ├── SupabaseIntegrationTests.swift
│   └── StandingsIntegrationTests.swift
├── GPXSimulation/                 ← simulated GPS via Xcode GPX files
│   ├── TorreyPinesSouth.gpx
│   ├── LocalMuni.gpx
│   ├── StationaryOnGreen.gpx
│   └── BoundaryEdges.gpx
└── Mocks/
    ├── MockSupabaseClient.swift
    ├── MockCLLocationManager.swift
    ├── MockURLSession.swift
    └── MockWCSession.swift

THCUITests/                        ← XCUITest target (end-to-end)
├── ScoreEntryUITests.swift
├── OfflineSyncUITests.swift
└── GPSSimulationUITests.swift

ManualTestScripts/                 ← markdown checklists, not code
├── AppleWatchChecklist.md
├── OfflineRoundChecklist.md
└── ReleaseChecklist.md
```

### Layer Definitions

| Layer | Runs in CI | Uses real I/O | Execution time |
|-------|-----------|--------------|----------------|
| Unit | Yes | No | < 2s total |
| Service | Yes | No (mocked) | < 10s total |
| Integration | Yes (staging env) | Yes | < 60s total |
| GPS Simulation | Yes (Xcode simulator) | Simulated via GPX | < 5 min |
| UI/End-to-End | On-demand | Simulator only | < 10 min |
| Manual | Pre-release | Real device | ~2h |

### Naming Convention

Test methods follow `test_<condition>_<expectedOutcome>()`. Example:
```swift
func test_sixUnderPar_returns15Points()
func test_courseWithOSMData_returnsPolygonsWithSourceOSM()
```

---

## 2. Test Specifications by Module

---

### 2.1 PointsCalculator

**File:** `THCTests/Unit/PointsCalculatorTests.swift`
**Source to port:** `src/lib/points.ts` — `calculatePoints(netVsPar: number): number`
**Formula:** `max(1, min(15, 10 - netVsPar))`

#### Spec 2.1.1 — Boundary: maximum cap
- **Given:** netVsPar = -6 (6 under par)
- **When:** calculatePoints is called
- **Then:** returns 15
- **Priority:** P0

#### Spec 2.1.2 — Boundary: above maximum (ceiling holds)
- **Given:** netVsPar = -10 (10 under par)
- **When:** calculatePoints is called
- **Then:** returns 15 (not 20)
- **Priority:** P0

#### Spec 2.1.3 — Near ceiling
- **Given:** netVsPar = -3 (3 under par)
- **When:** calculatePoints is called
- **Then:** returns 13
- **Priority:** P0

#### Spec 2.1.4 — Exact baseline (even par)
- **Given:** netVsPar = 0
- **When:** calculatePoints is called
- **Then:** returns 10
- **Priority:** P0

#### Spec 2.1.5 — Positive net vs par
- **Given:** netVsPar = 5 (5 over par)
- **When:** calculatePoints is called
- **Then:** returns 5
- **Priority:** P0

#### Spec 2.1.6 — Boundary: minimum cap
- **Given:** netVsPar = 9 (9 over par)
- **When:** calculatePoints is called
- **Then:** returns 1
- **Priority:** P0

#### Spec 2.1.7 — Boundary: below minimum (floor holds)
- **Given:** netVsPar = 10 (10 over par)
- **When:** calculatePoints is called
- **Then:** returns 1 (not 0)
- **Priority:** P0

#### Spec 2.1.8 — Far below minimum (floor holds at extreme)
- **Given:** netVsPar = 15 (15 over par)
- **When:** calculatePoints is called
- **Then:** returns 1
- **Priority:** P0

#### Spec 2.1.9 — One under par
- **Given:** netVsPar = -1
- **When:** calculatePoints is called
- **Then:** returns 11
- **Priority:** P0

#### Spec 2.1.10 — One over par
- **Given:** netVsPar = 1
- **When:** calculatePoints is called
- **Then:** returns 9
- **Priority:** P0

#### Spec 2.1.11 — Table-driven exhaustive range
- **Given:** netVsPar values from -20 to +20
- **When:** calculatePoints is called for each
- **Then:** result is always in [1, 15] inclusive
- **Priority:** P0
- **Note:** Loop assertion — no result outside bounds is acceptable.

---

### 2.2 DistanceCalculator

**File:** `THCTests/Unit/DistanceCalculatorTests.swift`
**Implementation:** `ios/Shared/Utilities/DistanceCalculator.swift`
**Key functions:** `distanceInYards(from:to:)`, `greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:) -> GreenDistances`, `hazardDistances(userLocation:hazardPolygon:) -> HazardDistances`

#### Spec 2.2.1 — Haversine: known reference pair (Torrey Pines)
- **Given:** coordinate A = (32.8964, -117.2528) [tee], coordinate B = (32.8951, -117.2518) [green]
- **When:** distanceInYards is called
- **Then:** result is within ±5 yards of the ground-truth distance verified against Google Maps
- **Priority:** P0
- **Note:** Pre-calculate truth value from online Haversine tool before writing code.

#### Spec 2.2.2 — Haversine: user standing on the green
- **Given:** from and to are the same coordinate
- **When:** distanceInYards is called
- **Then:** returns 0 (or < 1 yard due to floating point)
- **Priority:** P0

#### Spec 2.2.3 — Haversine: very long distance
- **Given:** coordinate pair ~600 yards apart (typical par 5)
- **When:** distanceInYards is called
- **Then:** returns a positive number with no integer overflow or NaN
- **Priority:** P0

#### Spec 2.2.4 — Haversine: antipodal points
- **Given:** two coordinates on opposite sides of the Earth
- **When:** distanceInYards is called
- **Then:** returns approximately 21,642,547 yards (half Earth circumference), no crash
- **Priority:** P2

#### Spec 2.2.5 — Front/back of green: OSM polygon + hole way present
- **Given:** a GeoJSON polygon for hole 1 green at Torrey Pines South, a `golf=hole` way providing line of play, user at 150 yards out
- **When:** greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:) is called
- **Then:** `GreenDistances.front! < GreenDistances.center < GreenDistances.back!`; all three differ by at least 1 yard; front and back are on the approach axis
- **Priority:** P0

#### Spec 2.2.6 — Front/back of green: no hole way, fall back to user bearing
- **Given:** green polygon exists but no `golf=hole` way
- **When:** greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:) is called
- **Then:** front is the polygon edge nearest the user; back is the farthest edge along user-to-center bearing; no crash
- **Priority:** P0

#### Spec 2.2.7 — Front/back of green: tap-and-save course (no polygon)
- **Given:** green represented only as a center coordinate (no polygon)
- **When:** greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:) is called
- **Then:** `GreenDistances.front` and `GreenDistances.back` are nil; `GreenDistances.center` is valid; caller shows center distance only
- **Priority:** P0

#### Spec 2.2.8 — Hazard carry distance
- **Given:** a bunker polygon 140–155 yards from the user
- **When:** carryDistance(hazard:userPosition:) is called
- **Then:** returns ~155 yards (far edge) with ±5-yard tolerance
- **Priority:** P1

#### Spec 2.2.9 — Hazard front distance
- **Given:** same bunker polygon 140–155 yards
- **When:** frontEdgeDistance(hazard:userPosition:) is called
- **Then:** returns ~140 yards (near edge) with ±5-yard tolerance
- **Priority:** P1

#### Spec 2.2.10 — Layup target: distance along line of play
- **Given:** line-of-play vector from user to green center, target distance = 100 yards from green
- **When:** layupCoordinate(greenCenter:userPosition:targetDistanceFromGreen:) is called
- **Then:** returned coordinate is exactly 100 yards from green center along the approach vector (±1 yard)
- **Priority:** P1

#### Spec 2.2.11 — Dogleg: distance to bend
- **Given:** a hole way with 3+ points that bends 45 degrees
- **When:** doglegDistance(holeWay:userPosition:) is called
- **Then:** returns the Haversine distance from user to the bend point (not the green)
- **Priority:** P1

---

### 2.3 CourseDataService

**File:** `THCTests/Service/CourseDataServiceTests.swift`
**Implementation:** `ios/THC/Services/CourseDataService.swift`
**Dependencies mocked:** `MockURLSession` (Overpass API), `MockSupabaseClient`, `MockGolfCourseAPIClient`

#### Spec 2.3.1 — OSM path: course has OSM data
- **Given:** Overpass API mock returns a valid OSM response with green polygons and hole ways for a course
- **When:** getCourseDetail(courseId:) is called
- **Then:** returns a Course with source = .osm, non-nil green polygons on each hole, non-nil hole ways
- **Priority:** P0

#### Spec 2.3.2 — OSM path: course lacks OSM data, tap-and-save exists
- **Given:** Overpass API mock returns empty result; Supabase mock returns tap-and-save pins for the course
- **When:** getCourseDetail(courseId:) is called
- **Then:** returns a Course with source = .tapAndSave, each hole has greenCenter, nil polygon
- **Priority:** P0

#### Spec 2.3.3 — Fallback order: both OSM and tap-and-save exist, OSM preferred
- **Given:** both Overpass and Supabase return data
- **When:** getCourseDetail(courseId:) is called
- **Then:** OSM data is returned; tap-and-save data is not merged
- **Priority:** P0

#### Spec 2.3.4 — Fallback: no OSM, no tap-and-save data
- **Given:** Overpass returns empty; Supabase returns empty course_holes rows
- **When:** getCourseDetail(courseId:) is called
- **Then:** returns a Course with source = .none; triggers tap-and-save UI flow (verified via delegate callback or published property)
- **Priority:** P0

#### Spec 2.3.5 — GolfCourseAPI search returns course metadata
- **Given:** GolfCourseAPI mock returns course: "Torrey Pines South", par 72, slope 144, rating 74.6
- **When:** searchCourses(query: "Torrey") is called
- **Then:** result contains a Course with those exact metadata values
- **Priority:** P1

#### Spec 2.3.6 — GolfCourseAPI: rate limit error (HTTP 429)
- **Given:** GolfCourseAPI mock returns HTTP 429
- **When:** searchCourses is called
- **Then:** throws a CourseDataError.rateLimited; cached results from SwiftData (if any) are returned instead; no crash
- **Priority:** P1

#### Spec 2.3.7 — Overpass API: network timeout falls through to tap-and-save
- **Given:** OverpassAPIProviding mock throws URLError.timedOut; Supabase mock has tap-and-save pins
- **When:** getCourseDetail(courseId:) is called
- **Then:** OSM path fails gracefully; service falls through to tap-and-save; returns CourseDetail with source = .tapAndSave
- **Priority:** P1

#### Spec 2.3.8 — SwiftData cache hit: course already cached
- **Given:** course is in SwiftData local cache with updatedAt < 7 days ago
- **When:** getCourseDetail(courseId:) is called
- **Then:** no network call is made; cached data is returned immediately
- **Priority:** P1

#### Spec 2.3.9 — SwiftData cache miss: stale cache forces refresh
- **Given:** course is in SwiftData local cache with updatedAt >= 7 days ago
- **When:** getCourseDetail(courseId:) is called
- **Then:** a network call is made; fresh data overwrites the cache
- **Priority:** P1

#### Spec 2.3.10 — Auto-detect: user within 500m of a known course
- **Given:** user location within 500m of Torrey Pines South (from Supabase course_data)
- **When:** detectNearbyCourse(userLocation:) is called
- **Then:** returns the correct Course, triggers "looks like you're at Torrey Pines" suggestion
- **Priority:** P0

#### Spec 2.3.11 — Auto-detect: user not near any known course
- **Given:** user in the middle of the ocean
- **When:** detectNearbyCourse(userLocation:) is called
- **Then:** returns nil; no crash
- **Priority:** P1

#### Spec 2.3.12 — Auto-detect: multiple courses within 500m (resort scenario)
- **Given:** Supabase mock returns 3 courses all within 500m of user location
- **When:** nearbyCourses(lat:lon:radiusKm: 0.5) is called
- **Then:** returns all 3 courses; does not auto-select one; caller (CourseSetupViewModel) shows picker
- **Priority:** P1

---

### 2.4 ScoreEntry

**File:** `THCTests/Unit/ScoreEntryTests.swift`
**Implementation:** `ios/THC/Features/Scoring/ScoreEntryViewModel.swift`
**Dependencies mocked:** `MockSupabaseClient`, `TestModelContainer (in-memory, see §3.5)`

#### Spec 2.4.1 — Net score calculation
- **Given:** gross = 95, courseHandicap = 18
- **When:** calculateNetScore(gross:courseHandicap:) is called
- **Then:** returns 77
- **Priority:** P0

#### Spec 2.4.2 — Net vs par calculation
- **Given:** net = 77, par = 72
- **When:** calculateNetVsPar(net:par:) is called
- **Then:** returns +5
- **Priority:** P0

#### Spec 2.4.3 — Points from net vs par
- **Given:** netVsPar = +5
- **When:** calculatePoints(netVsPar:) is called (delegation to PointsCalculator)
- **Then:** returns 5
- **Priority:** P0

#### Spec 2.4.4 — Points from net vs par (even)
- **Given:** gross = 90, courseHandicap = 18, par = 72 → net 72, netVsPar 0
- **When:** full ScoreEntryViewModel flow runs
- **Then:** points = 10
- **Priority:** P0

#### Spec 2.4.5 — Offline save: round saves to SwiftData when no network
- **Given:** network unavailable (mock URLSession returns no connection error); user enters complete round data
- **When:** submitRound() is called
- **Then:** round is persisted in SwiftData with syncStatus = .pending; no error is shown to the user; Supabase insert is NOT called
- **Priority:** P0

#### Spec 2.4.6 — Sync: pending round uploads on reconnect
- **Given:** one round in SwiftData with syncStatus = .pending; network becomes available
- **When:** syncPendingRounds() is called
- **Then:** Supabase insert is called exactly once; round.syncStatus updated to .synced
- **Priority:** P0

#### Spec 2.4.7 — Deduplication: same round submitted twice online
- **Given:** round with ghin_score_id "abc123" already exists in Supabase (mock returns existing row)
- **When:** submitRound() is called with the same ghin_score_id
- **Then:** no duplicate insert; existing record is returned; no error
- **Priority:** P0

#### Spec 2.4.8 — Deduplication: local SwiftData prevents double submission
- **Given:** same round is in SwiftData with syncStatus = .synced
- **When:** syncPendingRounds() is called
- **Then:** Supabase insert is NOT called for already-synced rounds
- **Priority:** P0

#### Spec 2.4.9 — Validation: gross score required
- **Given:** user submits a round with no gross score
- **When:** submitRound() is called
- **Then:** throws ScoreEntryError.missingRequiredField(.grossScore); no persistence occurs
- **Priority:** P0

#### Spec 2.4.10 — Validation: course name required
- **Given:** user submits a round with empty course name
- **When:** submitRound() is called
- **Then:** throws ScoreEntryError.missingRequiredField(.courseName)
- **Priority:** P0

#### Spec 2.4.11 — Validation: courseHandicap must be non-negative integer
- **Given:** user enters courseHandicap = -3
- **When:** submitRound() is called
- **Then:** throws ScoreEntryError.invalidCourseHandicap
- **Priority:** P1

#### Spec 2.4.12 — Source field: app-submitted round has source = "app"
- **Given:** user submits a round via the iOS app
- **When:** round is inserted into Supabase
- **Then:** the round's source field equals "app"
- **Priority:** P0

#### Spec 2.4.13 — Per-hole stats: optional fields do not block submission
- **Given:** user enters gross score only; putts, FIR, GIR are nil
- **When:** submitRound() is called
- **Then:** round saves successfully; hole_scores rows are not created
- **Priority:** P1

#### Spec 2.4.14 — Per-hole stats: when provided, hole_scores rows are created
- **Given:** user fills in putts (2), FIR (hit), GIR (yes) for hole 1
- **When:** submitRound() is called
- **Then:** one hole_scores row is inserted for hole 1 with correct values; round also saves
- **Priority:** P1

#### Spec 2.4.15 — Nine-hole round calculation
- **Given:** gross = 45, courseHandicap = 9, par = 36
- **When:** full ScoreEntryViewModel flow runs
- **Then:** net = 36, netVsPar = 0, points = 10
- **Priority:** P1

#### Spec 2.4.16 — Sync interrupted by app background: no half-synced state
- **Given:** round is being uploaded to Supabase; OS backgrounds the app mid-upload (simulated via Task cancellation)
- **When:** app returns to foreground and syncPendingRounds() runs again
- **Then:** round is either fully synced or still pending (not half-synced); no duplicate created
- **Priority:** P0

---

### 2.5 TapAndSave

**File:** `THCTests/Unit/TapAndSaveTests.swift`
**Implementation:** `ios/THC/Features/CourseSetup/TapAndSaveView.swift` + service layer
**Dependencies mocked:** `MockSupabaseClient`, `TestModelContainer (in-memory, see §3.5)`

#### Spec 2.5.1 — Save new green pin
- **Given:** user taps at coordinate (32.8951, -117.2518) on satellite map, confirms "Save as Hole 3 green"
- **When:** saveGreenPin(coordinate:courseID:holeNumber:) is called
- **Then:** Supabase insert into course_holes with correct lat, lon, course_id, hole_number, source = "tap_and_save"; local SwiftData cache updated
- **Priority:** P0

#### Spec 2.5.2 — Fetch green pin saved by another user
- **Given:** Supabase course_holes has a pin for Hole 3 saved by user B; user A opens the same course
- **When:** fetchCourseHoles(courseID:) is called
- **Then:** returns the pin; user A sees distances to green
- **Priority:** P0

#### Spec 2.5.3 — Overwrite existing green pin
- **Given:** course_holes already has a pin for Hole 3 at (32.8951, -117.2518)
- **When:** user taps a different location and saves as Hole 3 green
- **Then:** Supabase upsert replaces the old coordinate; only one row for course+hole exists; new distance reflects updated pin
- **Priority:** P0

#### Spec 2.5.4 — Green pin persists across app restarts
- **Given:** green pin saved in both Supabase and SwiftData
- **When:** app is terminated and relaunched; network is offline
- **Then:** green pin is loaded from SwiftData; distance calculation works without network
- **Priority:** P0

#### Spec 2.5.5 — Save fails: network unavailable
- **Given:** network is unavailable when user tries to save a green pin
- **When:** saveGreenPin is called
- **Then:** pin is queued in SwiftData with syncStatus = .pending; user sees a non-blocking "will sync when online" message
- **Priority:** P1

#### Spec 2.5.6 — Tap-for-distance (no save intent)
- **Given:** user taps any coordinate on the satellite map without intending to save
- **When:** instantDistance(from:to:) is called
- **Then:** correct Haversine distance displayed; no Supabase call made
- **Priority:** P0

#### Spec 2.5.7 — First-round learning: all 18 greens saved in sequence
- **Given:** user saves a pin for holes 1–18 sequentially during a round
- **When:** all 18 calls complete
- **Then:** course_holes has exactly 18 rows for this course; has_green_data on course_data is updated to true
- **Priority:** P1

---

### 2.6 LocationManager

**File:** `THCTests/Service/LocationManagerTests.swift`
**Implementation:** `ios/THC/Features/GPS/LocationManager.swift`
**Dependencies mocked:** `MockCLLocationManager`

#### Spec 2.6.1 — Tracking starts when round begins
- **Given:** user starts a round; LocationManager is initialized
- **When:** startTracking() is called
- **Then:** CLLocationManager.startUpdatingLocation() is called with desiredAccuracy = kCLLocationAccuracyBest; allowsBackgroundLocationUpdates = true
- **Priority:** P0

#### Spec 2.6.2 — Tracking stops when round ends
- **Given:** active round; LocationManager is tracking
- **When:** stopTracking() is called
- **Then:** CLLocationManager.stopUpdatingLocation() is called; allowsBackgroundLocationUpdates = false
- **Priority:** P0

#### Spec 2.6.3 — Battery optimization: polling reduces when stationary
- **Given:** user speed < 2 mph for 30 consecutive seconds
- **When:** locationManager(_:didUpdateLocations:) fires
- **Then:** LocationManager switches to distanceFilter = 10m (stationary) from continuous; actual GPS poll rate reduces
- **Priority:** P1

#### Spec 2.6.4 — Battery optimization: polling resumes when user moves
- **Given:** user was stationary (reduced polling); user speed exceeds 2 mph
- **When:** new location update arrives
- **Then:** LocationManager reverts to continuous updates / best accuracy
- **Priority:** P1

#### Spec 2.6.5 — Auto-advance: proximity to next tee
- **Given:** current hole = 5; user is within 30m of hole 6 tee coordinate
- **When:** locationManager fires with user's new position
- **Then:** currentHole advances to 6; delegate/publisher emits holeChanged(from: 5, to: 6)
- **Priority:** P0

#### Spec 2.6.6 — Auto-advance: no false advance when on the green
- **Given:** user is standing on hole 5 green, which is adjacent to hole 6 tee area
- **When:** locationManager fires
- **Then:** currentHole does NOT advance until the hole completion signal (score entered or explicit next-hole tap)
- **Priority:** P0

#### Spec 2.6.7 — Background location: app returns to foreground with valid location
- **Given:** app is backgrounded while tracking; user walks 200 yards
- **When:** app returns to foreground
- **Then:** current location is accurate within 10m; distance to green updates immediately; no stale distance shown
- **Priority:** P0

#### Spec 2.6.8 — Permission denied: graceful degradation
- **Given:** user denies location permission
- **When:** LocationManager initializes and requestAlwaysAuthorization() is called
- **Then:** error state is published; GPS screen shows "Location access required" message; app does not crash
- **Priority:** P0

#### Spec 2.6.9 — Watch battery warning threshold
- **Given:** Apple Watch battery drops to 30%
- **When:** WKInterfaceDevice.current().batteryLevel returns 0.30
- **Then:** a low-battery warning is shown to the user; GPS continues (no automatic shutdown)
- **Priority:** P1

---

### 2.7 WatchConnectivity

**File:** `THCTests/Service/WatchConnectivityTests.swift`
**Implementation:** `ios/THC/Services/WatchSyncService.swift`
**Dependencies mocked:** `MockWCSession`

#### Spec 2.7.1 — Course data transferred to watch on round start
- **Given:** user starts a round on iPhone; watch is reachable
- **When:** WatchSyncService.sendCourseData(course:) is called
- **Then:** WCSession.transferUserInfo(_:) is called with a dictionary containing all 18 holes' green coordinates and par values
- **Priority:** P0

#### Spec 2.7.2 — transferUserInfo used (not sendMessage) for course data
- **Given:** phone and watch are connected
- **When:** course data is sent
- **Then:** WCSession.transferUserInfo is called, NOT WCSession.sendMessage; this guarantees delivery even if watch app is not in foreground
- **Priority:** P0

#### Spec 2.7.3 — Watch receives course data when not in foreground
- **Given:** watch app is in background; phone calls transferUserInfo
- **When:** watch app comes to foreground
- **Then:** WCSession delegate session(_:didReceiveUserInfo:) fires; course data is populated; distances display correctly
- **Priority:** P0

#### Spec 2.7.4 — Live update sent via sendMessage when watch is active
- **Given:** watch app is in foreground and reachable; user advances to a new hole
- **When:** WatchSyncService.sendHoleUpdate(hole:) is called
- **Then:** WCSession.sendMessage is used for low-latency delivery; watch displays updated hole info immediately
- **Priority:** P1

#### Spec 2.7.5 — Watch score syncs back to phone
- **Given:** user enters a score on the watch (Digital Crown → confirm)
- **When:** watch sends score via transferUserInfo to phone
- **Then:** phone receives the score; ScoreEntryViewModel reflects the score for that hole; SwiftData is updated
- **Priority:** P0

#### Spec 2.7.6 — Conflict resolution: same hole scored on both phone and watch
- **Given:** score entered for hole 7 on watch AND on phone before sync
- **When:** sync completes
- **Then:** last-write-wins based on timestamp; exactly one value survives; no duplicate hole_scores row
- **Priority:** P0

#### Spec 2.7.7 — Watch standalone GPS activates when phone not reachable
- **Given:** phone is out of Bluetooth range; watch GPS hardware is available
- **When:** WCSession.isReachable returns false
- **Then:** IndependentGPSService activates on watch; distances continue to display using watch GPS
- **Priority:** P0

#### Spec 2.7.8 — Course data delivered despite watch app not running at send time
- **Given:** course data is sent via transferUserInfo while watch app is not running
- **When:** user opens watch app later
- **Then:** pending transferUserInfo items are processed; course data is available
- **Priority:** P0

---

### 2.8 AuthManager

**File:** `THCTests/Service/AuthManagerTests.swift`
**Implementation:** `ios/THC/Features/Auth/AuthManager.swift`
**Dependencies mocked:** `MockSupabaseClient` with configurable token expiry

#### Spec 2.8.1 — Successful Google OAuth login
- **Given:** ASWebAuthenticationSession mock returns a valid OAuth code
- **When:** signInWithGoogle() is called
- **Then:** Supabase session is established; AuthManager.currentUser is populated; isAuthenticated = true
- **Priority:** P0

#### Spec 2.8.2 — Silent token refresh before expiry
- **Given:** Supabase access token expires in 4 minutes (simulated)
- **When:** any Supabase operation is initiated
- **Then:** Supabase SDK's auto-refresh fires; a new access token is obtained silently; the original operation completes successfully
- **Priority:** P0

#### Spec 2.8.3 — Silent token refresh during a long round (4-5 hours)
- **Given:** round started 4.5 hours ago; access token has expired
- **When:** score sync to Supabase is attempted
- **Then:** Supabase SDK refreshes the token using the refresh_token; sync succeeds without requiring the user to log in again
- **Priority:** P0

#### Spec 2.8.4 — Refresh token expired: round data is not lost
- **Given:** refresh token is also expired (edge case: user hasn't opened app in weeks); user has unsaved round data
- **When:** sync is attempted
- **Then:** round data remains in SwiftData with syncStatus = .pending; user is shown a "Please log in again" prompt; no data loss
- **Priority:** P0

#### Spec 2.8.5 — Logout clears session and local cache
- **Given:** authenticated user with cached course data and pending rounds in SwiftData
- **When:** signOut() is called
- **Then:** Supabase session is cleared; SwiftData user-specific data is purged; isAuthenticated = false; pending unsynced rounds are NOT deleted (preserved for re-login)
- **Priority:** P1

#### Spec 2.8.6 — Auth state persists across app restarts
- **Given:** user was authenticated before app termination
- **When:** app cold launches
- **Then:** Supabase session is restored from Keychain; isAuthenticated = true without user interaction
- **Priority:** P0

---

### 2.9 Standings (Leaderboard + Player Stats)

**File:** `THCTests/Service/StandingsViewModelTests.swift` (unit) + `THCTests/Integration/StandingsIntegrationTests.swift`
**Implementation:** `ios/THC/Features/Standings/StandingsViewModel.swift`

#### Spec 2.9.1 — Leaderboard fetches and sorts players by best_n_points descending
- **Given:** Supabase mock returns 4 players with best_n_points: [45, 62, 38, 50]
- **When:** StandingsViewModel.fetchLeaderboard() is called
- **Then:** players are ordered [62, 50, 45, 38]; rank = index + 1
- **Priority:** P0

#### Spec 2.9.2 — Tiebreaker: equal points, lower best net vs par wins
- **Given:** two players both have 50 best_n_points; player A has best_net_vs_par = -2, player B has +1
- **When:** leaderboard is sorted
- **Then:** player A ranks above player B
- **Priority:** P0

#### Spec 2.9.3 — Eligibility gate: ineligible players shown but ranked separately
- **Given:** season requires min_rounds = 5; one player has total_rounds = 3 (ineligible)
- **When:** leaderboard is displayed
- **Then:** ineligible player appears in list but is visually separated and their rank is marked as provisional or hidden
- **Priority:** P1

#### Spec 2.9.4 — Player stats: best 10 rounds are summed (not all rounds)
- **Given:** player has 15 rounds with points [10, 8, 12, 7, 9, 11, 6, 10, 13, 5, 9, 8, 11, 7, 10]; season top_n_rounds = 10
- **When:** best_n_points is calculated
- **Then:** result = sum of top 10 values = 10+12+11+13+10+11+10+9+9+8 — verified against web app logic
- **Priority:** P0

#### Spec 2.9.5 — Pull-to-refresh updates standings from Supabase
- **Given:** standings are cached; a new round was submitted by another user
- **When:** user pulls to refresh
- **Then:** Supabase query fires; standings update to reflect the new round; UI re-renders
- **Priority:** P1

#### Spec 2.9.6 — Offline: cached standings displayed when no network
- **Given:** standings were fetched and cached in SwiftData; network is offline
- **When:** StandingsViewModel.fetchLeaderboard() is called
- **Then:** cached data is displayed; no crash; "Last updated: X" message shown
- **Priority:** P1

#### Spec 2.9.7 — Player profile: round history sorted by played_at descending
- **Given:** player has rounds on [2026-01-15, 2026-02-20, 2026-03-01]
- **When:** player detail view loads
- **Then:** rounds appear in order: 2026-03-01, 2026-02-20, 2026-01-15
- **Priority:** P1

---

### 2.10 Models (Codable Round-Trip)

**File:** `THCTests/Unit/ModelCodingTests.swift`
**Implementation:** `Shared/Models/*.swift`

#### Spec 2.10.1 — Player decodes from Supabase JSON (all fields)
- **Given:** real Supabase JSON for a player including `handicap_updated_at`
- **When:** JSONDecoder with `.convertFromSnakeCase` decodes the data
- **Then:** all fields populated correctly; `handicapUpdatedAt` is a valid Date
- **Priority:** P0

#### Spec 2.10.2 — Round decodes with source = "app"
- **Given:** Supabase JSON for a round with `source: "app"`
- **When:** decoded to Round struct
- **Then:** `source` field equals `"app"`; no decode error
- **Priority:** P0

#### Spec 2.10.3 — CourseHole decodes with null polygon
- **Given:** Supabase JSON for a course_hole with `green_polygon: null` (tap-and-save)
- **When:** decoded to CourseHole struct
- **Then:** `greenPolygon` is nil; all other fields present
- **Priority:** P0

#### Spec 2.10.4 — GeoJSONPolygon decodes from JSONB
- **Given:** Supabase JSONB value for a green polygon with nested coordinate arrays
- **When:** decoded to GeoJSONPolygon struct
- **Then:** `type` equals `"Polygon"`; coordinates array has correct depth and values
- **Priority:** P0

#### Spec 2.10.5 — Round encodes with snake_case keys
- **Given:** a Round struct with all fields set
- **When:** encoded to JSON with `.convertToSnakeCase`
- **Then:** output JSON keys are snake_case (`played_at`, `gross_score`, etc.)
- **Priority:** P1

---

### 2.11 OfflineStorage (SwiftData)

**File:** `THCTests/Unit/OfflineStorageTests.swift`
**Implementation:** `THC/Services/OfflineStorage.swift`
**Test isolation:** In-memory `ModelContainer` (see §3.5)

#### Spec 2.11.1 — Save round persists to SwiftData
- **Given:** in-memory ModelContainer; a LocalRound with syncedToSupabase = false
- **When:** `saveRound(_:)` is called
- **Then:** round is retrievable via `unsyncedRounds()`
- **Priority:** P0

#### Spec 2.11.2 — Unsynced rounds returns only pending
- **Given:** 3 rounds: 2 with syncedToSupabase = false, 1 with true
- **When:** `unsyncedRounds()` is called
- **Then:** returns exactly 2 rounds
- **Priority:** P0

#### Spec 2.11.3 — Mark round synced updates status
- **Given:** a LocalRound with syncedToSupabase = false
- **When:** `markRoundSynced(_:)` is called with its ID
- **Then:** round's syncedToSupabase is true; `unsyncedRounds()` no longer includes it
- **Priority:** P0

#### Spec 2.11.4 — Cache course persists with holes
- **Given:** a CachedCourse with 18 CachedHoles
- **When:** `cacheCourse(_:holes:)` is called
- **Then:** `getCachedCourse(id:)` returns the course with all 18 holes
- **Priority:** P1

#### Spec 2.11.5 — Get cached course returns nil when not cached
- **Given:** empty ModelContainer
- **When:** `getCachedCourse(id: UUID())` is called
- **Then:** returns nil; no crash
- **Priority:** P1

#### Spec 2.11.6 — Schema migration v1 to v2 preserves local rounds
- **Given:** SwiftData store with v1 schema containing 3 LocalRounds
- **When:** app migrates to v2 schema
- **Then:** all 3 rounds are still present with correct data; no data loss
- **Priority:** P0

---

### 2.12 RoundManager

**File:** `THCTests/Service/RoundManagerTests.swift`
**Implementation:** `THC/Features/GPS/RoundManager.swift`
**Dependencies mocked:** `MockCLLocationManager`, `MockSupabaseClient`, in-memory `ModelContainer`

#### Spec 2.12.1 — Start round sets state to active
- **Given:** RoundManager in `.notStarted` state with a valid CourseDetail
- **When:** `startRound()` is called
- **Then:** state transitions to `.active(hole: 1, score: 0)`
- **Priority:** P0

#### Spec 2.12.2 — Start round inserts live_rounds row
- **Given:** RoundManager starts a round
- **When:** `startRound()` completes
- **Then:** MockSupabaseClient.insertCalls contains one call to `live_rounds` with correct player_id and course_name
- **Priority:** P0

#### Spec 2.12.3 — Record hole score saves to SwiftData
- **Given:** active round on hole 1
- **When:** `recordHoleScore(HoleScoreEntry(strokes: 4))` is called
- **Then:** hole 1 score is stored locally; `holeScores[1]?.strokes == 4`
- **Priority:** P0

#### Spec 2.12.4 — Running total matches sum of hole scores
- **Given:** hole scores recorded: hole 1 = 4, hole 2 = 5, hole 3 = 3 (par 4 each)
- **When:** state is inspected
- **Then:** total strokes vs par = (4-4) + (5-4) + (3-4) = 0
- **Priority:** P0

#### Spec 2.12.5 — Auto-advance: 30 yards from next tee advances hole
- **Given:** current hole = 5; mock location within 30m of hole 6 tee; score for hole 5 recorded
- **When:** location update fires
- **Then:** currentHole advances to 6
- **Priority:** P0

#### Spec 2.12.6 — Auto-advance: 50 yards from green, no tee box data
- **Given:** current hole = 5; no tee coordinate for hole 6; user is 50+ yards from hole 5 green; score recorded
- **When:** location update fires
- **Then:** currentHole advances to 6
- **Priority:** P1

#### Spec 2.12.7 — Manual go-to-hole overrides auto-advance
- **Given:** active round on hole 5
- **When:** `goToHole(8)` is called
- **Then:** currentHole = 8; no score prompt for holes 6-7
- **Priority:** P1

#### Spec 2.12.8 — Finish round saves to SwiftData and triggers sync
- **Given:** active round with 18 holes scored
- **When:** `finishRound()` is called
- **Then:** LocalRound saved to SwiftData with syncedToSupabase = false; syncPendingRounds is triggered
- **Priority:** P0

#### Spec 2.12.9 — Finish round deletes live_rounds row
- **Given:** active round with live_rounds row in Supabase
- **When:** `finishRound()` is called
- **Then:** live_rounds row is deleted (MockSupabaseClient delete call captured)
- **Priority:** P1

#### Spec 2.12.10 — Finish round from notStarted state: no crash
- **Given:** RoundManager in `.notStarted` state
- **When:** `finishRound()` is called
- **Then:** no crash; returns gracefully (no-op or throws descriptive error)
- **Priority:** P1

#### Spec 2.12.11 — Record hole score after round finished is ignored
- **Given:** RoundManager in `.finished` state
- **When:** `recordHoleScore(...)` is called
- **Then:** no crash; holeScores unchanged; no Supabase call
- **Priority:** P1

#### Spec 2.12.12 — Distance to any coordinate returns Haversine
- **Given:** active round; user at known coordinate
- **When:** `distanceTo(coordinate)` is called with a known target
- **Then:** returns correct Haversine distance in yards (±5 yards)
- **Priority:** P0

---

### 2.13 OverpassAPIClient

**File:** `THCTests/Service/OverpassAPIClientTests.swift`
**Implementation:** `THC/Services/OverpassAPIClient.swift`
**Dependencies mocked:** `MockURLSession`

#### Spec 2.13.1 — Valid Overpass response parses greens and bunkers
- **Given:** MockURLSession returns `overpass_torrey_pines_south.json`
- **When:** `fetchGolfFeatures(lat:lon:radiusMeters:)` is called
- **Then:** `OSMGolfData` has non-empty `greens` and `bunkers` arrays; each feature has a valid polygon
- **Priority:** P0

#### Spec 2.13.2 — Empty Overpass response returns empty data
- **Given:** MockURLSession returns `overpass_empty.json`
- **When:** `fetchGolfFeatures(...)` is called
- **Then:** `OSMGolfData` has all empty arrays; no error thrown
- **Priority:** P0

#### Spec 2.13.3 — Malformed Overpass JSON throws parse error
- **Given:** MockURLSession returns `overpass_malformed.json`
- **When:** `fetchGolfFeatures(...)` is called
- **Then:** throws `OverpassAPIError.parseFailed`; no crash
- **Priority:** P0

#### Spec 2.13.4 — Overpass query contains all required golf tags
- **Given:** any call to `fetchGolfFeatures`
- **When:** the URL request is captured by MockURLSession
- **Then:** the Overpass QL query body contains `golf=green`, `golf=bunker`, `golf=fairway`, `golf=tee`, `golf=hole`, `natural=water`
- **Priority:** P1

#### Spec 2.13.5 — OSM feature with no ref tag: hole number is nil
- **Given:** Overpass response contains a green way with no `ref` tag
- **When:** parsed to `OSMGolfFeature`
- **Then:** associated hole number is nil (not 0, not crash)
- **Priority:** P1

#### Spec 2.13.6 — Hole way points ordered tee to green
- **Given:** Overpass response with a `golf=hole` way
- **When:** parsed to `OSMHoleWay`
- **Then:** `points` array is ordered tee-to-green (first point nearest tee, last nearest green)
- **Priority:** P1

#### Spec 2.13.7 — Malformed polygon (fewer than 3 points) throws error
- **Given:** Overpass response with a polygon containing only 2 coordinate pairs
- **When:** parsed
- **Then:** throws a descriptive parse error; feature is skipped gracefully
- **Priority:** P0

---

### 2.14 CourseSetupViewModel

**File:** `THCTests/Service/CourseSetupViewModelTests.swift`
**Implementation:** `THC/Features/CourseSetup/CourseSetupViewModel.swift`
**Dependencies mocked:** `MockCourseDataService`, `MockCLLocationManager`

#### Spec 2.14.1 — Search delegates to CourseDataService
- **Given:** CourseSetupViewModel with a mock CourseDataService
- **When:** `search(query: "Torrey")` is called
- **Then:** mock's `searchCourses(query:)` is called exactly once with "Torrey"
- **Priority:** P1

#### Spec 2.14.2 — Detect nearby: one course within 500m sets detectedCourse
- **Given:** mock returns 1 course within 500m
- **When:** `detectNearbyCourse()` is called
- **Then:** `detectedCourse` is set to that course; no picker needed
- **Priority:** P1

#### Spec 2.14.3 — Detect nearby: multiple courses triggers picker, not auto-select
- **Given:** mock returns 3 courses within 500m (resort scenario)
- **When:** `detectNearbyCourse()` is called
- **Then:** `detectedCourse` is nil; `nearbyCourses` contains all 3; UI should show picker
- **Priority:** P1

#### Spec 2.14.4 — Save green pin delegates correctly
- **Given:** CourseSetupViewModel with selected course
- **When:** `saveGreenPin(holeNumber: 5, lat: 32.89, lon: -117.25)` is called
- **Then:** mock's `saveGreenPin(courseId:holeNumber:greenLat:greenLon:savedBy:)` is called with correct args
- **Priority:** P1

---

### 2.15 SocialService

**File:** `THCTests/Service/SocialServiceTests.swift`
**Implementation:** `THC/Services/SocialService.swift`
**Dependencies mocked:** `MockSupabaseClient`

#### Spec 2.15.1 — Live rounds feed receives realtime updates
- **Given:** MockSupabaseClient's realtime channel emits a new `live_rounds` row
- **When:** `liveRoundsFeed()` AsyncStream is consumed
- **Then:** stream yields a `LiveRound` with correct player and hole info
- **Priority:** P1

#### Spec 2.15.2 — React to round inserts reaction
- **Given:** authenticated user
- **When:** `reactToRound(roundId: X, emoji: "🔥", comment: nil)` is called
- **Then:** MockSupabaseClient.insertCalls contains one `round_reactions` insert with correct values
- **Priority:** P1

#### Spec 2.15.3 — Live round cleanup after round ends
- **Given:** active `live_rounds` row for current user
- **When:** round ends (SocialService receives cleanup signal)
- **Then:** live_rounds row is deleted
- **Priority:** P1

#### Spec 2.15.4 — Register for push notifications stores token
- **Given:** a valid APNs device token
- **When:** `registerForPushNotifications(deviceToken:)` is called
- **Then:** token is stored in Supabase; no error
- **Priority:** P1

---

### 2.16 ShareCardGenerator

**File:** `THCTests/Unit/ShareCardGeneratorTests.swift`
**Implementation:** `THC/Features/Standings/ShareCardGenerator.swift`

#### Spec 2.16.1 — Generate image returns non-nil image
- **Given:** valid Player, Round, and array of HoleScores
- **When:** `generateImage(player:round:holeScores:)` is called
- **Then:** returned UIImage is non-nil with size > 0
- **Priority:** P2

#### Spec 2.16.2 — Generate image with nil hole scores: no crash
- **Given:** valid Player and Round; holeScores is nil
- **When:** `generateImage(player:round:holeScores:)` is called
- **Then:** returned UIImage is non-nil; no crash
- **Priority:** P2

---

## 3. Mock Strategy

### 3.1 MockSupabaseClient

**Purpose:** Eliminate real network calls from unit and service tests. All Supabase operations must be testable offline.

**Implementation pattern (Swift protocol):**

```swift
// MockSupabaseClient wraps the data-layer operations used by services.
// It implements the same protocols as the production SupabaseClientProvider
// so it can be injected anywhere SupabaseClientProviding is expected.

class MockSupabaseClient: SupabaseClientProviding {
    var stubbedResponses: [String: Result<Any, Error>] = [:]
    var insertCalls: [(table: String, payload: Any)] = []
    var updateCalls: [(table: String, payload: Any)] = []
}
```

**What to stub:**
- `from("rounds").select()` → configurable player rounds array
- `from("rounds").insert()` → success or error (duplicate, network)
- `from("course_data").select()` → course list near user
- `from("course_holes").select()` → per-hole green pins
- `from("course_holes").upsert()` → tap-and-save success/failure
- `auth().session` → mock Session with configurable expiry
- `auth().refreshSession()` → success or refresh-token-expired error

**Verification:** Tests assert `insertCalls.count`, `updateCalls.count` to catch unexpected I/O.

---

### 3.2 MockCLLocationManager

**Purpose:** Inject deterministic GPS positions without hardware.

**Implementation:**

```swift
class MockCLLocationManager: CLLocationManagerProtocol {
    var locations: [CLLocation] = []
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var delegate: CLLocationManagerDelegate?

    func startUpdatingLocation() {
        for location in locations {
            delegate?.locationManager?(realManager, didUpdateLocations: [location])
        }
    }
    func stopUpdatingLocation() { /* no-op */ }
    func requestAlwaysAuthorization() { /* delegate fires with pre-set status */ }
}
```

**Usage pattern:** Load a sequence of CLLocations from test data. Call `startUpdatingLocation()` to replay them synchronously in unit tests.

**Scenarios to pre-build:**
- `approachingGreen` — coordinates stepping toward a known green
- `stationaryOnFairway` — same coordinate repeated 10 times (< 2 mph)
- `crossingHoleBoundary` — coordinates that transition from hole 5 to hole 6
- `permissionDenied` — immediately sets status to `.denied`

---

### 3.3 MockURLSession (HTTP Mocks)

**Purpose:** Test Overpass API client and GolfCourseAPI client without live HTTP.

**Implementation:**

```swift
class MockURLSession: URLSessionProtocol {
    var stubbedData: [URL: (Data, HTTPURLResponse)] = [:]
    var stubbedErrors: [URL: Error] = [:]

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = stubbedErrors[request.url!] { throw error }
        return stubbedData[request.url!]!
    }
}
```

**Pre-built fixtures (JSON files in THCTests/Fixtures/):**
- `overpass_torrey_pines_south.json` — valid Overpass response with green polygons
- `overpass_empty.json` — empty result (no OSM data for course)
- `overpass_malformed.json` — invalid JSON (tests error handling)
- `golfcourseapi_search_torrey.json` — valid search response
- `golfcourseapi_429.json` — rate limit response body

---

### 3.4 MockWCSession

**Purpose:** Test WatchConnectivity logic without physical devices.

**Implementation:**

```swift
class MockWCSession: WCSessionProtocol {
    var isReachable: Bool = true
    var isPaired: Bool = true
    var isWatchAppInstalled: Bool = true
    var transferredUserInfoItems: [[String: Any]] = []
    var sentMessages: [[String: Any]] = []

    func transferUserInfo(_ userInfo: [String: Any]) {
        transferredUserInfoItems.append(userInfo)
    }
    func sendMessage(_ message: [String: Any], replyHandler: ..., errorHandler: ...) {
        sentMessages.append(message)
    }
}
```

**Key assertion:** Tests verify that course data is always sent via `transferredUserInfoItems` (not `sentMessages`), while live hole updates are sent via `sentMessages` only when `isReachable = true`.

---

### 3.5 TestModelContainer (SwiftData Isolation)

**Purpose:** Isolate SwiftData tests from persistent storage. All OfflineStorage, ScoreEntry, and TapAndSave tests use this.

**Implementation:**

```swift
// THCTests/Mocks/TestModelContainer.swift

import SwiftData

enum TestModelContainer {
    /// Creates a fresh in-memory ModelContainer for test isolation.
    /// Each test gets its own container — no cross-test state leakage.
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LocalRound.self, LocalHoleScore.self,
                 CachedCourse.self, CachedHole.self,
            configurations: config
        )
    }
}
```

**Usage pattern:** In test setUp, call `TestModelContainer.create()` and inject it into the service under test. Each test method gets a clean slate.

---

### 3.6 AuthSessionProviding (OAuth Testability)

**Purpose:** Allow unit testing of AuthManager without presenting a real `ASWebAuthenticationSession`.

**Note:** `ASWebAuthenticationSession` cannot be mocked directly. AuthManager must accept an injectable `AuthSessionProviding` protocol:

```swift
protocol AuthSessionProviding {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

// Production: wraps ASWebAuthenticationSession
// Test: returns a pre-configured callback URL immediately
```

This is an architecture requirement, not a mock file — it must be designed into `AuthManager` from the start (M3.2).

---

### 3.7 MockBGTaskScheduler

**Purpose:** Test background refresh registration and completion without the real BGTaskScheduler.

**Note:** Extract background refresh logic into a `BackgroundRefreshService` with a `BGTaskSchedulerProviding` protocol. The mock tracks registered task identifiers and triggers completion handlers on demand.

---

### 3.8 MockWKInterfaceDevice

**Purpose:** Test watch battery monitoring without real hardware.

**Note:** Wrap `WKInterfaceDevice.current().batteryLevel` behind a `WKInterfaceDeviceProviding` protocol. The mock returns configurable battery levels for testing the 30% warning threshold (Spec 2.6.9).

---

## 4. GPX Test File Specs

GPX files are placed in `ios/THCTests/GPXSimulation/` and loaded via Xcode's scheme editor under "Run → Options → Core Location → Simulate Location → Custom GPX File".

---

### 4.1 TorreyPinesSouth.gpx

**Purpose:** Full 18-hole simulation on a well-mapped OSM course.

**What it tests:**
- Auto-detect course from GPS proximity
- Auto-advance between holes (18 transitions)
- Distance accuracy vs known yardages (each hole recorded at tee, approach, green)
- Front/back of green calculation with real OSM polygons
- Hazard carry distances (Torrey Pines has ocean-view cliffs and fairway bunkers)
- Battery-mode switching (hold near green between holes, verify polling slows)

**Coordinate spec:**

```xml
<!-- Sample structure — actual coordinates from OSM or verified GPS walk -->
<trk>
  <name>TorreyPinesSouth18Holes</name>
  <trkseg>
    <!-- Hole 1 Tee: 32.9014, -117.2533 -->
    <trkpt lat="32.9014" lon="-117.2533"><ele>33</ele><time>2026-04-05T08:00:00Z</time></trkpt>
    <!-- ...approach coordinates... -->
    <!-- Hole 1 Green center: 32.8998, -117.2520 (from OSM) -->
    <trkpt lat="32.8998" lon="-117.2520"><ele>27</ele><time>2026-04-05T08:12:00Z</time></trkpt>
    <!-- Pause at green (stationary_mode trigger): repeat coordinate 6x at 10s intervals -->
    <!-- Hole 2 Tee: ... -->
  </trkseg>
</trk>
```

**Verification points:**

| Hole | Tee Coordinate | Expected distance from tee to green (yards) | Tolerance |
|------|---------------|-------------------------------------------|-----------|
| 1 | 32.9014, -117.2533 | 452 (black tees) | ±10 yards |
| 10 | 32.8974, -117.2495 | 312 (par 4) | ±10 yards |
| 18 | 32.8951, -117.2501 | 570 (par 5) | ±10 yards |

*Full table with all 18 holes to be completed against OSM data during implementation.*

---

### 4.2 LocalMuni.gpx

**Purpose:** Simulate a course that has NO OSM data, forcing the tap-and-save flow.

**What it tests:**
- Overpass returns empty → app triggers tap-and-save UI correctly
- User taps green on satellite view per hole (mocked tap in UI test)
- Green pin saves to Supabase; SwiftData cache updates
- On second simulation run with cached pins, auto-distances appear (no tapping needed)
- Satellite imagery is shown instead of polygon overlays

**Coordinate spec:** A 9-hole fictional course layout (or use a real lightly-mapped municipal course):

```xml
<trk>
  <name>LocalMuni9Holes</name>
  <trkseg>
    <!-- Generic coordinates: 9 holes in a roughly rectangular layout -->
    <!-- Each hole: tee → 150y approach → green center -->
    <!-- Pause 90 seconds at each green to simulate green-to-next-tee walk -->
  </trkseg>
</trk>
```

**Acceptance criteria:** After the first full loop, a second GPX playback of the same course completes without any tap prompts — distances auto-display from SwiftData cache.

---

### 4.3 StationaryOnGreen.gpx

**Purpose:** Stress-test the stationary detection and no-crash edge cases.

**What it tests:**
- User stands on green for 3 minutes without advancing → no crash, no false hole advance
- Battery optimization mode engaged (< 2 mph for 30+ seconds)
- Distance display shows ~0 yards; no negative distance rendered
- Score prompt does not re-appear multiple times

**Coordinate spec:**

```xml
<trk>
  <name>StationaryOnGreen3Min</name>
  <trkseg>
    <!-- Same coordinate repeated every 5s for 3 minutes (36 points) -->
    <!-- Use actual green center of hole 7 at any well-known course -->
  </trkseg>
</trk>
```

---

### 4.4 BoundaryEdges.gpx

**Purpose:** Edge case GPS scenarios that crash or mislead real apps.

**What it tests:**
- Coordinate exactly on the green center (distance = 0)
- Coordinate 1 yard beyond the far back edge of the green (distance = small negative? must return 0)
- Very fast movement simulating a cart path (> 20 mph) — auto-advance should NOT fire mid-speed
- Coordinate outside the course boundary entirely — no erroneous hole detection
- GPS signal loss: coordinate set returns no updates for 60 seconds, then resumes

**Scenarios as separate track segments within one file:**

```xml
<trk><name>OnGreenCenter</name>...</trk>
<trk><name>BeyondGreenBack</name>...</trk>
<trk><name>CartSpeed</name>...</trk>
<trk><name>CartPathGreenToTee</name>...</trk>
<trk><name>OffCourse</name>...</trk>
<trk><name>GPSLoss</name>...</trk>
```

**CartPathGreenToTee:** Cart path at 15mph from hole 1 green to hole 2 tee in <30 seconds. Verify auto-advance fires exactly once and only after tee box proximity is sustained for >3 seconds — not during the drive-by.

**GPSLoss acceptance criterion:** During the 60-second GPS blackout, the app shows last known distance with a "Searching..." badge. Does not crash. Resumes with updated distance on reconnect. No false hole advance during blackout.

---

### 4.5 WatchStandalone.gpx

**Purpose:** 3-hole simulation for watchOS simulator to verify `IndependentGPSService`.

**What it tests:**
- Watch GPS activates when phone is not reachable
- Distances calculated correctly from watch-side GPS
- Auto-advance works on watch independently

**Coordinate spec:** 3 holes from a known course, with tee-to-green coordinates for each.

---

## 5. Test Execution Strategy

### 5.1 CI Pipeline (GitHub Actions)

```yaml
# .github/workflows/ios-tests.yml
name: iOS Tests

on:
  push:
    paths: ['ios/**']
  pull_request:
    paths: ['ios/**']

jobs:
  unit-and-service-tests:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Run unit + service tests
        run: |
          xcodebuild test \
            -project ios/THC.xcodeproj \
            -scheme THCTests \
            -testPlan UnitAndService \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            -resultBundlePath TestResults/unit.xcresult
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-results
          path: TestResults/unit.xcresult

  gps-simulation-tests:
    runs-on: macos-15
    steps:
      - name: Run GPX simulation tests
        run: |
          xcodebuild test \
            -scheme THCUITests \
            -testPlan GPXSimulation \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
```

**What runs in CI automatically:**
- All unit tests (PointsCalculator, DistanceCalculator, ScoreEntry, TapAndSave)
- All service tests with mocked I/O
- GPX simulation UI tests on iPhone simulator

**What does NOT run in CI (cost/complexity):**
- Integration tests against staging Supabase (run manually before merge, or on scheduled nightly CI)
- watchOS tests (require paired simulator setup — run locally before merge)
- Manual device tests

---

### 5.2 Pre-Merge Gates

The following must pass before any PR to `main` is merged:

| Gate | Type | Failure action |
|------|------|---------------|
| All P0 unit tests pass | Automated | Block merge |
| All service tests pass | Automated | Block merge |
| No compiler warnings in THC target | Automated | Block merge |
| GPX simulation: TorreyPinesSouth distances within ±10 yards | Automated (UI test assertion) | Block merge |
| Integration test: post round → verify in standings | Manual sign-off | Author marks complete |
| Watch: score entry syncs to phone | Manual sign-off | Author marks complete |

---

### 5.3 Manual Test Checklist (Per Release / TestFlight Build)

**Stored at:** `ios/ManualTestScripts/ReleaseChecklist.md`

#### Apple Watch Checklist (run on physical watch, not simulator)

```markdown
[ ] Pair watch to test iPhone
[ ] Open THC Watch app cold (not pre-launched)
[ ] Start a round on iPhone → verify course data appears on watch within 30 seconds
[ ] Walk 50 yards → verify distance to green updates on watch face
[ ] Enter score via Digital Crown: select 4, confirm → verify score appears on iPhone
[ ] Disconnect iPhone Bluetooth → verify watch GPS activates and distances continue
[ ] Reconnect iPhone → verify no duplicate data
[ ] Open complications: verify rank and distance display
[ ] Drain watch to 30% → verify low-battery warning appears on iPhone
```

#### Offline Round Checklist

```markdown
[ ] Enable Airplane Mode before starting round
[ ] Start round (course must be cached from previous session)
[ ] Enter scores for 9 holes
[ ] Verify all 9 holes saved in SwiftData (check via Debug menu or Xcode debugger)
[ ] Disable Airplane Mode
[ ] Wait up to 30 seconds
[ ] Verify all 9 holes appear in Supabase rounds table (check via Supabase dashboard)
[ ] Verify standings update to reflect round
[ ] Repeat with a fresh device (no cached course) → verify graceful "cache miss" message in Airplane Mode
```

#### Push Notification Checklist

```markdown
[ ] Submit a round that vaults another player to #1 in standings
[ ] Verify the displaced player receives a push notification within 60 seconds
[ ] Verify notification tap opens the standings tab
[ ] Disable push permissions → submit round → verify no crash, no hang
```

#### First-Launch Experience Checklist

```markdown
[ ] Fresh install on device with no prior data
[ ] Grant location permissions (verify "Always" is requested, not "When In Use")
[ ] Open app near a known course → verify auto-detect suggestion within 30 seconds
[ ] Open app near an unmapped course → verify tap-and-save prompt appears
[ ] Deny location permission → verify graceful error message, no crash
```

#### TestFlight Distribution Checklist

```markdown
[ ] Archive build in Xcode with release signing
[ ] Upload to App Store Connect
[ ] Verify entitlements: background location, push notifications
[ ] Invite test users via TestFlight
[ ] Install on fresh device → verify clean first-launch experience
```

#### GPS Accuracy Spot Check

```markdown
[ ] At a known tee, stand at the tee markers
[ ] Note displayed distance to green
[ ] Compare against posted yardage on tee sign (should be within 15 yards)
[ ] Walk 50 yards toward green → verify distance decreases by ~50 yards
[ ] Stand on the green → verify distance shows 0–5 yards
```

---

### 5.4 Test Plans in Xcode

Create two named test plans in Xcode (`ios/THC.xcodeproj`):

**UnitAndService.xctestplan:**
```json
{
  "testTargets": [
    {
      "target": { "name": "THCTests" },
      "selectedTests": ["Unit/", "Service/"]
    }
  ],
  "defaultOptions": {
    "codeCoverage": true,
    "targetForVariableExpansion": { "name": "THC" }
  }
}
```

**GPXSimulation.xctestplan:**
```json
{
  "testTargets": [
    {
      "target": { "name": "THCUITests" },
      "selectedTests": ["GPSSimulationUITests/"]
    }
  ],
  "defaultOptions": {
    "locationScenario": { "identifier": "Custom" }
  }
}
```

---

## 6. Existing Pattern Carry-Overs

### 6.0 Integration Test Specifications

**File:** `THCTests/Integration/SupabaseIntegrationTests.swift`

These tests run against a **staging** Supabase instance, not production. They verify RLS policies, cross-user visibility, and end-to-end data flow.

#### Integration Spec I.1 — Tap-and-save cross-user visibility
- **Given:** User A saves a green pin for Hole 3 via Supabase
- **When:** User B queries `course_holes` for the same course
- **Then:** User B sees User A's pin; RLS allows cross-user reads
- **Priority:** P0

#### Integration Spec I.2 — Post round appears in standings
- **Given:** User submits a round with source = "app" via Supabase insert
- **When:** `season_standings` view is queried
- **Then:** the new round's points are reflected in the standings
- **Priority:** P0

#### Integration Spec I.3 — Points match server calculation
- **Given:** Round with gross 85, handicap 15, par 72 → net 70, netVsPar -2, points 12
- **When:** round is inserted and standings queried
- **Then:** `best_n_points` includes 12 for this round
- **Priority:** P0

#### Integration Spec I.4 — Token refresh with real Supabase
- **Given:** Supabase session with an access token near expiry
- **When:** a data operation is attempted
- **Then:** SDK auto-refreshes; operation succeeds without re-login
- **Priority:** P0

#### Integration Spec I.5 — Realtime subscription for live_rounds
- **Given:** Supabase Realtime channel subscribed to `live_rounds`
- **When:** a row is inserted into `live_rounds`
- **Then:** subscriber receives the event within 5 seconds
- **Priority:** P1

---

### 6.1 Points Formula: TypeScript → Swift Parity

The existing TypeScript formula in `src/lib/points.ts`:

```typescript
export function calculatePoints(netVsPar: number): number {
  const points = 10 - netVsPar;
  return Math.max(1, Math.min(15, points));
}
```

The Swift port in `ios/Shared/PointsCalculator.swift` must produce byte-for-byte identical outputs for all integer inputs. The test plan in section 2.1 covers every boundary case identified in the plan document.

**Cross-language parity test:** A separate test file `PointsCalculatorParityTests.swift` should run the full -20 to +20 range and verify against a hard-coded expected-values table derived from running the TypeScript version:

```swift
let expectations: [(netVsPar: Int, points: Int)] = [
    (-20, 15), (-6, 15), (-5, 15), (-1, 11),
    (0, 10), (1, 9), (5, 5), (9, 1), (10, 1), (15, 1), (20, 1)
    // ... full table
]
```

### 6.2 Deduplication: GHIN Sync Pattern → iOS Sync Pattern

The server-side GHIN sync in `src/lib/ghin/sync.ts` already implements deduplication by checking `ghin_score_id` before insert. The iOS app's ScoreEntry sync must mirror this:
- App-submitted rounds get a locally-generated UUID stored as `ghin_score_id` equivalent
- Before sync, query Supabase for existing row with same (player_id, played_at, course_name) composite
- If found, skip insert (Spec 2.4.7 and 2.4.8)

### 6.3 Net vs Par Calculation: Replicate Server Logic

The server computes `net_vs_par` as:
```typescript
const netVsPar = score.adjusted_gross_score - courseHandicap - par;
```

The iOS app must compute identically (Spec 2.4.2). Round struct field `net_vs_par` is stored to Supabase — it must match what the GHIN sync would have computed had the round come through GHIN.

### 6.4 Source Field

The `rounds.source` field currently accepts `"manual"` and `"ghin"`. iOS adds `"app"`. Spec 2.4.12 enforces this. The web app's type definition in `src/lib/types.ts` should be updated to add `"app"` to the union type in tandem with the iOS implementation.

### 6.5 Season Logic: best_n_rounds

The standings view computes `best_n_points` by summing the top N rounds where N = `season.top_n_rounds`. This logic lives server-side (Supabase view or computed column). The iOS Standings module does NOT recompute this client-side — it reads `best_n_points` from Supabase directly. Spec 2.9.4 verifies the value matches expectation.

---

## Appendix A: P0 Test Registry

All P0 tests must pass for MVP ship. These are the non-negotiable contracts:

| ID | Module | Test Name | Failure Risk |
|----|--------|-----------|-------------|
| 2.1.1–2.1.8 | PointsCalculator | All boundary cases | Wrong points in standings |
| 2.2.1 | DistanceCalculator | Haversine reference pair | Wrong distances displayed |
| 2.2.2 | DistanceCalculator | Zero distance on green | NaN or crash |
| 2.2.3 | DistanceCalculator | Long distance 600 yards | NaN on par 5 holes |
| 2.2.5 | DistanceCalculator | Front/back green with OSM | Wrong front/back shown |
| 2.2.6 | DistanceCalculator | Front/back without hole way | Wrong fallback shown |
| 2.2.7 | DistanceCalculator | No polygon → nil | Crash on nil deref |
| 2.3.1 | CourseDataService | OSM data returned | GPS screen blank |
| 2.3.2 | CourseDataService | Tap-and-save fallback | Fallback never triggers |
| 2.3.3 | CourseDataService | OSM preferred over tap-and-save | Wrong data source |
| 2.3.4 | CourseDataService | No data → triggers tap flow | User stuck, no prompt |
| 2.3.10 | CourseDataService | Auto-detect nearby course | Course not detected |
| 2.4.1–2.4.4 | ScoreEntry | Net score, net vs par, points | Wrong scores posted |
| 2.4.5 | ScoreEntry | Offline save to SwiftData | Data loss offline |
| 2.4.6 | ScoreEntry | Sync on reconnect | Offline scores never reach Supabase |
| 2.4.7 | ScoreEntry | Dedup online | Duplicate round in standings |
| 2.4.8 | ScoreEntry | Dedup SwiftData | Double submission on sync |
| 2.4.9–2.4.10 | ScoreEntry | Required field validation | Bad data in Supabase |
| 2.4.12 | ScoreEntry | source = "app" | Source field wrong |
| 2.5.1 | TapAndSave | Save green pin | Pin not saved |
| 2.5.2 | TapAndSave | Fetch other user's pin | User sees no distances first round |
| 2.5.3 | TapAndSave | Overwrite pin | Old wrong pin persists |
| 2.5.4 | TapAndSave | Pin persists offline | Distances lost after restart |
| 2.5.6 | TapAndSave | Tap-for-distance no Supabase call | Unnecessary writes |
| 2.6.1 | LocationManager | Tracking starts | GPS never starts |
| 2.6.2 | LocationManager | Tracking stops | Battery drain after round |
| 2.6.5 | LocationManager | Auto-advance | Hole never advances |
| 2.6.6 | LocationManager | No false advance on green | Spurious advance mid-hole |
| 2.6.7 | LocationManager | Foreground resume | Stale location shown |
| 2.6.8 | LocationManager | Permission denied graceful | Crash on nil CLLocation |
| 2.7.1 | WatchConnectivity | Course data transferred | Watch shows no distances |
| 2.7.2 | WatchConnectivity | transferUserInfo not sendMessage | Data drops if watch backgrounded |
| 2.7.3 | WatchConnectivity | Watch receives data when backgrounded | Watch shows nothing on first launch |
| 2.7.5 | WatchConnectivity | Watch score syncs to phone | Watch scores lost |
| 2.7.6 | WatchConnectivity | Conflict resolution | Duplicate hole scores |
| 2.7.7 | WatchConnectivity | Standalone GPS activates | Distances stop when phone away |
| 2.8.2 | AuthManager | Silent token refresh | Round sync fails mid-round |
| 2.8.3 | AuthManager | Long round token refresh (4-5h) | Sync fails after round |
| 2.8.4 | AuthManager | Refresh expired, no data loss | User loses offline round |
| 2.8.6 | AuthManager | Auth persists across restart | Forced re-login every launch |
| 2.9.1 | Standings | Sort by best_n_points desc | Wrong leaderboard order |
| 2.9.2 | Standings | Tiebreaker | Wrong rank displayed |
| 2.9.4 | Standings | Top N rounds summed | Inflated or deflated points |
| 2.10.1 | Models | Player decodes all fields | Silent field drops corrupt data |
| 2.10.2 | Models | Round decodes source = "app" | App rounds rejected |
| 2.10.3 | Models | CourseHole null polygon = nil | Crash on tap-and-save courses |
| 2.10.4 | Models | GeoJSON polygon decodes | Green shapes missing |
| 2.11.1 | OfflineStorage | Save round persists | Offline rounds lost |
| 2.11.2 | OfflineStorage | Unsynced returns only pending | Wrong rounds re-uploaded |
| 2.11.3 | OfflineStorage | Mark synced updates status | Infinite sync loop |
| 2.11.6 | OfflineStorage | Schema migration preserves data | Data loss on app update |
| 2.12.1 | RoundManager | Start round → active state | Round never starts |
| 2.12.2 | RoundManager | Start round inserts live_rounds | Live feed blank |
| 2.12.3 | RoundManager | Record score saves locally | Scores lost mid-round |
| 2.12.4 | RoundManager | Running total correct | Wrong score displayed |
| 2.12.5 | RoundManager | Auto-advance at 30y from tee | Hole never advances |
| 2.12.8 | RoundManager | Finish round saves + syncs | Round data lost |
| 2.12.12 | RoundManager | Distance to coordinate | Wrong distance shown |
| 2.13.1 | OverpassAPIClient | Valid response parsed | OSM data never loads |
| 2.13.2 | OverpassAPIClient | Empty response → empty data | Crash on unmapped course |
| 2.13.3 | OverpassAPIClient | Malformed JSON → error | Crash on bad OSM data |
| 2.13.7 | OverpassAPIClient | Bad polygon → error | Crash on degenerate geometry |
| 2.4.16 | ScoreEntry | Sync interrupted by background | Half-synced duplicates |
| I.1 | Integration | Tap-and-save cross-user RLS | Other users never see pins |
| I.2 | Integration | Post round → standings update | Standings never reflect app rounds |
| I.3 | Integration | Points match server calculation | Standings silently wrong |
| I.4 | Integration | Token refresh with real Supabase | Mid-round auth failure |

---

## Appendix B: Coverage Targets

| Module | Target Line Coverage | Rationale |
|--------|---------------------|-----------|
| PointsCalculator | 100% | Pure function, trivial to cover |
| DistanceCalculator | 90% | Some branch paths for polygon edge cases |
| Models (Codable) | 90% | Decode correctness is critical |
| OfflineStorage | 85% | Data persistence is safety-critical |
| RoundManager | 80% | Complex orchestration, many state paths |
| CourseDataService | 80% | Many branches, focus on P0 paths |
| OverpassAPIClient | 80% | Parsing variability, error paths matter |
| ScoreEntry | 85% | Offline/sync paths are critical |
| TapAndSave | 80% | Happy path + overwrite + offline |
| LocationManager | 70% | Hardware interactions hard to cover fully |
| WatchConnectivity | 75% | Session state machine has many states |
| AuthManager | 75% | OAuth flow uses real session auth |
| StandingsViewModel | 80% | Data transformation is straightforward |
| CourseSetupViewModel | 70% | Mostly delegation, lower risk |
| SocialService | 70% | Realtime hard to cover in unit tests |
| ShareCardGenerator | 50% | Image rendering; visual correctness is manual |
