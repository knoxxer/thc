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

## Course Data Strategy: Solving the Data Gap

### The Problem

OSM claims ~35,000 golf courses, but most only have an outer boundary (`leisure=golf_course`). Detailed hole-level data — green polygons, fairways, bunkers — exists for maybe 5,000–10,000 courses. Your users will inevitably show up at a course with no usable data.

### Solution: Tiered Data with Passive Crowdsourcing

The app uses a **three-tier data system**. Every course falls into one of these tiers, and the app adapts its experience accordingly. Over time, courses automatically graduate to higher tiers as users play them.

#### Tier 1: Full Map Data (Best Experience)
- **Source:** OSM green polygons, hole ways, fairway/bunker/water polygons
- **Experience:** Full map view with overlays, front/center/back of green, hazard distances, hole flyover
- **Coverage:** ~5,000–10,000 courses worldwide (mostly major/popular courses)

#### Tier 2: Green Center Points Only (Good Experience)
- **Source:** User-contributed pin drops, GolfCourseAPI.com metadata, or inferred from passive GPS traces
- **Experience:** Distance to center of green per hole, no map overlays, no hazard distances
- **Coverage:** Grows with every round played on the app

#### Tier 3: No Data — Guided Setup (Functional Experience)
- **Source:** The user maps the course as they play their first round
- **Experience:** On hole 1, app says "Tap to mark the green." User drops a pin on the green from the tee or fairway. That pin is saved. By hole 18, the course has Tier 2 data for all future rounds.
- **Coverage:** Any course in the world, first round

### Passive Crowdsourcing: How Data Improves Automatically

Every round played with GPS tracking contributes to the course database — **without the user doing anything extra:**

1. **Green detection** — When a user's GPS shows them stationary for 2+ minutes in a small area (putting), that location is inferred as a green center point. Multiple users' putting locations refine the green polygon over time.

2. **Tee box detection** — The location where a user starts each hole (first movement after being stationary near the previous green) maps tee box positions.

3. **Fairway corridors** — GPS traces of walking/cart paths between tee and green outline the playable corridor. Aggregate traces from multiple rounds reveal fairway shapes.

4. **Hole sequencing** — The order users walk between greens and tees reveals the hole routing (which green connects to which tee).

5. **Hazard inference** — Areas where users consistently walk around (never through) suggest water/OB. Areas with brief stops near greens suggest bunkers. These are lower confidence and would need manual confirmation.

All passive data is:
- **Anonymized** — stored as course geometry, not tied to individual users
- **Aggregated** — requires multiple users/rounds before promoting to shared data
- **Stored in Supabase** — new `course_data` and `course_contributions` tables
- **Versioned** — so bad data can be rolled back

### Data Sources (Layered)

| Source | What It Provides | Cost |
|--------|-----------------|------|
| OpenStreetMap / Overpass API | Full geometry (greens, fairways, bunkers, holes) for well-mapped courses | Free (ODbL) |
| GolfCourseAPI.com | Course name, address, hole count, par for ~30,000 courses | Free |
| User pin drops (Tier 3 guided setup) | Green center points | Free (user-contributed) |
| Passive GPS crowdsourcing | Green locations, tee boxes, fairway corridors, hole routing | Free (automatic) |
| THC community corrections | Fix bad green pins, flag incorrect data | Free (in-app) |

### Pre-fetching Strategy

Don't wait for the user to arrive at a course:
- On app launch, pre-fetch OSM data for courses within 50km of the user's location
- Cache course data in SwiftData — courses rarely change
- When a user selects a course manually (from search), fetch and cache immediately
- Background refresh via `BGAppRefreshTask` to keep cached courses current

### Course Selection UX

Don't rely solely on auto-detection:
- **Auto-detect** — On app open near a course, suggest "Looks like you're at Pebble Beach. Start round?"
- **Manual search** — Search by name, browse nearby courses, recent courses list
- **Favorites** — Pin your home course(s) for instant access
- **Handle multi-course locations** — At a resort with 3 courses, show a picker

