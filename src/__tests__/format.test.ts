import { describe, it, expect, vi, afterEach } from "vitest";
import { timeAgo, formatVsPar } from "@/lib/format";

describe("formatVsPar", () => {
  it("returns E for even par", () => {
    expect(formatVsPar(0)).toBe("E");
  });

  it("returns +N for over par", () => {
    expect(formatVsPar(1)).toBe("+1");
    expect(formatVsPar(5)).toBe("+5");
    expect(formatVsPar(10)).toBe("+10");
  });

  it("returns -N for under par", () => {
    expect(formatVsPar(-1)).toBe("-1");
    expect(formatVsPar(-5)).toBe("-5");
  });
});

describe("timeAgo", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it('returns "just now" for recent timestamps', () => {
    const now = new Date().toISOString();
    expect(timeAgo(now)).toBe("just now");
  });

  it("returns minutes for timestamps < 1 hour ago", () => {
    vi.useFakeTimers();
    const base = new Date("2024-06-01T12:00:00Z");
    vi.setSystemTime(base);

    const thirtyMinAgo = new Date("2024-06-01T11:30:00Z").toISOString();
    expect(timeAgo(thirtyMinAgo)).toBe("30m");
  });

  it("returns hours for timestamps < 1 day ago", () => {
    vi.useFakeTimers();
    const base = new Date("2024-06-01T12:00:00Z");
    vi.setSystemTime(base);

    const threeHoursAgo = new Date("2024-06-01T09:00:00Z").toISOString();
    expect(timeAgo(threeHoursAgo)).toBe("3h");
  });

  it("returns days for timestamps >= 1 day ago", () => {
    vi.useFakeTimers();
    const base = new Date("2024-06-05T12:00:00Z");
    vi.setSystemTime(base);

    const twoDaysAgo = new Date("2024-06-03T12:00:00Z").toISOString();
    expect(timeAgo(twoDaysAgo)).toBe("2d");
  });
});
