# Social Features for The Homie Cup

Social engagement layer for the THC golf app — activity feed, emoji reactions, comments, upcoming rounds, auto milestones, weekly recaps, and in-app notifications.

## Features

### 1. Activity Feed (`/feed`)

Chronological timeline of recently posted rounds. Each card shows player avatar, course name, date, score breakdown (gross → net → vs par → points), emoji reactions, and comments.

![Feed with reactions and comments](docs/mockups/06-feed-with-reactions-comments.png)

### 2. Emoji Reactions

8 golf-themed emojis: ⛳ 🔥 🏌️ 💀 🎯 👏 🤮 😤

- Tap a pill to toggle your reaction on/off
- Own reactions highlighted with gold border
- `[+]` button opens horizontal picker
- Optimistic UI — updates instantly, reverts on error
- Click-outside closes picker

### 3. Comments

Text comments on rounds. Separate `round_comments` table (not overloading `round_reactions`).

- Player name + timestamp on each comment
- 500 char limit enforced at DB level
- Notifications sent to round owner on new comments

### 4. Upcoming Rounds

Post future tee times so friends can RSVP.

![Upcoming rounds](docs/mockups/03-upcoming-rounds.png)

- Course name, datetime, optional notes
- RSVP buttons: **I'm In** (green) / **Maybe** (yellow) / **Can't** (red)
- Shows who's going and who's maybe by name
- Auto-cleanup of past tee times (24h after tee time)

### 5. Auto Milestones

Computed from existing data — no DB table, derived each time the feed loads.

![Auto milestones](docs/mockups/05-auto-milestones.png)

| Type | Example |
|------|---------|
| Season Best | 🏆 Jake posted 69 net at Torrey Pines — 13 pts |
| Posting Streak | 🔥 Mike has posted a round 4 weeks in a row |
| Eligibility | ✅ Dan hit 5 rounds and is now eligible |
| Points Milestone | 💯 Jake hit 103 total points this season |
| First Round | 👋 Welcome to the season! First round posted |

### 6. Weekly Recap

Auto-generated summary card for the past 7 days.

![Weekly recap](docs/mockups/04-weekly-recap.png)

- Rounds posted count
- Best round (player, course, points)
- Most active player + current rank
- Total points earned across all players

### 7. In-App Notifications

Bell icon in nav with unread count badge and dropdown.

![Notification dropdown](docs/mockups/02-notification-dropdown.png)

**Triggers:**
- Someone posts a new round → all players notified
- Someone reacts to your round → you're notified
- Someone comments on your round → you're notified
- Someone RSVPs to your upcoming round → organizer notified
- Someone posts an upcoming round → all players notified

**Implementation:**
- Polls every 30s (sufficient for 10 users)
- Change detection prevents no-op re-renders
- API route handles cross-user notification creation (bypasses RLS)

### 8. Navigation Update

![Nav with Feed and bell](docs/mockups/01-nav-with-feed-and-bell.png)

- "Feed" link added between Leaderboard and Rules (desktop + mobile)
- Notification bell with red unread badge (only shown when logged in)

## Database Migrations

| Migration | Tables |
|-----------|--------|
| `create_upcoming_rounds.sql` | `upcoming_rounds`, `upcoming_round_rsvps` |
| `create_round_comments.sql` | `round_comments` |
| `create_notifications.sql` | `notifications` |

All tables have RLS enabled. Existing tables used: `round_reactions` (already existed, UI built).

Run these migrations against your Supabase project after merging.

## New Files

### Pages & API
| File | Purpose |
|------|---------|
| `src/app/feed/page.tsx` | Server component, revalidate=60, fetches all feed data |
| `src/app/api/notifications/route.ts` | GET/PATCH/POST for notifications |

### Components
| File | Purpose |
|------|---------|
| `src/components/feed/ActivityFeed.tsx` | Feed wrapper combining all sections |
| `src/components/feed/FeedCard.tsx` | Individual round card |
| `src/components/feed/ReactionBar.tsx` | Emoji reactions with optimistic UI |
| `src/components/feed/CommentSection.tsx` | Text comments |
| `src/components/feed/UpcomingRoundCard.tsx` | Upcoming round with RSVP |
| `src/components/feed/PostUpcomingForm.tsx` | Form to post upcoming rounds |
| `src/components/feed/MilestoneCard.tsx` | Milestone display card |
| `src/components/feed/WeeklyRecapCard.tsx` | Weekly recap card |
| `src/components/ui/NotificationBell.tsx` | Bell icon + dropdown |

### Shared Libraries
| File | Purpose |
|------|---------|
| `src/lib/format.ts` | `timeAgo()`, `formatVsPar()` |
| `src/lib/send-notification.ts` | Client-side `sendNotification()` helper |
| `src/lib/notifications.ts` | Server-side notification creation |
| `src/lib/milestones.ts` | `generateMilestones()`, `generateWeeklyRecap()` |
| `src/lib/supabase/service.ts` | Shared singleton service client |

### Modified Files
| File | Change |
|------|--------|
| `src/lib/types.ts` | Added 9 new interfaces |
| `src/components/ui/Nav.tsx` | Feed link + NotificationBell |
| `src/components/leaderboard/LeaderboardTable.tsx` | Use shared `formatVsPar` |
| `src/app/players/[slug]/page.tsx` | Use shared `formatVsPar` |
| `src/app/api/ghin/sync/route.ts` | Use shared `getServiceClient` |
| `src/lib/ghin/sync.ts` | Use shared `getServiceClient` |

## Tests

### Unit Tests (Vitest) — 33 passing

```bash
npm test
```

- `format.test.ts` — `timeAgo`, `formatVsPar`
- `points.test.ts` — `calculatePoints` with floor/ceiling
- `milestones.test.ts` — All milestone types, threshold ordering, deduplication, weekly recap
- `ReactionBar.test.tsx` — Grouped pills, counts, picker, auth gating, highlights
- `FeedCard.test.tsx` — Player info, score breakdown, child components
- `MilestoneCard.test.tsx` — Rendering, styling, milestone types

### E2E Tests (Playwright) — 12 passing

```bash
npm run test:e2e
```

Uses a mock Supabase server (`e2e/mock-supabase.ts`) so tests run without real credentials.

- Feed page loading and content
- Navigation (desktop + mobile hamburger)
- Auth-gated elements (reaction buttons, post form)
- Page loads for leaderboard, rules, players

## Architecture Decisions

- **Feed is a separate page** (`/feed`), not replacing the homepage leaderboard
- **Separate `round_comments` table** instead of overloading `round_reactions.comment` — unique constraint on reactions makes multiple comments awkward
- **Milestones are computed, not stored** — derived from existing rounds/standings data, no staleness concerns
- **API route for notifications** — needed because creating notifications for other users requires bypassing RLS
- **Polling (30s) for notification count** — simpler than Realtime for 10 users
- **No web push yet** — in-app notifications are the MVP; browser push can be layered on later
