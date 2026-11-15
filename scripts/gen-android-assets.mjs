/**
 * Generates the placeholder Android launcher icons and splash screens (pixel-art Zampanò face)
 * straight into android/app/src/main/res. No dependencies: a tiny PNG encoder over node:zlib.
 *
 *   node scripts/gen-android-assets.mjs
 */
import { readdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import zlib from 'node:zlib';

const RES = 'android/app/src/main/res';

// 16x16 face: O outline, W white, S shade, K black (eyes + nose), P pink tongue.
const FACE = [
  '................',
  '.....OOOOOO.....',
  '...OOWWWWWWOO...',
  '..OWWWWWWWWWWO..',
  '.OSWWWWWWWWWWSO.',
  'OSSWWKKWWKKWWSSO',
  'OSSWWKKWWKKWWSSO',
  'OSSWWWWWWWWWWSSO',
  '.OSWWWWWWWWWWSO.',
  '.OSWWWWKKWWWWSO.',
  '..OWWWWKKWWWWO..',
  '..OOWWWWPPWWOO..',
  '...OOWWWPPWOO...',
  '.....OOOOOO.....',
  '................',
  '................',
];
const COLORS = {
  O: [0x2f, 0x38, 0x50, 255],
  W: [0xff, 0xff, 0xff, 255],
  S: [0xd9, 0xe2, 0xef, 255],
  K: [0x11, 0x11, 0x11, 255],
  P: [0xff, 0x6a, 0x8a, 255],
};
const GREEN = [0x3f, 0xcf, 0x1f, 255];
const GREEN_DARK = [0x2a, 0x9e, 0x12, 255];
const BLACK = [0, 0, 0, 255];

function canvas(w, h, bg) {
  const data = new Uint8Array(w * h * 4);
  for (let k = 0; k < w * h; k++) data.set(bg ?? [0, 0, 0, 0], k * 4);
  return { w, h, data };
}

function set(c, x, y, rgba) {
  if (x < 0 || y < 0 || x >= c.w || y >= c.h) return;
  c.data.set(rgba, (y * c.w + x) * 4);
}

/** Draws the face scaled by an integer factor at (ox, oy). */
function drawFace(c, ox, oy, scale) {
  FACE.forEach((row, j) => {
    [...row].forEach((ch, i) => {
      const col = COLORS[ch];
      if (!col) return;
      for (let y = 0; y < scale; y++) for (let x = 0; x < scale; x++) set(c, ox + i * scale + x, oy + j * scale + y, col);
    });
  });
}

/** Grass-checker background like the game tiles. */
function grass(c) {
  const cell = Math.max(2, Math.floor(c.w / 24));
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) set(c, x, y, (Math.floor(x / cell) + Math.floor(y / cell)) % 2 ? GREEN : GREEN_DARK);
}

function circleMask(c) {
  const r = c.w / 2;
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) if (Math.hypot(x + 0.5 - r, y + 0.5 - r) > r) set(c, x, y, [0, 0, 0, 0]);
}

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

function png(c) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(c.w, 0);
  ihdr.writeUInt32BE(c.h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc((c.w * 4 + 1) * c.h);
  for (let y = 0; y < c.h; y++) {
    raw[y * (c.w * 4 + 1)] = 0;
    Buffer.from(c.data.buffer, y * c.w * 4, c.w * 4).copy(raw, y * (c.w * 4 + 1) + 1);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function sizeOf(file) {
  const b = readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

if (!existsSync(RES)) {
  console.error(`${RES} not found: run "npx cap add android" first.`);
  process.exit(1);
}

let count = 0;
for (const dir of readdirSync(RES)) {
  const path = join(RES, dir);
  for (const name of ['ic_launcher.png', 'ic_launcher_round.png', 'ic_launcher_foreground.png', 'splash.png']) {
    const file = join(path, name);
    if (!existsSync(file)) continue;
    const { w, h } = sizeOf(file);
    let c;
    if (name === 'splash.png') {
      c = canvas(w, h, BLACK);
      const scale = Math.max(2, Math.floor(Math.min(w, h) / 3 / 16));
      drawFace(c, Math.floor((w - 16 * scale) / 2), Math.floor((h - 16 * scale) / 2), scale);
    } else if (name === 'ic_launcher_foreground.png') {
      // Adaptive icon: keep the face inside the central 66% safe zone.
      c = canvas(w, h);
      const scale = Math.floor((w * 0.55) / 16);
      drawFace(c, Math.floor((w - 16 * scale) / 2), Math.floor((w - 16 * scale) / 2) + scale, scale);
    } else {
      c = canvas(w, h);
      grass(c);
      const scale = Math.floor((w * 0.8) / 16);
      drawFace(c, Math.floor((w - 16 * scale) / 2), Math.floor((h - 16 * scale) / 2) + Math.floor(scale / 2), scale);
      if (name === 'ic_launcher_round.png') circleMask(c);
    }
    writeFileSync(file, png(c));
    count++;
  }
}

const bg = join(RES, 'values/ic_launcher_background.xml');
writeFileSync(
  bg,
  `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#3FCF1F</color>\n</resources>\n`,
);
console.log(`wrote ${count} images + ${bg}`);
