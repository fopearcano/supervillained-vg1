import { hash2 } from '../../core/rng';
import { TH, TW, insideDiamond } from '../../iso/projection';
import type { Palette } from '../../world/level';
import { PixelBuffer, rgba } from './pixel';

/**
 * Placeholder ground tiles (TW x TH diamonds). All of them use the same rasterization
 * (`insideDiamond`) so they tessellate perfectly.
 */

/** Normalized diamond coords: u in [-1,1] horizontally, v in [-1,1] vertically. */
function uv(x: number, y: number, yOff = 0): [number, number] {
  return [(x + 0.5 - TW / 2) / (TW / 2), (y - yOff + 0.5 - TH / 2) / (TH / 2)];
}

function fillDiamond(pb: PixelBuffer, yOff: number, color: (x: number, y: number) => number | null): void {
  for (let y = 0; y < TH; y++) {
    for (let x = 0; x < TW; x++) {
      if (!insideDiamond(x, y)) continue;
      const c = color(x, y);
      if (c !== null) pb.set(x, y + yOff, c);
    }
  }
}

/** Paints a short stroke without leaking outside the already-rasterized diamond. */
function strokeInside(pb: PixelBuffer, points: ReadonlyArray<readonly [number, number]>, color: number): void {
  for (const [x, y] of points) pb.setIfOpaque(x, y, color);
}

/** A low-frequency noise cell. It reads as a material patch instead of TV-static dithering. */
function patchNoise(x: number, y: number, salt: number): number {
  return hash2(Math.floor(x / 4), Math.floor(y / 2), salt);
}

export function drawGrass(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.grass;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    const patch = patchNoise(x, y, 11 + variant * 31);
    const fleck = hash2(x, y, 29 + variant * 43);
    if (patch < 0.13 && fleck < 0.55) return D;
    if (patch > 0.88 && fleck < 0.45) return L;
    return B;
  });
  // Readable three-pixel tufts, grouped in clumps rather than uniformly scattered noise.
  for (let k = 0; k < 5; k++) {
    const x = Math.floor(hash2(k, variant, 5) * (TW - 12)) + 6;
    const y = Math.floor(hash2(variant, k, 9) * (TH - 8)) + 4;
    strokeInside(pb, [[x, y], [x - 1, y - 1], [x + 1, y - 1]], D);
    pb.setIfOpaque(x, y - 1, L);
  }
  if (variant === 3) {
    // A deliberately rare wildflower tile becomes a landmark in large green spaces.
    const flowers = pal.flowers;
    for (let k = 0; k < 3; k++) {
      const x = 8 + k * 7;
      const y = 6 + (k % 2) * 3;
      if (insideDiamond(x, y)) pb.set(x, y, rgba(flowers[k % flowers.length]!));
    }
  }
  return pb;
}

/** Tall grass tile; blades poke 5px above the diamond (texture is TW x TH+5, anchor at y=5). */
export const TALL_GRASS_OFFSET = 5;

export function drawTallGrass(pal: Palette, variant: number): PixelBuffer {
  const off = TALL_GRASS_OFFSET;
  const pb = new PixelBuffer(TW, TH + off);
  const [base, dark, light] = pal.tallGrass;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, off, (x, y) => (patchNoise(x, y, 40) < 0.18 ? D : B));
  // The variants are wind poses of the same blades. MapRenderer plays them 0-1-2-1.
  const lean = variant - 1;
  for (let k = 0; k < 24; k++) {
    const x = Math.floor(hash2(k, 17, 77) * (TW - 2)) + 1;
    const y = Math.floor(hash2(23, k, 78) * (TH - 2)) + 1;
    if (!insideDiamond(x, y)) continue;
    const h = 3 + Math.floor(hash2(x, y, 79) * 4);
    for (let s = 0; s < h; s++) {
      const bend = Math.round((s / Math.max(1, h - 1)) ** 2 * lean * 2);
      pb.set(x + bend, y + off - s, s === h - 1 ? L : s === 0 ? D : B);
    }
  }
  return pb;
}

/**
 * Path tile with grass bleeding in along edges whose neighbor is not path.
 * mask bits: 1 = top-right edge (neighbor i, j-1), 2 = bottom-right (i+1, j),
 *            4 = bottom-left (i, j+1), 8 = top-left (i-1, j).
 */
