# THC iOS App — Test Suite Creation Report

## Result: SPEC-READY (RED — expected)

This is spec-driven development. All tests compile against protocols but fail (red) because no implementation exists yet. This is the intended state.

---

## Test Summary

- **Total test files:** 41
- **Unit test files:** 8
- **Service test files:** 15
- **Integration test files:** 2
- **Mock/fixture files:** 10
- **GPX simulation files:** 4
- **Manual test scripts:** 3
- **Total test methods:** ~120 across all files
- **Fixtures:** 5 JSON fixture files
- **Status:** All compile against protocol definitions; all red pending implementation

---

## Files Created

### Mocks (5 files)

| File | Purpose |
|------|---------|
| `Mocks/MockSupabaseClient.swift` | Captures insertCalls, updateCalls, deleteCalls; stubs by table name |
| `Mocks/MockCLLocationManager.swift` | Replays location sequences; permissionDenied scenario |
| `Mocks/MockURLSession.swift` | Stubs HTTP by URL; supports error injection and fixture loading |
| `Mocks/MockWCSession.swift` | Tracks transferredUserInfoItems vs sentMessages; configurable isReachable |
| `Mocks/TestModelContainer.swift` | In-memory ModelContainer for SwiftData test isolation |

### Unit Tests (8 files)

| File | Specs Covered | Count |
|------|--------------|-------|
| `Unit/PointsCalculatorTests.swift` | §2.1.1-2.1.11 | 11 tests |
| `Unit/DistanceCalculatorTests.swift` | §2.2.1-2.2.4 + invalid coord guards | 6 tests |
| `Unit/HazardDistanceTests.swift` | §2.2.5-2.2.11 | 7 tests |
| `Unit/ScoreEntryTests.swift` | §2.4.1-2.4.4, 2.4.9-2.4.12, 2.4.15 | 9 tests |
| `Unit/TapAndSaveTests.swift` | §2.5.1-2.5.7 | 7 tests |
| `Unit/ModelCodingTests.swift` | §2.10.1-2.10.5 + extra round-trip tests | 12 tests |
| `Unit/OfflineStorageTests.swift` | §2.11.1-2.11.6 | 6 tests |
| `Unit/ShareCardGeneratorTests.swift` | §2.16.1-2.16.2 | 2 tests |

### Service Tests (15 files)

| File | Specs Covered | Count |
|------|--------------|-------|
| `Service/CourseDataServiceTests.swift` | §2.3.1-2.3.12 | 12 tests |
| `Service/LocationManagerTests.swift` | §2.6.1-2.6.8 | 9 tests (no 2.6.9 — covered in WatchBattery) |
| `Service/WatchConnectivityTests.swift` | §2.7.1-2.7.8 | 8 tests |
| `Service/AuthManagerTests.swift` | §2.8.1-2.8.6 | 6 tests |
| `Service/StandingsViewModelTests.swift` | §2.9.1-2.9.7 | 7 tests |
| `Service/RoundManagerTests.swift` | §2.12.1-2.12.12 | 12 tests |
| `Service/OverpassAPIClientTests.swift` | §2.13.1-2.13.7 | 7 tests |
| `Service/CourseSetupViewModelTests.swift` | §2.14.1-2.14.4 | 4 tests |
| `Service/SocialServiceTests.swift` | §2.15.1-2.15.4 | 4 tests |
| `Service/LiveScoringTests.swift` | M9.1 specs | 5 tests |
| `Service/ScoreEntrySyncTests.swift` | M5.5 + §2.4.16 | 7 tests |
| `Service/BackgroundRefreshTests.swift` | M14.1 | 2 tests |
| `Service/WatchBatteryTests.swift` | M12.1 | 2 tests |
| `Service/PushNotificationTests.swift` | M13.1a | 3 tests |

### Integration Tests (2 files)

| File | Specs Covered | Count |
|------|--------------|-------|
| `Integration/SupabaseIntegrationTests.swift` | I.1-I.5 (staging) | 5 tests |
| `Integration/StandingsIntegrationTests.swift` | Round-to-standings pipeline | 4 tests |

### Fixtures (5 JSON files)

| File | Purpose |
|------|---------|
| `Fixtures/overpass_torrey_pines_south.json` | 10 OSM elements: 3 greens, 2 bunkers, 2 hole ways, fairway, tee, water |
| `Fixtures/overpass_empty.json` | Empty elements array (no OSM data) |
| `Fixtures/overpass_malformed.json` | Invalid JSON to trigger parse error tests |
| `Fixtures/golfcourseapi_search_torrey.json` | 2 Torrey Pines results with club/course metadata |
| `Fixtures/golfcourseapi_429.json` | Rate limit response body |

### GPX Simulation Files (4 files)

