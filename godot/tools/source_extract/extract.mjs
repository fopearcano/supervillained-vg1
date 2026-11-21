// SUPERVILLAINED VG1 — source asset/fixture extractor for the Godot port.
//
// Run from the repository root (Node 24, Playwright 1.63 Chromium):
//   node --experimental-transform-types --no-warnings \
//        --import ./godot/tools/source_extract/register.mjs \
//        godot/tools/source_extract/extract.mjs [--check]
//
// It never modifies the source tree. It:
//  1. copies the runtime-authoritative files this milestone needs into godot/assets (byte-for-byte),
//  2. freezes the source's procedural sprites by executing src/assets/placeholders/*.ts,
//  3. rasterizes the bitmap font by executing src/ui/pixelFont.ts in Chromium,
//  4. records reference fixtures produced by the audited TypeScript for the Godot tests,
//  5. writes godot/data/source_asset_manifest.json (path, SHA-256, size, dimensions, use).
// Outputs are rewritten only when their bytes change, so a second run produces no diff.
// --check verifies that every recorded source hash still matches and exits non-zero otherwise.

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import * as nodeModule from 'node:module';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { encodePng, pngSize } from './png.mjs';

const ROOT = process.cwd();
const SRC = path.join(ROOT, 'src');
const GODOT = path.join(ROOT, 'godot');
const AUDITED_COMMIT = '95b69c04c5c3b9626e49719f8f916a44659cd265';
const CHECK = process.argv.includes('--check');

if (!existsSync(path.join(SRC, 'config.ts')) || !existsSync(path.join(GODOT, 'project.godot'))) {
  console.error('Run from the repository root (needs src/ and godot/project.godot).');
  process.exit(2);
}

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
let changedOutputs = 0;
function writeIfChanged(file, data) {
  const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
  if (existsSync(file) && readFileSync(file).equals(buf)) return false;
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, buf);
  changedOutputs++;
  return true;
}
const stableJson = (v) => JSON.stringify(v, (_k, x) => (typeof x === 'number' && Object.is(x, -0) ? 0 : x), 1) + '\n';

// ---------------------------------------------------------------------------------------------
// Provenance: the source files must be byte-identical to the audited commit.
function gitTreeClean() {
  try {
    execFileSync('git', ['diff', '--quiet', AUDITED_COMMIT, '--', 'src', 'public', 'assets', 'package.json'], { cwd: ROOT });
    return true;
  } catch {
    return false;
  }
}
const sourceClean = gitTreeClean();
if (!sourceClean) {
  console.error(`Source tree differs from audited commit ${AUDITED_COMMIT}; refusing to extract.`);
  process.exit(3);
}

// ---------------------------------------------------------------------------------------------
// 1. Runtime-authoritative copies (only what this milestone references).
const COPIES = [
  { from: 'public/sprites/zampano.png', to: 'assets/sprites/zampano.png', use: 'Zampanò normal 8-direction main sheet (11 actions x 8 dirs, 40x40)' },
  { from: 'public/sprites/zampano-tired.png', to: 'assets/sprites/zampano-tired.png', use: 'Zampanò normal tired sheet (2 frames x 8 dirs)' },
  { from: 'public/sprites/runIcon.png', to: 'assets/sprites/run_icon.png', use: 'RUN button icon' },
  { from: 'public/environment-ink/ch01_greenzone.png', to: 'assets/environment/ch01_greenzone.png', use: 'Color Ink Green Zone environment bank' },
  { from: 'public/environment-ink/manifest.json', to: 'assets/environment/manifest.json', use: 'Color Ink environment manifest (frames, themes); floorDesigns ignored for 1:arcade' },
  { from: 'public/icon-192.png', to: 'assets/branding/icon.png', use: 'application icon (launcher art)' },
  { from: 'src/assets/fonts/OFL.txt', to: 'assets/fonts/OFL.txt', use: 'Press Start 2P license (OFL)' },
  { from: 'assets/music/greenzone-music.mp3', to: 'assets/audio/recorded/greenzone-music.mp3', use: 'Green Zone music (MUSIC_FILES.greenzone)' },
  { from: 'assets/sounds/dog-bark.mp3', to: 'assets/audio/recorded/dog-bark.mp3', use: 'SOUND_FILES.bark' },
  { from: 'assets/sounds/food-collect.mp3', to: 'assets/audio/recorded/food-collect.mp3', use: 'SOUND_FILES.treat' },
  { from: 'assets/sounds/poos.mp3', to: 'assets/audio/recorded/poos.mp3', use: 'SOUND_FILES.poop' },
  { from: 'assets/sounds/pees-drop.mp3', to: 'assets/audio/recorded/pees-drop.mp3', use: 'SOUND_FILES.pee' },
  { from: 'assets/sounds/pees-collect.wav', to: 'assets/audio/recorded/pees-collect.wav', use: 'SOUND_FILES.drink' },
  { from: 'assets/sounds/water.mp3', to: 'assets/audio/recorded/water.mp3', use: 'SOUND_FILES.splash' },
];
const INPUTS_ONLY = [
  { from: 'src/assets/fonts/PressStart2P.woff2', use: 'converter input for the bitmap font (not exported)' },
  { from: 'src/ui/pixelFont.ts', use: 'bitmap font rasterization contract (executed in Chromium)' },
  { from: 'src/assets/placeholders/items.ts', use: 'procedural item/HUD sprite generators (executed)' },
  { from: 'src/assets/placeholders/critters.ts', use: 'procedural shadow generator (executed)' },
];

