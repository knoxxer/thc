# THC iOS App — Golf GPS + Scoring + Homie Cup Standings

## Overview

Transform THC from a Next.js web app into a native iOS + Apple Watch app with:
1. **Golf course GPS** — distances to green, hazards, and layup targets on phone and watch
2. **Score entry** — post rounds from the course with per-hole stats
3. **Homie Cup standings** — leaderboard, player stats, and social features

The existing **Supabase backend** and **GHIN integration** stay as-is. The iOS app becomes a new client.

---

## Architecture Decision: Swift Native

**Recommendation: Native Swift/SwiftUI for both iOS and watchOS.**

Why not React Native?
- **watchOS requires native Swift** — React Native cannot run on Apple Watch (no JS runtime on watchOS)
- GPS-heavy apps perform better with native CoreLocation
- A React Native approach would still require a full Swift watchOS app + WatchConnectivity bridge — doubling the work
- SwiftUI shares code between iOS and watchOS targets naturally

The existing Next.js web app continues to serve as the desktop/browser experience. The iOS app is a new Xcode project that talks to the same Supabase backend.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS UI | SwiftUI (iOS 17+) |
| watchOS UI | SwiftUI (watchOS 10+) |
| GPS/Location | CoreLocation |
| Maps | MapKit |
| Auth | Supabase Auth (Google OAuth via ASWebAuthenticationSession) |
| Database | Supabase Swift SDK (`supabase-swift`) |
| Course Data | Multi-source (see Course Data Strategy below) |
| Local Storage | SwiftData (offline rounds, cached course data) |
| Watch Comms | WatchConnectivity framework |

---

## Course Data Strategy

### The Reality

- **~10 users.** Crowdsourcing won't work. Pre-mapping from satellite view won't happen.
- **No free API provides green GPS coordinates.** GolfCourseAPI.com has great metadata (par, yardage, tees, ratings for 30k courses) but no hole-level GPS.
- **Commercial GPS data** (iGolf, GolfLogix) costs $5,000+/year — absurd for a friend group.

### Solution: OSM Where Available + Tap-and-Save Everywhere Else

Two layers, zero setup required:

#### Layer 1: OpenStreetMap (Automatic, Zero Effort)
- ~5,000–10,000 courses worldwide have detailed green/hole/fairway polygons in OSM
- Query via Overpass API — completely free
- **Experience:** Full map overlays, front/center/back of green, hazard distances
- Popular/well-known courses are most likely to be mapped

#### Layer 2: Tap-and-Save (Zero Setup, First-Round Learning)
For courses OSM doesn't cover, the app learns the course as you play the first round:

1. **You see satellite imagery** of the course (Apple Maps)
2. **Before each shot, tap the green** on the satellite view to get your distance — the green is clearly visible as a dark circle
3. **App asks: "Save as Hole 1 green?"** — tap yes
4. **Next round at the same course: auto-distances** — greens are already saved
5. Green pins save to Supabase — **all 10 users benefit immediately** after one person plays one round

