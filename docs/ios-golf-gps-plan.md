# THC iOS App — Golf GPS + Scoring + Homie Cup Standings

## Overview

Transform THC from a Next.js web app into a native iOS + Apple Watch app with:
1. **Golf course GPS** — distances to green/hazards on phone and watch
2. **Score entry** — post rounds directly from the course
3. **Homie Cup standings** — leaderboard and player stats

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
| Course Data | OpenStreetMap via Overpass API (free, open source) |
| Local Storage | SwiftData (offline rounds, cached course data) |
| Watch Comms | WatchConnectivity framework |

---

## Course GPS Data: OpenStreetMap

**Why OSM over commercial APIs:**
- Free and open source — no per-request costs
- Community-maintained with ~35,000+ golf courses mapped worldwide
- Rich data: holes, greens, fairways, bunkers, water hazards, tee boxes
- Overpass API provides real-time queries by bounding box

### OSM Golf Data Model

OpenStreetMap tags golf features as:
- `leisure=golf_course` — the overall course boundary
- `golf=hole` — a way (line) from tee to green, tagged with `ref` (hole number) and `par`
- `golf=green` — polygon for each putting green
- `golf=tee` — polygon for tee boxes
- `golf=fairway` — polygon for fairway areas
- `golf=bunker` — polygon for sand traps
- `natural=water` + `golf=water_hazard` — water hazards
- `golf=driving_range`, `golf=practice` — practice areas

### Sample Overpass Query

```
[out:json][timeout:25];
// Find golf course by proximity to user
way["leisure"="golf_course"](around:5000, {lat}, {lon});
out body;
>;
out skel qt;

// Then fetch all golf features within that course
// golf=green, golf=hole, golf=fairway, golf=bunker, golf=tee
```

### Data Strategy

1. **On-demand fetch** — When user arrives at a course, query Overpass API for features within ~2km
2. **Local cache** — Store fetched course data in SwiftData; courses rarely change
3. **Fallback** — If OSM data is sparse for a course, allow manual pin-drop for green location
4. **Supplement with GolfCourseAPI.com** — Free API with ~30,000 courses for name/metadata lookup

---

## Feature Breakdown

### 1. Golf GPS (iOS + Apple Watch)

**Core experience: distance from current position to center/front/back of green.**

#### iOS App
- Map view showing current hole with fairway, bunkers, water, green overlays
- Distance callouts: front/center/back of green, layup targets
- Auto-advance to next hole based on GPS proximity to green
- Hole-by-hole view with par, handicap stroke index
- Shot tracking (optional): tap to mark shot location

#### Apple Watch App
- Glanceable distances: front/center/back of green
- Current hole number and par
- Auto-advance between holes
- Quick score entry per hole
- Complication for active round (distance to green)

#### GPS Implementation
```
CLLocationManager (kCLLocationAccuracyBest)
├── iPhone: streams location updates to map + calculates distances
├── Apple Watch: independent GPS when phone not nearby
└── WatchConnectivity: syncs course data phone → watch
```

**Distance calculation:** Haversine formula between `CLLocationCoordinate2D` (user) and green centroid/edges from OSM polygon data.

**Battery considerations:**
- Use `allowsBackgroundLocationUpdates` for continuous tracking during round
- Reduce update frequency when user is stationary (< 2mph)
- Typical 18-hole round: ~30-50% Apple Watch battery drain with GPS

### 2. Score Entry

**Score entry works both on-course and post-round.**

#### On-Course (Live Scoring)
- After each hole auto-advances, prompt for score
- Apple Watch: Digital Crown to select score, tap to confirm
- iPhone: tap score selector on hole summary screen
- Scores saved locally (SwiftData) and synced to Supabase when online

#### Post-Round Entry
- Same flow as current web app `/rounds/new`
- Course name, tee, gross score, course handicap
- Auto-lookup course details from OSM/GolfCourseAPI
- Calculate net score and points client-side

#### Data Flow
```
Score Entry (iOS/Watch)
  → SwiftData (local, offline-safe)
  → Supabase `rounds` table (source: "app")
  → Points calculated (same formula: max(1, min(15, 10 - netVsPar)))
  → Season standings update
```

### 3. Homie Cup Standings

- Leaderboard tab matching web app functionality
- Player profiles with round history
- Season stats: total rounds, best 10 points, eligibility status
- Pull-to-refresh from Supabase
- Push notifications for standings changes (optional, future)

#### Apple Watch Complication
- Show current rank and points total
- Tap to open standings list

---

## Xcode Project Structure

