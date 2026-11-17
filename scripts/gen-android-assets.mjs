/**
 * App icons and splash screens from the logo (branding/logo.png: the shape on white, cropped).
 *
 *   npm run android:icons
 *
 * Writes, at every size already present in android/app/src/main/res:
 *  - ic_launcher.png        square, white, the whole shape centred;
 *  - ic_launcher_round.png  white disc, the whole shape inside the circle;
 *  - ic_launcher_foreground.png  adaptive icon: the shape inside the 66 dp safe zone
 *    (the background colour is set to white);
 *  - splash.png             white screen with the logo in the middle;
 * and the web icons in public/ (favicon, Apple touch icon, 192/512 for installs).
 * No dependencies: a small PNG decoder/encoder over node:zlib and an area-average resize.
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import zlib from 'node:zlib';

const RES = 'android/app/src/main/res';
const LOGO = 'branding/logo.png';
const PUBLIC = 'public';
const WHITE = [255, 255, 255, 255];

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

function encodePng(img) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0);
  ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    raw[y * (img.w * 4 + 1)] = 0;
    for (let x = 0; x < img.w * 4; x++) raw[y * (img.w * 4 + 1) + 1 + x] = img.data[y * img.w * 4 + x];
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** 8-bit, non-interlaced RGB / RGBA / grey PNGs (what image editors and Pillow write). */
function decodePng(buf) {
  let p = 8;
  let w = 0;
  let h = 0;
  let type = 0;
  const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p);
    const kind = buf.toString('ascii', p + 4, p + 8);
    const data = buf.subarray(p + 8, p + 8 + len);
    if (kind === 'IHDR') {
      w = data.readUInt32BE(0);
      h = data.readUInt32BE(4);
      if (data[8] !== 8 || data[12] !== 0) throw new Error(`${LOGO}: only 8-bit non-interlaced PNGs are supported`);
      type = data[9];
    } else if (kind === 'IDAT') idat.push(data);
    p += 12 + len;
  }
  const ch = { 0: 1, 2: 3, 4: 2, 6: 4 }[type];
  if (!ch) throw new Error(`${LOGO}: unsupported PNG colour type ${type} (save it as RGB or RGBA)`);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * ch;
  const out = new Uint8Array(w * h * 4);
  let prev = new Uint8Array(stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const cur = new Uint8Array(stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? cur[x - ch] : 0;
      const b = prev[x];
      const c = x >= ch ? prev[x - ch] : 0;
      let v = line[x];
      if (f === 1) v += a;
      else if (f === 2) v += b;
      else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) {
        const pp = a + b - c;
        const pa = Math.abs(pp - a);
        const pb = Math.abs(pp - b);
        const pc = Math.abs(pp - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      cur[x] = v & 255;
    }
    for (let x = 0; x < w; x++) {
      const o = (y * w + x) * 4;
      const s = x * ch;
      if (ch >= 3) out.set([cur[s], cur[s + 1], cur[s + 2], ch === 4 ? cur[s + 3] : 255], o);
      else out.set([cur[s], cur[s], cur[s], ch === 2 ? cur[s + 1] : 255], o);
    }
    prev = cur;
  }
  return { w, h, data: out };
}

