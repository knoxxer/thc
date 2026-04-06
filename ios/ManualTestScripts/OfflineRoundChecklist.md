# Offline Round Manual Test Checklist

**When to run:** Before every TestFlight build.
**Device requirements:** Physical iPhone. No simulator (need real network on/off capability).
**Duration:** ~30 minutes

---

## Prerequisites

- [ ] Device has Supabase staging credentials configured
- [ ] At least one course is cached in the app from a previous session
  - If not: go online, open the app, select Torrey Pines South, let it cache, then proceed
- [ ] Previous round data (if any) is already synced — check Supabase dashboard
- [ ] Note the current standings to verify changes after sync

---

## Test A: Full Offline Round

### A1. Start in Airplane Mode

- [ ] Enable Airplane Mode on device
- [ ] Launch THC app
- [ ] Verify "Offline" indicator appears (or no connectivity badge)
- [ ] Verify the app does NOT crash on launch without network

### A2. Start Round Offline

- [ ] Tap "Start Round"
- [ ] Select a course from cached list (Torrey Pines South)
- [ ] Verify course data loads from SwiftData cache (no "Loading..." spinner hang)
- [ ] Start round — verify hole overview appears with distances

**Expected:** Distances appear within 3 seconds, no network required.

### A3. Enter 9 Holes Offline

- [ ] Enter scores for holes 1-9 manually
  - Suggested scores: 5, 4, 6, 4, 5, 3, 4, 5, 4 (total gross = 40)
- [ ] After each score, verify the running scorecard updates
- [ ] After Hole 9: tap "Finish Round"

**Expected:**
- [ ] Score entry works offline
- [ ] "Round saved locally" or similar confirmation shown
- [ ] NO Supabase call attempted (verify via Xcode network inspector or no error)

### A4. Verify SwiftData Persistence

- [ ] Force-quit and relaunch the app (still in Airplane Mode)
- [ ] Navigate to rounds history or debug menu

**Expected:**
- [ ] The 9-hole round is visible in the app
- [ ] syncStatus shows "Pending" / unsynced

*(Developer: can verify in Xcode → Debug → View Hierarchy or add a debug menu showing unsynced count)*

---

## Test B: Sync on Reconnect

### B1. Disable Airplane Mode

- [ ] Disable Airplane Mode
- [ ] Wait up to 30 seconds (background sync should trigger automatically)

**Expected:**
- [ ] Sync animation or indicator appears
- [ ] "Synced" status appears
- [ ] Count of pending rounds goes to 0

### B2. Verify in Supabase Dashboard

- [ ] Open Supabase dashboard → rounds table
- [ ] Sort by created_at DESC
- [ ] Find the round you just submitted

**Expected:**
- [ ] Round appears with correct gross score, course name, date
- [ ] `source` column = `"app"`
- [ ] `net_score`, `net_vs_par`, `points` calculated correctly

### B3. Verify Standings Update

- [ ] Open Standings tab in the app
- [ ] Pull to refresh

**Expected:**
- [ ] Points from the offline round appear in your standing
- [ ] Rank updates if points moved you up the leaderboard

---

## Test C: Cache Miss in Airplane Mode

- [ ] Clear app data or use a device with no previously cached courses
- [ ] Enable Airplane Mode
- [ ] Open app and attempt to start a round

**Expected:**
- [ ] App shows a clear "No course data available — connect to the internet to load courses" message
- [ ] Does NOT crash
- [ ] Does NOT show a blank screen or infinite spinner

---

## Test D: Partial Sync (Interrupted)

### D1. Set Up

- [ ] While offline, create 2 rounds (enter and finish each separately)
- [ ] Confirm both show as "Pending" in the app

### D2. Interrupt Sync

- [ ] Enable network access
- [ ] Immediately force-quit the app (within 1-2 seconds of sync starting)
- [ ] Re-launch the app

**Expected:**
- [ ] No duplicate rounds in Supabase (at most 1 of the 2 may have synced)
- [ ] The unsynced round is still marked as pending
- [ ] Subsequent auto-sync completes cleanly

---

## Test E: Stale Course Cache Forces Refresh

*Requires manipulation of SwiftData timestamps — developer-only test.*

- [ ] Using Xcode debugger or a debug menu, set a course's `lastFetched` to 8 days ago
- [ ] Re-open the app with network available
- [ ] Navigate to that course

**Expected:**
- [ ] App makes a network request for fresh course data
- [ ] Stale cache is replaced with fresh data
- [ ] No visual glitch or double-fetch

---

## Sign-Off

| Tester | Date | Build | Pass/Fail | Notes |
|--------|------|-------|-----------|-------|
|        |      |       |           |       |
