# Milestone Plan — THC iOS Golf GPS App (Atomic Tasks)

**Source spec:** `docs/ios-golf-gps-plan.md`
**Implementation plan:** `docs/implementation-plan.md`
**Test plan:** `docs/test-plan.md`
**Date:** 2026-04-05

---

## Executive Summary

14 milestones, **~130 atomic tasks**, each typed as SPEC / IMPL / WIRE / INFRA. Every IMPL references the SPEC it satisfies. No task exceeds ~4 hours.

**MVP line:** After Milestone 7 (~5 weeks). At that point: auth, standings, score entry with offline sync, course search, tap-and-save GPS, and basic hole overview with distances.

**Task types:**
- **SPEC** — Write test(s). Must compile but fail (red). No implementation.
- **IMPL** — Write minimum code to make a SPEC pass (green). No new tests.
- **WIRE** — Connect modules to UI or each other. No new logic or tests.
- **INFRA** — Project setup, CI, migrations, config.

---

## Existing Infrastructure

The Next.js web app provides:
- Supabase backend with `players`, `rounds`, `seasons` tables + RLS
- TypeScript types in `src/lib/types.ts` (`Player`, `Round`, `Season`, `SeasonStanding`)
- Points formula in `src/lib/points.ts`: `max(1, min(15, 10 - netVsPar))`
- GHIN sync with dedup pattern in `src/lib/ghin/sync.ts`
- Google OAuth configured in Supabase

---

## MVP Line

**MVP = Milestones 1–7 (~5 weeks).** User can:
1. Log in via Google OAuth
2. View standings and player profiles
3. Enter scores (post-round) with offline support
4. Start a round at any course (searched or auto-detected)
5. See distance to green center via tap-on-satellite-map
6. Save green locations for future rounds (tap-and-save)
7. View a basic hole overview with GPS distances

---

## Milestone 1: Xcode Project Scaffold

**Goal:** Empty iOS + watchOS app builds and runs, with CI.
**Effort:** 2 days | **Risk:** Low

#### M1.1: INFRA — Create Xcode project with iOS + watchOS targets
**Effort:** 2h | **Depends on:** none
**Done when:** `xcodebuild build -scheme THC -destination 'generic/platform=iOS'` succeeds

Create Xcode project at `ios/` with:
- iOS target (THC, iOS 17+)
- watchOS target (THCWatch, watchOS 10+)
- Directory structure matching `docs/ios-golf-gps-plan.md`

#### M1.2: INFRA — Create Shared framework target
**Effort:** 1h | **Depends on:** M1.1
**Done when:** Shared target builds; iOS and watchOS targets can import it

Shared/ framework for code shared between iOS and watchOS (models, PointsCalculator, DistanceCalculator, Constants).

#### M1.3: INFRA — Add supabase-swift SPM dependency
**Effort:** 1h | **Depends on:** M1.1
**Done when:** `import Supabase` compiles in iOS target

#### M1.4: INFRA — Create XCTest target with trivial test
**Effort:** 1h | **Depends on:** M1.1
**Done when:** `xcodebuild test` runs and passes 1 trivial test

Create `THCTests` target with `TrivialTests.swift`:
```swift
func test_trivial_passes() { XCTAssertTrue(true) }
```

#### M1.5: INFRA — GitHub Actions CI workflow
**Effort:** 2h | **Depends on:** M1.4
**Done when:** Push triggers CI; `xcodebuild test` passes on `macos-15` runner

#### M1.6: INFRA — .gitignore for Xcode artifacts
**Effort:** 0.5h | **Depends on:** M1.1
**Done when:** `*.xcuserdata`, `DerivedData/`, `build/` excluded from git

#### M1.7: INFRA — Secrets.plist template + setup docs
**Effort:** 0.5h | **Depends on:** M1.1
**Done when:** `ios/Secrets.plist.example` exists with placeholder keys (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); `.gitignore` excludes `Secrets.plist`

#### M1.8: INFRA — Xcode signing + Apple Developer setup
**Effort:** 1h | **Depends on:** M1.1
**Done when:** Development certificate and provisioning profiles configured; app runs on physical device

---

## Milestone 2: Data Models + Supabase Client

**Goal:** Swift models matching Supabase schema + configured client.
**Effort:** 2 days | **Risk:** Low

#### M2.1: SPEC — Model encoding/decoding round-trip tests
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `ModelCodingTests.swift` compiles, all tests fail (no models yet)

Test methods:
- `test_playerDecodesFromSupabaseJSON()`
- `test_playerDecodes_handicapUpdatedAt()`
- `test_roundDecodesFromSupabaseJSON()`
- `test_roundDecodes_sourceFieldAcceptsApp()`
- `test_seasonDecodesFromSupabaseJSON()`
- `test_seasonStandingDecodesFromSupabaseJSON()`
- `test_courseDataDecodesFromSupabaseJSON()`
- `test_courseHoleDecodesFromSupabaseJSON_nullPolygonIsNil()`
- `test_holeScoreDecodesFromSupabaseJSON()`
- `test_geoJSONPolygonDecodesFromJSONB()`
- `test_playerEncodesBackToJSON()`
- `test_roundEncodesWithSnakeCaseKeys()`

Use real Supabase JSON fixtures derived from existing tables.

#### M2.2: IMPL — Create Codable model structs (existing tables)
**Effort:** 2h | **Depends on:** M2.1
**Done when:** M2.1 tests for Player, Round, Season, SeasonStanding pass

Create in `Shared/Models/`:
- `Player.swift` — mirrors `src/lib/types.ts` Player (including `handicapUpdatedAt: Date?`)
- `Round.swift` — mirrors Round (add `"app"` to source)
- `Season.swift` — mirrors Season
- `SeasonStanding.swift` — mirrors SeasonStanding

Use `keyDecodingStrategy: .convertFromSnakeCase`.

#### M2.3: IMPL — Create Codable model structs (new tables)
**Effort:** 2h | **Depends on:** M2.1
**Done when:** M2.1 tests for CourseData, CourseHole, HoleScore pass

Create in `Shared/Models/`:
- `CourseData.swift`
- `CourseHole.swift`
- `GeoJSONPolygon.swift`
- `HoleScore.swift`
- `LiveRound.swift`
- `RoundReaction.swift`

