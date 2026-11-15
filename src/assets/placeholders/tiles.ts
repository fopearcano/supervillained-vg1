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

export function drawGrass(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.grass;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    const h = hash2(x, y, 11 + variant * 31);
    if (h < 0.09) return D;
    if (h < 0.16) return L;
    return B;
  });
  // A few grass blades (light tip over dark stem).
  for (let k = 0; k < 6; k++) {
    const x = Math.floor(hash2(k, variant, 5) * (TW - 8)) + 4;
    const y = Math.floor(hash2(variant, k, 9) * (TH - 6)) + 3;
    if (insideDiamond(x, y) && insideDiamond(x, y + 1)) {
      pb.set(x, y, L);
      pb.set(x, y + 1, D);
    }
  }
  if (variant === 3) {
    // Tiny flowers
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
  fillDiamond(pb, off, (x, y) => (hash2(x, y, 40 + variant) < 0.2 ? D : B));
  // Blades: vertical strokes growing upward from inside the diamond.
  for (let k = 0; k < 26; k++) {
    const x = Math.floor(hash2(k, variant, 77) * TW);
    const y = Math.floor(hash2(variant, k, 78) * TH);
    if (!insideDiamond(x, y)) continue;
    const h = 2 + Math.floor(hash2(x, y, 79) * 4);
    for (let s = 0; s < h; s++) pb.set(x, y + off - s, s === h - 1 ? L : s === 0 ? D : B);
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
    const h = hash2(x, y, 200 + variant);
    const edges = [
      [1, u - v],
      [2, u + v],
      [4, -u + v],
      [8, -u - v],
    ] as const;
    for (const [bit, e] of edges) {
      if (!(mask & bit)) continue;
      const depth = 1 - e; // 0 at the edge
      const reach = 0.16 + hash2(x, y, 300 + bit) * 0.16;
      if (depth < reach) return h < 0.3 ? GD : G;
    }
    if (h < 0.1) return D;
    if (h < 0.2) return L;
    return B;
  });
  return pb;
}

export function drawWater(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const [base, dark, light] = pal.water;
  const B = rgba(base);
  const D = rgba(dark);
  const L = rgba(light);
  fillDiamond(pb, 0, (x, y) => {
    const [u, v] = uv(x, y);
    if (Math.abs(u) + Math.abs(v) > 0.82) return D;
    const ripple = (x + y * 2 + variant * 5) % 11 === 0 || (x * 3 + y + variant * 3) % 17 === 0;
    return ripple ? L : B;
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
    const h = hash2(x, y, 500 + variant);
    if (h < 0.25) return D;
    if (h < 0.3) return L;
    return B;
  });
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
    if (edge > 0.75 && h < 0.45) return null;
    if (h < 0.18) return D;
    if (h < 0.26) return L;
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
