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

// Mock DesignToggle
vi.mock("@/components/ui/DesignToggle", () => ({
  useDesign: () => ({ design: "classic", toggle: vi.fn() }),
  DesignSwitch: () => <button>Try v2</button>,
}));

// Mock next/image
vi.mock("next/image", () => ({
  default: ({ alt, ...props }: { alt: string; [key: string]: unknown }) => <img alt={alt} {...props} />,
}));

import Nav from "@/components/ui/Nav";

describe("Nav accessibility", () => {
  it("hamburger button has aria-expanded attribute", () => {
    render(<Nav />);
    const menuButton = screen.getByLabelText("Menu");
    expect(menuButton).toHaveAttribute("aria-expanded", "false");
  });

  it("hamburger button has adequate touch target (44px)", () => {
    render(<Nav />);
    const menuButton = screen.getByLabelText("Menu");
    expect(menuButton.className).toContain("min-h-[44px]");
    expect(menuButton.className).toContain("min-w-[44px]");
  });

  it("shows active nav link styling for current page", () => {
    render(<Nav />);
    // Desktop nav links — the Leaderboard link should have "font-medium" since pathname is "/"
    const links = screen.getAllByText("Leaderboard");
    const desktopLink = links.find((el) => el.className.includes("font-medium"));
    expect(desktopLink).toBeDefined();
  });
});

describe("Form accessibility", () => {
  it("form labels are associated with inputs via htmlFor/id", async () => {
    // We test the raw file content to verify htmlFor/id pairing
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

describe("CSS v2 theme", () => {
  it("globals.css contains theme-v2 class with lighter muted color", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");

    expect(css).toContain(".theme-v2");
    expect(css).toContain("--muted: #9ab8a0");
  });

  it("globals.css has focus-visible styles for v2", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");

    expect(css).toContain(".theme-v2 :focus-visible");
    expect(css).toContain("outline: 2px solid var(--gold)");
  });

  it("globals.css has round-dim class for v2 opacity override", async () => {
    const fs = await import("fs");
    const css = fs.readFileSync("src/app/globals.css", "utf-8");

    expect(css).toContain(".theme-v2 .round-dim");
    expect(css).toContain("opacity: 0.75");
  });

  it("globals.css has mobile bottom padding for v2 tab bar", async () => {
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
