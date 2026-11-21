// SUPERVILLAINED VG1 — source asset/fixture extractor for the Godot port.
//
// Run from the repository root with the pinned Node (godot/tools/.node-version) and the
// package-lock's Playwright Chromium:
//   node --experimental-transform-types --no-warnings \
//        --import ./godot/tools/source_extract/register.mjs \
//        godot/tools/source_extract/extract.mjs [--check]
//
// It never modifies the source tree. It:
//  1. copies the runtime-authoritative files this milestone needs into godot/assets,
//  2. freezes the source's procedural sprites by executing src/assets/placeholders/*.ts,
//  3. rasterizes the bitmap font by executing src/ui/pixelFont.ts in Chromium,
//  4. measures the recorded effects' leading silence with the source's own leadingSilence(),
//  5. records reference fixtures produced by the audited TypeScript for the Godot tests,
//  6. writes godot/data/source_asset_manifest.json (path, SHA-256, size, dimensions, use).
//
// Platform independence: every copied or parsed source file is read from the audited commit's
// Git blob (`git cat-file blob`), never from the working tree, so a Windows CRLF checkout yields
// the same bytes and hashes. Generated text is LF-only (see godot/.gitattributes).
//
// Outputs are staged in memory. Without --check, files are rewritten only when their bytes change
// (a second run produces no diff). With --check, everything is regenerated in memory and compared
// byte-for-byte with the committed files; the process exits non-zero on any difference (1), on a
// source-tree change (3), on the wrong Node version (4), on a package-lock/Playwright mismatch (5)
// or when the launched Chromium is not the build pinned by playwright-core/browsers.json (6).
// Generated files record only pinned toolchain values; the host browser appears only in the
// console output (host evidence).

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import * as nodeModule from 'node:module';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
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

// One Node version for generation and checks (fixtures embed V8 arithmetic).
const PINNED_NODE = readFileSync(path.join(GODOT, 'tools/.node-version'), 'utf8').trim();
if (process.version !== `v${PINNED_NODE}`) {
  console.error(`Node ${process.version} is not the pinned v${PINNED_NODE} (godot/tools/.node-version); refusing to run.`);
  process.exit(4);
}

/** Dynamic import of an audited source module. ESM needs a file URL: a bare Windows path
 *  (C:\...) is rejected as an unsupported URL scheme. */
const importSource = (rel) => import(pathToFileURL(path.join(SRC, rel)).href);
const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const git = (args, opts = {}) => execFileSync('git', args, { cwd: ROOT, maxBuffer: 512 * 1024 * 1024, ...opts });
/** Bytes of a file exactly as committed in the audited commit (independent of checkout EOLs). */
const blob = (rel) => git(['cat-file', 'blob', `${AUDITED_COMMIT}:${rel}`]);
const blobText = (rel) => blob(rel).toString('utf8');
const stableJson = (v) => JSON.stringify(v, (_k, x) => (typeof x === 'number' && Object.is(x, -0) ? 0 : x), 1) + '\n';

/** Staged outputs: godot-relative path -> Buffer. */
const outputs = new Map();
function emit(rel, data) {
  const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
  if (!Buffer.isBuffer(data) && buf.includes(13)) throw new Error(`generated text ${rel} contains CR`);
  outputs.set(rel, buf);
  return buf;
}

// ---------------------------------------------------------------------------------------------
// Provenance guards: the executed/copied source must equal the audited commit, including the
// lockfile that pins Playwright (and so the Chromium build that rasterizes the font).
const GUARDED = ['src', 'public', 'assets', 'package.json', 'package-lock.json'];
try {
  git(['diff', '--quiet', AUDITED_COMMIT, '--', ...GUARDED], { stdio: 'ignore' });
} catch {
  console.error(`Source tree (${GUARDED.join(', ')}) differs from audited commit ${AUDITED_COMMIT}; refusing to run.`);
  process.exit(3);
}
const lock = JSON.parse(blobText('package-lock.json'));
const lockedPlaywright = lock.packages?.['node_modules/playwright']?.version;
const require = createRequire(path.join(ROOT, 'package.json'));
const playwrightVersion = require('playwright/package.json').version;
const lockedPlaywrightCore = lock.packages?.['node_modules/playwright-core']?.version;
const playwrightCoreVersion = require('playwright-core/package.json').version;
if (!lockedPlaywright || playwrightVersion !== lockedPlaywright || playwrightCoreVersion !== lockedPlaywrightCore) {
  console.error(`Playwright ${playwrightVersion} / playwright-core ${playwrightCoreVersion} do not match package-lock.json (${lockedPlaywright} / ${lockedPlaywrightCore}); run npm ci.`);
  process.exit(5);
}
// The Chromium build is pinned by the locked playwright-core (browsers.json), never by the host.
// Generated files record only these pinned values; the launched browser must report exactly this
// version (checked after launch, exit 6). The full Chromium build ('chromium' channel, what
// `npx playwright install chromium` installs on every platform) is used rather than the default
// headless shell, which hosts may substitute.
const browsersJson = path.join(path.dirname(require.resolve('playwright-core/package.json')), 'browsers.json');
const pinnedChromiumEntry = JSON.parse(readFileSync(browsersJson, 'utf8')).browsers.find((b) => b.name === 'chromium');
const PINNED_CHROMIUM = { version: pinnedChromiumEntry.browserVersion, revision: pinnedChromiumEntry.revision, channel: 'chromium' };