const manifestPath = path.join(GODOT, 'data', 'source_asset_manifest.json');
if (CHECK) {
  const m = JSON.parse(readFileSync(manifestPath, 'utf8'));
  let bad = 0;
  for (const e of [...m.copies, ...m.inputs]) {
    const h = sha256(readFileSync(path.join(ROOT, e.source)));
    if (h !== e.sha256) {
      console.error(`CHANGED ${e.source}: ${h} != recorded ${e.sha256}`);
      bad++;
    }
    if (e.target) {
      const t = sha256(readFileSync(path.join(GODOT, e.target)));
      if (t !== e.sha256) {
        console.error(`TARGET DIFFERS ${e.target}`);
        bad++;
      }
    }
  }
  console.log(bad ? `asset check FAILED (${bad})` : `asset check OK (${m.copies.length} copies, ${m.inputs.length} inputs)`);
  process.exit(bad ? 1 : 0);
}

const manifest = { audited_commit: AUDITED_COMMIT, generated_by: 'godot/tools/source_extract/extract.mjs', copies: [], inputs: [], generated: [] };
for (const c of COPIES) {
  const buf = readFileSync(path.join(ROOT, c.from));
  writeIfChanged(path.join(GODOT, c.to), buf);
  const entry = { source: c.from, target: c.to, sha256: sha256(buf), bytes: buf.length, use: c.use, provenance: 'repository file at audited commit; distribution rights to be recorded by owner (REL-001)' };
  if (c.from.endsWith('.png')) Object.assign(entry, pngSize(buf));
  manifest.copies.push(entry);
}
for (const c of INPUTS_ONLY) {
  const buf = readFileSync(path.join(ROOT, c.from));
  manifest.inputs.push({ source: c.from, sha256: sha256(buf), bytes: buf.length, use: c.use });
}

// ---------------------------------------------------------------------------------------------
// 2. Frozen procedural sprites (exact output of the source generators).
const items = await import(path.join(SRC, 'assets/placeholders/items.ts'));
const critters = await import(path.join(SRC, 'assets/placeholders/critters.ts'));
const manifestTs = await import(path.join(SRC, 'assets/manifest.ts'));
const SPR = manifestTs.SPRITES;
const frozen = [
  ['treat', [() => items.drawTreat()]],
  ['poop', [() => items.drawPoop()]],
  ['shadow', [() => critters.drawShadow(20, 7, 70)]],
  ['shadowSmall', [() => critters.drawShadow(10, 4, 70)]],
  ['star', [0, 1, 2].map((v) => () => items.drawStar(v))],
  ['dogFace', [() => items.drawDogFace()]],
  ['peeIcon', [() => items.drawPeeIcon()]],
  ['barkIcon', [() => items.drawBarkIcon()]],
  ['drop', [0, 1].map((v) => () => items.drawDrop(v))],
];
for (const [key, draws] of frozen) {
  const def = SPR[key];
  const bufs = draws.map((d) => d());
  // Variants side by side, like the manifest's sprite strips.
  const w = def.w * bufs.length;
  const h = def.h;
  const out = new Uint8Array(w * h * 4);
  bufs.forEach((b, v) => {
    if (b.w !== def.w || b.h !== def.h) throw new Error(`${key}: generator size ${b.w}x${b.h} != manifest ${def.w}x${def.h}`);
    const bytes = new Uint8Array(b.data.buffer);
    for (let y = 0; y < h; y++) out.set(bytes.subarray(y * b.w * 4, (y + 1) * b.w * 4), (y * w + v * def.w) * 4);
  });
  const png = encodePng(w, h, out);
  const target = `assets/generated/sprites/${key}.png`;
  writeIfChanged(path.join(GODOT, target), png);
  manifest.generated.push({ key, target, sha256: sha256(png), w, h, frame_w: def.w, frame_h: def.h, variants: bufs.length, anchor_x: def.anchorX, anchor_y: def.anchorY, recipe: `src/assets/placeholders/${key === 'shadow' || key === 'shadowSmall' ? 'critters.ts drawShadow' : 'items.ts'}` });
}

