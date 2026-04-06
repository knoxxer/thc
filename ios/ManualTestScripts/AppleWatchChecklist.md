# Apple Watch Manual Test Checklist

**When to run:** Before every TestFlight build and production release.
**Device requirements:** Physical Apple Watch (Series 4+ recommended) paired to test iPhone.
**Duration:** ~45 minutes

---

## Prerequisites

- [ ] Apple Watch is charged to at least 50%
- [ ] iPhone and Watch are paired and both have THC app installed
- [ ] Test account has at least 1 round submitted (for standings display)
- [ ] A known golf course is selected and cached (or use Torrey Pines South)
- [ ] Both apps are force-quit before starting

---

## 1. Initial Pairing + App Launch

- [ ] Open THC app on iPhone — verify it launches without crash
- [ ] Open THCWatch app cold (not pre-launched, from Watch crown)
- [ ] Verify watch app shows loading state then displays standing/distance screen

**Expected:** Watch app loads within 15 seconds of iPhone app being active.

---

## 2. Course Data Sync to Watch

- [ ] On iPhone: select "Torrey Pines South" (or any cached course)
- [ ] Tap "Start Round"
- [ ] Observe watch face

**Expected within 30 seconds:**
- [ ] Watch displays current hole number (Hole 1)
- [ ] Watch displays front/center/back distances (e.g., "F 145 | C 162 | B 178")
- [ ] Watch displays par for current hole

**Failure mode to watch for:** Watch still showing "Waiting for course data..."

---

## 3. Distance Updates While Walking

- [ ] Walk 50 yards toward the green
- [ ] Observe watch display

**Expected:**
- [ ] Distance to green decreases by approximately 50 yards
- [ ] Center distance updates within 5 seconds of stopping
- [ ] No negative distances displayed

---

## 4. Hole Advance Sync

- [ ] On iPhone: complete hole 1 (enter score)
- [ ] Walk to hole 2 tee area (within 30 yards)

**Expected:**
- [ ] iPhone auto-advances to Hole 2
- [ ] Watch reflects Hole 2 within 10 seconds
- [ ] Watch distances update to Hole 2 green

---

## 5. Score Entry via Digital Crown

- [ ] On watch: Crown → LiveScoringView for current hole
- [ ] Scroll Digital Crown to select stroke count (e.g., 4)
- [ ] Confirm score with tap

**Expected:**
- [ ] Score appears on iPhone's running scorecard within 30 seconds
- [ ] Hole is marked as scored on both devices
- [ ] No duplicate score entry

---

## 6. Conflict Resolution

- [ ] Enter score "4" on watch for Hole 3
- [ ] Immediately enter score "5" on iPhone for Hole 3 (within 5 seconds)

**Expected:**
- [ ] After sync, exactly ONE score is recorded
- [ ] The more recent entry (iPhone "5") should win (last-write-wins by timestamp)
- [ ] No error message, no crash

---

## 7. Standalone GPS (Phone Disconnected)

- [ ] Start a round on iPhone
- [ ] Move iPhone 10+ meters away or turn Bluetooth off on iPhone
- [ ] Observe watch

**Expected:**
- [ ] Watch detects phone is not reachable
- [ ] IndependentGPSService activates (may take up to 30 seconds)
- [ ] Distances continue to display using watch GPS
- [ ] Watch does not show "disconnected" error indefinitely

---

## 8. Reconnect After Standalone

- [ ] Bring iPhone back within Bluetooth range (or re-enable Bluetooth)

**Expected:**
- [ ] No duplicate data created
- [ ] Scores entered on watch while disconnected appear on iPhone
- [ ] Distance source reverts to iPhone GPS (if more accurate)

---

## 9. Standings Glance

- [ ] Open THCWatch Standings view (swipe or complication tap)

**Expected:**
- [ ] Top 5 players displayed with ranks and point totals
- [ ] Data matches iPhone standings view
- [ ] Your own rank highlighted

---

## 10. Watch Face Complication

- [ ] Add THC complication to watch face (if not already present)
- [ ] Stand in an active round near a green

**Expected:**
- [ ] Complication shows current rank
- [ ] Complication shows distance to green (updates within 60 seconds)

---

## 11. Low Battery Warning

- [ ] During a round, let Watch battery drain to below 30%
  *(Or use simulator with mock battery level = 0.30)*

**Expected:**
- [ ] iPhone displays a notification: "Watch battery below 30%"
- [ ] GPS continues (no automatic shutdown)
- [ ] Warning does not repeat every minute (only once per threshold crossing)

---

## 12. Edge Cases

- [ ] Lock watch screen during active round — unlock and verify distances still update
- [ ] Receive a phone call during active round — verify round data not lost
- [ ] Watch face times out (goes dark) during active round — tap to wake — verify distances current

---

## Sign-Off

| Tester | Date | Build | Pass/Fail | Notes |
|--------|------|-------|-----------|-------|
|        |      |       |           |       |
