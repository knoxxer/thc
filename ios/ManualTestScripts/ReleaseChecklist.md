# Release Checklist — THC iOS App

**When to run:** Before every TestFlight distribution and production App Store submission.
**Performed by:** Release manager + at least one other tester.
**Duration:** ~2 hours

---

## Phase 1: Pre-Archive Verification

### 1.1 Code Quality Gates

- [ ] All P0 unit tests pass (run `xcodebuild test -scheme THCTests -testPlan UnitAndService`)
- [ ] All service tests pass
- [ ] No compiler warnings in the THC target
- [ ] GPX simulation tests pass: TorreyPinesSouth distances within ±10 yards
- [ ] Code coverage >= 70% on core modules (PointsCalculator, DistanceCalculator, ScoreEntry)

### 1.2 Static Checks

- [ ] `Secrets.plist` is in `.gitignore` and NOT in the archive
- [ ] No hardcoded API keys, URLs, or credentials in source
- [ ] No `print()` statements left in production paths (only `#if DEBUG`)
- [ ] App version and build number incremented in Xcode project settings

---

## Phase 2: Integration Tests

### 2.1 Supabase Staging (run manually before merge)

- [ ] Integration test: submit round → verify in standings
- [ ] Integration test: tap-and-save cross-user visibility
- [ ] Integration test: RLS prevents writing another user's data

*(Set `TEST_PLAN_INTEGRATION=true` and run `xcodebuild test -testPlan Integration`)*

---

## Phase 3: Apple Watch Checklist

Run the full `AppleWatchChecklist.md` on a physical device:

- [ ] App-to-watch course data sync (< 30 seconds)
- [ ] Distance updates while walking
- [ ] Score entry via Digital Crown
- [ ] Conflict resolution (last-write-wins)
- [ ] Standalone GPS (phone disconnected)
- [ ] Low battery warning at 30%

---

## Phase 4: Offline Round Checklist

Run the full `OfflineRoundChecklist.md`:

- [ ] Full offline 9-hole round → sync on reconnect
- [ ] Round appears in Supabase with `source = "app"`
- [ ] Standings update correctly
- [ ] Cache miss error message (not crash) in airplane mode

---

## Phase 5: Push Notification Checklist

- [ ] Submit a round that vaults another player to #1 in standings
- [ ] Verify the displaced player receives a push notification within 60 seconds
- [ ] Verify notification tap opens the standings tab
- [ ] Disable push permissions on a test device → submit round → verify no crash, no hang

---

## Phase 6: First-Launch Experience Checklist

*(Use a fresh device or device with app deleted)*

- [ ] Fresh install on device with no prior data
- [ ] Grant location permissions — verify "Always" is requested, not "When In Use"
- [ ] Open app near a known course → verify auto-detect suggestion within 30 seconds
- [ ] Open app near an unmapped course → verify tap-and-save prompt appears
- [ ] Deny location permission → verify graceful error message, no crash

---

## Phase 7: GPS Accuracy Spot Check

*(Perform at an actual golf course or known outdoor location)*

- [ ] Stand at a known tee (with posted yardage on tee sign)
- [ ] Note displayed distance to green center
- [ ] Compare against posted yardage — should be within 15 yards
- [ ] Walk 50 yards toward green → verify distance decreases by ~50 yards
- [ ] Stand on the green → verify distance shows 0–5 yards

---

## Phase 8: TestFlight Distribution

- [ ] Archive build in Xcode with Release signing (Product → Archive)
- [ ] Validate archive passes App Store Connect validation
- [ ] Upload to App Store Connect
- [ ] Verify entitlements in archive:
  - [ ] Background location (`com.apple.developer.location.use-location-in-background`)
  - [ ] Push notifications (`aps-environment = development/production`)
  - [ ] WatchKit (`com.apple.developer.associated-domains` for WatchKit)
- [ ] Add release notes in TestFlight
- [ ] Invite test users (all THC members)

---

## Phase 9: Post-Distribution Verification

- [ ] Install on a fresh device via TestFlight
- [ ] Verify clean first-launch experience (no crash, no blank screens)
- [ ] Verify crash-free launch on:
  - [ ] iPhone 16 (iOS 18+)
  - [ ] iPhone 14 (iOS 17+, older device check)
  - [ ] Apple Watch Series 7+ (watchOS 10+)

---

## Phase 10: Monitoring (First 24 Hours Post-Release)

- [ ] Check Xcode Organizer for crash logs
- [ ] Check Supabase dashboard for unexpected errors or unusual data patterns
- [ ] Verify standings are updating correctly with `source = "app"` rounds
- [ ] No duplicate rounds appearing in the database

---

## Release Notes Template

```
THC iOS v[VERSION] — [DATE]

New Features:
- [Feature 1]
- [Feature 2]

Bug Fixes:
- [Fix 1]

Known Issues:
- [Issue 1]

Test Instructions:
- [Specific areas to test]
```

---

## Sign-Off

All gates must pass before distributing to TestFlight.

| Checkpoint | Reviewer | Date | Pass/Fail |
|------------|----------|------|-----------|
| Unit + service tests | | | |
| Integration tests | | | |
| Apple Watch checklist | | | |
| Offline round checklist | | | |
| Push notification checklist | | | |
| First-launch experience | | | |
| GPS accuracy spot check | | | |
| Archive + entitlements | | | |
| **Release approved** | | | |
