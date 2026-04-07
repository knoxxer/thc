import { chromium } from "@playwright/test";
import path from "path";
import fs from "fs";

const MOCKUP_PATH = path.resolve(__dirname, "../docs/social-features-mockups.html");
const OUTPUT_DIR = path.resolve(__dirname, "../docs/mockups");

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  // Use a very tall viewport so all content is "visible" for clipping
  const page = await browser.newPage({ viewport: { width: 560, height: 8000 } });

  await page.goto(`file://${MOCKUP_PATH}`);
  await page.waitForLoadState("load");

  // Full page screenshot
  await page.screenshot({
    path: path.join(OUTPUT_DIR, "00-full-page.png"),
    fullPage: true,
  });
  console.log("Saved: 00-full-page.png");

  // Get all h2 positions
  const headings = await page.locator("h2").all();
  const positions: { y: number; text: string }[] = [];
  for (const h of headings) {
    const box = await h.boundingBox();
    const text = await h.innerText();
    if (box) positions.push({ y: box.y, text });
  }

  const fullHeight = await page.evaluate(() => document.body.scrollHeight);

  const sectionNames = [
    "01-nav-with-feed-and-bell",
    "02-notification-dropdown",
    "03-upcoming-rounds",
    "04-weekly-recap",
    "05-auto-milestones",
    "06-feed-with-reactions-comments",
  ];

  for (let i = 0; i < positions.length && i < sectionNames.length; i++) {
    const startY = Math.max(0, positions[i].y - 4);
    const endY = i + 1 < positions.length ? positions[i + 1].y - 8 : fullHeight - 40;
    const height = Math.max(10, endY - startY);

    try {
      await page.screenshot({
        path: path.join(OUTPUT_DIR, `${sectionNames[i]}.png`),
        clip: { x: 0, y: startY, width: 560, height },
      });
      console.log(`Saved: ${sectionNames[i]}.png (${Math.round(height)}px)`);
    } catch (e) {
      console.log(`Skipped ${sectionNames[i]}: ${(e as Error).message}`);
    }
  }

  await browser.close();
  console.log(`\nAll mockups saved to: ${OUTPUT_DIR}`);
}

main().catch(console.error);
