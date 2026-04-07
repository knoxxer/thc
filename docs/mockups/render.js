const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  const htmlPath = path.resolve(__dirname, 'screens.html');

  // Render full page for all screens together
  await page.setViewport({ width: 1800, height: 920, deviceScaleFactor: 2 });
  await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: path.resolve(__dirname, 'all-screens.png'), fullPage: false });

  // Individual screens
  const devices = await page.$$('.device-wrap');

  for (let i = 0; i < devices.length; i++) {
    const names = ['01-leaderboard', '02-gps-hole-overview', '03-live-scoring', '04-apple-watch'];
    const box = await devices[i].boundingBox();
    if (box) {
      await page.screenshot({
        path: path.resolve(__dirname, `${names[i]}.png`),
        clip: { x: box.x - 10, y: box.y - 10, width: box.width + 20, height: box.height + 50 }
      });
    }
  }

  await browser.close();
  console.log('Done — screenshots saved to docs/mockups/');
})();