// Sheet layout data (consumed by tools/build_resources.gd): exactly CHARACTERS.zampano.
{
  const def = manifestTs.CHARACTERS.zampano;
  const layout = {
    audited_commit: AUDITED_COMMIT,
    source: 'src/assets/manifest.ts CHARACTERS.zampano',
    key: def.key,
    frame_w: def.frameW,
    frame_h: def.frameH,
    anchor_x: def.anchorX,
    anchor_y: def.anchorY,
    sheet: 'res://assets/sprites/zampano.png',
    anim_sheets: { tired: 'res://assets/sprites/zampano-tired.png' },
    sheet_dirs: manifestTs.SHEET_DIRS,
    anim_order: Object.keys(def.anims),
    anims: def.anims,
  };
  writeIfChanged(path.join(GODOT, 'data/characters/zampano_sheet.json'), stableJson(layout));
  // Environment frames used by this milestone, with the manifest's exact geometry.
  const env = JSON.parse(readFileSync(path.join(ROOT, 'public/environment-ink/manifest.json'), 'utf8')).zones.ch01_greenzone;
  writeIfChanged(path.join(GODOT, 'data/environment/ch01_greenzone_frames.json'), stableJson({ audited_commit: AUDITED_COMMIT, source: 'public/environment-ink/manifest.json zones.ch01_greenzone', image: 'res://assets/environment/ch01_greenzone.png', frames: env.frames, palette: env.palette, sprite_variants: manifestTs.SPRITES }));
}

// ---------------------------------------------------------------------------------------------
// 3. Bitmap font: execute src/ui/pixelFont.ts in Chromium with the bundled WOFF2.
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const fontTs = readFileSync(path.join(SRC, 'ui/pixelFont.ts'), 'utf8');
const woff2 = readFileSync(path.join(SRC, 'assets/fonts/PressStart2P.woff2'));
let fontJs = nodeModule.stripTypeScriptTypes(fontTs, { mode: 'strip' });
const importLine = /import fontUrl from '..\/assets\/fonts\/PressStart2P\.woff2\?url';/;
if (!importLine.test(fontJs)) throw new Error('pixelFont.ts import line changed; review the extractor');
fontJs = fontJs.replace(importLine, `const fontUrl = 'data:font/woff2;base64,${woff2.toString('base64')}';`);
fontJs += `\nwindow.__fontResult = (async () => { const f = await loadPixelFont(); return { loaded: f.loaded, advance: f.advance, cellH: f.cellH, w: f.atlas.width, h: f.atlas.height, png: f.atlas.toDataURL('image/png'), rgba: Array.from(f.atlas.getContext('2d').getImageData(0, 0, f.atlas.width, f.atlas.height).data), schwaX: f.glyphX('ə'), stressX: f.glyphX('ˈ'), lengthX: f.glyphX('ː'), unknownX: f.glyphX('é') }; })();\n`;
const browser = await chromium.launch();
const browserVersion = browser.version();
const page = await browser.newPage();
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ type: 'module', content: fontJs });
await page.waitForFunction(() => window.__fontResult !== undefined);
const font = await page.evaluate(() => window.__fontResult);
await browser.close();
if (!font.loaded) throw new Error('Press Start 2P failed to load in Chromium; refusing to emit a fallback font');
const fontRgba = Uint8Array.from(font.rgba);
const fontPng = encodePng(font.w, font.h, fontRgba);
writeIfChanged(path.join(GODOT, 'assets/fonts/pixel_font.png'), fontPng);
// BMFont text descriptor: monospace 8 px advance, union cell height, baseline at the cell bottom.
const glyphs = [];
for (let code = 32; code <= 126; code++) glyphs.push({ id: code, x: (code - 32) * font.advance });
glyphs.push({ id: 0x0259, x: font.schwaX }); // ə  rotated e (extra cell)
glyphs.push({ id: 0x02c8, x: font.stressX }); // ˈ borrows '
glyphs.push({ id: 0x02d0, x: font.lengthX }); // ː borrows :
const fnt = [
  `info face="SupervillainedPixel" size=${font.advance} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0 outline=0`,
  `common lineHeight=${font.cellH} base=${font.cellH} scaleW=${font.w} scaleH=${font.h} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4`,
  `page id=0 file="pixel_font.png"`,
  `chars count=${glyphs.length}`,
  ...glyphs.map((g) => `char id=${g.id} x=${g.x} y=0 width=${font.advance} height=${font.cellH} xoffset=0 yoffset=0 xadvance=${font.advance} page=0 chnl=15`),
  '',
].join('\n');
writeIfChanged(path.join(GODOT, 'assets/fonts/pixel_font.fnt'), fnt);
const glyphHashes = {};
for (let code = 32; code <= 126; code++) {
  const x0 = (code - 32) * font.advance;
  const cell = [];
  for (let y = 0; y < font.cellH; y++) for (let x = 0; x < font.advance; x++) cell.push(fontRgba[(y * font.w + x0 + x) * 4 + 3] ? 1 : 0);
  glyphHashes[code] = sha256(Buffer.from(cell)).slice(0, 16);
}
manifest.generated.push({ key: 'pixel_font', target: 'assets/fonts/pixel_font.png', sha256: sha256(fontPng), w: font.w, h: font.h, advance: font.advance, cell_h: font.cellH, recipe: 'src/ui/pixelFont.ts executed in Chromium', chromium: browserVersion, unknown_glyph_x: font.unknownX });
manifest.generated.push({ key: 'pixel_font_fnt', target: 'assets/fonts/pixel_font.fnt', sha256: sha256(Buffer.from(fnt)) });

