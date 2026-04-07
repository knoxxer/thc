import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import MilestoneCard from "@/components/feed/MilestoneCard";
import type { Milestone } from "@/lib/types";

describe("MilestoneCard", () => {
  it("renders season best milestone", () => {
    const milestone: Milestone = {
      type: "season_best",
      title: "Season Best Round!",
      description: "Jake posted 69 net at Torrey Pines — 13 pts",
      playerName: "Jake",
      playerSlug: "jake",
      timestamp: "2024-06-14T12:00:00Z",
    };

    render(<MilestoneCard milestone={milestone} />);

    expect(screen.getByText("Season Best Round!")).toBeInTheDocument();
    expect(screen.getByText("Jake posted 69 net at Torrey Pines — 13 pts")).toBeInTheDocument();
    expect(screen.getByText("View profile")).toBeInTheDocument();
  });

  it("renders streak milestone with correct emoji", () => {
    const milestone: Milestone = {
      type: "streak",
      title: "3-Week Streak!",
      description: "Jake has posted a round 3 weeks in a row",
      playerName: "Jake",
      playerSlug: "jake",
      timestamp: "2024-06-14T12:00:00Z",
    };

    render(<MilestoneCard milestone={milestone} />);

    expect(screen.getByText("3-Week Streak!")).toBeInTheDocument();
  });

  it("has gold-themed styling", () => {
    const milestone: Milestone = {
      type: "eligibility",
      title: "Now Eligible!",
      description: "Mike hit 5 rounds",
      playerName: "Mike",
      playerSlug: "mike",
      timestamp: "2024-06-14T12:00:00Z",
    };

    const { container } = render(<MilestoneCard milestone={milestone} />);
    const card = container.firstChild as HTMLElement;
    expect(card.className).toContain("border-gold");
  });
});