// ---------------------------------------------------------------------------------------------
// 1. Runtime-authoritative copies (only what this milestone references), from Git blobs.
const COPIES = [
  { from: 'public/sprites/zampano.png', to: 'assets/sprites/zampano.png', use: 'Zampanò normal 8-direction main sheet (11 actions x 8 dirs, 40x40)' },
  { from: 'public/sprites/zampano-tired.png', to: 'assets/sprites/zampano-tired.png', use: 'Zampanò normal tired sheet (2 frames x 8 dirs)' },
  { from: 'public/sprites/zampanoKnight.png', to: 'assets/sprites/zampanoKnight.png', use: 'Zampanò armoured (knight) main sheet; also the cross costume (AST-006 alias)' },
  { from: 'public/sprites/zampanoKnight-tired.png', to: 'assets/sprites/zampanoKnight-tired.png', use: 'Zampanò armoured tired sheet' },
  { from: 'public/sprites/sbrimbrulon.png', to: 'assets/sprites/sbrimbrulon.png', use: 'Sbrimbrulòn normal main sheet' },
  { from: 'public/sprites/sbrimbrulon-tired.png', to: 'assets/sprites/sbrimbrulon-tired.png', use: 'Sbrimbrulòn normal tired sheet' },
  { from: 'public/sprites/sbrimbrulonKnight.png', to: 'assets/sprites/sbrimbrulonKnight.png', use: 'Sbrimbrulòn armoured main sheet' },
  { from: 'public/sprites/sbrimbrulonKnight-tired.png', to: 'assets/sprites/sbrimbrulonKnight-tired.png', use: 'Sbrimbrulòn armoured tired sheet' },
  { from: 'public/sprites/bagnaskiz.png', to: 'assets/sprites/bagnaskiz.png', use: 'Bagnaskiz normal main sheet (full colour)' },
  { from: 'public/sprites/bagnaskiz-tired.png', to: 'assets/sprites/bagnaskiz-tired.png', use: 'Bagnaskiz normal tired sheet' },
  { from: 'public/sprites/bagnaskizArmoured.png', to: 'assets/sprites/bagnaskizArmoured.png', use: 'Bagnaskiz armoured (bagnaskizEmperor) main sheet' },
  { from: 'public/sprites/bagnaskizArmoured-tired.png', to: 'assets/sprites/bagnaskizArmoured-tired.png', use: 'Bagnaskiz armoured tired sheet' },
  { from: 'public/sprites/runIcon.png', to: 'assets/sprites/run_icon.png', use: 'RUN button icon' },
  { from: 'public/environment-ink/ch01_greenzone.png', to: 'assets/environment/ch01_greenzone.png', use: 'Color Ink Green Zone environment bank' },
  { from: 'public/environment-ink/manifest.json', to: 'assets/environment/manifest.json', use: 'Color Ink environment manifest (frames, themes, floor designs); kept verbatim (CRLF) for provenance' },
  { from: 'public/icon-192.png', to: 'assets/branding/icon.png', use: 'application icon (launcher art)' },
  { from: 'src/assets/fonts/OFL.txt', to: 'assets/fonts/OFL.txt', use: 'Press Start 2P license (OFL), exported with the game' },
  { from: 'assets/music/intro-music.mp3', to: 'assets/audio/recorded/intro-music.mp3', use: 'reading-screen music (MUSIC_FILES.intro): briefing' },
  { from: 'assets/music/greenzone-music.mp3', to: 'assets/audio/recorded/greenzone-music.mp3', use: 'Green Zone music (MUSIC_FILES.greenzone)' },
  { from: 'assets/sounds/dog-bark.mp3', to: 'assets/audio/recorded/dog-bark.mp3', use: 'SOUND_FILES.bark' },
  { from: 'assets/sounds/food-collect.mp3', to: 'assets/audio/recorded/food-collect.mp3', use: 'SOUND_FILES.treat' },
  { from: 'assets/sounds/poos.mp3', to: 'assets/audio/recorded/poos.mp3', use: 'SOUND_FILES.poop' },
  { from: 'assets/sounds/pees-drop.mp3', to: 'assets/audio/recorded/pees-drop.mp3', use: 'SOUND_FILES.pee' },
  { from: 'assets/sounds/pees-collect.wav', to: 'assets/audio/recorded/pees-collect.wav', use: 'SOUND_FILES.drink (imported as lossless PCM)' },
  { from: 'assets/sounds/water.mp3', to: 'assets/audio/recorded/water.mp3', use: 'SOUND_FILES.splash' },
  { from: 'assets/music/Level-2_SLY-Disco-Weapon.mp3', to: 'assets/audio/recorded/level2-music.mp3', use: 'MUSIC_FILES.level2 (Level 2, On the edge of dreams)' },
  { from: 'assets/music/Level-3_HM-Plenty-Good-Lovin.mp3', to: 'assets/audio/recorded/level3-music.mp3', use: 'MUSIC_FILES.level3 (Level 3, Venice)' },
  { from: 'assets/music/Level-4_CRI-Brother-Sister-(RM-Remix).mp3', to: 'assets/audio/recorded/level4-music.mp3', use: 'MUSIC_FILES.level4 (Level 4, The sea)' },
  { from: 'assets/sounds/cat-meow.mp3', to: 'assets/audio/recorded/cat-meow.mp3', use: 'SOUND_FILES.meow' },
  { from: 'assets/sounds/cash-after-cat.mp3', to: 'assets/audio/recorded/cash-after-cat.mp3', use: 'SOUND_FILES.coin' },
  { from: 'assets/sounds/ball.mp3', to: 'assets/audio/recorded/ball.mp3', use: 'SOUND_FILES.ball' },
  { from: 'assets/sounds/alarm-greenzone-under-attack.mp3', to: 'assets/audio/recorded/alarm-greenzone-under-attack.mp3', use: 'SOUND_FILES.alarm' },
  { from: 'assets/sounds/siren.mp3', to: 'assets/audio/recorded/siren.mp3', use: 'SOUND_FILES.siren' },
  { from: 'assets/sounds/laser-eyes.mp3', to: 'assets/audio/recorded/laser-eyes.mp3', use: 'SOUND_FILES.laser' },
];
const INPUTS_ONLY = [
  { from: 'src/assets/fonts/PressStart2P.woff2', use: 'converter input for the bitmap font (not exported)' },
  { from: 'src/ui/pixelFont.ts', use: 'bitmap font rasterization contract (executed in Chromium)' },
  { from: 'src/core/audio.ts', use: 'leadingSilence() executed in Chromium for the SFX start offsets' },
  { from: 'src/assets/placeholders/items.ts', use: 'procedural item/HUD sprite generators (executed)' },
  { from: 'src/assets/placeholders/critters.ts', use: 'procedural shadow generator (executed)' },
  { from: 'package-lock.json', use: 'pins Playwright (Chromium build used for the font and audio decoding)' },
  { from: 'src/core/synth.ts', use: 'sfxr-style renderer (renderSound/renderVoice) executed for the synthesized WAVs' },
  { from: 'src/fx/sounds.ts', use: 'SOUNDS recipes and renderMedievalMusic() executed for the synthesized WAVs' },
  { from: 'src/fx/audioFiles.ts', use: 'SOUND_FILES / MUSIC_FILES cue-to-file tables (executed)' },
];