| File | Holes | Duration | Key Tests |
|------|-------|----------|-----------|
| `GPXSimulation/TorreyPinesSouth.gpx` | 18 | ~100 min | Distance accuracy, 60s GPS blackout in hole 18, stationary detection |
| `GPXSimulation/LocalMuni.gpx` | 9 | ~60 min | No-OSM tap-and-save flow, 90s green pauses |
| `GPXSimulation/StationaryOnGreen.gpx` | 1 (stationary) | 3 min | 36 points × 5s = 180s; battery mode, zero-distance edge case |
| `GPXSimulation/BoundaryEdges.gpx` | 6 segments | ~30 min | OnGreenCenter, BeyondGreenBack, CartSpeed, CartPathGreenToTee, OffCourse, GPSLoss |

### Manual Test Scripts (3 files)

| File | Scope | Duration |
|------|-------|----------|
| `ManualTestScripts/AppleWatchChecklist.md` | Physical watch pairing, sync, Digital Crown, standalone GPS, battery warning | ~45 min |
| `ManualTestScripts/OfflineRoundChecklist.md` | Airplane mode round, sync on reconnect, cache miss, partial sync | ~30 min |
| `ManualTestScripts/ReleaseChecklist.md` | Full pre-release gate: code quality, integration, watch, offline, push, GPS accuracy | ~2 hours |

---

## Critical Design Decisions

### 1. Protocol-first mock compatibility

All mocks implement protocols (`SupabaseClientProviding`, `CLLocationManagerProtocol`, `URLSessionProtocol`, `WCSessionProtocol`) that must be extracted from their real implementations. The mock files define these protocols — implementors must satisfy them.

### 2. Method signatures are exact

Tests use the exact method signatures from the implementation plan:
- `distanceInYards(from:to:)` — NOT `haversineYards`
- `getCourseDetail(courseId:)` — NOT `fetchCourseData`
- `searchCourses(query:)` — NOT `searchCourses(name:)`
- `greenDistances(userLocation:greenCenter:greenPolygon:approachFrom:)` returns `GreenDistances`
- `hazardDistances(userLocation:hazardPolygon:)` returns `HazardDistances`
- `layupPoint(from:toward:yardsFromTarget:)` — NOT `layupCoordinate`
- `doglegDistance(holeWay:userPosition:)` — called on DistanceCalculator

### 3. Points formula parity

`PointsCalculatorTests` verifies parity with `src/lib/points.ts`: `max(1, min(15, 10 - netVsPar))`. The `StandingsIntegrationTests` includes a `test_pointsFormula_iosMatchesWebApp` test with hardcoded expected values from the TypeScript source.

### 4. Integration tests are opt-in

`SupabaseIntegrationTests` reads `TEST_PLAN_INTEGRATION=true` from the environment. In CI they run nightly, not on every push. Credentials come from environment variables (never hardcoded).

### 5. GPX simulation notes

- `TorreyPinesSouth.gpx` includes a 60-second gap in hole 18 to test GPS loss behavior
- `StationaryOnGreen.gpx` has 36 points × 5 seconds = exactly 3 minutes
- `BoundaryEdges.gpx` has 6 named `<trk>` segments for loading individually in Xcode scheme options
- `CartPathGreenToTee` validates the 3-second sustained proximity requirement for auto-advance

---

## Coverage Notes

### Well covered
- Points formula: exhaustive range test (-20 to +20), all boundary conditions
- Distance calculation: Haversine, front/back green, hazards, layup, dogleg, NaN guards
- Score entry: net calculation, validation, source field, 9-hole round
- Offline/sync: save, reconnect, dedup, partial interruption (§2.4.16), per-hole stats
- Watch connectivity: transferUserInfo vs sendMessage distinction, conflict resolution
- RoundManager: full state machine from notStarted → active → finished

### Areas needing implementation-time attention
- `SocialServiceTests.test_liveRoundsFeed_receivesRealtimeUpdates`: requires a real Realtime mock pattern. The mock hook `simulateRealtimeInsert` is a stub — implementation must expose an injectable callback.
- `AuthManagerTests`: `ASPresentationAnchor` type dependency needs the `ASPresentationAnchorProviding` protocol defined in the production code.
- `BackgroundRefreshTests`: `BGTaskScheduler` real registration cannot be called in tests — the `BGTaskSchedulerProviding` protocol abstraction is critical.
- `WatchBatteryTests`: `WKInterfaceDevice` protocol abstraction must be designed into the watch app from day 1.

---

## Next Steps

1. Implement milestones M1-M14 per `docs/specs/plan.md`
2. Each IMPL task should make its corresponding SPEC tests go green
3. Run `xcodebuild test -testPlan UnitAndService` after each IMPL milestone
4. For integration tests: configure staging environment and run with `TEST_PLAN_INTEGRATION=true`
5. Load GPX files via Xcode scheme editor for GPS simulation tests
