import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { inflateSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { animationDuration, animationFrame } from '../src/assets/animationTiming';
import { ANIMS, CHARACTERS, SHEET_DIRS, type AnimName } from '../src/assets/manifest';

interface Pixels { w: number; h: number; rgba: Buffer }
const decoded = new Map<string, Pixels>();

/** Decode the delivered pixels; file names and compressed bytes cannot prove eight views. */
function decodePng(path: string): Pixels {
  const previous = decoded.get(path);
  if (previous) return previous;
  const png = readFileSync(join('public', path));
  expect(png.subarray(0, 8), path).toEqual(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const w = png.readUInt32BE(16), h = png.readUInt32BE(20);
  expect([png[24], png[25], png[28]], `${path}: non-interlaced 8-bit RGBA`).toEqual([8, 6, 0]);
  const compressed: Buffer[] = [];
  for (let offset = 8; offset < png.length;) {
    const length = png.readUInt32BE(offset);
    if (png.toString('ascii', offset + 4, offset + 8) === 'IDAT') compressed.push(png.subarray(offset + 8, offset + 8 + length));
    offset += length + 12;
  }
  const raw = inflateSync(Buffer.concat(compressed));
  const stride = w * 4;
  expect(raw.length, path).toBe((stride + 1) * h);
  const rgba = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const filter = raw[y * (stride + 1)]!;
    expect(filter, path).toBeLessThanOrEqual(4);
    for (let x = 0; x < stride; x++) {
      const output = y * stride + x;
      const left = x >= 4 ? rgba[output - 4]! : 0;
      const above = y > 0 ? rgba[output - stride]! : 0;
      const corner = y > 0 && x >= 4 ? rgba[output - stride - 4]! : 0;
      const p = left + above - corner;
      const pa = Math.abs(p - left), pb = Math.abs(p - above), pc = Math.abs(p - corner);
      const paeth = pa <= pb && pa <= pc ? left : pb <= pc ? above : corner;
      const predictor = [0, left, above, (left + above) >> 1, paeth][filter]!;
      rgba[output] = (raw[y * (stride + 1) + x + 1]! + predictor) & 255;
    }
  }
  const result = { w, h, rgba };
  decoded.set(path, result);
  return result;
}

function visibleCell(image: Pixels, row: number, frame: number): Buffer {
  const cell = Buffer.alloc(40 * 40 * 4);
  for (let y = 0; y < 40; y++) {
    for (let x = 0; x < 40; x++) {
      const source = ((row * 40 + y) * image.w + frame * 40 + x) * 4;
      const target = (y * 40 + x) * 4;
      // Ignore invisible RGB and faint matte residue in source extraction.
      if (image.rgba[source + 3]! >= 128) image.rgba.copy(cell, target, source, source + 4);
    }
  }
  return cell;
}

describe('Bagnaskiz normal and Byzantine armoured integration', () => {
  it('uses the full-colour 8-directions sheets: the emperor wears the armour, the marshal his own', () => {
    expect(CHARACTERS.bagnaskiz.sheet).toBe('sprites/bagnaskiz.png');
    expect(CHARACTERS.bagnaskizEmperor.sheet).toBe('sprites/bagnaskizArmoured.png');
    expect(CHARACTERS.bagnaskizMarshal.sheet).toBe('sprites/pixel-cast/bagnaskizMarshal.png');
    for (const key of ['bagnaskiz', 'bagnaskizEmperor'] as const) {
      const def = CHARACTERS[key];
      expect(Object.keys(def.anims)).toEqual(ANIMS);
      expect([def.frameW, def.frameH, def.anchorX, def.anchorY]).toEqual([40, 40, 20, 36]);
    }
  });

  it('keeps his yellow eyes (a 32-colour copy of the sheet lost them)', () => {
    const image = decodePng(CHARACTERS.bagnaskiz.sheet!);
    let yellow = 0;
    for (let k = 0; k < image.rgba.length; k += 4) {
      const [r, g, b, a] = [image.rgba[k]!, image.rgba[k + 1]!, image.rgba[k + 2]!, image.rgba[k + 3]!];
      if (a >= 128 && r > 200 && g > 170 && b < 90) yellow++;
    }
    expect(yellow).toBeGreaterThan(500);
  });

  it('keeps the arcade hurt clip looping throughout the Green Zone stun', () => {
    const hurt = CHARACTERS.bagnaskiz.anims.hurt!;
    expect(hurt.loop).toBe(true);
    expect(animationFrame(hurt, animationDuration(hurt) + 0.05)).toBe(0);
  });
});

for (const key of ['bagnaskiz', 'bagnaskizEmperor'] as const) {
  describe(`${key} actual eight-direction sprite pixels`, () => {
    const def = CHARACTERS[key];
    const own = def.animSheets ?? {};
    const main = (Object.keys(def.anims) as AnimName[]).filter((action) => !own[action]);
    it.each(ANIMS)('%s has eight distinct visible views in every active frame', (action) => {
      const image = decodePng(own[action] ?? def.sheet!);
      const firstRow = own[action] ? 0 : main.indexOf(action) * SHEET_DIRS.length;
      for (let frame = 0; frame < def.anims[action]!.frames; frame++) {
        const signatures = SHEET_DIRS.map((direction, directionIndex) => {
          const pixels = visibleCell(image, firstRow + directionIndex, frame);
          expect(pixels.some((value, index) => index % 4 === 3 && value >= 128), `${action} ${direction} frame ${frame}: empty sprite`).toBe(true);
          for (let edge = 0; edge < 40; edge++) {
            const boundary = [edge, 39 * 40 + edge, edge * 40, edge * 40 + 39];
            expect(boundary.every((pixel) => pixels[pixel * 4 + 3] === 0), `${action} ${direction} frame ${frame}: artwork touches frame boundary`).toBe(true);
          }
          return createHash('sha256').update(pixels).digest('hex');
        });
        expect(new Set(signatures).size, `${action} frame ${frame}: a direction repeats another view`).toBe(8);
      }
    });
  });
}