const manifestRel = 'data/source_asset_manifest.json';
const manifest = { audited_commit: AUDITED_COMMIT, generated_by: 'godot/tools/source_extract/extract.mjs', copies: [], inputs: [], generated: [] };
for (const c of COPIES) {
  const buf = emit(c.to, blob(c.from));
  const entry = { source: c.from, target: c.to, sha256: sha256(buf), bytes: buf.length, use: c.use, provenance: 'Git blob at the audited commit; distribution rights to be recorded by owner (REL-001)' };
  if (c.from.endsWith('.png')) Object.assign(entry, pngSize(buf));
  manifest.copies.push(entry);
}
for (const c of INPUTS_ONLY) {
  const buf = blob(c.from);
  manifest.inputs.push({ source: c.from, sha256: sha256(buf), bytes: buf.length, use: c.use });
}

// ---------------------------------------------------------------------------------------------
// 2. Frozen procedural sprites (exact output of the source generators).
const items = await importSource('assets/placeholders/items.ts');
const critters = await importSource('assets/placeholders/critters.ts');
const manifestTs = await importSource('assets/manifest.ts');
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
  emit(target, png);
  manifest.generated.push({ key, target, sha256: sha256(png), w, h, frame_w: def.w, frame_h: def.h, variants: bufs.length, anchor_x: def.anchorX, anchor_y: def.anchorY, recipe: `src/assets/placeholders/${key === 'shadow' || key === 'shadowSmall' ? 'critters.ts drawShadow' : 'items.ts'}` });
}