#### M2.4: IMPL — SupabaseClient wrapper
**Effort:** 2h | **Depends on:** M1.3, M1.7
**Done when:** `SupabaseClientProvider` initializes with URL + anon key from `Secrets.plist`

Create `THC/Services/SupabaseClientProvider.swift` implementing `SupabaseClientProviding` protocol (iOS-only, not in Shared — watch uses WatchConnectivity). Load config from `Secrets.plist` (excluded from git).

#### M2.5: SPEC — SwiftData persistence round-trip tests
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `OfflineStorageTests.swift` compiles, tests fail (no SwiftData models yet)

Test methods:
- `test_saveRound_persistsToSwiftData()`
- `test_unsyncedRounds_returnsOnlyPending()`
- `test_markRoundSynced_updatesSyncStatus()`
- `test_cacheCourse_persistsWithHoles()`
- `test_getCachedCourse_returnsNilWhenNotCached()`
- `test_swiftDataMigration_v1ToV2_preservesLocalRounds()`

Use in-memory `ModelContainer` for test isolation (see test plan §3.5).

#### M2.6: IMPL — SwiftData @Model classes + OfflineStorage
**Effort:** 4h | **Depends on:** M2.5, M2.2, M2.3
**Done when:** M2.5 tests pass

Create `THC/Services/OfflineStorage.swift`:
- `LocalRound` @Model with `syncedToSupabase` flag
- `LocalHoleScore` @Model
- `CachedCourse` / `CachedHole` @Model classes
- `OfflineStorageProviding` protocol implementation
- Schema version v1 from day one

#### M2.7: INFRA — Mock infrastructure (MockSupabaseClient + MockSwiftDataContainer)
**Effort:** 2h | **Depends on:** M2.4
**Done when:** `MockSupabaseClient.swift` and in-memory ModelContainer helper compile in test target

Create `THCTests/Mocks/MockSupabaseClient.swift` per test plan §3.1.
Create `THCTests/Mocks/TestModelContainer.swift` — in-memory `ModelContainer(for:configurations: ModelConfiguration(isStoredInMemoryOnly: true))` per test plan §3.5.

---

## Milestone 3: Authentication

**Goal:** User logs in via Google OAuth and sees their player record.
**Effort:** 3 days | **Risk:** Medium

#### M3.1: SPEC — AuthManager state machine tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `AuthManagerTests.swift` compiles, tests fail

Test methods (from test plan §2.8):
- `test_successfulGoogleOAuth_setsSignedInState()`
- `test_silentTokenRefresh_beforeExpiry()`
- `test_longRoundTokenRefresh_after4Hours()`
- `test_refreshTokenExpired_roundDataNotLost()`
- `test_signOut_clearsSessionPreservesUnsynced()`
- `test_authPersistsAcrossAppRestart()`

Note: AuthManager must be designed with an injectable `AuthSessionProviding` protocol so that `ASWebAuthenticationSession` can be mocked in unit tests.

#### M3.2: IMPL — AuthManager core logic
**Effort:** 4h | **Depends on:** M3.1, M2.4
**Done when:** M3.1 tests pass (using MockSupabaseClient)

Create `THC/Features/Auth/AuthManager.swift`:
- `AuthState` enum (loading, signedOut, signedIn, notAPlayer)
- Maps `auth.users.id` → `players.auth_user_id`
- Session persistence via Supabase SDK Keychain storage
- Injectable `AuthSessionProviding` for testability

#### M3.3: INFRA — OAuth redirect URL scheme in Info.plist
**Effort:** 0.5h | **Depends on:** M1.1
**Done when:** `CFBundleURLTypes` contains `com.thc.app` scheme; matches Supabase redirect URI exactly

#### M3.4: WIRE — LoginView UI
**Effort:** 2h | **Depends on:** M3.2, M3.3
**Done when:** App shows login screen → tap "Sign in with Google" → AuthManager triggers OAuth → returns to app

Create `THC/Features/Auth/LoginView.swift` (SwiftUI).

#### M3.5: WIRE — ContentView with auth gate
**Effort:** 1h | **Depends on:** M3.4
**Done when:** Unauthenticated → LoginView. Authenticated → tab bar (placeholder tabs).

Create `THC/App/ContentView.swift` with tab-based root.

---

## Milestone 4: Standings + Player Profiles

**Goal:** Leaderboard and player detail views.
**Effort:** 3 days | **Risk:** Low

#### M4.1: SPEC — StandingsViewModel tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `StandingsViewModelTests.swift` compiles, tests fail

Test methods (from test plan §2.9):
- `test_leaderboardSortsByBestNPointsDescending()`
- `test_tiebreakerLowerNetVsParWins()`
- `test_ineligiblePlayersRankedSeparately()`
- `test_bestNRoundsSummedCorrectly()`
- `test_pullToRefreshFetchesFreshData()`
- `test_offlineCachedStandingsDisplayed()`
- `test_playerRoundsSortedByPlayedAtDescending()`

#### M4.2: IMPL — SyncService (standings fetch)
**Effort:** 2h | **Depends on:** M4.1, M2.4
**Done when:** `test_leaderboardSortsByBestNPointsDescending()` and `test_pullToRefreshFetchesFreshData()` pass

Create `THC/Services/SyncService.swift` implementing:
- `fetchStandings(seasonId:)` — queries `season_standings` view
- `fetchActiveSeason()` — queries `seasons` where `is_active = true`
- `fetchPlayerRounds(playerId:seasonId:)` — queries `rounds`

#### M4.3: IMPL — StandingsViewModel
**Effort:** 2h | **Depends on:** M4.2
**Done when:** All M4.1 tests pass

Create `THC/Features/Standings/StandingsViewModel.swift`:
- Sorts by `bestNPoints` desc, tiebreaker on `bestNetVsPar`
- Separates eligible/ineligible
- Caches to SwiftData for offline

#### M4.4: WIRE — LeaderboardView
**Effort:** 3h | **Depends on:** M4.3
**Done when:** Tab shows ranked player list with points, pull-to-refresh works

Create `THC/Features/Standings/LeaderboardView.swift`.

#### M4.5: WIRE — PlayerDetailView
**Effort:** 2h | **Depends on:** M4.3
**Done when:** Tapping a player shows profile with round history sorted by date desc, handicap index + `handicap_updated_at` displayed

Create `THC/Features/Standings/PlayerDetailView.swift`.

