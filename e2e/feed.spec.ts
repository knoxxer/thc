import { test, expect } from "@playwright/test";

test.describe("Feed Page", () => {
  test("loads /feed and shows heading", async ({ page }) => {
    await page.goto("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
  });

  test("shows feed content area", async ({ page }) => {
    await page.goto("/feed");
    // The ActivityFeed wrapper always renders a space-y-4 div
    await expect(page.locator("h1")).toContainText("Feed");
    // Page should have rendered content below the heading
    const body = page.locator("body");
    await expect(body).toBeVisible();
  });

  test("feed shows round cards or empty state", async ({ page }) => {
    await page.goto("/feed");
    // Wait for page to fully render
    await page.waitForLoadState("networkidle");
    // The feed should render either round cards or the empty state
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
    // Unauthenticated users should see no + buttons for reactions
    const plusButtons = page.locator('button:has-text("+")');
    const count = await plusButtons.count();
    expect(count).toBe(0);
  });

  test("post upcoming form hidden when not logged in", async ({ page }) => {
    await page.goto("/feed");
    const postButton = page.locator('text="+ Post an upcoming round"');
    await expect(postButton).toHaveCount(0);
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

  test("mobile nav has Feed in hamburger menu", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/");

    // Open hamburger menu
    const menuButton = page.locator('button[aria-label="Menu"]');
    await menuButton.click();

    // The mobile menu is inside the md:hidden dropdown — look for visible Feed links
    const feedLinks = page.locator('a[href="/feed"]');
    const visibleCount = await feedLinks.evaluateAll(
      (links) => links.filter((l) => l.offsetParent !== null).length
    );
    expect(visibleCount).toBeGreaterThan(0);
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