// Sheet layout data (consumed by tools/build_resources.gd): exactly the source CHARACTERS
// entries of every playable skin (PLAYABLE_CHARACTER_KEYS). A skin whose sheet, own-anim sheets and
// anims are those of another skin is an alias (zampanoCross = zampanoKnight art, AST-006): it gets
// no layout of its own and its profile slot reuses the other skin's SpriteFrames.
{
  const copyTarget = (publicRel) => {
    const c = COPIES.find((x) => x.from === `public/${publicRel}`);
    if (!c) throw new Error(`sheet public/${publicRel} is not copied`);
    return `res://${c.to}`;
  };
  const same = (a, b) => a.sheet === b.sheet && JSON.stringify(a.animSheets ?? {}) === JSON.stringify(b.animSheets ?? {}) && JSON.stringify(a.anims) === JSON.stringify(b.anims);
  const aliases = {};
  const skins = [];
  // Among skins with identical art the armoured one is canonical (the cross costume IS the armour).
  const canonical = (key) => {
    const twins = manifestTs.PLAYABLE_CHARACTER_KEYS.filter((k) => same(manifestTs.CHARACTERS[k], manifestTs.CHARACTERS[key]));
    return twins.find((k) => manifestTs.ARMOURED_SKINS.has(k)) ?? twins[0];
  };
  for (const key of manifestTs.PLAYABLE_CHARACTER_KEYS) {
    const def = manifestTs.CHARACTERS[key];
    if (!def.sheet) throw new Error(`playable skin ${key} has no delivered sheet`);
    if (canonical(key) !== key) { aliases[key] = canonical(key); continue; }
    skins.push(key);
    const layout = {
      audited_commit: AUDITED_COMMIT,
      source: `src/assets/manifest.ts CHARACTERS.${key}`,
      key: def.key,
      frame_w: def.frameW,
      frame_h: def.frameH,
      anchor_x: def.anchorX,
      anchor_y: def.anchorY,
      sheet: copyTarget(def.sheet),
      anim_sheets: Object.fromEntries(Object.entries(def.animSheets ?? {}).map(([a, rel]) => [a, copyTarget(rel)])),
      sheet_dirs: manifestTs.SHEET_DIRS,
      anim_order: Object.keys(def.anims),
      anims: def.anims,
    };
    emit(`data/characters/${key}_sheet.json`, stableJson(layout));
  }
  // Who can be played and which skin each costume slot uses (source costumeFor(), executed).
  const COSTUMES = ['zampano', 'zampanoCross', 'zampanoKnight'];
  const profiles = {
    audited_commit: AUDITED_COMMIT,
    source: 'src/assets/manifest.ts PLAY_AS, PLAYABLE_CHARACTER_KEYS, ARMOURED_SKINS, costumeFor()',
    play_as: [...manifestTs.PLAY_AS],
    playable_keys: [...manifestTs.PLAYABLE_CHARACTER_KEYS],
    armoured_skins: [...manifestTs.ARMOURED_SKINS].filter((k) => manifestTs.PLAYABLE_CHARACTER_KEYS.includes(k)),
    skins,
    aliases,
    costume_slots: { normal: 'zampano', cross: 'zampanoCross', armoured: 'zampanoKnight' },
    costumes: Object.fromEntries(manifestTs.PLAY_AS.map((p) => [p, Object.fromEntries(COSTUMES.map((c) => [c, manifestTs.costumeFor(p, c)]))])),
  };
  emit('data/characters/playable_profiles.json', stableJson(profiles));
  // Environment frames used by this milestone, with the manifest's exact geometry.
  const envManifest = JSON.parse(blobText('public/environment-ink/manifest.json'));
  const env = envManifest.zones.ch01_greenzone;
  emit('data/environment/ch01_greenzone_frames.json', stableJson({ audited_commit: AUDITED_COMMIT, source: 'public/environment-ink/manifest.json zones.ch01_greenzone', image: 'res://assets/environment/ch01_greenzone.png', frames: env.frames, palette: env.palette, sprite_variants: manifestTs.SPRITES }));
  // The obsolete 1:arcade composition, kept only as MAP-006/AST-014 test data (never applied to 1.0).
  const arcade = envManifest.floorDesigns['1:arcade'];
  emit('tests/fixtures/floor_design_1_arcade.json', stableJson({ audited_commit: AUDITED_COMMIT, key: '1:arcade', chapter_themes: envManifest.chapterThemes['1'], ...arcade }));
}

