const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 920, height: 960, deviceScaleFactor: 2 });
  await page.goto(`file://${path.resolve(__dirname, 'real-vs-yardage.html')}`, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: path.resolve(__dirname, 'osm-vs-yardage.png'), fullPage: false });

  // Individual screens
  const devices = await page.$$('.device-wrap');
  if (devices[0]) {
    const b = await devices[0].boundingBox();
    await page.screenshot({ path: path.resolve(__dirname, '05-osm-course-map.png'), clip: { x: b.x-10, y: b.y-10, width: b.width+20, height: b.height+60 }});
  }
  if (devices[1]) {
    const b = await devices[1].boundingBox();
    await page.screenshot({ path: path.resolve(__dirname, '06-yardage-only.png'), clip: { x: b.x-10, y: b.y-10, width: b.width+20, height: b.height+60 }});
  }

  await browser.close();
  console.log('Done');
})();
