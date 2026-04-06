# THC iOS App — Handoff Document

## What This Is

THC (The Homie Cup) is a season-long golf scoring competition for ~10 friends. The **web app** (Next.js + Supabase) already exists and handles standings, score entry, and GHIN handicap syncing. This branch adds a **native iOS + Apple Watch app** with golf course GPS, on-course scoring, and social features.

## Branch

**`claude/golf-gps-research-s70QO`** — all iOS work lives here. Do not merge to main until the Xcode project builds and tests pass on a real Mac.

## Current State

### What's Done

- **91 Swift files** (59 app + 32 tests) covering the full app
- **Plan doc** at `docs/ios-golf-gps-plan.md` — the single source of truth for all product decisions
- **Supabase migrations** in `supabase/migrations/` — 3 files for new tables
- **6 rounds of code review** completed with zero remaining issues found
- All pure Swift logic (scoring, distance calc, models, services) has been reviewed and fixed

### What's NOT Done

- **The app does not build yet.** The `ios/THC.xcodeproj/project.pbxproj` was AI-generated with fake UUIDs and won't open in Xcode. You must regenerate it.
- **No real device testing** has occurred
- **TestFlight distribution** not set up (needs Apple Developer account, $99/year)

## How to Get the App Building

### Option 1: Use XcodeGen (Recommended)

There's a `ios/project.yml` that defines the project structure. Install XcodeGen and regenerate:

```bash
brew install xcodegen
cd ios/
xcodegen generate
open THC.xcodeproj
```

This will create a valid `project.pbxproj` with real UUIDs from the project spec.

### Option 2: Create Fresh Xcode Project

1. Open Xcode → New Project → iOS App (SwiftUI, Swift)
2. Add watchOS target
3. Add Shared framework target
4. Add test target
5. Drag in all existing Swift files from `ios/`
6. Add Supabase Swift SDK via SPM: `https://github.com/supabase/supabase-swift`

## Architecture

```
ios/
├── Shared/              # Framework shared between iOS + watchOS
│   ├── Models/          # Codable structs matching Supabase schema
│   └── Utilities/       # PointsCalculator, DistanceCalculator
├── THC/                 # iOS app target
│   ├── App/             # THCApp entry, ContentView (tab bar), auth
│   ├── Features/
│   │   ├── GPS/         # HoleOverviewView, LocationManager, RoundManager
│   │   ├── Scoring/     # LiveScoringView, PostRoundView, ScoreEntryVM
│   │   ├── Standings/   # LeaderboardView, PlayerDetailView, social
│   │   ├── CourseSetup/ # CourseSearchView, TapAndSaveView
│   │   └── Auth/        # LoginView, AuthManager (Google OAuth)
│   └── Services/        # Supabase, Overpass, GolfCourseAPI, offline, sync
├── THCWatch/            # watchOS app target
│   ├── Views/           # ActiveRound, HoleDistance, QuickScore, Standings
│   ├── Services/        # PhoneConnectivity, IndependentGPS
│   └── Complications/   # THCComplication
└── THCTests/            # Unit + service + integration tests
    ├── Unit/            # PointsCalc, DistanceCalc, ScoreEntry, Models, etc.
    ├── Service/         # ViewModel tests, API client tests, sync tests
    ├── Integration/     # Supabase integration tests (need real backend)
    ├── Mocks/           # MockURLSession, MockSupabaseClient, etc.
    ├── Fixtures/        # JSON fixtures for API responses
    └── GPXSimulation/   # Simulated GPS tracks for Xcode
```

## Key Technical Decisions

### Scoring Formula (must match web app exactly)
```swift
// Shared/Utilities/PointsCalculator.swift
func calculatePoints(netVsPar: Int) -> Int {
    max(1, min(15, 10 - netVsPar))
}
```
Source of truth: `src/lib/points.ts`

### Course GPS Data Strategy

No free API provides green GPS coordinates. Commercial ones cost $5k+/year.

**Solution: two layers, zero setup:**
1. **OpenStreetMap** — ~5-10k courses have green polygons. Query via Overpass API (free). Full auto-distances.
2. **Tap-and-save** — On unmapped courses, user taps the green on satellite map to get distance. App asks "Save as Hole X green?" One tap saves it to Supabase. Next round = auto-distances for all users.

### GolfCourseAPI.com
- Used for course **metadata only** (name, par, scorecard, tee ratings, yardage for 30k courses)
- Does NOT have green GPS coordinates
- Free tier: 300 req/day
- API key stored as env var (do not ship in app bundle)

### Protocol-Based Testing