// ---------------------------------------------------------------------------------------------
// 3. Bitmap font: execute src/ui/pixelFont.ts in Chromium with the bundled WOFF2.
const { chromium } = require('playwright');
const fontTs = blobText('src/ui/pixelFont.ts');
const woff2 = blob('src/assets/fonts/PressStart2P.woff2');
let fontJs = nodeModule.stripTypeScriptTypes(fontTs, { mode: 'strip' });
const importLine = /import fontUrl from '..\/assets\/fonts\/PressStart2P\.woff2\?url';/;
if (!importLine.test(fontJs)) throw new Error('pixelFont.ts import line changed; review the extractor');
fontJs = fontJs.replace(importLine, `const fontUrl = 'data:font/woff2;base64,${woff2.toString('base64')}';`);
fontJs += `\nwindow.__fontResult = (async () => { const f = await loadPixelFont(); return { loaded: f.loaded, advance: f.advance, cellH: f.cellH, w: f.atlas.width, h: f.atlas.height, png: f.atlas.toDataURL('image/png'), rgba: Array.from(f.atlas.getContext('2d').getImageData(0, 0, f.atlas.width, f.atlas.height).data), schwaX: f.glyphX('ə'), stressX: f.glyphX('ˈ'), lengthX: f.glyphX('ː'), unknownX: f.glyphX('é') }; })();\n`;
const browser = await chromium.launch({ channel: PINNED_CHROMIUM.channel });
const hostChromium = browser.version();
if (hostChromium !== PINNED_CHROMIUM.version) {
  console.error(`Chromium ${hostChromium} is not the build pinned by playwright-core ${playwrightCoreVersion} (${PINNED_CHROMIUM.version}, revision ${PINNED_CHROMIUM.revision}); run npx playwright install chromium.`);
  await browser.close();
  process.exit(6);
}
const browserVersion = PINNED_CHROMIUM.version;
const page = await browser.newPage();
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ type: 'module', content: fontJs });
await page.waitForFunction(() => window.__fontResult !== undefined);
const font = await page.evaluate(() => window.__fontResult);
// Leading silence of every recorded effect, with the source's leadingSilence() and TRIM_LEVEL,
// decoded by Chromium's WebAudio at 48 kHz (the usual Android output rate) and at 44.1 kHz.
const audioTs = blobText('src/core/audio.ts');
const silenceSrc = audioTs.match(/function leadingSilence\(buffer: AudioBuffer\): number \{[\s\S]*?\n\}/);
if (!silenceSrc) throw new Error('leadingSilence() not found in src/core/audio.ts; review the extractor');
const configTsForTrim = await importSource('config.ts');
// The cue -> file tables exactly as the source declares them (src/fx/audioFiles.ts, executed).
const audioFilesTs = await importSource('fx/audioFiles.ts');
const SFX_FILES = { ...audioFilesTs.SOUND_FILES };
const MUSIC_FILES = { ...audioFilesTs.MUSIC_FILES };
const sfxPayload = Object.fromEntries(Object.entries(SFX_FILES).map(([k, rel]) => [k, blob(rel).toString('base64')]));
const silenceJs = nodeModule.stripTypeScriptTypes(silenceSrc[0], { mode: 'strip' });
const offsets = await page.evaluate(async ({ files, fnSrc, trim }) => {
  const AUDIO = { TRIM_LEVEL: trim };
  const leadingSilence = new Function('AUDIO', `${fnSrc}; return leadingSilence;`)(AUDIO);
  const out = {};
  for (const [name, b64] of Object.entries(files)) {
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    out[name] = {};
    for (const rate of [48000, 44100]) {
      const ctx = new OfflineAudioContext(1, 1, rate);
      const buffer = await ctx.decodeAudioData(bytes.slice().buffer);
      out[name][rate] = { offset: leadingSilence(buffer), duration: buffer.duration };
    }
  }
  return out;
}, { files: sfxPayload, fnSrc: silenceJs, trim: configTsForTrim.AUDIO.TRIM_LEVEL });
// AUD-001–004 reference: every recorded file decoded by Chromium WebAudio at 48 kHz (channels,
// duration, peak |sample| over all channels). Peaks are rounded to 1e-3 so the fixture does not
// depend on the decoder's last float bits.
const recordedPayload = Object.fromEntries([...Object.entries(SFX_FILES), ...Object.entries(MUSIC_FILES)].map(([k, rel]) => [rel, blob(rel).toString('base64')]));
const decoded = await page.evaluate(async ({ files }) => {
  const out = {};
  for (const [rel, b64] of Object.entries(files)) {
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    const ctx = new OfflineAudioContext(1, 1, 48000);
    const buffer = await ctx.decodeAudioData(bytes.slice().buffer);
    let peak = 0;
    for (let c = 0; c < buffer.numberOfChannels; c++) {
      const ch = buffer.getChannelData(c);
      for (let i = 0; i < ch.length; i++) { const a = Math.abs(ch[i]); if (a > peak) peak = a; }
    }
    out[rel] = { channels: buffer.numberOfChannels, duration: Math.round(buffer.duration * 1000) / 1000, peak: Math.round(peak * 1000) / 1000 };
  }
  return out;
}, { files: recordedPayload });
await browser.close();
emit('data/audio/sfx_leading_silence.json', stableJson({ audited_commit: AUDITED_COMMIT, recipe: 'src/core/audio.ts leadingSilence() in Chromium WebAudio', trim_level: configTsForTrim.AUDIO.TRIM_LEVEL, runtime_rate: 48000, chromium: browserVersion, files: SFX_FILES, offsets }));
if (!font.loaded) throw new Error('Press Start 2P failed to load in Chromium; refusing to emit a fallback font');
const fontRgba = Uint8Array.from(font.rgba);
const fontPng = encodePng(font.w, font.h, fontRgba);
emit('assets/fonts/pixel_font.png', fontPng);
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
emit('assets/fonts/pixel_font.fnt', fnt);
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
// 3b. Synthesized audio (ARCHITECTURE §12): the source's own recipes and renderer, executed in Node
// at the source rate (src/core/audio.ts SFX_RATE = MUSIC_RATE = 22050), written as mono 22,050 Hz
// signed 16-bit little-endian PCM WAV. Quantization: round(clamp(sample, -1, 1) * 32767) with
// JavaScript Math.round. No runtime synthesis remains in the port.
const synthTs = await importSource('core/synth.ts');
const soundsTs = await importSource('fx/sounds.ts');
const SYNTH_RATE = 22050;
const audioTsRates = audioTs.match(/const SFX_RATE = (\d+);\s*const MUSIC_RATE = (\d+);/);
if (!audioTsRates || Number(audioTsRates[1]) !== SYNTH_RATE || Number(audioTsRates[2]) !== SYNTH_RATE) throw new Error('src/core/audio.ts SFX_RATE/MUSIC_RATE changed; review the extractor');
const quantize = (s) => Math.round(Math.max(-1, Math.min(1, s)) * 32767);
function encodeWav(samples) {
  const pcm = Buffer.alloc(samples.length * 2);
  for (let k = 0; k < samples.length; k++) pcm.writeInt16LE(quantize(samples[k]), k * 2);
  const head = Buffer.alloc(44);
  head.write('RIFF', 0, 'ascii');
  head.writeUInt32LE(36 + pcm.length, 4);
  head.write('WAVE', 8, 'ascii');
  head.write('fmt ', 12, 'ascii');
  head.writeUInt32LE(16, 16); // fmt chunk size
  head.writeUInt16LE(1, 20); // PCM
  head.writeUInt16LE(1, 22); // mono
  head.writeUInt32LE(SYNTH_RATE, 24);
  head.writeUInt32LE(SYNTH_RATE * 2, 28); // byte rate
  head.writeUInt16LE(2, 32); // block align
  head.writeUInt16LE(16, 34); // bits per sample
  head.write('data', 36, 'ascii');
  head.writeUInt32LE(pcm.length, 40);
  return { wav: Buffer.concat([head, pcm]), pcm };
}
const synthFixture = { audited_commit: AUDITED_COMMIT, recipe: 'src/fx/sounds.ts + src/core/synth.ts executed in Node', rate: SYNTH_RATE, bits: 16, channels: 1, quantization: 'round(clamp(sample, -1, 1) * 32767), JavaScript Math.round', cues: {}, music: {} };
function emitSynth(name, samples, recipe, kind) {
  const { wav, pcm } = encodeWav(samples);
  const target = `assets/audio/synth/${name}.wav`;
  emit(target, wav);
  let peak = 0;
  for (let k = 0; k < pcm.length; k += 2) peak = Math.max(peak, Math.abs(pcm.readInt16LE(k)));
  // A few float samples (as rendered, float32) with their quantized values: checks the formula.
  const probe = [];
  for (const k of [0, 1, Math.floor(samples.length / 7), Math.floor(samples.length / 3), Math.floor(samples.length / 2), samples.length - 2, samples.length - 1]) probe.push([k, samples[k], quantize(samples[k])]);
  const peakAt = (() => { let best = 0; for (let k = 1; k < samples.length; k++) if (Math.abs(samples[k]) > Math.abs(samples[best])) best = k; return best; })();
  probe.push([peakAt, samples[peakAt], quantize(samples[peakAt])]);
  const entry = { target, sha256: sha256(wav), pcm_sha256: sha256(pcm), samples: samples.length, duration: samples.length / SYNTH_RATE, peak, recipe_sha256: sha256(stableJson(recipe)), probe };
  synthFixture[kind][name] = entry;
  manifest.generated.push({ key: `synth_${name}`, target, sha256: entry.sha256, samples: entry.samples, rate: SYNTH_RATE, recipe: kind === 'music' ? 'src/fx/sounds.ts renderMedievalMusic()' : `src/fx/sounds.ts SOUNDS.${name} via src/core/synth.ts renderSound()` });
}
for (const [name, recipe] of Object.entries(soundsTs.SOUNDS)) {
  const samples = synthTs.renderSound(recipe, SYNTH_RATE);
  const expected = Math.ceil(synthTs.soundDuration(recipe) * SYNTH_RATE) + 1;
  if (samples.length !== expected) throw new Error(`synth ${name}: ${samples.length} samples, expected ${expected}`);
  emitSynth(name, samples, recipe, 'cues');
  synthFixture.cues[name].source_duration = synthTs.soundDuration(recipe);
}
emitSynth('medieval', soundsTs.renderMedievalMusic(SYNTH_RATE), { fn: soundsTs.renderMedievalMusic.toString(), voice: synthTs.renderVoice.toString() }, 'music');
synthFixture.music.medieval.loop = { mode: 'forward', begin: 0, end: synthFixture.music.medieval.samples, note: 'AudioBufferSourceNode loop=true over the whole buffer, restarted from 0 on every setTrack' };