#### M4.6: WIRE — Wire standings tab into ContentView
**Effort:** 0.5h | **Depends on:** M4.4, M3.5
**Done when:** Standings tab shows real data from Supabase after login

---

## Milestone 5: Score Entry (Post-Round)

**Goal:** Submit rounds from app, matching web `/rounds/new`.
**Effort:** 4 days | **Risk:** Medium

#### M5.1: SPEC — PointsCalculator tests
**Effort:** 1h | **Depends on:** M1.4
**Done when:** `PointsCalculatorTests.swift` compiles, all 11 tests fail

Test methods (from test plan §2.1):
- `test_sixUnderPar_returns15()`
- `test_tenUnderPar_returnsCeiling15()`
- `test_threeUnderPar_returns13()`
- `test_evenPar_returns10()`
- `test_fiveOverPar_returns5()`
- `test_nineOverPar_returns1()`
- `test_tenOverPar_returnsFloor1()`
- `test_fifteenOverPar_returnsFloor1()`
- `test_oneUnderPar_returns11()`
- `test_oneOverPar_returns9()`
- `test_exhaustiveRange_neg20to20_allInBounds()`

#### M5.2: IMPL — PointsCalculator
**Effort:** 0.5h | **Depends on:** M5.1
**Done when:** All M5.1 tests pass

Create `Shared/PointsCalculator.swift`:
```swift
enum PointsCalculator {
    static func calculatePoints(netVsPar: Int) -> Int {
        max(1, min(15, 10 - netVsPar))
    }
}
```

#### M5.3: SPEC — ScoreEntry validation + calculation tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `ScoreEntryTests.swift` compiles, tests fail

Test methods (from test plan §2.4):
- `test_netScoreCalculation_gross95handicap18_returns77()`
- `test_netVsParCalculation_net77par72_returnsPlus5()`
- `test_pointsFromNetVsPar_plus5_returns5()`
- `test_fullFlow_gross90handicap18par72_returns10points()`
- `test_nineHoleRound_par36_calculatesCorrectly()`
- `test_validationRejectsNoGrossScore()`
- `test_validationRejectsEmptyCourseName()`
- `test_validationRejectsNegativeCourseHandicap()`
- `test_sourceFieldIsApp()`

#### M5.4: IMPL — ScoreEntryViewModel (validation + calculation)
**Effort:** 2h | **Depends on:** M5.3, M5.2
**Done when:** M5.3 tests pass

Create `THC/Features/Scoring/ScoreEntryViewModel.swift`:
- Net score = gross - courseHandicap
- Net vs par = netScore - par
- Points via PointsCalculator
- Validation for required fields

#### M5.5: SPEC — Offline save + sync tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `ScoreEntrySyncTests.swift` compiles, tests fail

Test methods:
- `test_offlineSave_roundPersistsToSwiftData()`
- `test_syncOnReconnect_uploadsToSupabase()`
- `test_syncInterrupted_byAppBackground_noHalfSyncedState()`
- `test_dedupOnline_sameRoundNotInsertedTwice()`
- `test_dedupSwiftData_syncedRoundNotResubmitted()`
- `test_perHoleStatsOptional_roundSavesWithoutThem()`
- `test_perHoleStatsProvided_holeScoreRowsCreated()`

#### M5.6: IMPL — SyncService (round submission + dedup)
**Effort:** 4h | **Depends on:** M5.5, M4.2
**Done when:** M5.5 tests pass

Extend `SyncService` with:
- `syncPendingRounds()` — uploads unsynced LocalRounds to Supabase
- Dedup check: use local round UUID as primary key, fall back to (player_id, played_at, course_name, gross_score) for GHIN rounds
- Sets `source = "app"` on all iOS-submitted rounds
- Handles background interruption gracefully (no half-synced state)

#### M5.7: INFRA — Supabase migration: add "app" source
**Effort:** 1h | **Depends on:** none
**Done when:** `rounds.source` accepts `"app"` value; existing data verified before constraint

Create `supabase/migrations/add_app_source.sql`. Include `SELECT DISTINCT source FROM rounds;` audit step before adding CHECK constraint.

#### M5.8: INFRA — Update web app types.ts with "app" source
**Effort:** 0.5h | **Depends on:** none
**Done when:** `Round.source` in `src/lib/types.ts` includes `"app"` in the union type

Update `source: "manual" | "ghin"` → `source: "manual" | "ghin" | "app"`.

#### M5.9: WIRE — PostRoundView UI
**Effort:** 3h | **Depends on:** M5.4
**Done when:** User fills form (course, par, gross, handicap, date) → sees calculated points → submit saves

Create `THC/Features/Scoring/PostRoundView.swift`.

#### M5.10: WIRE — Wire score entry tab into ContentView
**Effort:** 0.5h | **Depends on:** M5.9, M3.5
**Done when:** "New Round" tab shows post-round form; submitted round appears in standings

---

## Milestone 6: Course Search + Data Infrastructure

**Goal:** Course search, nearby detection, data service wired up.
**Effort:** 4 days | **Risk:** Medium

#### M6.1: SPEC — CourseDataService tests
**Effort:** 3h | **Depends on:** M2.7
**Done when:** `CourseDataServiceTests.swift` compiles, all tests fail

Test methods (from test plan §2.3):
- `test_courseWithOSMData_returnsPolygonsWithSourceOSM()`
- `test_courseWithTapAndSaveOnly_returnsCenterPoints()`
- `test_bothOSMAndTapAndSave_prefersOSM()`
- `test_noOSMNoTapAndSave_returnsNilTriggersFlow()`
- `test_golfCourseAPISearch_returnsCourseMetadata()`
- `test_golfCourseAPIRateLimit_returnsGracefulError()`
- `test_overpassTimeout_fallsToTapAndSave()`
- `test_swiftDataCacheHit_noNetworkCall()`
- `test_swiftDataCacheStale_forcesRefresh()`
- `test_autoDetect_within500m_returnsCourse()`
- `test_autoDetect_notNearAnyCourse_returnsNil()`
- `test_autoDetect_multipleCoursesWithin500m_returnsAll()`

#### M6.1a: SPEC — OverpassAPIClient parsing tests
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `OverpassAPIClientTests.swift` compiles, tests fail

