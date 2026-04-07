import type { FeedRound, SeasonStanding, Season, Milestone } from "./types";

/**
 * Generate milestone cards from recent rounds and current standings.
 * Milestones are computed (not stored) — derived each time the feed loads.
 */
export function generateMilestones(
  rounds: FeedRound[],
  standings: SeasonStanding[],
  season: Season
): Milestone[] {
  const milestones: Milestone[] = [];
  if (!rounds.length) return milestones;

  // Sort rounds by created_at desc (most recent first)
  const sorted = [...rounds].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );

  // Only look at rounds from the last 7 days for milestone generation
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const recentRounds = sorted.filter(
    (r) => new Date(r.created_at).getTime() > sevenDaysAgo
  );

  if (!recentRounds.length) return milestones;

  // --- Season Best Round ---
  const allPoints = rounds.map((r) => r.points ?? 0);
  const maxPoints = Math.max(...allPoints);
  const bestRound = recentRounds.find((r) => (r.points ?? 0) === maxPoints);
  if (bestRound && maxPoints > 0) {
    // Check if this is actually the season best (no older round has same or higher points)
    const olderRoundsMaxPoints = rounds
      .filter((r) => r.id !== bestRound.id)
      .reduce((max, r) => Math.max(max, r.points ?? 0), 0);

    if (maxPoints > olderRoundsMaxPoints) {
      milestones.push({
        type: "season_best",
        title: "Season Best Round!",
        description: `${bestRound.player.display_name} posted ${bestRound.net_score} net at ${bestRound.course_name} \u2014 ${maxPoints} pts`,
        playerName: bestRound.player.display_name,
        playerSlug: bestRound.player.slug,
        timestamp: bestRound.created_at,
      });
    }
  }

  // --- First Round of Season ---
  // Find players whose only round(s) are in the recent window
  const playerRoundCounts = new Map<string, number>();
  for (const r of rounds) {
    playerRoundCounts.set(
      r.player_id,
      (playerRoundCounts.get(r.player_id) ?? 0) + 1
    );
  }
  for (const r of recentRounds) {
    if (playerRoundCounts.get(r.player_id) === 1) {
      milestones.push({
        type: "first_round",
        title: "Welcome to the Season!",
        description: `${r.player.display_name} posted their first round`,
        playerName: r.player.display_name,
        playerSlug: r.player.slug,
        timestamp: r.created_at,
      });
    }
  }

  // --- Eligibility Reached ---
  const minRounds = season.min_rounds;
  for (const standing of standings) {
    if (standing.total_rounds === minRounds) {
      // This player just became eligible — check if their latest round is recent
      const playerRecentRound = recentRounds.find(
        (r) => r.player_id === standing.player_id
      );
      if (playerRecentRound) {
        milestones.push({
          type: "eligibility",
          title: "Now Eligible!",
          description: `${standing.player_name} hit ${minRounds} rounds and is now eligible for the standings`,
          playerName: standing.player_name,
          playerSlug: standing.player_slug,
          timestamp: playerRecentRound.created_at,
        });
      }
    }
  }

  // --- Points Milestones (50, 75, 100, etc.) ---
  const pointsThresholds = [50, 75, 100, 125, 150];
  for (const standing of standings) {
    const total = standing.best_n_points;
    for (const threshold of pointsThresholds) {
      if (total >= threshold) {
        // Check if they crossed this threshold with a recent round
        const playerRecentRounds = recentRounds.filter(
          (r) => r.player_id === standing.player_id
        );
        const recentPoints = playerRecentRounds.reduce(
          (sum, r) => sum + (r.points ?? 0),
          0
        );
        if (total - recentPoints < threshold && total >= threshold) {
          milestones.push({
            type: "points_milestone",
            title: `${threshold} Points!`,
            description: `${standing.player_name} hit ${total} total points this season`,
            playerName: standing.player_name,
            playerSlug: standing.player_slug,
            timestamp: playerRecentRounds[0]?.created_at ?? new Date().toISOString(),
          });
          break; // Only show the highest milestone crossed
        }
      }
    }
  }

  // --- Posting Streak (consecutive weeks) ---
  const playerWeeks = new Map<string, Set<string>>();
  for (const r of rounds) {
    const weekKey = getWeekKey(new Date(r.played_at));
    if (!playerWeeks.has(r.player_id)) {
      playerWeeks.set(r.player_id, new Set());
    }
    playerWeeks.get(r.player_id)!.add(weekKey);
  }

  const currentWeek = getWeekKey(new Date());
  for (const [playerId, weeks] of playerWeeks) {
    let streak = 0;
    let checkWeek = currentWeek;
    while (weeks.has(checkWeek)) {
      streak++;
      checkWeek = getPreviousWeekKey(checkWeek);
    }
    if (streak >= 3) {
      const playerRound = recentRounds.find((r) => r.player_id === playerId);
      if (playerRound) {
        milestones.push({
          type: "streak",
          title: `${streak}-Week Streak!`,
          description: `${playerRound.player.display_name} has posted a round ${streak} weeks in a row`,
          playerName: playerRound.player.display_name,
          playerSlug: playerRound.player.slug,
          timestamp: playerRound.created_at,
        });
      }
    }
  }

  // Deduplicate by type + playerName
  const seen = new Set<string>();
  return milestones.filter((m) => {
    const key = `${m.type}:${m.playerName}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * Generate weekly recap from rounds in the last 7 days.
 */
export function generateWeeklyRecap(
  rounds: FeedRound[],
  standings: SeasonStanding[]
): {
  weekLabel: string;
  roundsPosted: number;
  bestRound: { playerName: string; courseName: string; points: number } | null;
  totalPoints: number;
  biggestMover: { playerName: string; rank: number } | null;
} | null {
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const weekRounds = rounds.filter(
    (r) => new Date(r.created_at) > sevenDaysAgo
  );

  if (weekRounds.length === 0) return null;

  const startDate = sevenDaysAgo.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
  const endDate = now.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });

  // Best round
  let bestRound: { playerName: string; courseName: string; points: number } | null = null;
  let maxPts = 0;
  for (const r of weekRounds) {
    const pts = r.points ?? 0;
    if (pts > maxPts) {
      maxPts = pts;
      bestRound = {
        playerName: r.player.display_name,
        courseName: r.course_name,
        points: pts,
      };
    }
  }

  const totalPoints = weekRounds.reduce((sum, r) => sum + (r.points ?? 0), 0);

  // Biggest mover — player with most points this week (proxy for rank change)
  let biggestMover: { playerName: string; rank: number } | null = null;
  if (standings.length > 0) {
    const sortedStandings = [...standings].sort(
      (a, b) => b.best_n_points - a.best_n_points
    );
    // Find who posted the most points this week
    const weekPointsByPlayer = new Map<string, number>();
    for (const r of weekRounds) {
      weekPointsByPlayer.set(
        r.player_id,
        (weekPointsByPlayer.get(r.player_id) ?? 0) + (r.points ?? 0)
      );
    }
    let maxWeekPoints = 0;
    let moverId = "";
    for (const [pid, pts] of weekPointsByPlayer) {
      if (pts > maxWeekPoints) {
        maxWeekPoints = pts;
        moverId = pid;
      }
    }
    if (moverId) {
      const rank = sortedStandings.findIndex((s) => s.player_id === moverId) + 1;
      const standing = sortedStandings.find((s) => s.player_id === moverId);
      if (standing && rank > 0) {
        biggestMover = { playerName: standing.player_name, rank };
      }
    }
  }

  return {
    weekLabel: `${startDate} \u2013 ${endDate}`,
    roundsPosted: weekRounds.length,
    bestRound,
    totalPoints,
    biggestMover,
  };
}

// --- Helpers ---

function getWeekKey(date: Date): string {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  const dayOfWeek = d.getDay();
  const monday = new Date(d);
  monday.setDate(d.getDate() - ((dayOfWeek + 6) % 7));
  return monday.toISOString().split("T")[0];
}

function getPreviousWeekKey(weekKey: string): string {
  const d = new Date(weekKey);
  d.setDate(d.getDate() - 7);
  return d.toISOString().split("T")[0];
}