// ---------------------------------------------------------------------------------------------
// 4. Reference fixtures from the audited TypeScript.
const config = await import(path.join(SRC, 'config.ts'));
const { Rng, hash2 } = await import(path.join(SRC, 'core/rng.ts'));
const proj = await import(path.join(SRC, 'iso/projection.ts'));
const depth = await import(path.join(SRC, 'iso/depth.ts'));
const { Camera, clampAxis } = await import(path.join(SRC, 'iso/camera.ts'));
const { computeViewport } = await import(path.join(SRC, 'core/display.ts'));
const { LEVEL_1, buildGreenZoneRows } = await import(path.join(SRC, 'levels/level1.ts'));
const { loadLevel, parseAsciiMap } = await import(path.join(SRC, 'world/level.ts'));
const { GameMap } = await import(path.join(SRC, 'world/map.ts'));
const { placeTreats, randomSpotNear } = await import(path.join(SRC, 'systems/placement.ts'));
const { Zampano } = await import(path.join(SRC, 'entities/zampano.ts'));
const needs = await import(path.join(SRC, 'systems/needs.ts'));
const scoring = await import(path.join(SRC, 'systems/scoring.ts'));
const lives = await import(path.join(SRC, 'systems/lives.ts'));
const { Rules } = await import(path.join(SRC, 'systems/rules.ts'));
const { PollutionWaveDirector } = await import(path.join(SRC, 'systems/threatLogic.ts'));
const { Emitter } = await import(path.join(SRC, 'core/events.ts'));
const { animationFrame, animationDuration } = await import(path.join(SRC, 'assets/animationTiming.ts'));

const fx = { audited_commit: AUDITED_COMMIT, note: 'Generated from the audited TypeScript; do not hand-edit or regenerate to match a Godot mismatch.' };
const PICK = ['DISPLAY', 'LOOP', 'ISO', 'CAMERA', 'PLAYER', 'ENERGY', 'INPUT', 'OCCLUSION', 'HUNGER', 'TREAT', 'DIGESTION', 'POOP', 'BLADDER', 'POLLUTION', 'ZONE', 'LIVES', 'SCORE', 'BARK', 'FX'];
fx.config = Object.fromEntries(PICK.map((k) => [k, config[k]]));
fx.config.AUDIO = { DEFAULT_VOLUME: config.AUDIO.DEFAULT_VOLUME, MUSIC_FILE_VOLUME: config.AUDIO.MUSIC_FILE_VOLUME, SFX_VOLUME: config.AUDIO.SFX_VOLUME, FILE_GAIN: config.AUDIO.FILE_GAIN };

// RNG
fx.rng = { sequences: {}, ints: {}, hash2: [] };
for (const seed of [0, 1, 7, 20240501, 0xffffffff, (20240501 ^ 0x5bd1e995) >>> 0]) {
  const r = new Rng(seed);
  fx.rng.sequences[seed] = Array.from({ length: 24 }, () => r.next());
  const r2 = new Rng(seed);
  fx.rng.ints[seed] = Array.from({ length: 24 }, (_, k) => r2.int(-3, 3 + (k % 5)));
}
for (const [i, j, s] of [[0, 0, 0], [1, 0, 1], [0, 1, 1], [17, 42, 2], [95, 95, 3], [-3, 5, 9], [12, 7, 72], [12, 7, 73], [33, 60, 21], [33, 60, 22], [2, 90, 1]]) fx.rng.hash2.push([i, j, s, hash2(i, j, s)]);