### New Supabase Tables for Course Data

```sql
-- Course metadata (seeded from GolfCourseAPI, enriched over time)
course_data (
  id uuid primary key,
  name text,
  address text,
  lat double precision,
  lon double precision,
  hole_count int,
  par int,
  osm_id text,                    -- link to OSM if available
  data_tier int default 3,        -- 1=full, 2=points, 3=none
  created_at timestamptz,
  updated_at timestamptz
)

-- Per-hole data (from OSM, user pins, or crowdsourcing)
course_holes (
  id uuid primary key,
  course_id uuid references course_data,
  hole_number int,
  par int,
  green_lat double precision,     -- center of green
  green_lon double precision,
  green_polygon jsonb,            -- GeoJSON polygon if available
  tee_lat double precision,
  tee_lon double precision,
  fairway_polygon jsonb,
  hazards jsonb,                  -- array of {type, polygon/point}
  source text,                    -- 'osm', 'user_pin', 'crowdsourced'
  confidence float default 0,     -- 0-1, increases with more data points
  created_at timestamptz,
  updated_at timestamptz
)

-- Raw GPS contributions (anonymized, used to refine course_holes)
course_contributions (
  id uuid primary key,
  course_id uuid references course_data,
  hole_number int,
  contribution_type text,         -- 'green_location', 'tee_location', 'gps_trace'
  lat double precision,
  lon double precision,
  geometry jsonb,                 -- for traces/polygons
  created_at timestamptz
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

#### Social Features
- **Live round feed** — see when a homie is playing and their hole-by-hole score as it happens
- **Round reactions** — react to a buddy's posted round ("nice round" / trash talk)
- **Season milestones** — push notifications: "Jake just took the #1 spot", "You need 2 more rounds to qualify"
- **Share card** — generate a shareable image of your round scorecard for texts/social

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
│   │   │   ├── CourseSearchView.swift     # Search/browse/favorites
│   │   │   ├── GuidedPinDropView.swift    # Tier 3: map greens as you play
│   │   │   └── CourseCorrectionView.swift # Fix bad pins/data
│   │   └── Auth/
│   │       ├── LoginView.swift
│   │       └── AuthManager.swift          # Token refresh during long rounds
│   ├── Services/
│   │   ├── SupabaseClient.swift           # Auth + data, with silent token refresh
│   │   ├── CourseDataService.swift        # Multi-source: OSM + API + crowdsourced
│   │   ├── CrowdsourceService.swift       # Passive GPS trace collection
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
    ├── PointsCalculatorTests.swift        # Port of points.ts logic
    ├── DistanceCalculatorTests.swift      # Haversine + green edge tests
    ├── CourseDataServiceTests.swift       # Tier fallback logic
    └── GPXSimulation/                     # Simulated GPS tracks for testing
        ├── PebbleBeach.gpx
        └── LocalMuni.gpx
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Create Xcode project in `ios/` with iOS + watchOS targets
- [ ] Set up Supabase Swift SDK + auth (Google OAuth via ASWebAuthenticationSession)
- [ ] Implement silent token refresh for long sessions (4-5 hour rounds)
- [ ] Implement data models matching existing Supabase schema
- [ ] Build standings/leaderboard view (read-only)
- [ ] Player profiles with round history
- [ ] Course search and favorites (manual course selection)

### Phase 2: Score Entry (Weeks 3-4)
- [ ] Post-round score entry form (matching web `/rounds/new`)
- [ ] Points calculation (port `points.ts` → `PointsCalculator.swift`)
- [ ] SwiftData for offline storage + Supabase sync
- [ ] GHIN handicap display
- [ ] Per-hole stats: putts, FIR, GIR (optional fields)
- [ ] Unit tests for points calculation

### Phase 3: Golf GPS — Core (Weeks 5-8)
- [ ] CoreLocation setup + background tracking
- [ ] Multi-source course data: Overpass API + GolfCourseAPI.com + Supabase
- [ ] Tier detection: determine data quality for each course
- [ ] Tier 3 guided setup: pin-drop greens as you play
- [ ] Pre-fetch courses within 50km on app launch
- [ ] Local course caching in SwiftData (with schema migration plan)
- [ ] Hole overview screen (top-down view, primary GPS screen)
- [ ] Distance calculations: front/center/back of green (relative to line of play)
- [ ] Hazard distances: carry and front edge for bunkers/water
- [ ] Layup and dogleg target distances
- [ ] Auto-advance between holes by GPS proximity
- [ ] Tap-for-distance on any point on the map
- [ ] GPX simulation files for testing (Xcode location simulation)

### Phase 4: Apple Watch (Weeks 9-10)
- [ ] watchOS app with distance display (front/center/back + hazard)
- [ ] WatchConnectivity using `transferUserInfo` (guaranteed delivery)
- [ ] Independent GPS when phone not nearby
- [ ] Quick score entry (Digital Crown)
- [ ] Standings glance (top 5)
- [ ] Complication: current rank / distance to green on watch face

### Phase 5: Crowdsourcing + Social (Weeks 11-14)
- [ ] Passive GPS crowdsourcing: collect traces, infer green/tee locations
- [ ] Supabase tables: `course_data`, `course_holes`, `course_contributions`
- [ ] Community corrections: flag bad data, submit fixes
- [ ] Confidence scoring: promote crowdsourced data after N confirmations
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
2. **`course_data`** — Course metadata (name, location, data tier, OSM link)
3. **`course_holes`** — Per-hole data (green coords, tee coords, hazards, source, confidence)
4. **`course_contributions`** — Raw anonymized GPS contributions for crowdsourcing
5. **`hole_scores`** — Optional per-hole stats (putts, FIR, GIR) linked to rounds
6. **`round_reactions`** — Social reactions/comments on posted rounds
7. **`live_rounds`** — Active round state for live feed (ephemeral, cleaned up after round ends)

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
| **OSM data gaps** (most courses lack hole detail) | Three-tier system: full OSM → green points → guided pin-drop. Passive crowdsourcing fills gaps over time. |
| **Overpass API latency** (2-10s per query) | Pre-fetch within 50km on app launch. Cache in SwiftData. Never wait for "arrival" to fetch. |
| **Apple Watch battery drain** | Reduce GPS polling when stationary. Warn at 30%. Typical: 30-50% per 18 holes. |
| **Offline play** (no cell signal on course) | SwiftData stores round + cached course data locally. Sync on reconnect. |
| **Front/back green accuracy** | Calculate relative to line of play (hole way), not user position. Fall back to nearest/farthest edge. |
| **Auth token expiry mid-round** | Silent refresh via Supabase SDK. Rounds save to SwiftData first, sync is secondary. |
| **WatchConnectivity message drops** | Use `transferUserInfo` (queued, guaranteed) for course data. `sendMessage` only for live updates when connected. |
| **SwiftData schema migration** | Version models from day one. Plan migration paths for course cache and local rounds. |
| **Crowdsourced data quality** | Require N independent confirmations before promoting. Allow community flagging. Versioned data for rollback. |

---

## Testing Strategy

| Area | Approach |
|------|----------|
| Points calculation | Unit tests porting all cases from `points.ts` |
| Distance math | Unit tests for Haversine, front/back green edge, hazard carry |
| Course data tiers | Unit tests for tier detection and fallback logic |
| GPS on course | Xcode GPX simulation files with real course coordinates |
| Offline sync | Test with airplane mode: enter scores, reconnect, verify sync |
| Watch connectivity | Test with phone nearby and phone away (independent GPS) |
| Crowdsourcing | Simulate multiple users' GPS traces → verify green inference |

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