// ---------------------------------------------------------------------------------------------
// 4. Reference fixtures from the audited TypeScript.
const config = await importSource('config.ts');
const { Rng, hash2 } = await importSource('core/rng.ts');
const proj = await importSource('iso/projection.ts');
const depth = await importSource('iso/depth.ts');
const { Camera, clampAxis } = await importSource('iso/camera.ts');
const { computeViewport } = await importSource('core/display.ts');
const { LEVEL_1, buildGreenZoneRows } = await importSource('levels/level1.ts');
const { loadLevel, parseAsciiMap } = await importSource('world/level.ts');
const { GameMap } = await importSource('world/map.ts');
const { placeTreats, randomSpotNear } = await importSource('systems/placement.ts');
const { Zampano } = await importSource('entities/zampano.ts');
const needs = await importSource('systems/needs.ts');
const scoring = await importSource('systems/scoring.ts');
const lives = await importSource('systems/lives.ts');
const { Rules } = await importSource('systems/rules.ts');
const { PollutionWaveDirector } = await importSource('systems/threatLogic.ts');
const { Emitter } = await importSource('core/events.ts');
const { animationFrame, animationDuration } = await importSource('assets/animationTiming.ts');

const fx = { audited_commit: AUDITED_COMMIT, note: 'Generated from the audited TypeScript; do not hand-edit or regenerate to match a Godot mismatch.' };
const PICK = ['DISPLAY', 'LOOP', 'ISO', 'CAMERA', 'PLAYER', 'ENERGY', 'INPUT', 'OCCLUSION', 'HUNGER', 'TREAT', 'DIGESTION', 'POOP', 'BLADDER', 'POLLUTION', 'ZONE', 'LIVES', 'SCORE', 'BARK', 'FX'];
fx.config = Object.fromEntries(PICK.map((k) => [k, config[k]]));
fx.config.AUDIO = config.AUDIO;

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
// VIEW-002: the source computeViewport over a dense grid of device sizes (css = device px / dpr),
// one "width,height,scale,cssLeft,cssTop" group per case in loop order, ';'-separated (one line).
fx.viewport_grid = { dprs: [1, 1.5, 2, 2.625, 3], w: [100, 2600, 97], h: [160, 3000, 131], out: [] };
for (const dpr of fx.viewport_grid.dprs) {
  for (let w = 100; w < 2600; w += 97) {
    for (let h = 160; h < 3000; h += 131) {
      const v = computeViewport(w / dpr, h / dpr, dpr);
      fx.viewport_grid.out.push([v.width, v.height, v.scale, v.cssLeft, v.cssTop].join(','));
    }
  }
}
fx.viewport_grid.out = fx.viewport_grid.out.join(';');

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