function sizeOf(file) {
  const b = readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

// ------------------------------------------------------------------ images
function blank(w, h, rgba = [0, 0, 0, 0]) {
  const data = new Uint8Array(w * h * 4);
  for (let k = 0; k < w * h; k++) data.set(rgba, k * 4);
  return { w, h, data };
}

/** Area-average resize (each output pixel is the mean of the source area it covers). */
function resize(src, dw, dh) {
  const sx = src.w / dw;
  const sy = src.h / dh;
  const out = new Uint8Array(dw * dh * 4);
  for (let y = 0; y < dh; y++) {
    const y0 = y * sy;
    const y1 = y0 + sy;
    for (let x = 0; x < dw; x++) {
      const x0 = x * sx;
      const x1 = x0 + sx;
      const acc = [0, 0, 0, 0];
      let total = 0;
      for (let j = Math.floor(y0); j < Math.ceil(y1); j++) {
        const wy = Math.min(j + 1, y1) - Math.max(j, y0);
        for (let i = Math.floor(x0); i < Math.ceil(x1); i++) {
          const wx = Math.min(i + 1, x1) - Math.max(i, x0);
          const wgt = wx * wy;
          const o = (Math.min(j, src.h - 1) * src.w + Math.min(i, src.w - 1)) * 4;
          for (let c = 0; c < 4; c++) acc[c] += src.data[o + c] * wgt;
          total += wgt;
        }
      }
      for (let c = 0; c < 4; c++) out[(y * dw + x) * 4 + c] = Math.round(acc[c] / total);
    }
  }
  return { w: dw, h: dh, data: out };
}

/** Paste `img` centred on `dst`. */
function pasteCentered(dst, img) {
  const ox = Math.round((dst.w - img.w) / 2);
  const oy = Math.round((dst.h - img.h) / 2);
  for (let y = 0; y < img.h; y++) {
    for (let x = 0; x < img.w; x++) {
      const tx = ox + x;
      const ty = oy + y;
      if (tx < 0 || ty < 0 || tx >= dst.w || ty >= dst.h) continue;
      dst.data.set(img.data.subarray((y * img.w + x) * 4, (y * img.w + x) * 4 + 4), (ty * dst.w + tx) * 4);
    }
  }
  return dst;
}

/** The logo scaled to fit a box (keeps the aspect ratio). */
function logoIn(logo, boxW, boxH) {
  const s = Math.min(boxW / logo.w, boxH / logo.h);
  return resize(logo, Math.max(1, Math.round(logo.w * s)), Math.max(1, Math.round(logo.h * s)));
}

/** The logo scaled so its whole bounding box fits in a circle of radius r. */
function logoInCircle(logo, r) {
  const s = r / Math.hypot(logo.w / 2, logo.h / 2);
  return resize(logo, Math.max(1, Math.round(logo.w * s)), Math.max(1, Math.round(logo.h * s)));
}

/** Transparent outside the inscribed circle, with an anti-aliased edge (4×4 samples). */
function circleMask(img) {
  const r = img.w / 2;
  for (let y = 0; y < img.h; y++) {
    for (let x = 0; x < img.w; x++) {
      let inside = 0;
      for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++) if (Math.hypot(x + (i + 0.5) / 4 - r, y + (j + 0.5) / 4 - r) <= r) inside++;
      const o = (y * img.w + x) * 4 + 3;
      img.data[o] = Math.round((img.data[o] * inside) / 16);
    }
  }
  return img;
}

// ------------------------------------------------------------------ build
const makers = {
  /** Square launcher icon: white, the whole shape centred with a margin. */
  'ic_launcher.png': (w, h) => pasteCentered(blank(w, h, WHITE), logoIn(logo, w * 0.8, h * 0.84)),
  /** Round launcher icon: white disc, the whole shape inside the circle. */
  'ic_launcher_round.png': (w, h) => circleMask(pasteCentered(blank(w, h, WHITE), logoInCircle(logo, (w / 2) * 0.9))),
  /** Adaptive icon foreground (108 dp): the shape inside the 66 dp safe circle, on white. */
  'ic_launcher_foreground.png': (w, h) => pasteCentered(blank(w, h, WHITE), logoInCircle(logo, (w / 2) * (64 / 108))),
  /** Splash: white, the logo in the middle. */
  'splash.png': (w, h) => pasteCentered(blank(w, h, WHITE), logoIn(logo, w * 0.5, h * 0.42)),
};

if (!existsSync(LOGO)) {
  console.error(`${LOGO} not found.`);
  process.exit(1);
}
const logo = decodePng(readFileSync(LOGO));

let count = 0;
if (existsSync(RES)) {
  for (const dir of readdirSync(RES)) {
    for (const [name, make] of Object.entries(makers)) {
      const file = join(RES, dir, name);
      if (!existsSync(file)) continue;
      const { w, h } = sizeOf(file);
      writeFileSync(file, encodePng(make(w, h)));
      count++;
    }
  }
  writeFileSync(
    join(RES, 'values/ic_launcher_background.xml'),
    `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n`,
  );
} else console.warn(`${RES} not found: Android icons skipped (run "npx cap add android" first).`);

// Web icons (served from the site root by Vite).
mkdirSync(PUBLIC, { recursive: true });
for (const [file, size] of [
  ['favicon-32.png', 32],
  ['favicon-64.png', 64],
  ['apple-touch-icon.png', 180],
  ['icon-192.png', 192],
  ['icon-512.png', 512],
]) {
  writeFileSync(join(PUBLIC, file), encodePng(makers['ic_launcher.png'](size, size)));
  count++;
}
console.log(`wrote ${count} images from ${LOGO}`);
