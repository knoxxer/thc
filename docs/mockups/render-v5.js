const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

function b64(dir, r, c) {
  return `data:image/jpeg;base64,${fs.readFileSync(`${dir}/tile_${r}_${c}.png`).toString('base64')}`;
}
const tp = {}, rb = {};
for (let r=0;r<3;r++) for (let c=0;c<3;c++) { tp[`${r}_${c}`]=b64('/tmp/tiles',r,c); rb[`${r}_${c}`]=b64('/tmp/tiles2',r,c); }

// We'll use Puppeteer to:
// 1. Load the 768x768 tile grid
// 2. Rotate it so green is at top
// 3. Place overlays at correct positions
// 4. Screenshot the result inside a phone frame

// Key positions in 768x768 grid (pre-rotation)
const GREEN = {x:206, y:552};
const TEE = {x:564, y:360};
const USER = {x:334, y:495};

// Rotation: -242 degrees (or equivalently +118 degrees)
const ROT = 118; // positive = clockwise in CSS

const html = `<!DOCTYPE html>
<html><head><style>
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#1a1a2e; font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif; display:flex; gap:50px; padding:40px; justify-content:center; }
.phone { width:393px; height:852px; background:#0a1a0f; border-radius:47px; overflow:hidden; border:4px solid #333; position:relative; }
.notch { width:126px; height:34px; background:#000; border-radius:0 0 20px 20px; position:absolute; top:0; left:50%; transform:translateX(-50%); z-index:10; }
.sbar { height:54px; display:flex; justify-content:space-between; align-items:center; padding:14px 30px 0; color:#fff; font-size:15px; font-weight:600; z-index:5; position:relative; }
.scr { padding:0 16px; height:calc(100% - 54px - 83px); overflow:hidden; }
.tabs { height:83px; background:rgba(18,34,24,0.95); border-top:0.5px solid #1c3324; display:flex; justify-content:space-around; align-items:flex-start; padding-top:10px; position:absolute; bottom:0; width:100%; }
.tab { text-align:center; color:#7a9a80; font-size:10px; }
.tab.a { color:#C5A059; }
.ti { font-size:24px; margin-bottom:2px; }
.hi { width:134px; height:5px; background:#fff; border-radius:3px; position:absolute; bottom:8px; left:50%; transform:translateX(-50%); opacity:0.3; }
.dw { position:relative; margin-bottom:50px; }
.sl { text-align:center; color:#e8efe8; font-size:16px; font-weight:600; margin-top:16px; }
.ssl { text-align:center; color:#7a9a80; font-size:13px; margin-top:4px; }
.hdr { display:flex; justify-content:space-between; align-items:center; padding:8px 4px; z-index:5; position:relative; }
.hn { font-size:22px; font-weight:700; color:#e8efe8; text-shadow:0 1px 4px rgba(0,0,0,0.8); }
.hp { font-size:13px; color:#bbb; text-shadow:0 1px 3px rgba(0,0,0,0.8); }
.map { width:361px; height:400px; border-radius:16px; position:relative; overflow:hidden; margin-bottom:12px; }

/* Tile container: 768x768 grid, rotated */
.tgrid {
  display:grid; grid-template-columns:repeat(3,256px); grid-template-rows:repeat(3,256px);
  position:absolute; width:768px; height:768px;
  transform-origin: 385px 456px;
  transform: rotate(${ROT}deg);
}
.tgrid img { width:256px; height:256px; display:block; }

.dr { display:flex; margin-bottom:10px; }
.db { text-align:center; background:#122218; border-radius:12px; padding:10px 14px; flex:1; margin:0 4px; border:1px solid #1c3324; }
.dl { font-size:10px; color:#7a9a80; text-transform:uppercase; letter-spacing:1px; }
.dv { font-size:26px; font-weight:700; color:#e8efe8; margin-top:2px; }
.db.ctr .dv { color:#C5A059; }
.hz { display:flex; justify-content:space-between; background:#122218; border-radius:10px; padding:9px 14px; margin-bottom:5px; border:1px solid #1c3324; }
</style>
<script>
// After rotation, compute where green/tee/user end up in the 768x768 space
// Then we position the tile grid so green is at viewport (180, 70)
function rotatePoint(px, py, cx, cy, angleDeg) {
  const a = angleDeg * Math.PI / 180;
  const dx = px - cx, dy = py - cy;
  return {
    x: dx * Math.cos(a) - dy * Math.sin(a) + cx,
    y: dx * Math.sin(a) + dy * Math.cos(a) + cy
  };
}

window.addEventListener('DOMContentLoaded', () => {
  const cx = 385, cy = 456;
  const rot = ${ROT};

  const g = rotatePoint(${GREEN.x}, ${GREEN.y}, cx, cy, rot);
  const t = rotatePoint(${TEE.x}, ${TEE.y}, cx, cy, rot);
  const u = rotatePoint(${USER.x}, ${USER.y}, cx, cy, rot);

  // Position tile grid so green is at viewport (180, 70)
  const tgrid = document.getElementById('tg1');
  const offsetX = 180 - g.x;
  const offsetY = 70 - g.y;
  tgrid.style.left = offsetX + 'px';
  tgrid.style.top = offsetY + 'px';

  // Place SVG overlay points
  const svg = document.getElementById('ov1');
  // Convert rotated grid coords to viewport coords
  function toVP(rx, ry) {
    return { x: rx + offsetX, y: ry + offsetY };
  }
  const gv = toVP(g.x, g.y);
  const tv = toVP(t.x, t.y);
  const uv = toVP(u.x, u.y);

  // Set overlay elements
  document.getElementById('green-el').setAttribute('cx', gv.x);
  document.getElementById('green-el').setAttribute('cy', gv.y);
  document.getElementById('green-el2').setAttribute('cx', gv.x);
  document.getElementById('green-el2').setAttribute('cy', gv.y);

  document.getElementById('pin1').setAttribute('x1', gv.x);
  document.getElementById('pin1').setAttribute('y1', gv.y);
  document.getElementById('pin1').setAttribute('x2', gv.x);
  document.getElementById('pin1').setAttribute('y2', gv.y - 16);
  document.getElementById('flag').setAttribute('points',
    gv.x+','+( gv.y-16)+' '+(gv.x+10)+','+(gv.y-13)+' '+gv.x+','+(gv.y-10));

  // Front/back markers (offset from green center along play direction)
  const playAngle = Math.atan2(gv.y - tv.y, gv.x - tv.x);
  const fOff = 18; // front offset
  document.getElementById('front-c').setAttribute('cx', gv.x - Math.cos(playAngle) * fOff);
  document.getElementById('front-c').setAttribute('cy', gv.y - Math.sin(playAngle) * fOff);
  document.getElementById('front-t').setAttribute('x', gv.x - Math.cos(playAngle) * fOff + 8);
  document.getElementById('front-t').setAttribute('y', gv.y - Math.sin(playAngle) * fOff + 4);
  document.getElementById('back-c').setAttribute('cx', gv.x + Math.cos(playAngle) * fOff);
  document.getElementById('back-c').setAttribute('cy', gv.y + Math.sin(playAngle) * fOff);
  document.getElementById('back-t').setAttribute('x', gv.x + Math.cos(playAngle) * fOff + 8);
  document.getElementById('back-t').setAttribute('y', gv.y + Math.sin(playAngle) * fOff + 4);

  // User dot
  document.getElementById('user-c').setAttribute('cx', uv.x);
  document.getElementById('user-c').setAttribute('cy', uv.y);
  document.getElementById('user-r').setAttribute('cx', uv.x);
  document.getElementById('user-r').setAttribute('cy', uv.y);

  // Distance line
  document.getElementById('dline').setAttribute('x1', uv.x);
  document.getElementById('dline').setAttribute('y1', uv.y);
  document.getElementById('dline').setAttribute('x2', gv.x);
  document.getElementById('dline').setAttribute('y2', gv.y);

  // Distance badge
  const midX = (uv.x + gv.x) / 2;
  const midY = (uv.y + gv.y) / 2;
  document.getElementById('dbg').setAttribute('x', midX - 38);
  document.getElementById('dbg').setAttribute('y', midY - 15);
  document.getElementById('dtxt').setAttribute('x', midX);
  document.getElementById('dtxt').setAttribute('y', midY + 6);

  // Bunker outlines near green
  const bOff1Angle = playAngle + 1.2;
  document.getElementById('bk1').setAttribute('cx', gv.x + Math.cos(bOff1Angle) * 28);
  document.getElementById('bk1').setAttribute('cy', gv.y + Math.sin(bOff1Angle) * 28);
  const bOff2Angle = playAngle - 0.8;
  document.getElementById('bk2').setAttribute('cx', gv.x + Math.cos(bOff2Angle) * 30);
  document.getElementById('bk2').setAttribute('cy', gv.y + Math.sin(bOff2Angle) * 30);

  // ---- Screen 2: same satellite, no overlays ----
  // Reuse same Torrey Pines tiles + rotation, just with minimal overlay
  const tg2 = document.getElementById('tg2');
  tg2.style.left = offsetX + 'px';
  tg2.style.top = offsetY + 'px';

  // Same user position, green pin only (no outlines, no F/B)
  const gv2 = toVP(g.x, g.y);
  const uv2 = toVP(u.x, u.y);

  document.getElementById('gpin2').setAttribute('cx', gv2.x);
  document.getElementById('gpin2').setAttribute('cy', gv2.y);
  document.getElementById('gpin2t').setAttribute('x', gv2.x + 12);
  document.getElementById('gpin2t').setAttribute('y', gv2.y + 4);
  document.getElementById('user2-c').setAttribute('cx', uv2.x);
  document.getElementById('user2-c').setAttribute('cy', uv2.y);
  document.getElementById('user2-r').setAttribute('cx', uv2.x);
  document.getElementById('user2-r').setAttribute('cy', uv2.y);
  document.getElementById('dline2').setAttribute('x1', uv2.x);
  document.getElementById('dline2').setAttribute('y1', uv2.y);
  document.getElementById('dline2').setAttribute('x2', gv2.x);
  document.getElementById('dline2').setAttribute('y2', gv2.y);
  const m2x = (uv2.x+gv2.x)/2, m2y = (uv2.y+gv2.y)/2;
  document.getElementById('dbg2').setAttribute('x', m2x - 38);
  document.getElementById('dbg2').setAttribute('y', m2y - 15);
  document.getElementById('dtxt2').setAttribute('x', m2x);
  document.getElementById('dtxt2').setAttribute('y', m2y + 6);
});
</script>
</head><body>

<!-- SCREEN 1: With course data -->
<div class="dw">
<div class="phone">
  <div class="notch"></div>
  <div class="sbar"><span>10:23</span><span></span></div>
  <div class="scr">
    <div class="hdr">
      <div><div class="hn">Hole 1</div><div class="hp">Par 4 · 453 yds · SI 7</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#ccc;text-shadow:0 1px 3px rgba(0,0,0,0.8)">Torrey Pines South</div><div style="font-size:12px;color:#4CAF50;text-shadow:0 1px 3px rgba(0,0,0,0.8)">● GPS</div></div>
    </div>
    <div class="map">
      <div class="tgrid" id="tg1">
        <img src="${tp['0_0']}"><img src="${tp['0_1']}"><img src="${tp['0_2']}">
        <img src="${tp['1_0']}"><img src="${tp['1_1']}"><img src="${tp['1_2']}">
        <img src="${tp['2_0']}"><img src="${tp['2_1']}"><img src="${tp['2_2']}">
      </div>
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.1)"></div>
      <svg id="ov1" style="position:absolute;top:0;left:0;width:100%;height:100%;" viewBox="0 0 361 400">
        <!-- Green -->
        <ellipse id="green-el" cx="0" cy="0" rx="16" ry="12" fill="rgba(45,180,60,0.3)" stroke="#4CAF50" stroke-width="2.5"/>
        <ellipse id="green-el2" cx="0" cy="0" rx="16" ry="12" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1"/>
        <!-- Pin -->
        <line id="pin1" stroke="#fff" stroke-width="1.5"/>
        <polygon id="flag" fill="#e85d5d"/>
        <!-- F/B -->
        <circle id="front-c" r="3.5" fill="none" stroke="rgba(255,255,255,0.9)" stroke-width="1.5"/>
        <text id="front-t" font-size="11" fill="#fff" font-weight="700" style="text-shadow:0 1px 4px rgba(0,0,0,1)">F</text>
        <circle id="back-c" r="3.5" fill="none" stroke="rgba(255,255,255,0.9)" stroke-width="1.5"/>
        <text id="back-t" font-size="11" fill="#fff" font-weight="700" style="text-shadow:0 1px 4px rgba(0,0,0,1)">B</text>
        <!-- Bunker outlines -->
        <ellipse id="bk1" rx="12" ry="8" fill="none" stroke="rgba(240,220,160,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <ellipse id="bk2" rx="10" ry="7" fill="none" stroke="rgba(240,220,160,0.7)" stroke-width="1.5" stroke-dasharray="3,2"/>
        <!-- User -->
        <circle id="user-c" r="9" fill="#4A90D9" stroke="#fff" stroke-width="3"/>
        <circle id="user-r" r="20" fill="none" stroke="rgba(74,144,217,0.25)" stroke-width="1.5"/>
        <!-- Distance -->
        <line id="dline" stroke="rgba(197,160,89,0.6)" stroke-width="2" stroke-dasharray="5,4"/>
        <rect id="dbg" width="76" height="30" rx="9" fill="rgba(0,0,0,0.85)"/>
        <text id="dtxt" text-anchor="middle" font-size="16" fill="#C5A059" font-weight="700">172 yds</text>
        <!-- Compass top-right -->
        <circle cx="330" cy="28" r="17" fill="rgba(0,0,0,0.7)" stroke="rgba(255,255,255,0.3)" stroke-width="0.5"/>
        <text x="330" y="33" text-anchor="middle" font-size="13" fill="#fff" font-weight="600">N</text>
        <line x1="330" y1="17" x2="330" y2="12" stroke="#e85d5d" stroke-width="2"/>
        <!-- Hole badge -->
        <rect x="12" y="12" width="38" height="26" rx="8" fill="rgba(0,0,0,0.8)"/>
        <text x="31" y="30" text-anchor="middle" font-size="14" fill="#C5A059" font-weight="700">#1</text>
      </svg>
    </div>
    <div class="dr">
      <div class="db"><div class="dl">Front</div><div class="dv">158</div></div>
      <div class="db ctr"><div class="dl">Center</div><div class="dv">172</div></div>
      <div class="db"><div class="dl">Back</div><div class="dv">186</div></div>
    </div>
    <div class="hz"><div style="font-size:13px;color:#e8efe8">⚪ Greenside bunker</div><div><span style="font-size:13px;font-weight:600;color:#7a9a80">147</span>&nbsp;<span style="font-size:13px;font-weight:600;color:#e85d5d">Carry 162</span></div></div>
    <div class="hz"><div style="font-size:13px;color:#e8efe8">⚪ Fairway bunker (L)</div><div><span style="font-size:13px;font-weight:600;color:#7a9a80">42</span>&nbsp;<span style="font-size:13px;font-weight:600;color:#e85d5d">Carry 58</span></div></div>
  </div>
  <div class="tabs"><div class="tab"><div class="ti">🏆</div>Standings</div><div class="tab a"><div class="ti">⛳</div>GPS</div><div class="tab"><div class="ti">📝</div>Score</div><div class="tab"><div class="ti">👤</div>Profile</div></div>
  <div class="hi"></div>
</div>
<div class="sl">With Course Data</div>
<div class="ssl">Satellite + overlays + F/C/B</div>
</div>

<!-- SCREEN 2: Satellite only -->
<div class="dw">
<div class="phone">
  <div class="notch"></div>
  <div class="sbar"><span>2:15</span><span></span></div>
  <div class="scr">
    <div class="hdr">
      <div><div class="hn">Hole 4</div><div class="hp">Par 4 · 380 yds</div></div>
      <div style="text-align:right"><div style="font-size:12px;color:#ccc;text-shadow:0 1px 3px rgba(0,0,0,0.8)">Torrey Pines South</div><div style="font-size:12px;color:#C5A059;text-shadow:0 1px 3px rgba(0,0,0,0.8)">● Satellite</div></div>
    </div>
    <div class="map">
      <div class="tgrid" id="tg2">
        <img src="${tp['0_0']}"><img src="${tp['0_1']}"><img src="${tp['0_2']}">
        <img src="${tp['1_0']}"><img src="${tp['1_1']}"><img src="${tp['1_2']}">
        <img src="${tp['2_0']}"><img src="${tp['2_1']}"><img src="${tp['2_2']}">
      </div>
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.05)"></div>
      <svg style="position:absolute;top:0;left:0;width:100%;height:100%;" viewBox="0 0 361 400">
        <!-- Green pin (from tap-and-save) -->
        <circle id="gpin2" r="7" fill="rgba(197,160,89,0.4)" stroke="#C5A059" stroke-width="2.5"/>
        <text id="gpin2t" font-size="12" fill="#C5A059" font-weight="600" style="text-shadow:0 1px 4px rgba(0,0,0,1)">Green</text>
        <!-- User -->
        <circle id="user2-c" r="9" fill="#4A90D9" stroke="#fff" stroke-width="3"/>
        <circle id="user2-r" r="20" fill="none" stroke="rgba(74,144,217,0.25)" stroke-width="1.5"/>
        <!-- Distance -->
        <line id="dline2" stroke="rgba(197,160,89,0.5)" stroke-width="1.5" stroke-dasharray="5,4"/>
        <rect id="dbg2" width="76" height="30" rx="9" fill="rgba(0,0,0,0.85)"/>
        <text id="dtxt2" text-anchor="middle" font-size="15" fill="#C5A059" font-weight="700">164 yds</text>
        <!-- Compass -->
        <circle cx="330" cy="28" r="17" fill="rgba(0,0,0,0.7)" stroke="rgba(255,255,255,0.3)" stroke-width="0.5"/>
        <text x="330" y="33" text-anchor="middle" font-size="13" fill="#fff" font-weight="600">N</text>
        <line x1="330" y1="17" x2="330" y2="12" stroke="#e85d5d" stroke-width="2"/>
        <!-- Hole badge -->
        <rect x="12" y="12" width="38" height="26" rx="8" fill="rgba(0,0,0,0.8)"/>
        <text x="31" y="30" text-anchor="middle" font-size="14" fill="#C5A059" font-weight="700">#4</text>
      </svg>
    </div>
    <div class="dr">
      <div class="db" style="opacity:0.3;border-style:dashed"><div class="dl">Front</div><div class="dv">—</div></div>
      <div class="db ctr"><div class="dl">Center</div><div class="dv">164</div></div>
      <div class="db" style="opacity:0.3;border-style:dashed"><div class="dl">Back</div><div class="dv">—</div></div>
    </div>
    <div style="display:flex;justify-content:space-between;background:#122218;border-radius:12px;padding:14px 18px;margin-top:8px;border:1px solid #1c3324">
      <div style="text-align:center;flex:1"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Score</div><div style="color:#e8efe8;font-size:22px;font-weight:700">—</div></div>
      <div style="text-align:center;flex:1;border-left:1px solid #1c3324;border-right:1px solid #1c3324"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Thru 3</div><div style="color:#C5A059;font-size:22px;font-weight:700">+2</div></div>
      <div style="text-align:center;flex:1"><div style="color:#7a9a80;font-size:11px;text-transform:uppercase">Net</div><div style="color:#2E7D32;font-size:22px;font-weight:700">E</div></div>
    </div>
    <div style="display:flex;justify-content:center;background:linear-gradient(135deg,#1a2e1f,#122218);border-radius:12px;padding:14px;margin-top:8px;border:1px solid rgba(197,160,89,0.3)">
      <span style="color:#7a9a80;font-size:13px">Projected&nbsp;</span><span style="color:#C5A059;font-size:20px;font-weight:700">10 pts</span>
    </div>
  </div>
  <div class="tabs"><div class="tab"><div class="ti">🏆</div>Standings</div><div class="tab a"><div class="ti">⛳</div>GPS</div><div class="tab"><div class="ti">📝</div>Score</div><div class="tab"><div class="ti">👤</div>Profile</div></div>
  <div class="hi"></div>
</div>
<div class="sl">Without Course Data</div>
<div class="ssl">Satellite + center distance only</div>
</div>

</body></html>`;

(async () => {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 920, height: 960, deviceScaleFactor: 2 });
  await page.setContent(html, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 500)); // let JS positioning run
  const dir = '/home/user/thc/docs/mockups';
  await page.screenshot({ path: `${dir}/v5-both.png`, fullPage: false });
  const devs = await page.$$('.dw');
  if (devs[0]) { const b = await devs[0].boundingBox(); await page.screenshot({ path: `${dir}/v5-with-data.png`, clip:{x:b.x-10,y:b.y-10,width:b.width+20,height:b.height+60}}); }
  if (devs[1]) { const b = await devs[1].boundingBox(); await page.screenshot({ path: `${dir}/v5-satellite-only.png`, clip:{x:b.x-10,y:b.y-10,width:b.width+20,height:b.height+60}}); }
  await browser.close();
  console.log('Done — v5');
})();
