import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// Mock next/navigation
vi.mock("next/navigation", () => ({
  usePathname: () => "/",
}));

// Mock supabase client
vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: {
      getUser: () => Promise.resolve({ data: { user: null } }),
    },
  }),
}));

// Mock next/link
vi.mock("next/link", () => ({
  default: ({ children, href, ...props }: { children: React.ReactNode; href: string; [key: string]: unknown }) => (
    <a href={href} {...props}>{children}</a>
  ),
}));

import BottomTabs from "@/components/ui/BottomTabs";

describe("BottomTabs", () => {
  it("renders all navigation tabs", () => {
    render(<BottomTabs />);
    expect(screen.getByText("Standings")).toBeInTheDocument();
    expect(screen.getByText("Rules")).toBeInTheDocument();
    expect(screen.getByText("Players")).toBeInTheDocument();
    expect(screen.getByText("Post")).toBeInTheDocument();
  });

  it("highlights the active tab (Standings on /)", () => {
    render(<BottomTabs />);
    const standingsLink = screen.getByText("Standings").closest("a");
    expect(standingsLink?.className).toContain("text-gold");
  });

  it("non-active tabs are dimmed", () => {
    render(<BottomTabs />);
    const rulesLink = screen.getByText("Rules").closest("a");
    expect(rulesLink?.className).toContain("text-white/50");
  });

  it("all tabs have minimum 56px touch target height", () => {
    render(<BottomTabs />);
    const standingsLink = screen.getByText("Standings").closest("a");
    expect(standingsLink?.className).toContain("min-h-[56px]");
  });

  it("Post tab links to login when not authenticated", () => {
    render(<BottomTabs />);
    const postLink = screen.getByText("Post").closest("a");
    expect(postLink).toHaveAttribute("href", "/login");
  });

  it("has the fixed bottom positioning classes", () => {
    render(<BottomTabs />);
    const nav = screen.getByText("Standings").closest("nav");
    expect(nav?.className).toContain("fixed");
    expect(nav?.className).toContain("bottom-0");
  });
});