Test methods (from test plan §2.13):
- `test_validOverpassResponse_parsesGreensAndBunkers()`
- `test_emptyOverpassResponse_returnsEmptyOSMGolfData()`
- `test_malformedOverpassJSON_throwsParseError()`
- `test_overpassQueryContainsAllRequiredGolfTags()`
- `test_osmFeatureWithNoRefTag_holeNumberIsNil()`
- `test_holeWayPoints_orderedTeeToGreen()`
- `test_malformedPolygon_fewerThan3Points_throwsError()`

#### M6.1b: SPEC — CourseSetupViewModel tests
**Effort:** 1h | **Depends on:** M2.7
**Done when:** `CourseSetupViewModelTests.swift` compiles, tests fail

Test methods (from test plan §2.14):
- `test_search_delegatesToCourseDataService()`
- `test_detectNearbyCourse_exactlyOneWithin500m_setsDetectedCourse()`
- `test_detectNearbyCourse_multipleCourses_triggersPickerNotAutoSelect()`
- `test_saveGreenPin_delegatesCorrectly()`

#### M6.2: INFRA — Mock HTTP infrastructure
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `MockURLSession.swift` compiles; can stub responses for any URL

Create `THCTests/Mocks/MockURLSession.swift` per test plan §3.3.
Create fixtures in `THCTests/Fixtures/`:
- `overpass_torrey_pines_south.json`
- `overpass_empty.json`
- `overpass_malformed.json`
- `golfcourseapi_search_torrey.json`
- `golfcourseapi_429.json`

#### M6.3: IMPL — OverpassAPIClient
**Effort:** 3h | **Depends on:** M6.1a, M6.2
**Done when:** All M6.1a tests pass

Create `THC/Services/OverpassAPIClient.swift` implementing `OverpassAPIProviding`:
- Overpass QL query for golf=green, golf=bunker, golf=hole, etc.
- Parse JSON response into `OSMGolfData`
- Defensive parsing: handle missing fields, malformed polygons

#### M6.4: IMPL — GolfCourseAPIClient
**Effort:** 2h | **Depends on:** M6.1, M6.2
**Done when:** `test_golfCourseAPISearch_returnsCourseMetadata()` and `test_golfCourseAPIRateLimit_returnsGracefulError()` pass

Create `THC/Services/GolfCourseAPIClient.swift` implementing `GolfCourseAPIProviding`:
- Search by name, fetch detail
- Rate limit tracking (300/day) in UserDefaults
- Graceful error when API key not available (first launch, fetch failed)

#### M6.5: IMPL — CourseDataService (multi-source resolution)
**Effort:** 4h | **Depends on:** M6.3, M6.4, M2.6
**Done when:** All M6.1 tests pass

Create `THC/Services/CourseDataService.swift` implementing `CourseDataServiceProviding`:
- Resolution order: SwiftData cache → Supabase tap-and-save → OSM Overpass (cache-first for performance; OSM is slow)
- Auto-detect: nearby courses within 500m (single → auto-suggest; multiple → show picker)
- Cache with 7-day TTL

#### M6.6: INFRA — Supabase migration: course tables + app_config + extensions
**Effort:** 2h | **Depends on:** none
**Done when:** `course_data`, `course_holes`, and `app_config` tables exist with RLS policies

Create `supabase/migrations/create_course_tables.sql` with:
- `CREATE EXTENSION IF NOT EXISTS pg_trgm;` and `CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;` (prerequisites)
- `course_data` table (id, name, lat, lon, par, osm_id, has_green_data, etc.)
- `course_holes` table (id, course_id, hole_number, green_lat, green_lon, green_polygon, source, etc.)
- `app_config` table (key text primary key, value text) — for GolfCourseAPI key storage
- RLS: all authenticated read, all authenticated write (trusted group)
- DELETE policy on `course_holes` for authenticated users
- Seed `app_config` with GolfCourseAPI key

#### M6.7: IMPL — CourseSetupViewModel
**Effort:** 2h | **Depends on:** M6.1b, M6.5
**Done when:** All M6.1b tests pass

Create `THC/Features/CourseSetup/CourseSetupViewModel.swift`:
- Auto-detect: one course within 500m → suggest; multiple → picker
- Search results, course selection, favorites management

#### M6.8: WIRE — CourseSearchView
**Effort:** 3h | **Depends on:** M6.7
**Done when:** User searches "Torrey Pines" → sees results → taps to select → course detail loads

Create `THC/Features/CourseSetup/CourseSearchView.swift` including:
- Search bar + results list
- Nearby courses section
- Favorites section (pin/unpin stored in SwiftData)
- Multi-course picker when multiple within 500m

---

## Milestone 7: GPS Core + Tap-and-Save + Basic Hole View

**Goal:** MVP GPS experience. This completes the MVP.
**Effort:** 5 days | **Risk:** High

#### M7.1: SPEC — DistanceCalculator tests (Haversine)
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `DistanceCalculatorTests.swift` compiles, tests fail

Test methods (from test plan §2.2):
- `test_haversine_torreyPinesReferencePair_withinTolerance()`
- `test_haversine_sameCoordinate_returnsZero()`
- `test_haversine_longDistance600yards_noOverflow()`
- `test_haversine_antipodalPoints_noNaN()`
- `test_haversine_latOutOfRange_nocrash()`
- `test_greenDistances_nanCoordinate_doesNotReturnNaN()`

#### M7.2: IMPL — DistanceCalculator (Haversine)
**Effort:** 2h | **Depends on:** M7.1
**Done when:** M7.1 Haversine tests pass

Create `Shared/Utilities/DistanceCalculator.swift`:
- `distanceInYards(from:to:)` using Haversine formula
- `distanceInMeters(from:to:)` convenience
- Guard against invalid coordinate inputs (NaN, out-of-range)

#### M7.3: SPEC — DistanceCalculator tests (front/back green)
**Effort:** 2h | **Depends on:** M7.2
**Done when:** Tests compile and fail

Test methods:
- `test_frontBackGreen_withPolygonAndHoleWay_frontLessThanBack()`
- `test_frontBackGreen_noHoleWay_fallbackToUserBearing()`
- `test_frontBackGreen_noPolygon_returnsNilFrontBack()`

#### M7.4: IMPL — DistanceCalculator (front/back green + hazards)
**Effort:** 4h | **Depends on:** M7.3
**Done when:** M7.3 tests pass

Extend `DistanceCalculator` with:
- `greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:)` → `GreenDistances`
- `hazardDistances(userLocation:hazardPolygon:)` → `HazardDistances`
- `layupPoint(from:toward:yardsFromTarget:)` → coordinate

