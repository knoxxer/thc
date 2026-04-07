import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ReactionBar from "@/components/feed/ReactionBar";
import type { RoundReaction } from "@/lib/types";

// Mock supabase client
vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    from: () => ({
      insert: () => ({ select: () => ({ single: () => Promise.resolve({ data: { id: "new-id" }, error: null }) }) }),
      delete: () => ({ eq: () => Promise.resolve({ error: null }) }),
    }),
  }),
}));

vi.mock("@/lib/send-notification", () => ({
  sendNotification: vi.fn(),
}));

const baseReactions: RoundReaction[] = [
  { id: "r1", round_id: "round-1", player_id: "p1", emoji: "\ud83d\udd25", comment: null, created_at: "2024-06-14T12:00:00Z" },
  { id: "r2", round_id: "round-1", player_id: "p2", emoji: "\ud83d\udd25", comment: null, created_at: "2024-06-14T12:00:00Z" },
  { id: "r3", round_id: "round-1", player_id: "p1", emoji: "\ud83d\udc4f", comment: null, created_at: "2024-06-14T12:00:00Z" },
];

describe("ReactionBar", () => {
  it("renders grouped reaction pills with counts", () => {
    render(
      <ReactionBar
        roundId="round-1"
        reactions={baseReactions}
        currentPlayerId={null}
        roundOwnerId="owner-1"
      />
    );

    // Should show fire emoji with count 2, and clap with count 1
    expect(screen.getByText("2")).toBeInTheDocument();
    expect(screen.getByText("1")).toBeInTheDocument();
  });

  it("does not show + button when not logged in", () => {
    render(
      <ReactionBar
        roundId="round-1"
        reactions={[]}
        currentPlayerId={null}
        roundOwnerId="owner-1"
      />
    );

    expect(screen.queryByText("+")).not.toBeInTheDocument();
  });

  it("shows + button when logged in", () => {
    render(
      <ReactionBar
        roundId="round-1"
        reactions={[]}
        currentPlayerId="p1"
        roundOwnerId="owner-1"
      />
    );

    expect(screen.getByText("+")).toBeInTheDocument();
  });

  it("opens emoji picker on + click", async () => {
    const user = userEvent.setup();

    const { container } = render(
      <ReactionBar
        roundId="round-1"
        reactions={[]}
        currentPlayerId="p1"
        roundOwnerId="owner-1"
      />
    );

    const card = container.firstChild as HTMLElement;
    const scope = within(card);
    await user.click(scope.getByText("+"));

    // Should show 8 emoji buttons in the picker + the "+" button itself
    const buttons = scope.getAllByRole("button");
    expect(buttons.length).toBe(9);
  });

  it("highlights own reactions", () => {
    const { container } = render(
      <ReactionBar
        roundId="round-1"
        reactions={baseReactions}
        currentPlayerId="p1"
        roundOwnerId="owner-1"
      />
    );

    // p1 has both fire and clap reactions — both pills should have gold border
    const goldBorderButtons = container.querySelectorAll(".border-gold\\/50");
    expect(goldBorderButtons.length).toBe(2);
  });
});
