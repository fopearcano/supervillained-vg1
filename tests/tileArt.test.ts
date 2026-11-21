import { describe, expect, it } from 'vitest';
import { alphaOf, rgba, type PixelBuffer } from '../src/assets/placeholders/pixel';
import { drawStoryTile } from '../src/assets/placeholders/storyArt';
import { drawGrass, drawPath, drawTallGrass, drawWater } from '../src/assets/placeholders/tiles';
import { TH, TW, insideDiamond } from '../src/iso/projection';
import type { Palette } from '../src/world/level';

const palette: Palette = {
  grass: ['#408c38', '#286426', '#78c85a'],
  tallGrass: ['#397c32', '#22551f', '#83bd58'],
  path: ['#b79058', '#795b36', '#dfc483'],
  water: ['#318aa6', '#1c5b78', '#78d4de'],
  forest: ['#214c2c', '#14341e', '#47784a'],
  foliage: ['#163b20', '#2c6c35', '#70b354'],
  pollution: ['#745632', '#4d351f', '#a27b43'],
  flowers: ['#fff06a', '#ff88aa', '#e9e5ff'],
  deep: ['#1e4c9a', '#14366e', '#4a7cc8'],
};

function opaqueColors(pb: PixelBuffer): Set<number> {
  return new Set([...pb.data].filter((c) => alphaOf(c) > 0));
}

function fingerprint(pb: PixelBuffer): string {
  let hash = 2166136261;
  for (const value of pb.data) hash = Math.imul(hash ^ value, 16777619);
  return `${pb.w}x${pb.h}:${hash >>> 0}`;
}

describe('procedural ground art', () => {
  it('keeps every story surface inside the tessellating isometric diamond', () => {
    for (const kind of ['floor', 'stone', 'sand', 'snow', 'deep', 'dock', 'carpet', 'wallBase']) {
      const tile = drawStoryTile(palette, kind, 1);
      expect(tile.w, kind).toBe(TW);
      expect(tile.h, kind).toBe(TH);
      expect(opaqueColors(tile).size, kind).toBeGreaterThanOrEqual(3);
      for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
        if (!insideDiamond(x, y)) expect(alphaOf(tile.get(x, y)), `${kind} leaked at ${x},${y}`).toBe(0);
      }
    }
  });

  it('builds distinct material variants instead of recoloring one flat tile', () => {
    for (const kind of ['floor', 'stone', 'sand', 'snow', 'deep', 'dock', 'carpet']) {
      const frames = [0, 1, 2].map((variant) => fingerprint(drawStoryTile(palette, kind, variant)));
      expect(new Set(frames).size, kind).toBeGreaterThan(1);
    }
    expect(fingerprint(drawGrass(palette, 0))).not.toBe(fingerprint(drawGrass(palette, 1)));
    expect(fingerprint(drawWater(palette, 0))).not.toBe(fingerprint(drawWater(palette, 1)));
  });

  it('preserves authored path edges and gives tall grass three wind poses', () => {
    expect(fingerprint(drawPath(palette, 0, 0))).not.toBe(fingerprint(drawPath(palette, 15, 0)));
    const wind = [0, 1, 2].map((variant) => fingerprint(drawTallGrass(palette, variant)));
    expect(new Set(wind).size).toBe(3);
  });

  it('does not outline water diamonds inside continuous ponds and seas', () => {
    const boundary = (tile: PixelBuffer): number[] => {
      const colors: number[] = [];
      for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
        if (!insideDiamond(x, y)) continue;
        if (
          !insideDiamond(x - 1, y) ||
          !insideDiamond(x + 1, y) ||
          !insideDiamond(x, y - 1) ||
          !insideDiamond(x, y + 1)
        ) colors.push(tile.get(x, y));
      }
      return colors;
    };
    for (const variant of [0, 1]) {
      const pondEdge = boundary(drawWater(palette, variant));
      const seaEdge = boundary(drawStoryTile(palette, 'deep', variant));
      expect(pondEdge.filter((c) => c === rgba(palette.water[1])).length).toBeLessThan(pondEdge.length / 2);
      expect(seaEdge.filter((c) => c === rgba(palette.deep![1])).length).toBeLessThan(seaEdge.length / 2);
    }
  });
});
