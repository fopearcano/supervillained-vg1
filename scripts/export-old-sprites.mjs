/**
 * Freezes the old character art as PNG sheets.
 *
 *   npm run sprites:old
 *
 * When a delivered sprite sheet replaces a character's procedural (placeholder) art, the art it
 * replaced is kept as the "old" version: this script draws it with the game's own generator
 * (src/assets/placeholders) and writes, for every character with an `oldSheet` in the manifest,
 * a sheet in the same layout as the new one (rows = anims in manifest order x N, NE, E, SE, S,
 * SW, W, NW; columns = frames) into public/sprites/old/. Anims the old art never had (tired)
 * are left out: the game shows the idle frames for them. It also writes the old RUN icon
 * (the chevrons drawn in src/ui/touchControls.ts) as old/runIcon.png, for reference.
 *
 * Run it only before a sheet is replaced, or when the generator changes on purpose: the PNGs
 * are what OPTIONS > ART: OLD shows.
 * No dependencies: TypeScript modules are loaded through Vite's SSR loader, PNGs are encoded
 * over node:zlib.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import zlib from 'node:zlib';
import { createServer } from 'vite';

const OUT = 'public';

// ------------------------------------------------------------------ PNG
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}

/** RGBA bytes (w*h*4) → PNG. */
function encodePng(w, h, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0; // filter: none
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ------------------------------------------------------------------ sheets
const vite = await createServer({ server: { middlewareMode: true }, appType: 'custom', logLevel: 'error' });
try {
  const { CHARACTERS, SHEET_DIRS } = await vite.ssrLoadModule('/src/assets/manifest.ts');
  const { drawCritter, poseFor } = await vite.ssrLoadModule('/src/assets/placeholders/critters.ts');
  const { CAST_SPECS } = await vite.ssrLoadModule('/src/assets/placeholders/cast.ts');
  const NEW_ONLY = new Set(['tired']);

  for (const def of Object.values(CHARACTERS)) {
    if (!def.oldSheet) continue;
    const anims = Object.entries(def.anims).filter(([a]) => !NEW_ONLY.has(a));
    const cols = Math.max(...anims.map(([, a]) => a.frames));
    const w = cols * def.frameW;
    const h = anims.length * SHEET_DIRS.length * def.frameH;
    const sheet = Buffer.alloc(w * h * 4);
    let row = 0;
    for (const [anim, ad] of anims) {
      for (const dir of SHEET_DIRS) {
        for (let f = 0; f < ad.frames; f++) {
          const pb = drawCritter(CAST_SPECS[def.key], dir, poseFor(anim, f));
          // Uint32 ABGR little-endian = R, G, B, A bytes in memory.
          const src = Buffer.from(pb.data.buffer, pb.data.byteOffset, pb.data.byteLength);
          for (let y = 0; y < pb.h; y++) {
            src.copy(sheet, ((row * def.frameH + y) * w + f * def.frameW) * 4, y * pb.w * 4, (y + 1) * pb.w * 4);
          }
        }
        row++;
      }
    }
    const file = join(OUT, def.oldSheet);
    mkdirSync(join(file, '..'), { recursive: true });
    writeFileSync(file, encodePng(w, h, sheet));
    console.log(`${file}  ${w}x${h}  (${anims.map(([a]) => a).join(', ')})`);
  }

  // The old RUN icon: two white chevrons, 7x5 (as drawn by drawChevrons in touchControls.ts).
  const iw = 7;
  const ih = 5;
  const icon = Buffer.alloc(iw * ih * 4);
  for (const ox of [0, 4]) {
    for (const [dx, dy] of [[0, 0], [1, 1], [2, 2], [1, 3], [0, 4]]) icon.fill(255, ((dy * iw) + ox + dx) * 4, ((dy * iw) + ox + dx) * 4 + 4);
  }
  const iconFile = join(OUT, 'sprites/old/runIcon.png');
  writeFileSync(iconFile, encodePng(iw, ih, icon));
  console.log(`${iconFile}  ${iw}x${ih}`);
} finally {
  await vite.close();
}