// Projection
const pts = [];
const pr = new Rng(99);
for (let k = 0; k < 40; k++) pts.push([pr.range(-120, 120), pr.range(-120, 120)]);
pts.push([0, 0], [1, 0], [0, 1], [-2.5, 3.25], [95.5, 95.5]);
fx.projection = {
  grid_to_screen: pts.map(([x, y]) => [x, y, proj.gridToScreen(x, y)]),
  screen_to_grid: pts.map(([x, y]) => [x, y, proj.screenToGrid(x, y)]),
  screen_dir_to_grid: [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0.3, -0.8], [0, 0]].map(([x, y]) => [x, y, proj.screenDirToGrid(x, y)]),
  dir_from_grid: [],
  dir_to_grid: proj.DIRS8.map((d) => [d, proj.dirToGridVector(d)]),
};
for (let k = 0; k < 64; k++) {
  const a = (k / 64) * Math.PI * 2 + 0.013;
  fx.projection.dir_from_grid.push([Math.cos(a), Math.sin(a), proj.dirFromGridVector(Math.cos(a), Math.sin(a), 'S')]);
}

// Viewport
fx.viewport = [];
for (const [w, h, dpr] of [[400, 860, 2], [360, 800, 3], [390, 844, 3], [412, 915, 2.625], [1920, 1080, 1], [1280, 720, 1.5], [432, 864, 1], [768, 1024, 2], [320, 480, 1], [216, 432, 1], [1080, 2400, 1], [800, 600, 1]]) {
  fx.viewport.push({ css_w: w, css_h: h, dpr, out: computeViewport(w, h, dpr) });
}

// Depth
const sortables = [
  { gx: 1, gy: 1, depthBias: 0, id: 1 }, { gx: 2, gy: 0, depthBias: 0, id: 2 }, { gx: 0, gy: 2, depthBias: 0, id: 3 },
  { gx: 1, gy: 1, depthBias: 0.1, id: 4 }, { gx: 1, gy: 1, depthBias: -0.3, id: 5 }, { gx: 1, gy: 1, depthBias: 0, id: 6 },
  { gx: 3.2, gy: 4.1, depthBias: 0, id: 7 }, { gx: 4.1, gy: 3.2, depthBias: 0, id: 8 }, { gx: 0.5, gy: 0.5, depthBias: 0, id: 9 },
];
fx.depth = { items: sortables, sorted_ids: [...sortables].sort(depth.compareDepth).map((s) => s.id) };

// Camera trace (shake 0 → deterministic)
{
  const cam = new Camera();
  cam.setView(216, 432);
  cam.bounds = { x: -400, y: -50, w: 800, h: 900 };
  cam.snapTo(10, 200);
  const trace = [];
  let tx = 10;
  let ty = 200;
  for (let k = 0; k < 240; k++) {
    const vx = k < 120 ? 50 : -30;
    const vy = k < 60 ? 0 : -25;
    tx += vx / 60;
    ty += vy / 60;
    cam.update(1 / 60, tx, ty, vx, vy);
    if (k % 20 === 19) trace.push({ k, tx, ty, x: cam.x, y: cam.y, origin: cam.viewOrigin(1) });
  }
  fx.camera = { view: [216, 432], bounds: cam.bounds, snap: [10, 200], trace, clamp_axis: [[0, -10, 10, 30], [5, -100, 100, 30], [99, -100, 100, 30], [-99, -100, 100, 30]].map((a) => [...a, clampAxis(...a)]) };
}

// Green Zone map
const level = loadLevel(LEVEL_1);
const map = new GameMap(level);
const rows = buildGreenZoneRows();
const exitDistance = Array.from(map.exitDistance);
fx.green_zone = {
  rows,
  rows_sha256: sha256(rows.join('\n')),
  width: map.width,
  height: map.height,
  start: map.startTile,
  exit: map.exitTile,
  props: map.props.map((p) => [p.kind, p.i, p.j]),
  playable_count: map.playableCount,
  start_exit_distance: map.exitDistance[map.index(map.startTile.i, map.startTile.j)],
  exit_distance_sha256: sha256(exitDistance.join(',')),
  reachable_count: exitDistance.filter((d) => d >= 0).length,
  progress_samples: [[90.5, 90.5], [60.5, 60.5], [30.2, 31.7], [4.5, 4.5], [50, 50], [0.5, 0.5]].map(([x, y]) => [x, y, map.progressAt(x, y)]),
  treats: placeTreats(map, LEVEL_1.spawns.treats, LEVEL_1.seed),
  ground_counts: (() => { const c = {}; for (const g of map.ground) c[g] = (c[g] ?? 0) + 1; return c; })(),
  definition: { id: LEVEL_1.id, number: LEVEL_1.number, zoneName: LEVEL_1.zoneName, seed: LEVEL_1.seed, parTime: LEVEL_1.parTime, spawns: LEVEL_1.spawns, events: LEVEL_1.events },
  random_spot: (() => { const r = new Rng(5); return Array.from({ length: 12 }, () => randomSpotNear(map, 60.5, 60.5, 3, 8, r)); })(),
};