All services use protocol abstractions so mocks can be injected in tests:
- `OfflineStorageProviding` → `OfflineStorage` / `MockOfflineStorage`
- `OverpassAPIProviding` → `OverpassAPIClient` / mock
- `TapAndSavePersisting` → `SupabaseTapAndSavePersistence` / `MockTapAndSavePersistence`
- `SyncServiceProviding` → `SyncService` / mock
- `SupabaseRoundUploading` → `LiveSupabaseRoundUploader` / `MockSupabaseRoundUploader`
- `URLSessionDataProviding` → `URLSession` / `MockURLSession`

### Offline-First

Rounds save to SwiftData (local) first, then sync to Supabase. `SyncService` handles the queue. `RoundManager.startRound()` creates a stub `LocalRound` immediately so hole scores can be appended during play (this was a critical bug that was fixed — don't revert it).

### Watch Communication

Uses `WatchConnectivity` with `transferUserInfo` (guaranteed delivery) for course data, not `sendMessage` (which drops when not reachable).

## Supabase Schema Changes

Three migration files in `supabase/migrations/`:

1. **`add_app_source.sql`** — Adds `"app"` to the `rounds.source` CHECK constraint
2. **`create_course_tables.sql`** — `course_data` and `course_holes` tables with RLS
3. **`create_social_tables.sql`** — `hole_scores`, `round_reactions`, `live_rounds` tables

Run these against your Supabase instance before testing the iOS app.

## Environment Variables Needed

```
# Existing (already in Vercel)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=

# iOS app needs these (via Secrets.plist or runtime fetch)
SUPABASE_URL=           # same as above
SUPABASE_ANON_KEY=      # same as above
GOLFCOURSEAPI_KEY=      # from golfcourseapi.com (free signup)
```

See `ios/Secrets.plist.example` for the expected format. **Do not commit real keys.**

## Bugs Fixed During Review (Don't Re-Introduce)

These were real bugs found and fixed across 6 review rounds:

| Bug | Why It Matters |
|-----|---------------|
| `RoundManager` hole scores lost during live rounds | `startRound()` must save stub `LocalRound` before play begins, not after |
| `SyncService` called real Supabase in tests | Uses `SupabaseRoundUploading` protocol now — don't bypass it |
| `ScoreEntryViewModel.isSubmitting` stuck on error | Must use `defer { isSubmitting = false }` |
| `OverpassAPIClient` POST body encoding | Must percent-encode QL value with `.urlHostAllowed`, not `.urlQueryAllowed` |
| `CourseDataService` misclassified OSM as tap-and-save | Check `hole.source` field, not just `greenLat != nil` |
| `BackgroundRefreshService` Gulf of Guinea bug | `(0,0)` coordinate needs separate `hasLocation` boolean, not `!= 0` check |
| `TapAndSaveService` untestable | Uses `TapAndSavePersisting` protocol now |
| `StandingsViewModelTests` tautological assertion | Must assert against hardcoded expected value, not re-compute it |
| `ContentView` profile tab never loaded rounds | Must pass `viewModel` to `PlayerDetailView` |
| `project.yml` watchOS missing `GENERATE_INFOPLIST_FILE` | Required for XcodeGen to produce valid Watch target |
| `PushNotificationService` protocol type mismatch | `UNAuthorizationOptions`, not `Any` |
| `DistanceCalculatorTests` wrong ground truth | Torrey Pines reference was 195y, actual Haversine = 188y |
| `HazardDistanceTests` bunker polygon 10x too far | Latitudes were off by ~0.01 degrees |

## What To Do Next

1. **Get it building** — Run `xcodegen generate` in `ios/`, open in Xcode, resolve any remaining SPM/signing issues
2. **Run tests** — `xcodebuild test -scheme THCTests -destination 'platform=iOS Simulator,name=iPhone 16'`
3. **Run Supabase migrations** — Apply the 3 migration files to your Supabase instance
4. **Test on device** — GPS features need real device (simulator can use GPX files)
5. **Set up TestFlight** — Apple Developer account ($99/year), add team members
6. **Ship Phase 1** — Standings + score entry (no GPS yet) to validate the Supabase connection works
7. **Then Phase 2-5** — GPS, Watch, Social per the plan doc

## Key Files to Read First

| File | What It Tells You |
|------|------------------|
| `docs/ios-golf-gps-plan.md` | Full product spec, architecture, data strategy, testing |
| `ios/Shared/Utilities/PointsCalculator.swift` | Scoring formula (must match web) |
| `ios/Shared/Utilities/DistanceCalculator.swift` | Haversine + green edge projection |
| `ios/THC/Services/CourseDataService.swift` | How OSM + tap-and-save + GolfCourseAPI work together |
| `ios/THC/Features/GPS/RoundManager.swift` | Round lifecycle: start → play → score → finish → sync |
| `ios/THC/Services/SyncService.swift` | Offline queue + Supabase sync + dedup |
| `src/lib/types.ts` | Web app types — Swift models must match these |
| `src/lib/points.ts` | Web app scoring — Swift PointsCalculator must match |