**First round experience:** Satellite map + tap for distance (2 seconds per hole, you're already looking at the map)
**Every round after:** Automatic distances, just like an OSM course

This means **the app works everywhere on day one** with no pre-mapping, no purchases, and no manual setup sessions. It just gets better over time as courses are played.

#### GolfCourseAPI.com (Course Metadata)
- Search courses by name, get scorecard, par, tee ratings, yardage
- Used for **score entry** (auto-fill course info) and **course search**, not GPS
- Free tier: 300 requests/day (plenty for 10 users)
- API key: stored in environment variables

### Data Sources

| Source | What It Provides | Cost |
|--------|-----------------|------|
| OpenStreetMap / Overpass API | Green polygons, fairways, bunkers, hole layouts for well-mapped courses | Free (ODbL) |
| GolfCourseAPI.com | Course name, address, par, scorecard, tee ratings, yardage for 30k courses | Free (300 req/day) |
| Tap-and-save green pins | Green center points — shared across all users after one round | Free (automatic) |

### Experience Comparison

| Feature | OSM Course | Tap-and-Save Course |
|---------|-----------|---------------------|
| Distance to center of green | Automatic | Automatic (after first round) |
| Front/back of green | Yes (polygon edges) | No (center only) |
| Map overlays (fairway shapes) | Yes | No (satellite imagery) |
| Hazard distances | Yes (from polygons) | Tap-for-distance on any point |
| First round experience | Full auto | Tap green each hole (~2s) |

### Pre-fetching & Caching

- On app launch, pre-fetch OSM data for courses within 50km
- Cache all course data in SwiftData — courses rarely change
- When a user selects a course from search, fetch and cache immediately
- Background refresh via `BGAppRefreshTask` to keep cache current

### Course Selection UX

- **Auto-detect** — Near a course? "Looks like you're at Torrey Pines. Start round?"
- **Manual search** — Search by name via GolfCourseAPI.com, browse nearby, recent courses
- **Favorites** — Pin your home course(s)
- **Multi-course locations** — At a resort with 3 courses, show a picker

### New Supabase Tables

```sql
-- Course metadata (seeded from GolfCourseAPI)
course_data (
  id uuid primary key,
  golfcourseapi_id int,           -- link to GolfCourseAPI.com
  name text,                      -- e.g. "Torrey Pines South"
  club_name text,                 -- e.g. "Torrey Pines Municipal Golf Course"
  address text,
  lat double precision,
  lon double precision,
  hole_count int,
  par int,
  osm_id text,                    -- link to OSM if available
  has_green_data boolean,         -- true if greens are mapped (OSM or tap-and-save)
  created_at timestamptz,
  updated_at timestamptz
)

-- Per-hole data (from OSM or tap-and-save)
course_holes (
  id uuid primary key,
  course_id uuid references course_data,
  hole_number int,
  par int,
  yardage int,                    -- from GolfCourseAPI
  handicap int,                   -- stroke index from GolfCourseAPI
  green_lat double precision,     -- center of green
  green_lon double precision,
  green_polygon jsonb,            -- GeoJSON polygon (OSM only, null for tap-and-save)
  tee_lat double precision,
  tee_lon double precision,
  source text,                    -- 'osm' or 'tap_and_save'
  saved_by uuid,                  -- who tapped the green
  created_at timestamptz,
  updated_at timestamptz
)
```

### Front/Back Green Distance Calculation

"Front" and "back" of the green depend on **angle of approach**, not just the user's position:

1. Get the `golf=hole` way from OSM (the line of play from tee to green)
2. The **front** of the green is the edge of the green polygon closest to the previous point on the hole way (the approach angle)
3. The **back** is the farthest edge along that same line
4. If no hole way exists, use the line from the user's position to the green center — front is nearest edge, back is farthest edge
5. All distances use the Haversine formula between user's `CLLocationCoordinate2D` and the calculated points

---

## Feature Breakdown

### 1. Golf GPS (iOS + Apple Watch)

**Core experience: hole overview with distances to green, hazards, and layup targets.**

#### iOS App — Primary GPS Screen: Hole Overview
The main screen during a round is a **top-down hole view** showing:
- Full hole layout from tee to green (satellite or stylized map)
- Green shape with front/center/back distances
- Hazard distances — "187 to carry water", "145 to front bunker"
- Layup targets — "lay up to 100 yards" marker for par 5s and doglegs
- Dogleg distances — distance to the turn on dog-leg holes
- Par and stroke index for the current hole
- Tap anywhere on the map to get distance to that point

Secondary views:
- Scorecard view (running score for the round)
- Shot tracking: tap to mark where your ball is, get distance to green from that spot. Over time, this builds your average distances per club.

#### Apple Watch App
- Glanceable distances: front/center/back of green
- Hazard distance (next hazard in play)
- Current hole number and par
- Auto-advance between holes
- Quick score entry per hole (Digital Crown to select, tap to confirm)
- Complication for active round (distance to green on watch face)

#### GPS Implementation
```
CLLocationManager (kCLLocationAccuracyBest)
├── iPhone: streams location updates → map + distance calculations
├── Apple Watch: independent GPS when phone not nearby
└── WatchConnectivity: syncs course data phone → watch
    └── Use transferUserInfo (guaranteed delivery) not sendMessage
```

**Hazard & Layup Distances:**
- For each hazard polygon (bunker, water) on the current hole, calculate:
  - Distance to **carry** (far edge — how far to clear it)
  - Distance to **front edge** (how far to reach it)
- Layup targets: place a marker at a set distance from the green (e.g., 100y) along the hole's line of play
- Dogleg: distance to the bend point on the `golf=hole` way

**Battery considerations:**
- Use `allowsBackgroundLocationUpdates` for continuous tracking during round
- Reduce GPS update frequency when stationary (< 2mph) — poll every 10s instead of continuous
- Show battery warning if watch drops below 30% mid-round
- Typical 18-hole round: ~30-50% Apple Watch battery drain with GPS

### 2. Score Entry

**Score entry works both on-course and post-round, with optional per-hole stats.**

#### On-Course (Live Scoring)
- After each hole auto-advances, prompt for score entry
- **Required:** strokes for the hole
- **Optional quick stats:** putts, fairway hit (yes/no/left/right), green in regulation (yes/no)
- Apple Watch: Digital Crown to select score, tap to confirm (strokes only for speed)
- iPhone: tap score selector with optional stats toggles
- Scores saved locally (SwiftData) and synced to Supabase when online

#### Post-Round Entry
- Same flow as current web app `/rounds/new`
- Course name, tee, gross score, course handicap
- Auto-lookup course details from cached course data
- Calculate net score and points client-side

#### Per-Hole Stats (Optional)
Track these per hole for players who want more insight:
- **Putts** — putting average over time
- **Fairway hit** — left/right/hit/N/A (par 3s)
- **Green in regulation** — yes/no
- These feed into a simple stats dashboard on the player profile (not required for Homie Cup scoring)

#### Data Flow
```
Score Entry (iOS/Watch)
  → SwiftData (local, offline-safe)
  → Supabase `rounds` table (source: "app")
  → Points calculated (same formula: max(1, min(15, 10 - netVsPar)))
  → Season standings update
  → Per-hole stats stored in new `hole_scores` table (optional)
```

### 3. Homie Cup Standings & Social

- Leaderboard tab matching web app functionality
- Player profiles with round history and stats (putts/round, FIR%, GIR%)
- Season stats: total rounds, best 10 points, eligibility status
- Pull-to-refresh from Supabase
- `BGAppRefreshTask` to keep standings fresh in background

#### Social Features (10 friends = perfect size for this)
- **Live round feed** — see when a homie is playing and their hole-by-hole score as it happens
- **Round reactions** — react to a buddy's posted round ("nice round" / trash talk)
- **Season milestones** — push notifications: "Jake just took the #1 spot", "You need 2 more rounds to qualify"
- **Share card** — generate a shareable image of your round scorecard for texts/group chat

#### Apple Watch
- Complication: current rank and points total on watch face
- Glance: top 5 standings
- Tap to open full standings list

---

## Xcode Project Structure

```
ios/
├── THC.xcodeproj
├── THC/                              # iOS App Target
│   ├── App/
│   │   ├── THCApp.swift              # App entry point
│   │   └── ContentView.swift         # Tab-based root view (GPS, Standings, Profile)
│   ├── Features/
│   │   ├── GPS/
│   │   │   ├── HoleOverviewView.swift    # Primary screen: top-down hole map
│   │   │   ├── CourseMapView.swift        # Full course satellite view
│   │   │   ├── DistanceOverlay.swift      # Green/hazard/layup distance callouts
│   │   │   ├── HazardDistanceView.swift   # Carry/front distances to hazards
│   │   │   ├── ShotTracker.swift          # Tap-to-mark shot locations
│   │   │   └── LocationManager.swift      # CoreLocation wrapper
│   │   ├── Scoring/
│   │   │   ├── LiveScoringView.swift      # Per-hole score + optional stats
│   │   │   ├── PostRoundView.swift        # Post-round entry form
│   │   │   ├── HoleStatsView.swift        # Putts, FIR, GIR toggles
│   │   │   └── ScoreEntryViewModel.swift
│   │   ├── Standings/
│   │   │   ├── LeaderboardView.swift
│   │   │   ├── PlayerDetailView.swift     # Profile + stats dashboard
│   │   │   ├── LiveRoundFeedView.swift    # See homies' active rounds
│   │   │   ├── ShareCardView.swift        # Shareable round image
│   │   │   └── StandingsViewModel.swift
│   │   ├── CourseSetup/
│   │   │   ├── CourseSearchView.swift     # Search via GolfCourseAPI / nearby / favorites
│   │   │   └── TapAndSaveView.swift       # Tap green on satellite map → save for everyone
│   │   └── Auth/
│   │       ├── LoginView.swift
│   │       └── AuthManager.swift          # Token refresh during long rounds
│   ├── Services/
│   │   ├── SupabaseClient.swift           # Auth + data, with silent token refresh
│   │   ├── CourseDataService.swift        # Multi-source: OSM + pin drops from Supabase
│   │   ├── OverpassAPIClient.swift        # OSM Overpass queries
│   │   ├── GHINService.swift
│   │   └── WatchSyncService.swift         # WatchConnectivity (transferUserInfo)
│   ├── Models/
│   │   ├── Player.swift
│   │   ├── Round.swift
│   │   ├── HoleScore.swift                # Per-hole stats (putts, FIR, GIR)
│   │   ├── Season.swift
│   │   ├── Course.swift                   # Multi-tier course data
│   │   └── Hole.swift                     # Green coords, hazards, line of play
│   └── Utilities/
│       ├── DistanceCalculator.swift       # Haversine + front/back green logic
│       └── PointsCalculator.swift
├── THCWatch/                          # watchOS App Target
│   ├── THCWatchApp.swift
│   ├── Views/
│   │   ├── ActiveRoundView.swift          # Distance + hole info
│   │   ├── HoleDistanceView.swift         # Front/center/back + hazard
│   │   ├── QuickScoreView.swift           # Digital Crown score entry
│   │   └── StandingsGlanceView.swift      # Top 5 leaderboard
│   ├── Services/
│   │   ├── PhoneConnectivityService.swift # transferUserInfo receiver
│   │   └── IndependentGPSService.swift    # Standalone GPS when phone away
│   └── Complications/
│       └── THCComplication.swift           # Rank + distance on watch face
├── Shared/                            # Shared between iOS + watchOS
│   ├── Models/
│   ├── PointsCalculator.swift
│   └── Constants.swift
└── THCTests/
    ├── PointsCalculatorTests.swift        # All points formula cases
    ├── DistanceCalculatorTests.swift      # Haversine + green edge tests
    ├── CourseDataServiceTests.swift       # OSM vs tap-and-save fallback
    ├── ScoreEntryTests.swift              # Net score, sync, dedup
    ├── TapAndSaveTests.swift              # Save/fetch/overwrite green pins
    └── GPXSimulation/                     # Simulated GPS for Xcode
        ├── TorreyPinesSouth.gpx
        └── LocalMuni.gpx
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Create Xcode project in `ios/` with iOS + watchOS targets
- [ ] Set up XCTest target and CI (GitHub Actions or local `xcodebuild test`)
- [ ] Set up Supabase Swift SDK + auth (Google OAuth via ASWebAuthenticationSession)
- [ ] Implement silent token refresh for long sessions (4-5 hour rounds)
- [ ] Implement data models matching existing Supabase schema
- [ ] Build standings/leaderboard view (read-only)
- [ ] Player profiles with round history
- [ ] Course search and favorites (manual course selection)

### Phase 2: Score Entry (Weeks 3-4)
- [ ] Post-round score entry form (matching web `/rounds/new`)
- [ ] Points calculation (port `points.ts` → `PointsCalculator.swift`)
- [ ] Unit tests: PointsCalculatorTests, ScoreEntryTests
- [ ] SwiftData for offline storage + Supabase sync
- [ ] Offline test: airplane mode → enter scores → reconnect → verify sync
- [ ] GHIN handicap display
- [ ] Per-hole stats: putts, FIR, GIR (optional fields)

### Phase 3: Golf GPS — Core (Weeks 5-8)
- [ ] CoreLocation setup + background tracking
- [ ] Course data service: check OSM first, then Supabase tap-and-save pins
- [ ] Tap-and-save: tap green on satellite map → "Save as Hole X?" → Supabase
- [ ] Tap-for-distance: tap any point on satellite map for instant yardage
- [ ] Pre-fetch OSM data and cache in SwiftData
- [ ] Unit tests: DistanceCalculatorTests, CourseDataServiceTests, TapAndSaveTests
- [ ] Hole overview screen (top-down view, primary GPS screen)
- [ ] Distance calculations: front/center/back of green (relative to line of play)
- [ ] Hazard distances: carry and front edge for bunkers/water
- [ ] Layup and dogleg target distances
- [ ] Auto-advance between holes by GPS proximity
- [ ] Tap-for-distance on any point on the map
- [ ] GPX simulation files (TorreyPinesSouth.gpx, LocalMuni.gpx)
- [ ] GPS simulation test: verify auto-detect, auto-advance, distance accuracy

### Phase 4: Apple Watch (Weeks 9-10)
- [ ] watchOS app with distance display (front/center/back + hazard)
- [ ] WatchConnectivity using `transferUserInfo` (guaranteed delivery)
- [ ] Independent GPS when phone not nearby
- [ ] Quick score entry (Digital Crown)
- [ ] Standings glance (top 5)
- [ ] Complication: current rank / distance to green on watch face

### Phase 5: Social + Polish (Weeks 11-13)
- [ ] Live round feed: see homies' active rounds hole-by-hole
- [ ] Round reactions and comments
- [ ] Season milestone push notifications
- [ ] Shareable round scorecard image
- [ ] Shot tracking with club distance averages (stretch goal)
- [ ] `BGAppRefreshTask` for background standings + course data refresh

---

## Backend Changes Needed

### Existing Table Changes
1. **`rounds.source`** — Add `"app"` value alongside `"manual"` and `"ghin"`

### New Tables
2. **`course_data`** — Course metadata (name, location, OSM link, who set it up)
3. **`course_holes`** — Per-hole data (green coords, tee coords, hazards, source)
4. **`hole_scores`** — Optional per-hole stats (putts, FIR, GIR) linked to rounds
5. **`round_reactions`** — Social reactions/comments on posted rounds
6. **`live_rounds`** — Active round state for live feed (ephemeral, cleaned up after round ends)

### No New API Endpoints
- iOS app uses Supabase Swift SDK directly (same `anon` key + RLS policies)
- Auth via `ASWebAuthenticationSession` — existing RLS policies work as-is
- Realtime subscriptions for live round feed (Supabase Realtime)

---

## Open Source Dependencies

| Package | Purpose | License |
|---------|---------|---------|
| [supabase-swift](https://github.com/supabase/supabase-swift) | Database + auth + realtime SDK | MIT |
| OpenStreetMap / Overpass API | Golf course geometry data | ODbL |
| CoreLocation (Apple) | GPS positioning | Built-in |
| MapKit (Apple) | Map rendering | Built-in |
| WatchConnectivity (Apple) | Phone ↔ Watch comms | Built-in |
| SwiftData (Apple) | Local persistence + offline | Built-in |
| BGTaskScheduler (Apple) | Background refresh | Built-in |

---

## Key Technical Risks

| Risk | Mitigation |
|------|-----------|
| **OSM data gaps** (most courses lack hole detail) | Tap-and-save: first round you tap greens on satellite map, app saves them, all future rounds have auto-distances. Zero pre-mapping needed. |
| **Overpass API latency** (2-10s per query) | Pre-fetch within 50km on app launch. Cache in SwiftData. Never wait for "arrival" to fetch. |
| **Apple Watch battery drain** | Reduce GPS polling when stationary. Warn at 30%. Typical: 30-50% per 18 holes. |
| **Offline play** (no cell signal on course) | SwiftData stores round + cached course data locally. Sync on reconnect. |
| **Front/back green accuracy** | Calculate relative to line of play (hole way), not user position. Fall back to nearest/farthest edge. |
| **Auth token expiry mid-round** | Silent refresh via Supabase SDK. Rounds save to SwiftData first, sync is secondary. |
| **WatchConnectivity message drops** | Use `transferUserInfo` (queued, guaranteed) for course data. `sendMessage` only for live updates when connected. |
| **SwiftData schema migration** | Version models from day one. Plan migration paths for course cache and local rounds. |
| **Tap-and-save accuracy** | Tapping on satellite view from the course is accurate to ~5-10 yards. Any user can re-tap to correct. Good enough for rec golfers. |

---

## Testing Strategy

### Unit Tests (XCTest, run in CI)

**PointsCalculatorTests.swift** — Port every case from `points.ts`:
```
- 6 under par → 15 (capped at max)
- 3 under par → 13
- even par → 10
- 5 over par → 5
- 9 over par → 1
- 10 over par → 1 (capped at min)
- 15 over par → 1 (floor holds)
```

**DistanceCalculatorTests.swift:**
```
- Haversine: known lat/lon pairs → expected distance in yards (verify against Google Maps)
- Front/back green: given green polygon + hole way → correct front/back points
- Front/back green: no polygon (tap-and-save) → returns center only, no front/back
- Edge case: user standing ON the green → distance ≈ 0
- Edge case: user 500+ yards away → reasonable number, no overflow
```

**CourseDataServiceTests.swift:**
```
- Course with OSM data → returns OSM polygons, source = 'osm'
- Course with tap-and-save data only → returns center points, source = 'tap_and_save'
- Course with no data → returns nil, triggers tap-and-save flow
- Course with both OSM + tap-and-save → prefers OSM
- GolfCourseAPI search → returns course metadata (mock HTTP)
- GolfCourseAPI rate limit (300/day) → graceful error, cached results
```

**ScoreEntryTests.swift:**
```
- Net score calculation: gross 95, handicap 18 → net 77
- Net vs par: net 77, par 72 → +5
- Points from net vs par: +5 → 5 points
- Round saves to SwiftData when offline
- Round syncs to Supabase when online
- Duplicate prevention: same round doesn't post twice
```

**TapAndSaveTests.swift:**
```
- Tap coordinate saves to course_holes with correct hole_number
- Saved green is available to all users (Supabase query returns it)
- Re-tap overwrites previous green location
- Saved green persists across app restarts (SwiftData cache)
```

### Integration Tests

**Supabase Integration (run against test/staging environment):**
```
- Auth: Google OAuth → valid session → fetch player data
- Post round: create round → verify it appears in standings
- Course data: save tap-and-save pin → fetch from another client → pin is there
- Token refresh: simulate expired token → silent refresh → operation succeeds
```

### GPS Simulation Tests (Xcode, manual)

**GPX simulation files** for testing without being on a course:
- `TorreyPinesSouth.gpx` — Walk-through of 18 holes with known coordinates
- `LocalMuni.gpx` — A course with no OSM data (tests tap-and-save flow)
- `StationaryOnGreen.gpx` — User stays on green for 3 min (tests no-crash edge case)

**Test scenarios with GPX files:**
```
- Auto-detect course: simulated location near Torrey Pines → app suggests correct course
- Auto-advance: GPS moves from hole 1 green area to hole 2 tee → app advances to hole 2
- Distance accuracy: known position → known green → expected distance ±5 yards
- Background GPS: app backgrounded → returns to foreground → location still tracking
- Battery: monitor energy usage during simulated 18-hole walk
```

### Apple Watch Tests (Xcode, manual on simulator + device)

```
- WatchConnectivity: send course data phone → watch → verify arrival
- Independent GPS: disconnect phone → watch GPS activates → distances show
- Quick score: Digital Crown → select score → verify saved locally
- Complication: displays current rank from cached standings data
```

### Offline Tests (manual)

```
- Airplane mode on: enter scores for 18 holes → all saved locally
- Airplane mode off: scores sync to Supabase → appear in standings
- Conflict: score entered on watch + phone for same hole → last write wins
- Cache: course data cached → airplane mode → course still loads
```

### What NOT to Test (keep it simple for 10 users)

- No load testing (10 users won't stress Supabase)
- No A/B testing
- No accessibility automation (do manual checks instead)
- No screenshot testing

---

## Gap Analysis

### vs. Existing Golf GPS Apps (Golfshot, Arccos, 18Birdies, Hole19)

| Feature | Commercial Apps | THC Plan | Gap |
|---------|----------------|----------|-----|
| Course coverage | 40,000+ with full GPS | OSM (~5-10k full) + tap-and-save | **Medium.** First round at unmapped courses requires tapping greens. Acceptable for 10 users who replay same courses. |
| Front/center/back of green | Yes, surveyed data | OSM courses only; tap-and-save = center only | **Low.** Center distance is what matters most. Rec golfers rarely club based on front vs back. |
| 3D flyover / elevation | Yes | No | **Acceptable skip.** Nice-to-have, not core for rec golfers. Satellite view is sufficient. |
| Club recommendations | Yes (AI/ML based) | No | **Acceptable skip.** Would need shot tracking data + ML. Not worth it for 10 users. |
| Automatic shot tracking (Arccos sensors) | Yes (hardware) | No (manual tap) | **Acceptable skip.** Requires $200 hardware. Manual tap is fine for casual use. |
| Apple Watch standalone | Yes | Yes | **No gap.** |
| Strokes gained analytics | Yes | No | **Acceptable skip for now.** Could add later with per-hole stats data. |
| Social / group features | Basic (Hole19 has some) | Strong — Homie Cup, live feed, reactions | **THC advantage.** The friend group social is the differentiator. |
| Score posting to GHIN | Yes | Via existing GHIN sync (server-side) | **No gap.** |
| Handicap tracking | Yes | Yes (via GHIN) | **No gap.** |
| Cost to user | $30-100/year subscription | Free | **THC advantage.** |

### vs. Current THC Web App

| Feature | Web App | iOS Plan | Gap to Close |
|---------|---------|----------|-------------|
| View standings | Yes | Yes | None |
| View player profiles | Yes | Yes | None |
| Post scores manually | Yes | Yes + per-hole stats | iOS is better |
| GHIN auto-sync | Yes (server cron) | Yes (same backend) | None |
| Golf GPS | No | Yes | New feature |
| Apple Watch | No | Yes | New feature |
| Live round tracking | No | Yes | New feature |
| Social (reactions, feed) | No | Yes | New feature |
| Offline support | No (web only) | Yes (SwiftData) | iOS is better |
| Push notifications | No | Yes | New feature |

### Gaps in the Current Plan (Things Missing)

| Gap | Severity | Recommendation |
|-----|----------|---------------|
| **No Android app** | None | All 10 users have iPhones. Web app remains as desktop/backup. |
| **No web app GPS** | Low | Web app stays for desktop standings viewing. GPS is a mobile-only feature. |
| **No penalty stroke tracking** | Low | Rec golfers usually just count total strokes. Could add later. |
| **No tournament/event mode** | Low | The Homie Cup IS the tournament. Per-round competitions (skins, nassau) could be a future feature. |
| **No caddie/club recommendation** | Low | Requires shot tracking + ML. Not viable for 10 users. |
| **No photo/video per hole** | Low | "Pic on 16 at Pebble" would be fun but is scope creep. Could add to social feed later. |
| **No Apple Watch Ultra depth** | None | Standard Apple Watch GPS is sufficient. |
| **GolfCourseAPI rate limit** | Low | 300 req/day free tier is plenty for 10 users. Monitor and upgrade to $7/mo if needed. |
| **App Store distribution** | None | TestFlight distribution (invite-only, no App Store review). Requires Apple Developer account ($99/year). |
| **No iPad optimization** | Low | SwiftUI will run on iPad but won't be optimized for larger screen. Fine for 10 users. |

### Data / Privacy Gaps

| Gap | Recommendation |
|-----|---------------|
| GPS tracking during rounds | Add privacy disclosure in app + App Store listing. Only track during active round. |
| Supabase RLS for course_data | All users can read course data. Only authenticated users can write. Any user can edit any green pin (small trust group). |
| GolfCourseAPI key in app binary | Store in Supabase and fetch at runtime, or use a thin server-side proxy. Don't ship API keys in the app bundle. |
| GHIN credentials | Already server-side only (Vercel env vars). iOS app doesn't touch these. |

---

## References

- [OSM Golf Tagging](https://wiki.openstreetmap.org/wiki/Key:golf)
- [osmgolf (reference implementation)](https://github.com/leif81/osmgolf)
- [GolfPS-Android (open source GPS app)](https://github.com/DeJong-Development/GolfPS-Android)
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
- [Golf Quartz (Apple Watch golf app)](https://creaceed.com/blog/2024/06/golf-quartz-a-new-golfing-app-made-for-apple-watch/)
- [CoreLocation docs](https://developer.apple.com/documentation/corelocation)
- [GolfCourseAPI.com (free)](https://golfcourseapi.com/)
- [Overpass API examples](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_API_by_Example)
