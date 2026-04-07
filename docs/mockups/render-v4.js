const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

function tileToBase64(dir, row, col) {
  const data = fs.readFileSync(`${dir}/tile_${row}_${col}.png`);
  return `data:image/jpeg;base64,${data.toString('base64')}`;
}

// Torrey Pines tiles
const tp = {};
for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) tp[`${r}_${c}`] = tileToBase64('/tmp/tiles', r, c);

// Rancho Bernardo tiles
const rb = {};
for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) rb[`${r}_${c}`] = tileToBase64('/tmp/tiles2', r, c);

// Torrey Pines projection
const zoom = 17, n = Math.pow(2, zoom);
function tileToLatLon(x, y) {
  return { lat: Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n))) * 180 / Math.PI, lon: x / n * 360 - 180 };
}

const tpTL = tileToLatLon(22846, 52836);
const tpBR = tileToLatLon(22849, 52839);
function tpProject(lat, lon) {
  return { x: (lon - tpTL.lon) / (tpBR.lon - tpTL.lon) * 768, y: (tpTL.lat - lat) / (tpTL.lat - tpBR.lat) * 768 };
}

const rbTL = tileToLatLon(22910, 52784);
const rbBR = tileToLatLon(22913, 52787);

// Key points
const tee = tpProject(32.9040176, -117.2455388);
const green = tpProject(32.9022891, -117.2493766);
const user = tpProject(32.9028, -117.2480);

// Crop to show the hole nicely
const pts = [tee, green, user];
const mX = Math.min(...pts.map(p=>p.x)) - 50, MX = Math.max(...pts.map(p=>p.x)) + 50;
const mY = Math.min(...pts.map(p=>p.y)) - 30, MY = Math.max(...pts.map(p=>p.y)) + 50;
const cW = MX - mX, cH = MY - mY;