// Map parser errors and padding
fx.map_parse = {
  ok: parseAsciiMap(['S..', '.T', 'E 1'], {}),
  base: parseAsciiMap(['S:2', ':E:'], { base: ':' }),
  no_exit: parseAsciiMap(['S..'], { requireExit: false }),
  errors: [[[]], [['S?E']], [['..E']], [['S.S', 'E..']], [['S..']], [['SEE']]].map(([r]) => { try { parseAsciiMap(r); return 'ok'; } catch (e) { return String(e.message); } }),
};
fx.map_parse.ok.ground = Array.from(fx.map_parse.ok.ground);
fx.map_parse.base.ground = Array.from(fx.map_parse.base.ground);
fx.map_parse.no_exit.ground = Array.from(fx.map_parse.no_exit.ground);

// moveCircle traces (grid collision/slide reference)
fx.move_circle = [];
{
  const starts = [[90.5, 90.5], [82.5, 79.7], [89.3, 86.1], [5.5, 6.5], [57.5, 57.5], [70.3, 66.4]];
  const dirs = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]];
  for (const [sx, sy] of starts) {
    for (const [dx, dy] of dirs) {
      const len = Math.hypot(dx, dy);
      const step = 0.125; // run speed 7.5 t/s at 60 Hz
      let x = sx;
      let y = sy;
      const trace = [];
      for (let k = 0; k < 90; k++) {
        const r = map.moveCircle(x, y, (dx / len) * step, (dy / len) * step, config.PLAYER.RADIUS);
        x = r.x;
        y = r.y;
        if (k % 10 === 9) trace.push([x, y, r.blocked]);
      }
      fx.move_circle.push({ start: [sx, sy], dir: [dx, dy], step, trace });
    }
  }
}

// Zampanò movement / animation traces with the real source class.
const DT = 1 / 60;
function zTrace(name, setup, script, ticks, every = 6) {
  const z = new Zampano(map.start.x, map.start.y);
  z.face('N');
  if (setup) setup(z);
  const trace = [];
  for (let k = 0; k < ticks; k++) {
    const [mx, my, run] = script(k);
    z.setIntent(mx, my, run);
    z.updateMovement(DT, map);
    if (k % every === every - 1) trace.push({ k, gx: z.gx, gy: z.gy, vx: z.vx, vy: z.vy, facing: z.facing, anim: z.animator.anim, running: z.running, energy: z.energy.value, exhausted: z.energy.exhausted, state: z.state, speed: z.animator.speed });
  }
  return { name, start: [z.gx, z.gy], trace };
}
const find = (pred) => { for (let j = 0; j < map.height; j++) for (let i = 0; i < map.width; i++) if (pred(i, j)) return [i + 0.5, j + 0.5]; return null; };
const tallGrass = find((i, j) => map.groundAt(i, j) === 3 && map.groundAt(i + 1, j) === 3 && map.groundAt(i - 1, j) === 3 && !map.propAt(i, j));
const water = find((i, j) => map.groundAt(i, j) === 4 && map.groundAt(i, j - 1) === 4 && map.groundAt(i, j + 1) === 4);
const bush = find((i, j) => map.propAt(i, j)?.kind === 'bush');
const SCREEN_DIRS = [[0, -1], [0.7071, -0.7071], [1, 0], [0.7071, 0.7071], [0, 1], [-0.7071, 0.7071], [-1, 0], [-0.7071, -0.7071]];
fx.zampano = { terrain_cells: { tallGrass, water, bush }, traces: [] };
for (const [d, [sx, sy]] of SCREEN_DIRS.entries()) {
  for (const mag of [0.8, 0.4]) fx.zampano.traces.push(zTrace(`walk_${d}_${mag}`, null, (k) => (k < 75 ? [sx * mag, sy * mag, false] : [0, 0, false]), 105));
  fx.zampano.traces.push(zTrace(`run_${d}`, null, (k) => (k < 75 ? [sx, sy, true] : [0, 0, false]), 105));
}
fx.zampano.traces.push(zTrace('run_exhaust', null, (k) => (k < 400 ? [0, -1, true] : [0, 0, false]), 900, 15));
fx.zampano.traces.push(zTrace('idle_phases', null, () => [0, 0, false], 720, 30));
fx.zampano.traces.push(zTrace('scripted_run', null, (k) => (k < 120 ? [0, -1, 'scripted'] : [0, 0, false]), 150, 10));
for (const [name, cell] of [['tall_grass', tallGrass], ['water', water], ['bush', bush]]) {
  fx.zampano.traces.push(zTrace(`terrain_${name}`, (z) => z.setPosition(cell[0], cell[1]), () => [0.7071 * 0.8, 0.7071 * 0.8, false], 30, 3));
}
{
  // Action lock: walking, then a 0.7 s pee starts at tick 30 (the rules' tryPee does this).
  const z = new Zampano(map.start.x, map.start.y);
  z.face('N');
  const trace = [];
  for (let k = 0; k < 120; k++) {
    if (k === 30) z.startAction('pee', config.BLADDER.PEE_TIME);
    if (k === 80) z.knockback(1, 0.5, 7);
    z.setIntent(0, -0.8, false);
    z.updateMovement(DT, map);
    if (k % 5 === 4) trace.push({ k, gx: z.gx, gy: z.gy, vx: z.vx, vy: z.vy, state: z.state, anim: z.animator.anim, controllable: z.controllable, speed: z.animator.speed });
  }
  fx.zampano.action_lock = trace;
}
fx.zampano.speed_mul = { lives: [2, 3, 5, 9, 1, 12, NaN].map((n) => [Number.isNaN(n) ? 'nan' : n, lives.clampLives(n), lives.livesSpeed(n)]) };