#### M7.5: SPEC — TapAndSave tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `TapAndSaveTests.swift` compiles, tests fail

Test methods (from test plan §2.5):
- `test_saveNewGreenPin_insertsToSupabase()`
- `test_fetchGreenPin_savedByAnotherUser()`
- `test_overwriteExistingGreenPin_replacesOld()`
- `test_greenPinPersistsAcrossRestart()`
- `test_saveFailsOffline_queuesInSwiftData()`
- `test_tapForDistance_noSupabaseCall()`
- `test_allEighteenGreensSaved_updatesHasGreenData()`

#### M7.6: IMPL — TapAndSave service logic
**Effort:** 3h | **Depends on:** M7.5, M6.5
**Done when:** M7.5 tests pass

Implement in `CourseDataService`:
- `saveGreenPin(courseId:holeNumber:greenLat:greenLon:savedBy:)` — upsert to Supabase + SwiftData
- Update `has_green_data` on `course_data` when all holes have pins

#### M7.7: SPEC — LocationManager tests
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `LocationManagerTests.swift` compiles, tests fail

Test methods (from test plan §2.6):
- `test_trackingStartsWithBestAccuracy()`
- `test_trackingStopsOnRoundEnd()`
- `test_stationaryReducesPolling()`
- `test_movementResumesPolling()`
- `test_autoAdvance_nearNextTee()`
- `test_noFalseAdvance_onGreenNearNextTee()`
- `test_foregroundResume_validLocation()`
- `test_permissionDenied_gracefulDegradation()`

Create `THCTests/Mocks/MockCLLocationManager.swift` per test plan §3.2.

#### M7.8: IMPL — LocationManager
**Effort:** 4h | **Depends on:** M7.7
**Done when:** M7.7 tests pass (using MockCLLocationManager)

Create `THC/Features/GPS/LocationManager.swift`:
- CoreLocation wrapper with `startRoundTracking()` / `stopRoundTracking()`
- Battery optimization: reduce polling when speed < 2mph
- Background location updates during active round
- `locationUpdates` AsyncStream

#### M7.8a: SPEC — RoundManager state machine tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `RoundManagerTests.swift` compiles, tests fail

Test methods (from test plan §2.12):
- `test_startRound_setsStateToActive()`
- `test_startRound_insertsLiveRoundToSupabase()`
- `test_recordHoleScore_savesToSwiftData()`
- `test_runningTotal_matchesSumOfHoleScores()`
- `test_autoAdvance_30yardsFromNextTee_advances()`
- `test_autoAdvance_50yardsFromGreen_noTeeBox_advances()`
- `test_manualGoToHole_overridesAutoAdvance()`
- `test_finishRound_savesToSwiftDataAndSyncs()`
- `test_finishRound_deletesLiveRoundRow()`
- `test_finishRound_fromNotStartedState_nocrash()`
- `test_recordHoleScore_afterRoundFinished_isIgnored()`
- `test_distanceTo_anyCoordinate_returnsHaversine()`

#### M7.9: IMPL — RoundManager (orchestrator)
**Effort:** 4h | **Depends on:** M7.8a, M7.8, M7.4, M6.5, M2.6
**Done when:** All M7.8a tests pass

Create `THC/Features/GPS/RoundManager.swift`:
- State machine: notStarted → active → finished
- Auto-advance logic (30m from next tee, or 50m from current green)
- Distance calculations delegated to DistanceCalculator
- Score accumulation per hole
- Offline save via OfflineStorage
- Live round broadcasting to `live_rounds`