```
THC/
├── THC.xcodeproj
├── THC/                          # iOS App Target
│   ├── App/
│   │   ├── THCApp.swift          # App entry point
│   │   └── ContentView.swift     # Tab-based root view
│   ├── Features/
│   │   ├── GPS/
│   │   │   ├── CourseMapView.swift
│   │   │   ├── HoleView.swift
│   │   │   ├── DistanceOverlay.swift
│   │   │   └── LocationManager.swift
│   │   ├── Scoring/
│   │   │   ├── LiveScoringView.swift
│   │   │   ├── PostRoundView.swift
│   │   │   └── ScoreEntryViewModel.swift
│   │   ├── Standings/
│   │   │   ├── LeaderboardView.swift
│   │   │   ├── PlayerDetailView.swift
│   │   │   └── StandingsViewModel.swift
│   │   └── Auth/
│   │       ├── LoginView.swift
│   │       └── AuthManager.swift
│   ├── Services/
│   │   ├── SupabaseClient.swift
│   │   ├── CourseDataService.swift  # OSM Overpass queries
│   │   ├── GHINService.swift
│   │   └── WatchSyncService.swift
│   ├── Models/
│   │   ├── Player.swift
│   │   ├── Round.swift
│   │   ├── Season.swift
│   │   ├── Course.swift            # OSM course data
│   │   └── Hole.swift
│   └── Utilities/
│       ├── DistanceCalculator.swift
│       └── PointsCalculator.swift
├── THCWatch/                     # watchOS App Target
│   ├── THCWatchApp.swift
│   ├── Views/
│   │   ├── ActiveRoundView.swift
│   │   ├── HoleDistanceView.swift
│   │   ├── QuickScoreView.swift
│   │   └── StandingsGlanceView.swift
│   ├── Services/
│   │   └── PhoneConnectivityService.swift
│   └── Complications/
│       └── THCComplication.swift
├── Shared/                       # Shared between iOS + watchOS
│   ├── Models/
│   ├── PointsCalculator.swift
│   └── Constants.swift
└── THCTests/
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Create Xcode project with iOS + watchOS targets
- [ ] Set up Supabase Swift SDK + auth (Google OAuth)
- [ ] Implement data models matching existing Supabase schema
- [ ] Build standings/leaderboard view (read-only)
- [ ] Player profiles and round history

### Phase 2: Score Entry (Weeks 3-4)
- [ ] Post-round score entry form (matching web app)
- [ ] Points calculation (port `points.ts` to Swift)
- [ ] SwiftData for offline storage + sync
- [ ] GHIN handicap display

### Phase 3: Golf GPS (Weeks 5-8)
- [ ] CoreLocation setup + background tracking
- [ ] Overpass API integration for course data
- [ ] Course detection (nearest course to user location)
- [ ] Map view with hole overlays (green, fairway, bunker polygons)
- [ ] Distance calculations (front/center/back of green)
- [ ] Auto-advance between holes
- [ ] Local course data caching

### Phase 4: Apple Watch (Weeks 9-10)
- [ ] watchOS app with distance display
- [ ] WatchConnectivity for course data sync
- [ ] Quick score entry on watch
- [ ] Standings glance
- [ ] Complication (current rank / distance to green)

### Phase 5: Live Scoring Integration (Weeks 11-12)
- [ ] On-course score entry after each hole
- [ ] Hole-by-hole score → round summary → Supabase sync
- [ ] Score source: `"app"` alongside existing `"manual"` and `"ghin"`
- [ ] Push notifications (optional)

---

## Backend Changes Needed

Minimal changes to existing Supabase backend:

1. **New `source` value** — Add `"app"` to the `rounds.source` enum alongside `"manual"` and `"ghin"`
2. **API access** — iOS app uses Supabase Swift SDK directly (same `anon` key + RLS policies)
3. **Auth** — Supabase supports native Google OAuth via `ASWebAuthenticationSession`; existing RLS policies work as-is
4. **No new API endpoints needed** — Supabase client SDK handles all CRUD operations

---

## Open Source Dependencies

| Package | Purpose | License |
|---------|---------|---------|
| [supabase-swift](https://github.com/supabase/supabase-swift) | Database + auth SDK | MIT |
| OpenStreetMap / Overpass API | Golf course geometry data | ODbL |
| CoreLocation (Apple) | GPS positioning | Built-in |
| MapKit (Apple) | Map rendering | Built-in |
| WatchConnectivity (Apple) | Phone ↔ Watch comms | Built-in |

---

## Key Technical Risks

| Risk | Mitigation |
|------|-----------|
| OSM golf data coverage gaps | Allow manual green pin-drop; supplement with GolfCourseAPI.com |
| Apple Watch battery drain | Reduce GPS update frequency when stationary; show battery warning |
| Offline play (no signal) | SwiftData stores round locally; sync when back online |
| Overpass API rate limits | Cache aggressively; courses don't change often |
| Green polygon accuracy | Use centroid for center distance; front/back from polygon edges |

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