const html = `<!DOCTYPE html>
<html><head><style>
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#1a1a2e; font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif; display:flex; gap:50px; padding:40px; justify-content:center; }
.phone { width:393px; height:852px; background:#0a1a0f; border-radius:47px; overflow:hidden; border:4px solid #333; position:relative; }
.notch { width:126px; height:34px; background:#000; border-radius:0 0 20px 20px; position:absolute; top:0; left:50%; transform:translateX(-50%); z-index:10; }
.status-bar { height:54px; display:flex; justify-content:space-between; align-items:center; padding:14px 30px 0; color:#fff; font-size:15px; font-weight:600; z-index:5; position:relative; }
.screen { padding:0 16px; height:calc(100% - 54px - 83px); overflow:hidden; }
.tab-bar { height:83px; background:rgba(18,34,24,0.95); border-top:0.5px solid #1c3324; display:flex; justify-content:space-around; align-items:flex-start; padding-top:10px; position:absolute; bottom:0; width:100%; }
.tab { text-align:center; color:#7a9a80; font-size:10px; }
.tab.active { color:#C5A059; }
.tab-icon { font-size:24px; margin-bottom:2px; }
.home-indicator { width:134px; height:5px; background:#fff; border-radius:3px; position:absolute; bottom:8px; left:50%; transform:translateX(-50%); opacity:0.3; }
.device-wrap { position:relative; margin-bottom:50px; }
.screen-label { text-align:center; color:#e8efe8; font-size:16px; font-weight:600; margin-top:16px; }
.screen-sublabel { text-align:center; color:#7a9a80; font-size:13px; margin-top:4px; }
.header { display:flex; justify-content:space-between; align-items:center; padding:8px 4px; z-index:5; position:relative; }
.hole-num { font-size:22px; font-weight:700; color:#e8efe8; text-shadow:0 1px 4px rgba(0,0,0,0.8); }
.hole-par { font-size:13px; color:#bbb; text-shadow:0 1px 3px rgba(0,0,0,0.8); }
.map { width:100%; height:400px; border-radius:16px; position:relative; overflow:hidden; margin-bottom:12px; }
.tiles { display:grid; grid-template-columns:repeat(3,256px); position:absolute; }
.tiles img { width:256px; height:256px; display:block; }
.overlay { position:absolute; top:0; left:0; width:100%; height:100%; }
.dist-row { display:flex; margin-bottom:10px; }
.dist-box { text-align:center; background:#122218; border-radius:12px; padding:10px 14px; flex:1; margin:0 4px; border:1px solid #1c3324; }
.dist-lbl { font-size:10px; color:#7a9a80; text-transform:uppercase; letter-spacing:1px; }
.dist-val { font-size:26px; font-weight:700; color:#e8efe8; margin-top:2px; }
.dist-box.ctr .dist-val { color:#C5A059; }
.hz { display:flex; justify-content:space-between; background:#122218; border-radius:10px; padding:9px 14px; margin-bottom:5px; border:1px solid #1c3324; }
.hz-name { font-size:13px; color:#e8efe8; }
.hz-d { font-size:13px; font-weight:600; }
.hz-carry { color:#e85d5d; }
.hz-front { color:#7a9a80; }
</style></head><body>

<!-- SCREEN 1: Satellite + OSM overlays (Torrey Pines) -->
<div class="device-wrap">
<div class="phone">
  <div class="notch"></div>
  <div class="status-bar"><span>10:23</span><span></span></div>
  <div class="screen">
    <div class="header">
      <div><div class="hole-num">Hole 1</div><div class="hole-par">Par 4 · 453 yds · SI 7</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#ccc;text-shadow:0 1px 3px rgba(0,0,0,0.8)">Torrey Pines South</div><div style="font-size:12px;color:#4CAF50;text-shadow:0 1px 3px rgba(0,0,0,0.8)">● GPS</div></div>
    </div>
    <div class="map">
      <div class="tiles" style="left:${-mX}px;top:${-mY}px">
        <img src="${tp['0_0']}"><img src="${tp['0_1']}"><img src="${tp['0_2']}">
        <img src="${tp['1_0']}"><img src="${tp['1_1']}"><img src="${tp['1_2']}">
        <img src="${tp['2_0']}"><img src="${tp['2_1']}"><img src="${tp['2_2']}">
      </div>
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.1)"></div>
      <svg class="overlay" viewBox="${mX} ${mY} ${cW} ${cH}">
        <!-- Green outline -->
        <ellipse cx="${green.x}" cy="${green.y}" rx="18" ry="13" fill="rgba(45,180,60,0.3)" stroke="#4CAF50" stroke-width="2.5" transform="rotate(-20 ${green.x} ${green.y})"/>
        <!-- Pin -->
        <line x1="${green.x-2}" y1="${green.y}" x2="${green.x-2}" y2="${green.y-14}" stroke="#fff" stroke-width="1.5"/>
        <polygon points="${green.x-2},${green.y-14} ${green.x+8},${green.y-11} ${green.x-2},${green.y-8}" fill="#e85d5d"/>
        <!-- F/B -->
        <circle cx="${green.x+9}" cy="${green.y-5}" r="3" fill="none" stroke="rgba(255,255,255,0.9)" stroke-width="1.5"/>
        <text x="${green.x+15}" y="${green.y-2}" font-size="11" fill="#fff" font-weight="700" style="text-shadow:0 1px 4px rgba(0,0,0,1)">F</text>
        <circle cx="${green.x-10}" cy="${green.y+9}" r="3" fill="none" stroke="rgba(255,255,255,0.9)" stroke-width="1.5"/>
        <text x="${green.x-23}" y="${green.y+12}" font-size="11" fill="#fff" font-weight="700" style="text-shadow:0 1px 4px rgba(0,0,0,1)">B</text>
        <!-- Bunker outlines -->
        <ellipse cx="${green.x+24}" cy="${green.y-8}" rx="11" ry="7" fill="none" stroke="rgba(240,220,160,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <ellipse cx="${green.x-22}" cy="${green.y+14}" rx="9" ry="6" fill="none" stroke="rgba(240,220,160,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <ellipse cx="${(user.x+green.x)/2+28}" cy="${(user.y+green.y)/2+8}" rx="12" ry="7" fill="none" stroke="rgba(240,220,160,0.6)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <!-- User -->
        <circle cx="${user.x}" cy="${user.y}" r="9" fill="#4A90D9" stroke="#fff" stroke-width="3"/>
        <circle cx="${user.x}" cy="${user.y}" r="20" fill="none" stroke="rgba(74,144,217,0.25)" stroke-width="1.5"/>
        <!-- Distance line -->
        <line x1="${user.x}" y1="${user.y}" x2="${green.x}" y2="${green.y}" stroke="rgba(197,160,89,0.6)" stroke-width="2" stroke-dasharray="5,4"/>
        <!-- Distance badge -->
        <rect x="${(user.x+green.x)/2-36}" y="${(user.y+green.y)/2-15}" width="72" height="30" rx="9" fill="rgba(0,0,0,0.85)"/>
        <text x="${(user.x+green.x)/2}" y="${(user.y+green.y)/2+7}" text-anchor="middle" font-size="16" fill="#C5A059" font-weight="700">172 yds</text>
        <!-- Compass -->
        <circle cx="${mX+cW-28}" cy="${mY+28}" r="17" fill="rgba(0,0,0,0.7)" stroke="rgba(255,255,255,0.3)" stroke-width="0.5"/>
        <text x="${mX+cW-28}" y="${mY+33}" text-anchor="middle" font-size="13" fill="#fff" font-weight="600">N</text>
        <line x1="${mX+cW-28}" y1="${mY+17}" x2="${mX+cW-28}" y2="${mY+12}" stroke="#e85d5d" stroke-width="2"/>
        <!-- Hole badge -->
        <rect x="${mX+12}" y="${mY+12}" width="38" height="26" rx="8" fill="rgba(0,0,0,0.8)"/>
        <text x="${mX+31}" y="${mY+30}" text-anchor="middle" font-size="14" fill="#C5A059" font-weight="700">#1</text>
      </svg>
    </div>
    <div class="dist-row">
      <div class="dist-box"><div class="dist-lbl">Front</div><div class="dist-val">158</div></div>
      <div class="dist-box ctr"><div class="dist-lbl">Center</div><div class="dist-val">172</div></div>
      <div class="dist-box"><div class="dist-lbl">Back</div><div class="dist-val">186</div></div>
    </div>
    <div class="hz"><div class="hz-name">⚪ Greenside bunker</div><div><span class="hz-d hz-front">147</span>&nbsp;<span class="hz-d hz-carry">Carry 162</span></div></div>
    <div class="hz"><div class="hz-name">⚪ Fairway bunker (L)</div><div><span class="hz-d hz-front">42</span>&nbsp;<span class="hz-d hz-carry">Carry 58</span></div></div>
  </div>
  <div class="tab-bar">
    <div class="tab"><div class="tab-icon">🏆</div>Standings</div>
    <div class="tab active"><div class="tab-icon">⛳</div>GPS</div>
    <div class="tab"><div class="tab-icon">📝</div>Score</div>
    <div class="tab"><div class="tab-icon">👤</div>Profile</div>
  </div>
  <div class="home-indicator"></div>
</div>
<div class="screen-label">With Course Data</div>
<div class="screen-sublabel">Satellite + green/bunker overlays + F/C/B</div>
</div>

<!-- SCREEN 2: Satellite only, no overlays (unmapped course) -->
<div class="device-wrap">
<div class="phone">
  <div class="notch"></div>
  <div class="status-bar"><span>2:15</span><span></span></div>
  <div class="screen">
    <div class="header">
      <div><div class="hole-num">Hole 4</div><div class="hole-par">Par 4 · 380 yds</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#ccc;text-shadow:0 1px 3px rgba(0,0,0,0.8)">Rancho Bernardo Inn</div><div style="font-size:12px;color:#C5A059;text-shadow:0 1px 3px rgba(0,0,0,0.8)">● Satellite</div></div>
    </div>
    <div class="map">
      <div class="tiles" style="left:-120px;top:-100px">
        <img src="${rb['0_0']}"><img src="${rb['0_1']}"><img src="${rb['0_2']}">
        <img src="${rb['1_0']}"><img src="${rb['1_1']}"><img src="${rb['1_2']}">
        <img src="${rb['2_0']}"><img src="${rb['2_1']}"><img src="${rb['2_2']}">
      </div>
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.05)"></div>
      <svg class="overlay" viewBox="0 0 361 400">
        <!-- Just user dot and distance to saved green pin -->
        <!-- User position -->
        <circle cx="180" cy="180" r="9" fill="#4A90D9" stroke="#fff" stroke-width="3"/>
        <circle cx="180" cy="180" r="20" fill="none" stroke="rgba(74,144,217,0.25)" stroke-width="1.5"/>

        <!-- Green pin (saved from previous round via tap-and-save) -->
        <circle cx="140" cy="310" r="6" fill="rgba(197,160,89,0.5)" stroke="#C5A059" stroke-width="2"/>
        <text x="152" y="314" font-size="11" fill="#C5A059" font-weight="600" style="text-shadow:0 1px 4px rgba(0,0,0,1)">Green</text>

        <!-- Distance line -->
        <line x1="180" y1="180" x2="140" y2="310" stroke="rgba(197,160,89,0.5)" stroke-width="1.5" stroke-dasharray="5,4"/>

        <!-- Distance badge -->
        <rect x="128" y="232" width="68" height="28" rx="8" fill="rgba(0,0,0,0.85)"/>
        <text x="162" y="251" text-anchor="middle" font-size="15" fill="#C5A059" font-weight="700">164 yds</text>

        <!-- Compass -->
        <circle cx="330" cy="28" r="17" fill="rgba(0,0,0,0.7)" stroke="rgba(255,255,255,0.3)" stroke-width="0.5"/>
        <text x="330" y="33" text-anchor="middle" font-size="13" fill="#fff" font-weight="600">N</text>
        <line x1="330" y1="17" x2="330" y2="12" stroke="#e85d5d" stroke-width="2"/>

        <!-- Hole badge -->
        <rect x="12" y="12" width="38" height="26" rx="8" fill="rgba(0,0,0,0.8)"/>
        <text x="31" y="30" text-anchor="middle" font-size="14" fill="#C5A059" font-weight="700">#4</text>
      </svg>
    </div>
    <div class="dist-row">
      <div class="dist-box" style="opacity:0.3;border-style:dashed"><div class="dist-lbl">Front</div><div class="dist-val">—</div></div>
      <div class="dist-box ctr"><div class="dist-lbl">Center</div><div class="dist-val">164</div></div>
      <div class="dist-box" style="opacity:0.3;border-style:dashed"><div class="dist-lbl">Back</div><div class="dist-val">—</div></div>
    </div>
    <div style="display:flex;justify-content:space-between;align-items:center;background:#122218;border-radius:12px;padding:14px 18px;margin-top:8px;border:1px solid #1c3324">
      <div style="text-align:center;flex:1"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Score</div><div style="color:#e8efe8;font-size:22px;font-weight:700">—</div></div>
      <div style="text-align:center;flex:1;border-left:1px solid #1c3324;border-right:1px solid #1c3324"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Thru 3</div><div style="color:#C5A059;font-size:22px;font-weight:700">+2</div></div>
      <div style="text-align:center;flex:1"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Net</div><div style="color:#2E7D32;font-size:22px;font-weight:700">E</div></div>
    </div>
    <div style="display:flex;justify-content:center;align-items:center;background:linear-gradient(135deg,#1a2e1f,#122218);border-radius:12px;padding:14px 18px;margin-top:8px;border:1px solid rgba(197,160,89,0.3)">
      <div style="color:#7a9a80;font-size:13px">Projected&nbsp;</div>
      <div style="color:#C5A059;font-size:20px;font-weight:700">10 pts</div>
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
<div class="screen-label">Without Course Data</div>
<div class="screen-sublabel">Satellite + center distance only</div>
</div>

</body></html>`;

(async () => {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 920, height: 960, deviceScaleFactor: 2 });
  await page.setContent(html, { waitUntil: 'networkidle0' });
  const dir = '/home/user/thc/docs/mockups';
  await page.screenshot({ path: `${dir}/v4-both.png`, fullPage: false });
  const devs = await page.$$('.device-wrap');
  if (devs[0]) { const b = await devs[0].boundingBox(); await page.screenshot({ path: `${dir}/v4-with-data.png`, clip: { x:b.x-10, y:b.y-10, width:b.width+20, height:b.height+60 }}); }
  if (devs[1]) { const b = await devs[1].boundingBox(); await page.screenshot({ path: `${dir}/v4-satellite-only.png`, clip: { x:b.x-10, y:b.y-10, width:b.width+20, height:b.height+60 }}); }
  await browser.close();
  console.log('Done — v4');
})();
