import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/react";
import FeedCard from "@/components/feed/FeedCard";
import type { FeedRound } from "@/lib/types";

vi.mock("@/components/feed/ReactionBar", () => ({
  default: () => <div data-testid="reaction-bar" />,
}));
vi.mock("@/components/feed/CommentSection", () => ({
  default: () => <div data-testid="comment-section" />,
}));

const mockRound: FeedRound = {
  id: "round-1",
  player_id: "player-1",
  season_id: "season-1",
  played_at: "2024-06-14",
  course_name: "Torrey Pines South",
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
  source: "manual",
  entered_by: null,
  created_at: "2024-06-14T12:00:00Z",
  player: {
    id: "player-1",
    display_name: "Jake",
    slug: "jake",
    avatar_url: null,
  },
};

describe("FeedCard", () => {
  it("renders player name, course, and score breakdown", () => {
    const { container } = render(
      <FeedCard
        round={mockRound}
        reactions={[]}
        comments={[]}
        currentPlayerId={null}
      />
    );

    const card = container.firstChild as HTMLElement;
    const scope = within(card);

    expect(scope.getByText("Jake")).toBeInTheDocument();
    expect(scope.getByText("Torrey Pines South")).toBeInTheDocument();
    expect(scope.getByText("82 gross")).toBeInTheDocument();
    expect(scope.getByText("72 net")).toBeInTheDocument();
    expect(scope.getByText("E")).toBeInTheDocument();
    expect(scope.getByText("10 pts")).toBeInTheDocument();
    expect(scope.getByText("J")).toBeInTheDocument();
  });

  it("renders ReactionBar and CommentSection", () => {
    const { container } = render(
      <FeedCard
        round={mockRound}
        reactions={[]}
        comments={[]}
        currentPlayerId={null}
      />
    );

    const card = container.firstChild as HTMLElement;
    const scope = within(card);

    expect(scope.getByTestId("reaction-bar")).toBeInTheDocument();
    expect(scope.getByTestId("comment-section")).toBeInTheDocument();
  });

  it("shows +N for over par rounds", () => {
    const overParRound = { ...mockRound, net_vs_par: 3, points: 7 };

    const { container } = render(
      <FeedCard
        round={overParRound}
        reactions={[]}
        comments={[]}
        currentPlayerId={null}
      />
    );

    const card = container.firstChild as HTMLElement;
    const scope = within(card);

    expect(scope.getByText("+3")).toBeInTheDocument();
    expect(scope.getByText("7 pts")).toBeInTheDocument();
  });
});