// Animation timing fixture
fx.animation = {};
for (const [name, def] of Object.entries(manifestTs.CHARACTERS.zampano.anims)) {
  fx.animation[name] = { def, duration: animationDuration(def), frames_at: [0, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2.3].map((t) => [t, animationFrame(def, t)]) };
}

// Needs
{
  const h = new needs.Hunger();
  const d = new needs.Digestion();
  const b = new needs.Bladder();
  const e = new needs.Energy();
  const t = [];
  for (let k = 0; k < 1500; k++) {
    const act = k < 300 ? 'idle' : k < 600 ? 'walk' : k < 900 ? 'run' : 'idle';
    const starved = h.update(DT, act);
    if (k % 100 === 0) d.add(26);
    const de = d.update(DT);
    if (de === 'poop') d.done();
    b.update(DT);
    if (k === 50 || k === 60 || k === 70 || k === 80) b.use();
    if (k === 1300) b.drink();
    const ee = e.update(DT, act);
    if (k % 50 === 49 || starved || de || ee) t.push({ k, hunger: h.value, starved, meter: d.meter, warning: d.warning, warningLeft: d.warningLeft, due: d.due, de, charges: b.charges, regen: b.regenFraction, canDrink: b.canDrink, energy: e.value, exhausted: e.exhausted, ee });
  }
  fx.needs = t;
}

// Scoring / lives
fx.scoring = {
  stars: [0, 0.5, 0.8, 0.81, 0.85, 0.9, 0.95, 0.97, 0.99, 0.995, 1].map((v) => [v, scoring.starsFromHealth(v)]),
  final_health: [[1, 3, 3], [0.97, 1, 4], [0.5, 0, 100], [0.99, 5, 2]].map(([hh, p, q]) => [hh, p, q, scoring.finalHealth(hh, p, q)]),
  time_bonus: [[100, 240], [239.4, 240], [300, 240], [0, 240]].map(([tt, par]) => [tt, par, scoring.timeBonus(tt, par)]),
  star_bonus: [0, 0.5, 2.5, 5].map((s) => [s, scoring.starBonus(s)]),
  format_time: [0, 59.9, 61, 3599, 3600.5].map((s) => [s, scoring.formatTime(s)]),
  format_score: [0, 7, 12345, -3, 99.9].map((s) => [s, scoring.formatScore(s)]),
};

// Pollution field: stamp/clean on the real map
{
  const m = new GameMap(level);
  const n1 = m.stampDirt(60.3, 61.2, 2.6, 1);
  const n2 = m.stampDirt(61.0, 60.0, 1.7, 0.75);
  const after = [];
  m.forTilesInRadius(60.5, 60.5, 4, (k) => { if (m.dirt[k] > 0) after.push([k, m.dirt[k]]); });
  const h1 = m.health();
  const c = m.clean(60.6, 60.9, 2.2);
  const left = [];
  m.forTilesInRadius(60.5, 60.5, 4, (k) => { if (m.dirt[k] > 0) left.push([k, m.dirt[k]]); });
  fx.pollution = { newly: [n1, n2], dirt_after_stamps: after, health_after_stamps: h1, cleaned: c, dirt_after_clean: left, fresh_count: m.fresh.size, health_after_clean: m.health(), surface: [[60.5, 60.5], [tallGrass[0], tallGrass[1]], [bush[0], bush[1]], [89.5, 89.5]].map(([x, y]) => [x, y, m.poopSurfaceAt(x, y)]) };
}

// Pollution waves director
{
  const dir = new PollutionWaveDirector(LEVEL_1.events.pollutionWaves);
  fx.waves = [0, 0.1, 0.25, 0.25, 0.5, 0.9, 1].map((p) => [p, dir.update(p).map((w) => w.progress), dir.remaining]);
}

