const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

// Convert tile images to base64 for embedding in HTML
function tileToBase64(row, col) {
  const data = fs.readFileSync(`/tmp/tiles/tile_${row}_${col}.png`);
  return `data:image/jpeg;base64,${data.toString('base64')}`;
}

const tiles = {};
for (let r = 0; r < 3; r++) {
  for (let c = 0; c < 3; c++) {
    tiles[`${r}_${c}`] = tileToBase64(r, c);
  }
}

// Tile math for zoom 17
// Each tile is 256px, covers ~0.00274658 degrees lat, ~0.00274658 degrees lon at this zoom
// Tile 22846,52836 top-left corner:
const zoom = 17;
const n = Math.pow(2, zoom);

function tileToLatLon(x, y) {
  const lon = x / n * 360 - 180;
  const latRad = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n)));
  const lat = latRad * 180 / Math.PI;
  return { lat, lon };
}

const topLeft = tileToLatLon(22846, 52836);
const bottomRight = tileToLatLon(22849, 52839);

// Our 3x3 tile grid covers:
console.log(`Grid covers: ${topLeft.lat}, ${topLeft.lon} to ${bottomRight.lat}, ${bottomRight.lon}`);

// Project lat/lon to pixel position in our 768x768 tile grid
function project(lat, lon) {
  const x = (lon - topLeft.lon) / (bottomRight.lon - topLeft.lon) * 768;
  const y = (topLeft.lat - lat) / (topLeft.lat - bottomRight.lat) * 768;
  return { x, y };
}

// Key coordinates
const tee = project(32.9040176, -117.2455388);
const greenCenter = project(32.9022891, -117.2493766);
const user = project(32.9028, -117.2480);
const mid = project(32.9027720, -117.2476531);

console.log(`Tee: ${tee.x.toFixed(0)}, ${tee.y.toFixed(0)}`);
console.log(`Green: ${greenCenter.x.toFixed(0)}, ${greenCenter.y.toFixed(0)}`);
console.log(`User: ${user.x.toFixed(0)}, ${user.y.toFixed(0)}`);

// Crop area: we want to show tee to green, portrait oriented
// Add some padding
const allPts = [tee, greenCenter, user];
const minX = Math.min(...allPts.map(p => p.x)) - 60;
const maxX = Math.max(...allPts.map(p => p.x)) + 60;
const minY = Math.min(...allPts.map(p => p.y)) - 40;
const maxY = Math.max(...allPts.map(p => p.y)) + 60;

// Make it fit phone aspect ratio (361 x 400 viewbox)
const cropW = maxX - minX;
const cropH = maxY - minY;

