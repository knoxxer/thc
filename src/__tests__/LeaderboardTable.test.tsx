import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import LeaderboardTable from "@/components/leaderboard/LeaderboardTable";
import { SeasonStanding } from "@/lib/types";

// Mock next/link
vi.mock("next/link", () => ({
  default: ({ children, href, ...props }: { children: React.ReactNode; href: string; [key: string]: unknown }) => (
    <a href={href} {...props}>{children}</a>
  ),
}));

// Mock useDesign
const mockDesign: { design: string; toggle: ReturnType<typeof vi.fn> } = { design: "classic", toggle: vi.fn() };
vi.mock("@/components/ui/DesignToggle", () => ({
  useDesign: () => mockDesign,
}));

const mockStandings: SeasonStanding[] = [
  {
    player_id: "1",
    player_name: "Alice A",
    player_slug: "alice-a",
    season_id: "s1",
    total_rounds: 8,
    best_n_points: 95,
    best_net_vs_par: -3,
    best_round_points: 13,
    handicap_index: 15.2,
    avatar_url: null,
    is_eligible: true,
  },
  {
    player_id: "2",
    player_name: "Bob B",
    player_slug: "bob-b",
    season_id: "s1",
    total_rounds: 6,
    best_n_points: 80,
    best_net_vs_par: -1,
    best_round_points: 11,
    handicap_index: 20.0,
    avatar_url: null,
    is_eligible: true,
  },
  {
    player_id: "3",
    player_name: "Carol C",
    player_slug: "carol-c",
    season_id: "s1",
    total_rounds: 7,
    best_n_points: 70,
    best_net_vs_par: 0,
    best_round_points: 10,
    handicap_index: 10.5,
    avatar_url: null,
    is_eligible: true,
  },
];

describe("LeaderboardTable", () => {
  beforeEach(() => {
    mockDesign.design = "classic";
  });

  it("renders empty state with link to post score", () => {
    render(<LeaderboardTable standings={[]} />);
    expect(screen.getByText("No rounds posted yet.")).toBeInTheDocument();
    expect(screen.getByText("post a score")).toBeInTheDocument();
  });

  it("renders rank badges correctly", () => {
    render(<LeaderboardTable standings={mockStandings} />);
    expect(screen.getAllByText("1st").length).toBeGreaterThan(0);
    expect(screen.getAllByText("2nd").length).toBeGreaterThan(0);
    expect(screen.getAllByText("3rd").length).toBeGreaterThan(0);
  });

  it("sorts by points descending", () => {
    render(<LeaderboardTable standings={mockStandings} />);
    const names = screen.getAllByText(/Alice|Bob|Carol/).map((el) => el.textContent);
    // Alice (95) should be first, Bob (80) second, Carol (70) third
    expect(names[0]).toContain("Alice");
  });

  it("shows 3rd place in amber-700 in classic mode", () => {
    render(<LeaderboardTable standings={mockStandings} />);
    const thirdBadges = screen.getAllByText("3rd");
    thirdBadges.forEach((badge) => {
      expect(badge.className).toContain("text-amber-700");
    });
  });

  it("shows 3rd place in amber-500 in v2 mode", () => {
    mockDesign.design = "v2";
    render(<LeaderboardTable standings={mockStandings} />);
    const thirdBadges = screen.getAllByText("3rd");
    thirdBadges.forEach((badge) => {
      expect(badge.className).toContain("text-amber-500");
    });
  });

  it("desktop table has sr-only caption for accessibility", () => {
    render(<LeaderboardTable standings={mockStandings} />);
    const caption = screen.getByText("Season leaderboard standings");
    expect(caption).toBeInTheDocument();
    expect(caption.tagName).toBe("CAPTION");
    expect(caption.className).toContain("sr-only");
  });

  it("highlights leader row with gold background", () => {
    render(<LeaderboardTable standings={mockStandings} />);
    // The leader's points should be gold
    const points = screen.getAllByText("95");
    points.forEach((el) => {
      expect(el.className).toContain("text-gold");
    });
  });
});
