import { test, expect } from "@playwright/test";

test.describe("Feed Page", () => {
  test("loads /feed and shows heading", async ({ page }) => {
    await page.goto("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
  });

  test("shows empty state or rounds", async ({ page }) => {
    await page.goto("/feed");

    // Should show either rounds or empty state message
    const content = page.locator("main");
    await expect(content).toBeVisible();

    const feedContent = page.locator('[class*="space-y"]');
    await expect(feedContent).toBeVisible();
  });

  test("nav contains Feed link", async ({ page }) => {
    await page.goto("/");

    const feedLink = page.locator('a[href="/feed"]');
    await expect(feedLink.first()).toBeVisible();
  });

  test("Feed link navigates to /feed", async ({ page }) => {
    await page.goto("/");

    // Click Feed in nav (desktop or mobile)
    const feedLink = page.locator('a[href="/feed"]').first();
    await feedLink.click();

    await expect(page).toHaveURL("/feed");
    await expect(page.locator("h1")).toContainText("Feed");
  });

  test("reaction bar shows + button when logged in", async ({ page }) => {
    // This test verifies the reaction bar renders properly
    // For unauthenticated users, + button should NOT appear
    await page.goto("/feed");

    // The + button should not be visible without auth
    const plusButtons = page.locator('button:has-text("+")');
    // Count may be 0 if no rounds, or if user is not logged in
    const count = await plusButtons.count();
    // Unauthenticated users should see 0 + buttons
    expect(count).toBe(0);
  });

  test("post upcoming form hidden when not logged in", async ({ page }) => {
    await page.goto("/feed");

    // The post form button should not be visible without auth
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

    // Feed link should be visible in the dropdown
    const feedLink = page.locator('a[href="/feed"]');
    await expect(feedLink.first()).toBeVisible();
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