#### M7.10: INFRA — Info.plist location permissions + background modes
**Effort:** 0.5h | **Depends on:** M1.1
**Done when:** `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `UIBackgroundModes: location` are in Info.plist

#### M7.11: WIRE — HoleOverviewView (primary GPS screen)
**Effort:** 4h | **Depends on:** M7.9, M7.10
**Done when:** Satellite MapKit view shows user position, current hole, distance to green center

Create `THC/Features/GPS/HoleOverviewView.swift`:
- Top-down satellite view centered on current hole
- User location pin
- Green distance callout (center, front/back if available)
- Par and hole number display

#### M7.12: WIRE — TapAndSaveView (tap green on map)
**Effort:** 3h | **Depends on:** M7.6, M7.11
**Done when:** Tap green on satellite → "Save as Hole X?" → saves → distance appears

Create `THC/Features/CourseSetup/TapAndSaveView.swift`.

#### M7.13: WIRE — Tap-for-distance on map
**Effort:** 2h | **Depends on:** M7.11
**Done when:** Tap any point on satellite map → shows distance in yards from current position

#### M7.14: INFRA — GPX simulation files (all 4)
**Effort:** 4h | **Depends on:** none
**Done when:** All 4 GPX files load in Xcode simulator

Create `ios/THCTests/GPXSimulation/`:
- `TorreyPinesSouth.gpx` — 18 holes with real coordinates, verification table for 5+ representative holes
- `LocalMuni.gpx` — 9-hole course (no OSM data, tests tap-and-save flow)
- `StationaryOnGreen.gpx` — Same coordinate repeated for 3 min (stationary detection, zero-distance edge case)
- `BoundaryEdges.gpx` — 5 edge case segments: on green center, beyond green back, cart speed (15mph), off course, GPS loss (60s blackout then resume)

GPS blackout acceptance criterion: app shows last known distance with a "Searching..." badge; does not crash; resumes on reconnect.

#### M7.15: WIRE — Round start flow (course select → GPS → hole view)
**Effort:** 2h | **Depends on:** M7.11, M6.8
**Done when:** Select course → start round → GPS activates → hole overview shows

Connect CourseSearchView → RoundManager → HoleOverviewView flow.

**MVP ships to TestFlight here.**

---

## Milestone 8: Social Schema (Backend)

**Goal:** Backend tables ready for social features + live rounds.
**Effort:** 2 days | **Risk:** Low

#### M8.1: INFRA — Supabase migration: hole_scores table
**Effort:** 1h | **Depends on:** none
**Done when:** `hole_scores` table exists with FK to `rounds`, RLS active

#### M8.2: INFRA — Supabase migration: round_reactions table
**Effort:** 1h | **Depends on:** none
**Done when:** `round_reactions` table exists with FK to `rounds` and `players`

#### M8.3: INFRA — Supabase migration: live_rounds table + Realtime
**Effort:** 1h | **Depends on:** none
**Done when:** `live_rounds` table exists; Realtime enabled via `ALTER PUBLICATION supabase_realtime ADD TABLE live_rounds;`

#### M8.4: INFRA — RLS policies for social tables
**Effort:** 1h | **Depends on:** M8.1, M8.2, M8.3
**Done when:** Authenticated users can read all; can only write own data

#### M8.5: INFRA — live_rounds cleanup (stale row removal)
**Effort:** 1h | **Depends on:** M8.3
**Done when:** Scheduled cleanup function exists (pg_cron on Pro plan, or Supabase Edge Function on Free plan) to delete `live_rounds` rows older than 12 hours

---

## Milestone 9: Live Scoring (On-Course)

**Goal:** Per-hole score entry during round with auto-advance.
**Effort:** 3 days | **Risk:** Medium

#### M9.1: SPEC — Live scoring tests
**Effort:** 2h | **Depends on:** M7.8a
**Done when:** `LiveScoringTests.swift` compiles, tests fail

Test methods:
- `test_autoAdvanceTriggers_atCorrectProximity()`
- `test_scoreRecorded_persistsToSwiftData()`
- `test_runningTotal_matchesSumOfHoleScores()`
- `test_optionalStats_putsFIRGIR_savedWhenProvided()`
- `test_optionalStats_nilWhenNotProvided()`

#### M9.2: IMPL — RoundManager extensions (live scoring)
**Effort:** 3h | **Depends on:** M9.1, M7.9
**Done when:** M9.1 tests pass

Extend RoundManager:
- `recordHoleScore(_ entry:)` — saves to SwiftData, advances hole
- Live round broadcasting to `live_rounds` table
- Running scorecard accumulation

#### M9.3: WIRE — LiveScoringView
**Effort:** 3h | **Depends on:** M9.2
**Done when:** After hole, score prompt appears; strokes required, putts/FIR/GIR optional

Create `THC/Features/Scoring/LiveScoringView.swift`.

#### M9.4: WIRE — HoleStatsView (optional per-hole stats)
**Effort:** 2h | **Depends on:** M9.3
**Done when:** Putts picker, FIR toggle (hit/left/right/NA), GIR toggle work

Create `THC/Features/Scoring/HoleStatsView.swift`.

#### M9.5: WIRE — Running scorecard view
**Effort:** 2h | **Depends on:** M9.2
**Done when:** Swipe during round shows scorecard with all holes scored so far

---

## Milestone 10: Full Hole Overview (OSM Overlays + Hazards)

**Goal:** Full GPS experience for OSM-mapped courses.
**Effort:** 4 days | **Risk:** High

#### M10.1: SPEC — Hazard distance tests
**Effort:** 2h | **Depends on:** M7.2
**Done when:** `HazardDistanceTests.swift` compiles, tests fail

Test methods (from test plan §2.2.8–2.2.11):
- `test_hazardCarryDistance_farEdge_withinTolerance()`
- `test_hazardFrontDistance_nearEdge_withinTolerance()`
- `test_layupTarget_100yardsFromGreen_correctCoordinate()`
- `test_doglegDistance_toBendPoint_correct()`

#### M10.2: IMPL — Hazard + layup + dogleg calculations
**Effort:** 3h | **Depends on:** M10.1, M7.4
**Done when:** M10.1 tests pass

Extend DistanceCalculator with hazard carry/front, layup point, dogleg distance.

#### M10.3: WIRE — Green polygon overlay on MapKit
**Effort:** 3h | **Depends on:** M7.11, M6.3
**Done when:** OSM green polygon renders on satellite map; front/center/back distances display

#### M10.4: WIRE — Hazard polygon overlays
**Effort:** 3h | **Depends on:** M10.2, M7.11
**Done when:** Bunkers and water hazards render on map; carry and front edge distances display

Create `THC/Features/GPS/HazardDistanceView.swift`.

#### M10.5: WIRE — DistanceOverlay (all distance callouts)
**Effort:** 2h | **Depends on:** M10.3, M10.4
**Done when:** Hole overview shows green distances, hazard distances, layup target, dogleg distance

Create `THC/Features/GPS/DistanceOverlay.swift`.

#### M10.6: WIRE — Graceful degradation for non-OSM courses
**Effort:** 1h | **Depends on:** M10.5
**Done when:** Tap-and-save course shows center distance only; no polygon overlays; no crash

---

## Milestone 11: Apple Watch — Core

**Goal:** watchOS app shows distances during a round, synced from phone.
**Effort:** 4 days | **Risk:** High

#### M11.1: SPEC — WatchConnectivity tests
**Effort:** 2h | **Depends on:** M1.4
**Done when:** `WatchConnectivityTests.swift` compiles, tests fail

Test methods (from test plan §2.7):
- `test_courseDataTransferredOnRoundStart()`
- `test_transferUserInfoUsed_notSendMessage()`
- `test_watchReceivesCourseData_whenBackgrounded()`
- `test_liveUpdateViaSendMessage_whenReachable()`
- `test_watchScoreSyncsToPhone()`
- `test_conflictResolution_lastWriteWins()`
- `test_standaloneGPSActivates_whenPhoneUnreachable()`
- `test_courseDataDelivered_despiteWatchAppNotRunning()`

Create `THCTests/Mocks/MockWCSession.swift` per test plan §3.4.

#### M11.2: IMPL — WatchSyncService (iPhone side)
**Effort:** 3h | **Depends on:** M11.1
**Done when:** `test_courseDataTransferredOnRoundStart()`, `test_transferUserInfoUsed_notSendMessage()` pass

Create `THC/Services/WatchSyncService.swift`:
- `sendCourseToWatch(_:)` via `transferUserInfo`
- `sendRoundStateToWatch(_:)` via `sendMessage` when reachable
- `watchScoreEntries` AsyncStream from delegate callbacks

#### M11.3: IMPL — PhoneConnectivityService (Watch side)
**Effort:** 2h | **Depends on:** M11.1
**Done when:** Watch-side receive tests pass

Create `THCWatch/Services/PhoneConnectivityService.swift`:
- Receives `transferUserInfo` → parses `WatchRoundState`
- Sends score entries back via `transferUserInfo`

#### M11.4: WIRE — THCWatchApp entry point
**Effort:** 1h | **Depends on:** M1.1
**Done when:** Watch app launches on simulator

Create `THCWatch/THCWatchApp.swift`.

#### M11.5: WIRE — ActiveRoundView (watch)
**Effort:** 3h | **Depends on:** M11.3
**Done when:** Watch displays front/center/back distances for current hole

Create `THCWatch/Views/ActiveRoundView.swift` and `HoleDistanceView.swift`.

#### M11.6: WIRE — Hole advances on watch when phone advances
**Effort:** 1h | **Depends on:** M11.5, M11.2
**Done when:** Phone advances to hole 5 → watch shows hole 5

---

## Milestone 12: Apple Watch — Independent GPS + Score Entry

**Goal:** Watch works standalone; Digital Crown score entry.
**Effort:** 3 days | **Risk:** High

#### M12.1: SPEC — Battery monitoring test
**Effort:** 1h | **Depends on:** M1.4
**Done when:** `WatchBatteryTests.swift` compiles, tests fail

Test methods:
- `test_batteryAt30Percent_showsWarning()`
- `test_batteryAbove30Percent_noWarning()`

Note: Requires `WKInterfaceDeviceProviding` protocol wrapper for testability.

#### M12.2: IMPL — IndependentGPSService (watch)
**Effort:** 3h | **Depends on:** M11.1
**Done when:** `test_standaloneGPSActivates_whenPhoneUnreachable()` passes

Create `THCWatch/Services/IndependentGPSService.swift`:
- Activates when `WCSession.isReachable = false`
- Uses watch CoreLocation for distances

#### M12.3: WIRE — QuickScoreView (Digital Crown)
**Effort:** 3h | **Depends on:** M11.3
**Done when:** Digital Crown scrolls stroke count, tap confirms, score syncs to phone

Create `THCWatch/Views/QuickScoreView.swift`.

#### M12.4: WIRE — StandingsGlanceView (watch)
**Effort:** 2h | **Depends on:** M11.3
**Done when:** Watch shows top 5 leaderboard

Create `THCWatch/Views/StandingsGlanceView.swift`.

#### M12.5: WIRE — THCComplication (watch face)
**Effort:** 3h | **Depends on:** M11.3
**Done when:** Watch face complication shows current rank + distance to green

Create `THCWatch/Complications/THCComplication.swift`.

#### M12.6: IMPL — Battery monitoring + warning
**Effort:** 1h | **Depends on:** M12.1, M11.5
**Done when:** M12.1 tests pass; watch displays low-battery warning at 30%

---

## Milestone 13: Social Features

**Goal:** Live round feed, reactions, share card, push notifications.
**Effort:** 4 days | **Risk:** Medium

#### M13.1: SPEC — Social service tests
**Effort:** 2h | **Depends on:** M2.7
**Done when:** `SocialServiceTests.swift` compiles, tests fail

Test methods (from test plan §2.15):
- `test_liveRoundsFeed_receivesRealtimeUpdates()`
- `test_reactToRound_insertsReaction()`
- `test_liveRoundCleanup_afterRoundEnds()`
- `test_registerForPushNotifications_storesToken()`

#### M13.1a: SPEC — Push notification tests
**Effort:** 1h | **Depends on:** M2.7
**Done when:** `PushNotificationTests.swift` compiles, tests fail

Test methods:
- `test_playerTakesFirstPlace_triggersPushToOthers()`
- `test_eligibilityApproaching_triggersReminderPush()`
- `test_pushPermissionDenied_noCrash()`

#### M13.2: IMPL — SocialService
**Effort:** 3h | **Depends on:** M13.1, M8.3
**Done when:** M13.1 tests pass

Create `THC/Services/SocialService.swift`:
- Supabase Realtime subscription on `live_rounds`
- Reaction insert/fetch on `round_reactions`
- Connection lifecycle: connect when live feed visible, disconnect when not

#### M13.3: IMPL — Live round broadcasting in RoundManager
**Effort:** 2h | **Depends on:** M13.2, M9.2
**Done when:** Starting a round inserts to `live_rounds`; score updates reflected; finishing deletes

#### M13.4: WIRE — LiveRoundFeedView + tab wiring
**Effort:** 3h | **Depends on:** M13.2, M3.5
**Done when:** User sees active rounds from other players in real-time; accessible from standings or dedicated tab

Create `THC/Features/Standings/LiveRoundFeedView.swift`. Wire into ContentView navigation.

#### M13.5: WIRE — Round reactions UI
**Effort:** 2h | **Depends on:** M13.2
**Done when:** Emoji reactions appear on round detail; user can add reaction

#### M13.6: SPEC — ShareCardGenerator tests
**Effort:** 1h | **Depends on:** M1.4
**Done when:** `ShareCardGeneratorTests.swift` compiles, tests fail

Test methods:
- `test_generateImage_returnsNonNilImage()`
- `test_generateImage_withNilHoleScores_nocrash()`

#### M13.7: IMPL — ShareCardGenerator
**Effort:** 1h | **Depends on:** M13.6
**Done when:** M13.6 tests pass

Create `THC/Features/Standings/ShareCardGenerator.swift` using `ImageRenderer`.

#### M13.8: WIRE — ShareCardView (shareable scorecard)
**Effort:** 2h | **Depends on:** M13.7
**Done when:** User generates scorecard image and shares via UIActivityViewController

Create `THC/Features/Standings/ShareCardView.swift`.

#### M13.9: INFRA — Push notification infrastructure
**Effort:** 4h | **Depends on:** M8.4
**Done when:** APNs certificate configured; Supabase Edge Function fires push on leaderboard change

Setup: Apple Developer APNs certificate, Supabase Edge Function (or database trigger) for milestone events, device token registration in `SocialService`.

---

## Milestone 14: Polish + Background Refresh

**Goal:** Background data refresh, GHIN display, TestFlight polish.
**Effort:** 3 days | **Risk:** Low

#### M14.1: SPEC — Background refresh tests
**Effort:** 1h | **Depends on:** M1.4
**Done when:** `BackgroundRefreshTests.swift` compiles, tests fail

Test methods:
- `test_backgroundRefreshRegistered_inBGTaskScheduler()`
- `test_backgroundRefresh_fetchesStandingsAndCourseData()`

Note: Extract logic into `BackgroundRefreshService` with injectable `BGTaskSchedulerProviding` protocol.

#### M14.2: IMPL — BGAppRefreshTask for standings + course data
**Effort:** 2h | **Depends on:** M14.1, M4.3, M6.5
**Done when:** M14.1 tests pass; standings refresh in background

#### M14.3: INFRA — BGTaskSchedulerPermittedIdentifiers in Info.plist
**Effort:** 0.5h | **Depends on:** M1.1
**Done when:** `BGTaskSchedulerPermittedIdentifiers` key added to Info.plist

#### M14.4: WIRE — GHIN handicap display on player profile
**Effort:** 1h | **Depends on:** M4.5
**Done when:** Player profile shows handicap index and last updated date from `players.handicap_index` and `players.handicap_updated_at`

#### M14.5: IMPL — Pre-fetch OSM data for nearby courses on launch
**Effort:** 2h | **Depends on:** M6.3
**Done when:** App launch triggers background fetch of OSM data within 50km

#### M14.6: INFRA — Performance audit (battery, memory, network)
**Effort:** 4h | **Depends on:** M7.8
**Done when:** Xcode Instruments shows no excessive GPS drain when idle; memory stable during 18-hole sim

#### M14.7: INFRA — App icon, launch screen, TestFlight metadata
**Effort:** 2h | **Depends on:** none
**Done when:** Clean TestFlight build uploaded with icon and description

#### M14.8: INFRA — Privacy disclosures for GPS tracking
**Effort:** 1h | **Depends on:** none
**Done when:** Info.plist has location usage descriptions; privacy disclosure documented

#### M14.9: WIRE — End-to-end walkthrough on real device
**Effort:** 4h | **Depends on:** all prior
**Done when:** Full round flow tested on physical iPhone + Apple Watch

---

## Explicitly Out of Scope

These features appear in the original spec but are not planned for this version:
- **Shot tracking with club distance averages** — Stretch goal. Requires per-shot data + analytics.
- **3D flyover / elevation** — Nice-to-have, not core.
- **Club recommendations** — Requires ML + shot data.
- **iPad optimization** — SwiftUI runs on iPad but not optimized.

---

## Critical Path

```
M1 ──► M2 ──► M3 ──► M4 ──► M5 ──► M7 ──► M9 ──► M10
 Scaffold  Models  Auth  Standings  Scoring  GPS+MVP  LiveScore  FullHole
                                       │
                                       ▼
                              M6 (Course Data)──► M7
