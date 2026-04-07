import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// Mock next/navigation
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

// Mock supabase client
vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: {
      getUser: () => Promise.resolve({ data: { user: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: vi.fn() } } }),
    },
  }),
}));

// Mock next/image
vi.mock("next/image", () => ({
  default: ({ alt, ...props }: { alt: string; [key: string]: unknown }) => <img alt={alt} {...props} />,
}));

import Nav from "@/components/ui/Nav";

describe("Nav accessibility", () => {
  it("shows active nav link styling for current page", () => {
    render(<Nav />);
    const links = screen.getAllByText("Leaderboard");
    const desktopLink = links.find((el) => el.className.includes("font-medium"));
    expect(desktopLink).toBeDefined();
  });
});

describe("Form accessibility", () => {
  it("form labels are associated with inputs via htmlFor/id", async () => {
    const fs = await import("fs");
    const content = fs.readFileSync("src/app/rounds/new/page.tsx", "utf-8");

    expect(content).toContain('htmlFor="played-at"');
    expect(content).toContain('id="played-at"');
    expect(content).toContain('htmlFor="course-name"');
    expect(content).toContain('id="course-name"');
    expect(content).toContain('htmlFor="course-par"');
    expect(content).toContain('id="course-par"');
    expect(content).toContain('htmlFor="gross-score"');
    expect(content).toContain('id="gross-score"');
    expect(content).toContain('htmlFor="course-handicap"');
    expect(content).toContain('id="course-handicap"');
  });

  it("course handicap input has aria-describedby for help text", async () => {
    const fs = await import("fs");
    const content = fs.readFileSync("src/app/rounds/new/page.tsx", "utf-8");

    expect(content).toContain('aria-describedby="handicap-help"');
    expect(content).toContain('id="handicap-help"');
  });
});

describe("CSS theme", () => {
  it("globals.css has lighter muted color", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");
    expect(css).toContain("--muted: #9ab8a0");
  });

  it("globals.css has focus-visible styles", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");
    expect(css).toContain(":focus-visible");
    expect(css).toContain("outline: 2px solid var(--gold)");
  });

  it("globals.css has round-dim class for opacity", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");
    expect(css).toContain(".round-dim");
    expect(css).toContain("opacity: 0.75");
  });

  it("globals.css has mobile bottom padding for tab bar", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");
    expect(css).toContain("padding-bottom: 72px");
  });
});

describe("Table accessibility", () => {
  it("leaderboard table has sr-only caption", async () => {
    const fs = await import("fs");
    const content = fs.readFileSync("src/components/leaderboard/LeaderboardTable.tsx", "utf-8");
    expect(content).toContain('caption className="sr-only"');
    expect(content).toContain("Season leaderboard standings");
  });

  it("round history table has sr-only caption", async () => {
    const fs = await import("fs");
    const content = fs.readFileSync("src/app/players/[slug]/page.tsx", "utf-8");
    expect(content).toContain('caption className="sr-only"');
    expect(content).toContain("Round history");
  });
});
