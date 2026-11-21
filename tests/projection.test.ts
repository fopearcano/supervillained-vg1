import { describe, expect, it } from 'vitest';
import {
  TH,
  TW,
  depthKey,
  dirFromGridVector,
  dirFromScreenVector,
  dirToGridVector,
  gridToScreen,
  gridVecToScreen,
  insideDiamond,
  mirrorDir,
  screenDirToGrid,
  screenToGrid,
  DIRS8,
} from '../src/iso/projection';

describe('grid <-> screen projection', () => {
  it('projects the tile corners of a 2:1 diamond', () => {
    expect(gridToScreen(0, 0)).toEqual({ x: 0, y: 0 });
    expect(gridToScreen(1, 0)).toEqual({ x: TW / 2, y: TH / 2 });
    expect(gridToScreen(0, 1)).toEqual({ x: -TW / 2, y: TH / 2 });
    expect(gridToScreen(1, 1)).toEqual({ x: 0, y: TH });
  });

  it('round-trips grid -> screen -> grid', () => {
    for (const [gx, gy] of [
      [0, 0],
      [3.25, 7.5],
      [-2, 5],
      [71.9, 0.1],
      [12.345, 67.89],
    ]) {
      const s = gridToScreen(gx!, gy!);
      const g = screenToGrid(s.x, s.y);
      expect(g.x).toBeCloseTo(gx!, 9);
      expect(g.y).toBeCloseTo(gy!, 9);
    }
  });

  it('round-trips screen -> grid -> screen', () => {
    for (const [sx, sy] of [
      [0, 0],
      [100, 37],
      [-64, 250.5],
      [3, -9],
    ]) {
      const g = screenToGrid(sx!, sy!);
      const s = gridToScreen(g.x, g.y);
      expect(s.x).toBeCloseTo(sx!, 9);
      expect(s.y).toBeCloseTo(sy!, 9);
    }
  });
});

describe('screen-space joystick to grid direction', () => {
  const cases: Array<[number, number]> = [
    [1, 0],
    [0, -1],
    [-1, 0],
    [0, 1],
    [0.6, -0.8],
    [-0.3, 0.95],
  ];
  it('moves in the same SCREEN direction as the stick', () => {
    for (const [dx, dy] of cases) {
      const g = screenDirToGrid(dx, dy);
      const s = gridVecToScreen(g.x, g.y);
      // On-screen motion is parallel to the stick (up = up on screen, right = right).
      const angStick = Math.atan2(dy, dx);
      const angMove = Math.atan2(s.y, s.x);
      expect(Math.cos(angStick - angMove)).toBeGreaterThan(0.999);
    }
  });

  it('returns unit vectors in grid space', () => {
    for (const [dx, dy] of cases) {
      const g = screenDirToGrid(dx, dy);
      expect(Math.hypot(g.x, g.y)).toBeCloseTo(1, 9);
    }
  });

  it('up on screen means decreasing gx and gy', () => {
    const g = screenDirToGrid(0, -1);
    expect(g.x).toBeLessThan(0);
    expect(g.y).toBeLessThan(0);
    expect(g.x).toBeCloseTo(g.y, 9);
  });

  it('handles the null vector', () => {
    expect(screenDirToGrid(0, 0)).toEqual({ x: 0, y: 0 });
  });
});

describe('8-direction facing', () => {
  it('classifies screen vectors', () => {
    expect(dirFromScreenVector(1, 0)).toBe('E');
    expect(dirFromScreenVector(0, -1)).toBe('N');
    expect(dirFromScreenVector(-1, 1)).toBe('SW');
    expect(dirFromScreenVector(1, -1)).toBe('NE');
    expect(dirFromScreenVector(0, 0, 'W')).toBe('W');
  });

  it('round-trips every direction through grid space', () => {
    for (const d of DIRS8) {
      const g = dirToGridVector(d);
      expect(dirFromGridVector(g.x, g.y)).toBe(d);
    }
  });

  it('mirrors east/west', () => {
    expect(mirrorDir('NE')).toBe('NW');
    expect(mirrorDir('SW')).toBe('SE');
    expect(mirrorDir('N')).toBe('N');
  });
});

describe('diamond rasterization', () => {
  it('tiles tessellate: each pixel row of the plane is covered exactly once', () => {
    // Sample a region covered by a 4x4 block of tiles and count coverage per pixel.
    const cover = new Map<string, number>();
    for (let j = 0; j < 4; j++) {
      for (let i = 0; i < 4; i++) {
        const top = gridToScreen(i, j);
        for (let y = 0; y < TH; y++) {
          for (let x = 0; x < TW; x++) {
            if (!insideDiamond(x, y)) continue;
            const key = `${top.x - TW / 2 + x},${top.y + y}`;
            cover.set(key, (cover.get(key) ?? 0) + 1);
          }
        }
      }
    }
    // Inner region (center of the block) must be covered exactly once.
    for (let y = 24; y < 40; y++) {
      for (let x = -8; x < 8; x++) expect(cover.get(`${x},${y}`)).toBe(1);
    }
  });

  it('depth key grows toward the viewer', () => {
    expect(depthKey(2, 3)).toBeGreaterThan(depthKey(1, 3));
  });
});