```

**Longest chain:** M1 → M2 → M3 → M4 → M5 → M7 → M9 → M10 (8 milestones, ~27 days)

**Note:** M6 is a predecessor to M7 via M7.9's dependency on M6.5. If M6 slips, M7 cannot complete.

### Parallelization Opportunities

| Can Run in Parallel | After |
|---------------------|-------|
| M6 (Course Data) | M2 (needs models + mocks, not standings) |
| M8 (Social Schema) | M5 (just SQL, no iOS dependency) |
| M11 (Watch Core) | M7 (needs GPS on phone first) |
| M13 (Social) | M8 + M9 (needs tables + live scoring) |
| M14 (Polish) | M10 (can start before watch is done) |

**Within milestones**, SPEC tasks can often be written in parallel with INFRA tasks.

With parallelization:
- **Weeks 1-2:** M1, M2, M3 (sequential — foundation)
- **Weeks 3-4:** M4 + M6 in parallel, then M5
- **Week 5:** M7 (MVP GPS) + M8 in parallel — **TestFlight MVP ships**
- **Weeks 6-7:** M9 + M11 in parallel
- **Weeks 8-9:** M10 + M12 in parallel
- **Weeks 10-11:** M13 + M14 in parallel

**Realistic total: 10-11 weeks.**

---

## Staging Strategy

**All Supabase migrations must be tested against a staging environment before production.** The web app and iOS app share the same Supabase instance. A botched migration affects both.

1. Use Supabase branching (Pro plan) or a separate staging project
2. Run all SQL migrations against staging first
3. Verify web app still functions after each migration
4. Only then apply to production

---

## Risk Summary

| # | Milestone | Risk | Rating | Mitigation |
|---|-----------|------|--------|-----------|
| 1 | M3 | OAuth callback URL config | Medium | Test on real device early; M3.3 ensures Info.plist is correct |
| 2 | M5 | Offline sync + dedup | Medium | Use local UUID as primary dedup key; last-write-wins |
| 3 | M6 | OSM data parsing variability | Medium | Parse defensively; M6.1a tests malformed responses |
| 4 | M6 | GolfCourseAPI availability | Medium | Cache everything; graceful fallback for missing API key |
| 5 | M7 | CoreLocation background mode | Medium | M7.10 ensures Info.plist; real device testing |
| 6 | M7 | Tap accuracy on satellite map | Medium | Auto-zoom to hole level |
| 7 | M10 | Front/back green polygon math | High | Test-first with known polygons |
| 8 | M10 | OSM inconsistent tagging | Medium | Graceful fallback to center |
| 9 | M11 | WatchConnectivity on real hardware | High | Cannot rely on simulator |
| 10 | M12 | Watch battery drain with GPS | High | Warn users, reduce stationary polling |
| 11 | M13 | Push notification infrastructure | Medium | APNs + Edge Function; M13.9 covers setup |
| 12 | ALL | Supabase migration breaks web app | Medium | Staging strategy (see above) |

---

## Backend Migrations

| Milestone | Migration | Description |
|-----------|-----------|-------------|
| M5 | `add_app_source.sql` | Add `"app"` to `rounds.source` (with data audit) |
| M6 | `create_course_tables.sql` | Create `course_data`, `course_holes`, `app_config` + enable `pg_trgm` |
| M8 | `create_social_tables.sql` | Create `hole_scores`, `round_reactions`, `live_rounds` + Realtime |

Run against staging before production. Independent — can be applied in any order.

---

## Total Estimate

| Phase | Milestones | Tasks | Estimated Days | Weeks |
|-------|-----------|-------|---------------|-------|
| Foundation | M1-M3 | 22 | 7 days | ~2 weeks |
| Core Features | M4-M7 | 51 | 16 days | ~3 weeks |
| Enhancement | M8-M10 | 17 | 9 days | ~2 weeks |
| Apple Watch | M11-M12 | 18 | 7 days | ~2 weeks |
| Social + Polish | M13-M14 | 22 | 7 days | ~2 weeks |
| **Total** | **14 milestones** | **~130 tasks** | **46 days** | **~10-11 weeks** |
