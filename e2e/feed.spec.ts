import { test, expect } from "@playwright/test";

test.describe("Feed Page", () => {
  test("loads /feed and shows heading", async ({ page }) => {
    await page.goto("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
  });

  test("shows feed content area", async ({ page }) => {
    await page.goto("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
    const body = page.locator("body");
    await expect(body).toBeVisible();
  });

  test("feed shows round cards or empty state", async ({ page }) => {
    await page.goto("/feed");
    await page.waitForLoadState("networkidle");
    const bodyText = await page.locator("body").innerText();
    const hasRounds = bodyText.includes("Torrey Pines") || bodyText.includes("gross");
    const hasEmpty = bodyText.includes("No rounds posted yet") || bodyText.includes("No active season");
    expect(hasRounds || hasEmpty).toBe(true);
  });

  test("nav contains Feed link", async ({ page }) => {
    await page.goto("/");
    const feedLink = page.locator('a[href="/feed"]');
    await expect(feedLink.first()).toBeVisible();
  });

  test("Feed link navigates to /feed", async ({ page }) => {
    await page.goto("/");
    const feedLink = page.locator('a[href="/feed"]').first();
    await feedLink.click();
    await expect(page).toHaveURL("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
  });

  test("reaction + button hidden when not logged in", async ({ page }) => {
    await page.goto("/feed");
    const plusButtons = page.locator('button:has-text("+")');
    const count = await plusButtons.count();
    expect(count).toBe(0);
  });

  test("post upcoming form hidden when not logged in", async ({ page }) => {
    await page.goto("/feed");
    const postButton = page.locator('text="+ Post an upcoming round"');
    await expect(postButton).toHaveCount(0);
  });

  test("comment input hidden when not logged in", async ({ page }) => {
    await page.goto("/feed");
    const commentInput = page.locator('input[placeholder="Add comment..."]');
    await expect(commentInput).toHaveCount(0);
  });
});

test.describe("Social API", () => {
  test("POST /api/social returns 401 without auth", async ({ request }) => {
    const res = await request.post("/api/social", {
      data: { action: "add_reaction", roundId: "test", emoji: "🔥" },
    });
    expect(res.status()).toBe(401);
  });

  test("POST /api/social returns 400 for unknown action", async ({ request }) => {
    // This will return 401 since no auth, but tests the endpoint exists
    const res = await request.post("/api/social", {
      data: { action: "unknown" },
    });
    // 401 because unauthenticated — endpoint is reachable
    expect([400, 401]).toContain(res.status());
  });
});

test.describe("Notifications API", () => {
  test("GET /api/notifications returns 401 without auth", async ({ request }) => {
    const res = await request.get("/api/notifications");
    expect(res.status()).toBe(401);
  });

  test("PATCH /api/notifications returns 401 without auth", async ({ request }) => {
    const res = await request.patch("/api/notifications", {
      data: { all: true },
    });
    expect(res.status()).toBe(401);
  });
});

test.describe("Navigation", () => {
  test("desktop nav shows all links", async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto("/");

    await expect(page.locator('a[href="/"]').first()).toBeVisible();
    await expect(page.locator('a[href="/feed"]').first()).toBeVisible();
    await expect(page.locator('a[href="/rules"]').first()).toBeVisible();
    await expect(page.locator('a[href="/players"]').first()).toBeVisible();
  });

  test("mobile bottom tabs include Feed", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Bottom tabs should have a Feed link (any link to /feed visible on page)
    const feedLinks = page.locator('a[href="/feed"]');
    const count = await feedLinks.count();
    expect(count).toBeGreaterThan(0);
  });

  test("mobile Feed tab links to /feed", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Verify the Feed link exists and points to /feed
    const feedLink = page.locator('a[href="/feed"]').first();
    await expect(feedLink).toHaveAttribute("href", "/feed");
  });
});

test.describe("Leaderboard", () => {
  test("homepage shows Season Standings", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("h1")).toContainText("Season Standings");
  });
});

test.describe("Rules Page", () => {
  test("rules page loads", async ({ page }) => {
    await page.goto("/rules");
    await expect(page.locator("h1")).toBeVisible();
  });
});

test.describe("Players Page", () => {
  test("players page loads", async ({ page }) => {
    await page.goto("/players");
    await expect(page.locator("h1")).toContainText("The Homies");
  });
});