export function drawPath(pal: Palette, mask: number, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.path;
  const [gBase, gDark] = pal.grass;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  const G = rgba(gBase);
  const GD = rgba(gDark);
  fillDiamond(pb, 0, (x, y) => {
    const [u, v] = uv(x, y);
    const h = hash2(x, y, 200 + variant * 17);
    const edges = [
      [1, u - v],
      [2, u + v],
      [4, -u + v],
      [8, -u - v],
    ] as const;
    for (const [bit, e] of edges) {
      if (!(mask & bit)) continue;
      const depth = 1 - e; // 0 at the edge
      const reach = 0.12 + patchNoise(x, y, 300 + bit + variant * 13) * 0.18;
      if (depth < reach) return h < 0.3 ? GD : G;
    }
    const aggregate = patchNoise(x, y, 231 + variant * 29);
    if (aggregate < 0.12 && h < 0.55) return D;
    if (aggregate > 0.9 && h < 0.45) return L;
    return B;
  });
  // Paired wheel ruts make long routes visually continuous and easier to read at a glance.
  for (let y = 2; y < TH - 2; y++) {
    for (let x = 2; x < TW - 2; x++) {
      if (!insideDiamond(x, y)) continue;
      const lane = ((x - y * 2 + 64 + variant * 3) % 16 + 16) % 16;
      if ((lane === 4 || lane === 11) && hash2(x, y, 410 + variant) > 0.18) pb.set(x, y, D);
    }
  }
  // A few bright stones break up the broad earth bands without noisy single-pixel dithering.
  for (let k = 0; k < 4; k++) {
    const x = 5 + Math.floor(hash2(k, variant, 421) * (TW - 10));
    const y = 3 + Math.floor(hash2(variant, k, 422) * (TH - 6));
    pb.setIfOpaque(x, y, L);
  }
  return pb;
}

export function drawWater(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.water;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    // Never outline the diamond: adjacent tiles must merge into one pond, not blue paving.
    const band = ((x + y * 3 + variant * 4) % 13 + 13) % 13;
    if ((band === 0 || band === 1) && hash2(Math.floor(x / 3), y, 480) > 0.28) return L;
    if (band === 7 && hash2(x, y, 481) > 0.55) return D;
    return B;
  });
  return pb;
}

export function drawForest(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.forest;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    const patch = patchNoise(x, y, 500 + variant * 31);
    const h = hash2(x, y, 530 + variant);
    if (patch < 0.32 && h < 0.8) return D;
    if (patch > 0.86 && h < 0.5) return L;
    return B;
  });
  // Roots and fallen twigs make the solid forest border feel deliberately dense.
  const rootY = 6 + (variant % 2) * 2;
  strokeInside(pb, [[TW / 2, rootY], [TW / 2 - 2, rootY + 1], [TW / 2 - 4, rootY + 2]], D);
  strokeInside(pb, [[TW / 2, rootY], [TW / 2 + 2, rootY + 1], [TW / 2 + 5, rootY + 2]], L);
  return pb;
}

/** Pollution blotch (drawn with alpha on top of the ground). */
export function drawDirt(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.pollution;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    const h = hash2(x, y, 600 + variant);
    const [u, v] = uv(x, y);
    const edge = Math.abs(u) + Math.abs(v);
    const blob = patchNoise(x + variant * 3, y, 640);
    if (edge > 0.62 + blob * 0.28) return null;
    if (blob < 0.2 || h < 0.08) return D;
    if (blob > 0.88 && h < 0.45) return L;
    return B;
  });
  return pb;
}

/** "Re-greened" highlight: bright, sparkly. */
export function drawFresh(): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const G = rgba('#b8ff5a');
  const Y = rgba('#fff36a');
  const W = rgba('#ffffff');
  fillDiamond(pb, 0, (x, y) => {
    const h = hash2(x, y, 700);
    if (h < 0.04) return W;
    if (h < 0.14) return Y;
    return G;
  });
  return pb;
}

/** Glowing ring decal around the exit. */
export function drawExitRing(): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const Y = rgba('#fff36a');
  fillDiamond(pb, 0, (x, y) => {
    const [u, v] = uv(x, y);
    const e = Math.abs(u) + Math.abs(v);
    return e > 0.72 ? Y : null;
  });
  return pb;
}