// AST-005 for every playable skin: the source's own cycle durations and loop flags.
fx.animation_skins = {};
for (const key of manifestTs.PLAYABLE_CHARACTER_KEYS) {
  fx.animation_skins[key] = Object.fromEntries(Object.entries(manifestTs.CHARACTERS[key].anims).map(([name, def]) => [name, { frames: def.frames, loop: def.loop, holds: def.frameDurationsMs ?? null, duration: animationDuration(def) }]));
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


// MOVE-005: external push (a magnet-like pull applied every tick) and knockback decay.
{
  const z = new Zampano(map.start.x, map.start.y);
  z.face('N');
  const trace = [];
  for (let k = 0; k < 150; k++) {
    if (k < 90) { z.pushX = 1.6; z.pushY = -0.4; }
    if (k === 60) z.knockback(-1, 0.3, 7);
    z.setIntent(k < 120 ? 0.3 : 0, k < 120 ? -0.6 : 0, false);
    z.updateMovement(DT, map);
    if (k % 5 === 4) trace.push({ k, gx: z.gx, gy: z.gy, vx: z.vx, vy: z.vy, knockX: z.knockX, knockY: z.knockY, facing: z.facing, state: z.state });
  }
  fx.zampano.push_knock = trace;
}
// DOG-002: the rest sequence restarts after an action (sit at 3 s, a pee at 5 s, stand again).
{
  const z = new Zampano(map.start.x, map.start.y);
  z.face('N');
  const trace = [];
  for (let k = 0; k < 720; k++) {
    if (k === 300) z.startAction('pee', config.BLADDER.PEE_TIME);
    z.setIntent(0, 0, false);
    z.updateMovement(DT, map);
    if (k % 10 === 9) trace.push({ k, anim: z.animator.anim, state: z.state, speed: z.animator.speed });
  }
  fx.zampano.idle_after_action = trace;
}

/** A Rules run driven by a per-tick script; records every tick's state and the event log. */
function rulesScenario(script, ticks) {
  const m = new GameMap(level);
  const player = new Zampano(m.start.x, m.start.y);
  player.face('N');
  const events = new Emitter();
  const log = [];
  let tick = 0;
  for (const ev of ['treat', 'poop', 'pee', 'peeEmpty', 'drink', 'splash', 'digestWarning', 'lifeLost', 'gameOver', 'levelComplete', 'poopCleaned']) events.on(ev, () => log.push([tick, ev]));
  const rules = new Rules({ map: m, player, events, addEntity() {}, removeEntity() {} }, LEVEL_1, 2);
  const treats = rules.treats.map((t) => [t.gx, t.gy]);
  const fountain = m.props.find((p) => p.kind === 'fountain');
  const pending = new Set();
  const input = { move: { x: 0, y: 0 }, runHeld: false, consume: (a) => pending.delete(a) };
  const ctx = { m, player, rules, treats, fountain, pending };
  const trace = [];
  for (tick = 0; tick < ticks; tick++) {
    script(tick, ctx);
    rules.update(DT, input);
    trace.push([tick, player.state, +player.stateDuration.toFixed(6), rules.poopWarning, rules.digestion.due, rules.stats.poops, rules.stats.pees, rules.stats.treats, rules.bladder.charges, rules.stats.lives, rules.state]);
  }
  return { trace, events: log, treats: treats.slice(0, 5), fountain: [fountain.x, fountain.y], exit: [m.exit.x, m.exit.y] };
}
// DOG-004: the poop falls due while he pees; it waits for the end of the action.
fx.rules_busy = rulesScenario((t, c) => {
  if (t === 10 || t === 20 || t === 30 || t === 40) c.player.setPosition(...c.treats[(t / 10) - 1]);
  if (t === 215) c.pending.add('pee');
}, 330);
// DOG-005: overlapping requests (bark, pee, treat, starvation, drink, exit) resolve like the source.
fx.rules_overlap = rulesScenario((t, c) => {
  if (t === 5) c.player.startAction('bark', config.BARK.ANIM_TIME);
  if (t === 8 || t === 40 || t === 50 || t === 125 || t === 170) c.pending.add('pee');
  if (t === 52) c.player.setPosition(...c.treats[0]);
  if (t === 120) c.rules.hunger.value = 0.001;
  if (t === 150) c.player.setPosition(c.fountain.x + 0.9, c.fountain.y);
  if (t === 230) c.player.setPosition(c.m.exit.x + 0.3, c.m.exit.y + 0.3);
}, 260);

emit('tests/fixtures/source_reference.json', stableJson(fx));
emit('tests/fixtures/source_audio.json', stableJson({ audited_commit: AUDITED_COMMIT, note: 'Generated from the audited TypeScript and Chromium WebAudio; do not hand-edit.', sound_files: SFX_FILES, music_files: MUSIC_FILES, decoded_48k: decoded, synth: synthFixture }));
emit('tests/fixtures/source_font_glyphs.json', stableJson({ audited_commit: AUDITED_COMMIT, chromium: browserVersion, advance: font.advance, cell_h: font.cellH, glyph_alpha_sha256_16: glyphHashes }));
manifest.toolchain = { node: `v${PINNED_NODE}`, pinned_node: PINNED_NODE, playwright: playwrightVersion, chromium: PINNED_CHROMIUM.version, chromium_revision: PINNED_CHROMIUM.revision, chromium_channel: PINNED_CHROMIUM.channel, chromium_pinned_by: 'node_modules/playwright-core/browsers.json' };
// Every other generated output, so tests and --check can verify them by hash.
manifest.outputs = [...outputs.entries()].filter(([rel]) => !manifest.copies.some((c) => c.target === rel)).map(([rel, buf]) => ({ target: rel, sha256: sha256(buf), bytes: buf.length })).sort((a, b) => (a.target < b.target ? -1 : 1));
emit(manifestRel, stableJson(manifest));

// ---------------------------------------------------------------------------------------------
// Finalize: compare (--check) or write the files whose bytes changed.
let differences = 0;
let written = 0;
for (const [rel, buf] of [...outputs.entries()].sort()) {
  const file = path.join(GODOT, rel);
  const same = existsSync(file) && readFileSync(file).equals(buf);
  if (same) continue;
  if (CHECK) {
    console.error(`${existsSync(file) ? 'DIFFERS' : 'MISSING'} godot/${rel}`);
    differences++;
  } else {
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, buf);
    written++;
  }
}
if (CHECK) {
  console.log(differences ? `asset check FAILED: ${differences} of ${outputs.size} output(s) differ (Node ${process.version}, Chromium ${PINNED_CHROMIUM.version} pinned, host browser reported ${hostChromium})` : `asset check OK: ${outputs.size} outputs identical (${manifest.copies.length} copies), Node ${process.version}, Playwright ${playwrightVersion}, Chromium ${PINNED_CHROMIUM.version} (revision ${PINNED_CHROMIUM.revision}, pinned; host browser reported ${hostChromium})`);
  process.exit(differences ? 1 : 0);
}
console.log(`extract done: ${outputs.size} outputs (${manifest.copies.length} copies); ${written} file(s) changed; Chromium ${PINNED_CHROMIUM.version} (revision ${PINNED_CHROMIUM.revision}, pinned; host browser reported ${hostChromium})`);