const html = `<!DOCTYPE html>
<html>
<head>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #1a1a2e; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif; display: flex; gap: 50px; padding: 40px; justify-content: center; }
  .phone { width: 393px; height: 852px; background: #0a1a0f; border-radius: 47px; overflow: hidden; border: 4px solid #333; position: relative; }
  .notch { width: 126px; height: 34px; background: #000; border-radius: 0 0 20px 20px; position: absolute; top: 0; left: 50%; transform: translateX(-50%); z-index: 10; }
  .status-bar { height: 54px; display: flex; justify-content: space-between; align-items: center; padding: 14px 30px 0; color: #fff; font-size: 15px; font-weight: 600; position: relative; z-index: 5; }
  .screen { padding: 0 16px; height: calc(100% - 54px - 83px); overflow: hidden; }
  .tab-bar { height: 83px; background: rgba(18,34,24,0.95); border-top: 0.5px solid #1c3324; display: flex; justify-content: space-around; align-items: flex-start; padding-top: 10px; position: absolute; bottom: 0; width: 100%; }
  .tab { text-align: center; color: #7a9a80; font-size: 10px; }
  .tab.active { color: #C5A059; }
  .tab-icon { font-size: 24px; margin-bottom: 2px; }
  .home-indicator { width: 134px; height: 5px; background: #fff; border-radius: 3px; position: absolute; bottom: 8px; left: 50%; transform: translateX(-50%); opacity: 0.3; }
  .device-wrap { position: relative; margin-bottom: 50px; }
  .screen-label { text-align: center; color: #e8efe8; font-size: 16px; font-weight: 600; margin-top: 16px; }
  .screen-sublabel { text-align: center; color: #7a9a80; font-size: 13px; margin-top: 4px; }
  .gps-hole-header { display: flex; justify-content: space-between; align-items: center; padding: 8px 4px; position: relative; z-index: 5; }
  .hole-num { font-size: 22px; font-weight: 700; color: #e8efe8; text-shadow: 0 1px 4px rgba(0,0,0,0.8); }
  .hole-par { font-size: 13px; color: #bbb; text-shadow: 0 1px 3px rgba(0,0,0,0.8); }
  .map-area { width: 100%; height: 400px; border-radius: 16px; position: relative; overflow: hidden; margin-bottom: 12px; }
  .sat-grid { display: grid; grid-template-columns: repeat(3, 256px); grid-template-rows: repeat(3, 256px); position: absolute; }
  .sat-grid img { width: 256px; height: 256px; display: block; }
  .map-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
  .distance-main { display: flex; justify-content: space-around; margin-bottom: 10px; }
  .dist-item { text-align: center; background: #122218; border-radius: 12px; padding: 10px 14px; flex: 1; margin: 0 4px; border: 1px solid #1c3324; }
  .dist-label { font-size: 10px; color: #7a9a80; text-transform: uppercase; letter-spacing: 1px; }
  .dist-value { font-size: 26px; font-weight: 700; color: #e8efe8; margin-top: 2px; }
  .dist-item.center .dist-value { color: #C5A059; }
  .hazard-row { display: flex; justify-content: space-between; background: #122218; border-radius: 10px; padding: 9px 14px; margin-bottom: 5px; border: 1px solid #1c3324; }
  .hazard-name { font-size: 13px; color: #e8efe8; }
  .hazard-dist { font-size: 13px; font-weight: 600; }
  .hazard-carry { color: #e85d5d; }
  .hazard-front { color: #7a9a80; }
  .yardage-card { background: #081a0e; border-radius: 16px; padding: 50px 20px; margin-bottom: 12px; text-align: center; }
  .yardage-big { font-size: 120px; font-weight: 700; color: #C5A059; line-height: 1; letter-spacing: -3px; }
  .yardage-label { font-size: 14px; color: #7a9a80; text-transform: uppercase; letter-spacing: 2px; margin-top: 8px; }
</style>
</head>
<body>

<!-- SCREEN 1: Satellite + OSM overlay -->
<div class="device-wrap">
<div class="phone">
  <div class="notch"></div>
  <div class="status-bar"><span>10:23</span><span></span></div>
  <div class="screen">
    <div class="gps-hole-header">
      <div><div class="hole-num">Hole 1</div><div class="hole-par">Par 4 · 453 yds · SI 7</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#ccc;text-shadow:0 1px 3px rgba(0,0,0,0.8);">Torrey Pines South</div><div style="font-size:12px;color:#4CAF50;text-shadow:0 1px 3px rgba(0,0,0,0.8);">● GPS</div></div>
    </div>

    <div class="map-area">
      <!-- Satellite tile grid -->
      <div class="sat-grid" style="left: ${-minX}px; top: ${-minY}px;">
        <img src="${tiles['0_0']}"><img src="${tiles['0_1']}"><img src="${tiles['0_2']}">
        <img src="${tiles['1_0']}"><img src="${tiles['1_1']}"><img src="${tiles['1_2']}">
        <img src="${tiles['2_0']}"><img src="${tiles['2_1']}"><img src="${tiles['2_2']}">
      </div>

      <!-- Semi-transparent overlay to darken satellite slightly -->
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.15);"></div>

      <!-- SVG overlay with course features -->
      <svg class="map-overlay" viewBox="${minX} ${minY} ${cropW} ${cropH}" xmlns="http://www.w3.org/2000/svg">

        <!-- Green outline -->
        <ellipse cx="${greenCenter.x}" cy="${greenCenter.y}" rx="18" ry="13" fill="rgba(45,180,60,0.25)" stroke="#4CAF50" stroke-width="2.5" transform="rotate(-20 ${greenCenter.x} ${greenCenter.y})"/>

        <!-- Pin -->
        <line x1="${greenCenter.x - 2}" y1="${greenCenter.y}" x2="${greenCenter.x - 2}" y2="${greenCenter.y - 14}" stroke="#fff" stroke-width="1.5"/>
        <polygon points="${greenCenter.x - 2},${greenCenter.y - 14} ${greenCenter.x + 8},${greenCenter.y - 11} ${greenCenter.x - 2},${greenCenter.y - 8}" fill="#e85d5d"/>

        <!-- Front/back markers -->
        <circle cx="${greenCenter.x + 8}" cy="${greenCenter.y - 5}" r="3" fill="none" stroke="rgba(255,255,255,0.8)" stroke-width="1.5"/>
        <text x="${greenCenter.x + 14}" y="${greenCenter.y - 3}" font-size="10" fill="#fff" font-weight="700" style="text-shadow:0 1px 3px rgba(0,0,0,0.9)">F</text>
        <circle cx="${greenCenter.x - 10}" cy="${greenCenter.y + 8}" r="3" fill="none" stroke="rgba(255,255,255,0.8)" stroke-width="1.5"/>
        <text x="${greenCenter.x - 22}" y="${greenCenter.y + 11}" font-size="10" fill="#fff" font-weight="700" style="text-shadow:0 1px 3px rgba(0,0,0,0.9)">B</text>

        <!-- Bunker highlights -->
        <ellipse cx="${greenCenter.x + 22}" cy="${greenCenter.y - 8}" rx="10" ry="6" fill="none" stroke="rgba(230,210,150,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <ellipse cx="${greenCenter.x - 20}" cy="${greenCenter.y + 12}" rx="8" ry="5" fill="none" stroke="rgba(230,210,150,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>

        <!-- Fairway bunker -->
        <ellipse cx="${(user.x + greenCenter.x) / 2 + 25}" cy="${(user.y + greenCenter.y) / 2 + 5}" rx="11" ry="7" fill="none" stroke="rgba(230,210,150,0.6)" stroke-width="1.5" stroke-dasharray="3,2"/>

        <!-- User position -->
        <circle cx="${user.x}" cy="${user.y}" r="8" fill="#4A90D9" stroke="#fff" stroke-width="3" filter="url(#shadow)"/>
        <circle cx="${user.x}" cy="${user.y}" r="18" fill="none" stroke="rgba(74,144,217,0.3)" stroke-width="1.5"/>

        <!-- Distance line -->
        <line x1="${user.x}" y1="${user.y}" x2="${greenCenter.x}" y2="${greenCenter.y}" stroke="rgba(197,160,89,0.6)" stroke-width="2" stroke-dasharray="5,4"/>

        <!-- Distance badge -->
        <rect x="${(user.x + greenCenter.x) / 2 - 34}" y="${(user.y + greenCenter.y) / 2 - 14}" width="68" height="28" rx="8" fill="rgba(0,0,0,0.85)"/>
        <text x="${(user.x + greenCenter.x) / 2}" y="${(user.y + greenCenter.y) / 2 + 5}" text-anchor="middle" font-size="15" fill="#C5A059" font-weight="700">172 yds</text>

        <!-- Yardage markers -->
        <rect x="${project(32.9034, -117.2470).x - 16}" y="${project(32.9034, -117.2470).y - 9}" width="32" height="18" rx="5" fill="rgba(0,0,0,0.6)"/>
        <text x="${project(32.9034, -117.2470).x}" y="${project(32.9034, -117.2470).y + 4}" text-anchor="middle" font-size="10" fill="rgba(255,255,255,0.6)">250</text>

        <rect x="${project(32.9026, -117.2484).x - 16}" y="${project(32.9026, -117.2484).y - 9}" width="32" height="18" rx="5" fill="rgba(0,0,0,0.6)"/>
        <text x="${project(32.9026, -117.2484).x}" y="${project(32.9026, -117.2484).y + 4}" text-anchor="middle" font-size="10" fill="rgba(255,255,255,0.6)">150</text>

        <!-- Compass -->
        <circle cx="${minX + cropW - 25}" cy="${minY + 25}" r="16" fill="rgba(0,0,0,0.7)" stroke="rgba(255,255,255,0.3)" stroke-width="0.5"/>
        <text x="${minX + cropW - 25}" y="${minY + 30}" text-anchor="middle" font-size="12" fill="#fff" font-weight="600">N</text>
        <line x1="${minX + cropW - 25}" y1="${minY + 15}" x2="${minX + cropW - 25}" y2="${minY + 10}" stroke="#e85d5d" stroke-width="2"/>

        <!-- Hole badge -->
        <rect x="${minX + 10}" y="${minY + 10}" width="36" height="24" rx="8" fill="rgba(0,0,0,0.8)"/>
        <text x="${minX + 28}" y="${minY + 27}" text-anchor="middle" font-size="14" fill="#C5A059" font-weight="700">#1</text>

        <defs>
          <filter id="shadow"><feDropShadow dx="0" dy="1" stdDeviation="3" flood-opacity="0.6"/></filter>
        </defs>
      </svg>
    </div>

    <div class="distance-main">
      <div class="dist-item"><div class="dist-label">Front</div><div class="dist-value">158</div></div>
      <div class="dist-item center"><div class="dist-label">Center</div><div class="dist-value">172</div></div>
      <div class="dist-item"><div class="dist-label">Back</div><div class="dist-value">186</div></div>
    </div>

    <div class="hazard-row">
      <div class="hazard-name">⚪ Greenside bunker</div>
      <div><span class="hazard-dist hazard-front">147</span>   <span class="hazard-dist hazard-carry">Carry 162</span></div>
    </div>
    <div class="hazard-row">
      <div class="hazard-name">⚪ Fairway bunker (L)</div>
      <div><span class="hazard-dist hazard-front">42</span>   <span class="hazard-dist hazard-carry">Carry 58</span></div>
    </div>
  </div>

  <div class="tab-bar">
    <div class="tab"><div class="tab-icon">🏆</div>Standings</div>
    <div class="tab active"><div class="tab-icon">⛳</div>GPS</div>
    <div class="tab"><div class="tab-icon">📝</div>Score</div>
    <div class="tab"><div class="tab-icon">👤</div>Profile</div>
  </div>
  <div class="home-indicator"></div>
</div>
<div class="screen-label">Satellite + Course Overlay</div>
<div class="screen-sublabel">Real Torrey Pines Hole 1</div>
</div>

<!-- SCREEN 2: Yardage Only -->
<div class="device-wrap">
<div class="phone">
  <div class="notch"></div>
  <div class="status-bar"><span>2:15</span><span></span></div>
  <div class="screen">
    <div class="gps-hole-header">
      <div><div class="hole-num">Hole 4</div><div class="hole-par">Par 4 · 380 yds</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#7a9a80;">Rancho Bernardo Inn</div><div style="font-size:12px;color:#C5A059;">● Yardage</div></div>
    </div>

    <div class="yardage-card">
      <div class="yardage-big">164</div>
      <div class="yardage-label">yards to green</div>
    </div>

    <div class="distance-main">
      <div class="dist-item" style="opacity:0.3;border-style:dashed;"><div class="dist-label">Front</div><div class="dist-value">—</div></div>
      <div class="dist-item center"><div class="dist-label">Center</div><div class="dist-value">164</div></div>
      <div class="dist-item" style="opacity:0.3;border-style:dashed;"><div class="dist-label">Back</div><div class="dist-value">—</div></div>
    </div>

    <div style="text-align:center;padding:20px;color:#7a9a80;font-size:13px;">
      Course map not available<br>
      <span style="font-size:12px;">Front/back and hazard distances require<br>OpenStreetMap data for this course</span>
    </div>

    <div style="display:flex;justify-content:space-between;align-items:center;background:#122218;border-radius:12px;padding:14px 18px;margin-top:16px;border:1px solid #1c3324;">
      <div style="color:#7a9a80;font-size:14px;">◀ Hole 3</div>
      <div style="color:#e8efe8;font-size:16px;font-weight:600;">4 of 18</div>
      <div style="color:#7a9a80;font-size:14px;">Hole 5 ▶</div>
    </div>

    <div style="display:flex;justify-content:space-between;align-items:center;background:#122218;border-radius:12px;padding:14px 18px;margin-top:8px;border:1px solid #1c3324;">
      <div style="text-align:center;flex:1;"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase;">Score</div><div style="color:#e8efe8;font-size:22px;font-weight:700;">—</div></div>
      <div style="text-align:center;flex:1;border-left:1px solid #1c3324;border-right:1px solid #1c3324;"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase;">Thru 3</div><div style="color:#C5A059;font-size:22px;font-weight:700;">+2</div></div>
      <div style="text-align:center;flex:1;"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase;">Net</div><div style="color:#2E7D32;font-size:22px;font-weight:700;">E</div></div>
    </div>

    <div style="display:flex;justify-content:center;align-items:center;background:linear-gradient(135deg,#1a2e1f,#122218);border-radius:12px;padding:14px 18px;margin-top:8px;border:1px solid rgba(197,160,89,0.3);">
      <div style="color:#7a9a80;font-size:13px;">Projected&nbsp;</div>
      <div style="color:#C5A059;font-size:20px;font-weight:700;">10 pts</div>
    </div>
  </div>

  <div class="tab-bar">
    <div class="tab"><div class="tab-icon">🏆</div>Standings</div>
    <div class="tab active"><div class="tab-icon">⛳</div>GPS</div>
    <div class="tab"><div class="tab-icon">📝</div>Score</div>
    <div class="tab"><div class="tab-icon">👤</div>Profile</div>
  </div>
  <div class="home-indicator"></div>
</div>
<div class="screen-label">No Course Data — Yardage Only</div>
<div class="screen-sublabel">Center distance only</div>
</div>

</body>
</html>`;

(async () => {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 920, height: 960, deviceScaleFactor: 2 });
  await page.setContent(html, { waitUntil: 'networkidle0' });

  await page.screenshot({ path: path.resolve('/home/user/thc/docs/mockups', 'v3-satellite-overlay.png'), fullPage: false });

  const devices = await page.$$('.device-wrap');
  if (devices[0]) {
    const b = await devices[0].boundingBox();
    await page.screenshot({ path: path.resolve('/home/user/thc/docs/mockups', 'v3-osm-satellite.png'), clip: { x: b.x-10, y: b.y-10, width: b.width+20, height: b.height+60 }});
  }
  if (devices[1]) {
    const b = await devices[1].boundingBox();
    await page.screenshot({ path: path.resolve('/home/user/thc/docs/mockups', 'v3-yardage-only.png'), clip: { x: b.x-10, y: b.y-10, width: b.width+20, height: b.height+60 }});
  }

  await browser.close();
  console.log('Done — v3 screenshots saved');
})();
