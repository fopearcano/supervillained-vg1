import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { inflateSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { CHARACTERS, SHEET_DIRS, type AnimName, type CharacterKey } from '../src/assets/manifest';

/** Decodes an 8-bit RGBA, non-interlaced PNG (what the delivered sheets are) into raw pixels. */
function decodePng(path: string): { w: number; h: number; px: Uint8Array } {
  const b = readFileSync(join('public', path));
  let off = 8;
  let w = 0;
  let h = 0;
  const idat: Buffer[] = [];
  while (off < b.length) {
    const len = b.readUInt32BE(off);
    const type = b.toString('ascii', off + 4, off + 8);
    const data = b.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      w = data.readUInt32BE(0);
      h = data.readUInt32BE(4);
      expect([data[8], data[9], data[12]], path).toEqual([8, 6, 0]);
    } else if (type === 'IDAT') idat.push(data);
    off += 12 + len;
  }
  const raw = inflateSync(Buffer.concat(idat));
  const stride = w * 4;
  const px = new Uint8Array(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)]!;
    for (let x = 0; x < stride; x++) {
      const v = raw[y * (stride + 1) + 1 + x]!;
      const a = x >= 4 ? px[y * stride + x - 4]! : 0;
      const up = y > 0 ? px[(y - 1) * stride + x]! : 0;
      const c = y > 0 && x >= 4 ? px[(y - 1) * stride + x - 4]! : 0;
      const p = a + up - c;
      const pr = Math.abs(p - a) <= Math.abs(p - up) && Math.abs(p - a) <= Math.abs(p - c) ? a : Math.abs(p - up) <= Math.abs(p - c) ? up : c;
      px[y * stride + x] = (v + [0, a, up, (a + up) >> 1, pr][f]!) & 255;
    }
  }
  return { w, h, px };
}

/** One 40x40 cell as a string of its RGBA bytes ('' when fully transparent). */
function cell(img: { w: number; px: Uint8Array }, col: number, row: number): string {
  let s = '';
  let opaque = false;
  for (let y = 0; y < 40; y++) {
    for (let x = 0; x < 40; x++) {
      const i = ((row * 40 + y) * img.w + col * 40 + x) * 4;
      if (img.px[i + 3]) opaque = true;
      s += String.fromCharCode(img.px[i]!, img.px[i + 1]!, img.px[i + 2]!, img.px[i + 3]!);
    }
  }
  return opaque ? s : '';
}

const SIDE: Record<string, string> = { NE: 'E', SE: 'E', NW: 'W', SW: 'W' };
const KEYS: CharacterKey[] = ['zampano', 'zampanoKnight', 'sbrimbrulon', 'sbrimbrulonKnight'];

describe('eight-direction sheets (8-directions update)', () => {
  it.each(KEYS)('%s: every action is drawn in all eight headings, each diagonal its own view', (key) => {
    const def = CHARACTERS[key];
    const own = def.animSheets ?? {};
    const main = decodePng(def.sheet!);
    let row = 0;
    for (const [anim, ad] of Object.entries(def.anims) as Array<[AnimName, { frames: number }]>) {
      const path = own[anim];
      const img = path ? decodePng(path) : main;
      const base = path ? 0 : row;
      for (let f = 0; f < ad.frames; f++) {
        const views = Object.fromEntries(SHEET_DIRS.map((d, k) => [d, cell(img, f, base + k)]));
        for (const d of SHEET_DIRS) expect(views[d], `${key} ${anim} ${d} frame ${f} is empty`).not.toBe('');
        for (const [diag, side] of Object.entries(SIDE)) expect(views[diag] === views[side], `${key} ${anim} ${diag} frame ${f} repeats ${side}`).toBe(false);
      }
      if (!path) row += SHEET_DIRS.length;
    }
  });
});
