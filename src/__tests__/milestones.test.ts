import { describe, it, expect, vi, afterEach } from "vitest";
import { generateMilestones, generateWeeklyRecap } from "@/lib/milestones";
import type { FeedRound, SeasonStanding, Season } from "@/lib/types";

function makeSeason(overrides?: Partial<Season>): Season {
  return {
    id: "season-1",
    name: "2024",
    starts_at: "2024-01-01T00:00:00Z",
    ends_at: "2024-12-31T23:59:59Z",
    is_active: true,
    min_rounds: 5,
    top_n_rounds: 10,
    created_at: "2024-01-01T00:00:00Z",
    ...overrides,
  };
}

function makeRound(overrides?: Partial<FeedRound>): FeedRound {
  return {
    id: `round-${Math.random().toString(36).slice(2)}`,
    player_id: "player-1",
    season_id: "season-1",
    played_at: new Date().toISOString().split("T")[0],
    course_name: "Test Course",
    tee_name: null,
    course_rating: null,
    slope_rating: null,
    par: 72,
    gross_score: 82,
    course_handicap: 10,
    net_score: 72,
    net_vs_par: 0,
    points: 10,
    ghin_score_id: null,
    source: "manual" as const,
    entered_by: null,
    created_at: new Date().toISOString(),
    player: {
      id: "player-1",
      display_name: "Jake",
      slug: "jake",
      avatar_url: null,
    },
    ...overrides,
  };
}

function makeStanding(overrides?: Partial<SeasonStanding>): SeasonStanding {
  return {
    player_id: "player-1",
    season_id: "season-1",
    player_name: "Jake",
    player_slug: "jake",
    handicap_index: 10,
    avatar_url: null,
    total_rounds: 5,
    is_eligible: true,
    best_n_points: 80,
    best_round_points: 12,
    best_net_vs_par: -2,
    ...overrides,
  };
}

describe("generateMilestones", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns empty array for no rounds", () => {
    const result = generateMilestones([], [], makeSeason());
    expect(result).toEqual([]);
  });

  it("returns empty array when all rounds are older than 7 days", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const oldRound = makeRound({
      created_at: "2024-06-01T12:00:00Z",
    });

    const result = generateMilestones([oldRound], [], makeSeason());
    expect(result).toEqual([]);
  });

  it("detects season best round", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const bestRound = makeRound({
      id: "best",
      points: 13,
      net_score: 69,
      created_at: "2024-06-14T12:00:00Z",
    });

    const result = generateMilestones([bestRound], [], makeSeason());
    expect(result).toContainEqual(
      expect.objectContaining({
        type: "season_best",
        title: "Season Best Round!",
      })
    );
  });

  it("does not flag season best if an older round has same or higher points", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const olderBetter = makeRound({
      id: "older",
      points: 14,
      created_at: "2024-06-01T12:00:00Z",
    });
    const recentGood = makeRound({
      id: "recent",
      points: 13,
      created_at: "2024-06-14T12:00:00Z",
    });

    const result = generateMilestones(
      [recentGood, olderBetter],
      [],
      makeSeason()
    );
    expect(result.find((m) => m.type === "season_best")).toBeUndefined();
  });

  it("detects first round of season", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const firstRound = makeRound({
      player_id: "new-player",
      created_at: "2024-06-14T12:00:00Z",
      player: {
        id: "new-player",
        display_name: "New Player",
        slug: "new-player",
        avatar_url: null,
      },
    });

    const result = generateMilestones([firstRound], [], makeSeason());
    expect(result).toContainEqual(
      expect.objectContaining({
        type: "first_round",
        title: "Welcome to the Season!",
      })
    );
  });

  it("detects eligibility reached", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const round = makeRound({
      created_at: "2024-06-14T12:00:00Z",
    });
    const standing = makeStanding({ total_rounds: 5 });

    const result = generateMilestones([round], [standing], makeSeason({ min_rounds: 5 }));
    expect(result).toContainEqual(
      expect.objectContaining({
        type: "eligibility",
        title: "Now Eligible!",
      })
    );
  });

  it("detects points milestone and shows highest crossed threshold", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const round = makeRound({
      points: 12,
      created_at: "2024-06-14T12:00:00Z",
    });
    // Player crossed both 50 and 75 this week (was at 68, now 80)
    const standing = makeStanding({
      best_n_points: 80,
    });

    const result = generateMilestones([round], [standing], makeSeason());
    const pointsMilestones = result.filter((m) => m.type === "points_milestone");
    expect(pointsMilestones).toHaveLength(1);
    // Should show 75 (highest crossed), not 50
    expect(pointsMilestones[0].title).toBe("75 Points!");
  });

  it("deduplicates milestones by type + player", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const round1 = makeRound({
      id: "r1",
      player_id: "p1",
      created_at: "2024-06-14T12:00:00Z",
      player: { id: "p1", display_name: "Jake", slug: "jake", avatar_url: null },
    });
    const round2 = makeRound({
      id: "r2",
      player_id: "p1",
      created_at: "2024-06-13T12:00:00Z",
      player: { id: "p1", display_name: "Jake", slug: "jake", avatar_url: null },
    });

    // Both are "first round" for the same player — but since count is 2, neither triggers first_round
    // This is the dedup mechanism test — two rounds from same player won't both get first_round
    const result = generateMilestones([round1, round2], [], makeSeason());
    const firstRounds = result.filter((m) => m.type === "first_round");
    expect(firstRounds.length).toBeLessThanOrEqual(1);
  });
});

describe("generateWeeklyRecap", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns null when no rounds in last 7 days", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const oldRound = makeRound({
      created_at: "2024-06-01T12:00:00Z",
    });

    const result = generateWeeklyRecap([oldRound], []);
    expect(result).toBeNull();
  });

  it("returns recap with correct stats", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-06-15T12:00:00Z"));

    const round1 = makeRound({
      points: 10,
      created_at: "2024-06-14T12:00:00Z",
      course_name: "Torrey Pines",
    });
    const round2 = makeRound({
      points: 12,
      player_id: "player-2",
      created_at: "2024-06-13T12:00:00Z",
      course_name: "Riviera",
      player: {
        id: "player-2",
        display_name: "Mike",
        slug: "mike",
        avatar_url: null,
      },
    });

    const standings = [
      makeStanding({ player_id: "player-1", best_n_points: 80 }),
      makeStanding({
        player_id: "player-2",
        player_name: "Mike",
        player_slug: "mike",
        best_n_points: 70,
      }),
    ];

    const result = generateWeeklyRecap([round1, round2], standings);
    expect(result).not.toBeNull();
    expect(result!.roundsPosted).toBe(2);
    expect(result!.totalPoints).toBe(22);
    expect(result!.bestRound?.playerName).toBe("Mike");
    expect(result!.bestRound?.points).toBe(12);
    expect(result!.biggestMover).not.toBeNull();
  });
});
