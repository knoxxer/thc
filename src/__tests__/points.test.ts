import { describe, it, expect } from "vitest";
import { calculatePoints } from "@/lib/points";

describe("calculatePoints", () => {
  it("returns 10 for even par", () => {
    expect(calculatePoints(0)).toBe(10);
  });

  it("adds a point for each stroke under par", () => {
    expect(calculatePoints(-1)).toBe(11);
    expect(calculatePoints(-2)).toBe(12);
    expect(calculatePoints(-3)).toBe(13);
  });

  it("caps at 15 for very low scores", () => {
    expect(calculatePoints(-5)).toBe(15);
    expect(calculatePoints(-10)).toBe(15);
  });

  it("removes a point for each stroke over par", () => {
    expect(calculatePoints(1)).toBe(9);
    expect(calculatePoints(5)).toBe(5);
  });

  it("floors at 1 for very high scores", () => {
    expect(calculatePoints(9)).toBe(1);
    expect(calculatePoints(10)).toBe(1);
    expect(calculatePoints(20)).toBe(1);
  });
});