// Rules: a scripted Green Zone run (teleports place him on treats; the input is scripted).
{
  const m = new GameMap(level);
  const player = new Zampano(m.start.x, m.start.y);
  player.face('N');
  const events = new Emitter();
  const log = [];
  for (const ev of ['score', 'treat', 'poop', 'pee', 'peeEmpty', 'drink', 'splash', 'digestWarning', 'lifeLost', 'gameOver', 'levelComplete', 'poopCleaned', 'tired']) events.on(ev, (e) => log.push([tick, ev, e]));
  let tick = 0;
  const world = { map: m, player, events, addEntity() {}, removeEntity() {} };
  const rules = new Rules(world, LEVEL_1, 2);
  const treats = rules.treats.map((t) => [t.gx, t.gy]);
  const pending = new Set();
  const input = { move: { x: 0, y: 0 }, runHeld: false, consume: (a) => pending.delete(a) };
  const fountain = m.props.find((p) => p.kind === 'fountain');
  const script = [];
  // Teleports (by tick) and inputs.
  const tp = new Map([[180, treats[0]], [240, treats[1]], [300, treats[2]], [360, treats[3]], [700, [fountain.x + 0.9, fountain.y]], [900, treats[4]]]);
  const trace = [];
  for (tick = 0; tick < 12000; tick++) {
    if (tp.has(tick)) { const [x, y] = tp.get(tick); player.setPosition(x, y); script.push([tick, 'teleport', x, y]); }
    if (tick < 170) { input.move.x = 0; input.move.y = -0.8; input.runHeld = tick > 90 && tick < 140; }
    else { input.move.x = 0; input.move.y = 0; input.runHeld = false; }
    if (tick >= 1000 && tick < 1100) { input.move.x = 0.6; input.move.y = 0.2; }
    if ([620, 640, 660, 680].includes(tick)) { pending.add('pee'); script.push([tick, 'pee']); }
    if (tick === 1200) { pending.add('pee'); script.push([tick, 'pee']); }
    rules.update(DT, input);
    if (tick % 60 === 59 || tick % 60 === 0 && tick < 1300) {
      trace.push({ tick, gx: player.gx, gy: player.gy, state: player.state, score: rules.stats.score, pees: rules.stats.pees, poops: rules.stats.poops, treats: rules.stats.treats, marks: rules.stats.marks, lives: rules.stats.lives, time: rules.stats.time, hunger: rules.hunger.value, meter: rules.digestion.meter, warning: rules.poopWarning, charges: rules.bladder.charges, health: m.health(), clean: m.cleanCount, poopRadius: rules.poops.map((p) => p.radius), rstate: rules.state });
    }
    if (rules.state !== 'playing' && rules.endedFor > 2) break;
  }
  fx.rules_run = { lives: 2, treats_start: treats.length, teleports: [...tp.entries()], script, trace, events: log.map(([t, ev, e]) => [t, ev, JSON.parse(JSON.stringify(e))]), final_state: rules.state, final_tick: tick };
}
{
  // Exit: walk from a tile next to the exit.
  const m = new GameMap(level);
  const player = new Zampano(m.exit.x + 1.2, m.exit.y + 1.2);
  const events = new Emitter();
  const log = [];
  events.on('levelComplete', () => log.push(['levelComplete', tick2]));
  let tick2 = 0;
  const rules = new Rules({ map: m, player, events, addEntity() {}, removeEntity() {} }, LEVEL_1, 2);
  const input = { move: { x: 0, y: -0.8 }, runHeld: false, consume: () => false };
  for (tick2 = 0; tick2 < 120 && rules.state === 'playing'; tick2++) rules.update(DT, input);
  fx.exit_run = { start: [m.exit.x + 1.2, m.exit.y + 1.2], ticks: tick2, state: rules.state, player: [player.gx, player.gy, player.state], log };
}

writeIfChanged(path.join(GODOT, 'tests/fixtures/source_reference.json'), stableJson(fx));
writeIfChanged(path.join(GODOT, 'tests/fixtures/source_font_glyphs.json'), stableJson({ audited_commit: AUDITED_COMMIT, chromium: browserVersion, advance: font.advance, cell_h: font.cellH, glyph_alpha_sha256_16: glyphHashes }));
manifest.toolchain = { node: process.version, playwright: require('playwright/package.json').version, chromium: browserVersion, pinned_node: readFileSync(path.join(GODOT, 'tools/.node-version'), 'utf8').trim() };
writeIfChanged(manifestPath, stableJson(manifest));
console.log(`extract done: ${manifest.copies.length} copies, ${manifest.generated.length} generated, fixtures written; ${changedOutputs} file(s) changed`);
