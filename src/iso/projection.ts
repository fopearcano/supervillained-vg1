import { ISO } from '../config';

/**
 * Isometric (2:1 diamond) projection.
 *
 * Grid space: continuous (gx, gy); tile (i, j) covers [i, i+1) x [j, j+1).
 * Screen space: logical pixels, y down. The grid origin (0,0) projects to screen (0,0),
 * which is the TOP vertex of tile (0,0).
 *
 *   sx = (gx - gy) * TW/2
 *   sy = (gx + gy) * TH/2
 */

export const TW = ISO.TILE_W;
export const TH = ISO.TILE_H;
const HALF_W = TW / 2;
const HALF_H = TH / 2;

export interface Vec2 {
  x: number;
  y: number;
}

export function gridToScreen(gx: number, gy: number): Vec2 {
  return { x: (gx - gy) * HALF_W, y: (gx + gy) * HALF_H };
}

export function screenToGrid(sx: number, sy: number): Vec2 {
  return { x: sy / TH + sx / TW, y: sy / TH - sx / TW };
}

/** Screen-space position of the center of tile (i, j). */
export function tileCenterScreen(i: number, j: number): Vec2 {
  return gridToScreen(i + 0.5, j + 0.5);
}

/**
 * Converts a direction expressed in screen space (e.g. a joystick: up = up on screen)
 * into a unit direction in grid space. Returns {0,0} for a null vector.
 */
export function screenDirToGrid(dx: number, dy: number): Vec2 {
  // Linear part of screenToGrid, with TW = 2*TH folded in up to a positive scale.
  const gx = dy + dx * (TH / TW);
  const gy = dy - dx * (TH / TW);
  const len = Math.hypot(gx, gy);
  if (len < 1e-9) return { x: 0, y: 0 };
  return { x: gx / len, y: gy / len };
}

/** Converts a grid-space vector to the screen-space vector it projects to (not normalized). */
export function gridVecToScreen(dgx: number, dgy: number): Vec2 {
  return { x: (dgx - dgy) * HALF_W, y: (dgx + dgy) * HALF_H };
}

/** Eight facing directions, expressed in SCREEN space (N = up on screen). */
export type Dir8 = 'N' | 'NE' | 'E' | 'SE' | 'S' | 'SW' | 'W' | 'NW';

/** Clockwise from East, matching atan2 with y pointing down. */
const DIRS_BY_ANGLE: readonly Dir8[] = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'];

export const DIRS8: readonly Dir8[] = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

const DIR_VECTORS: Record<Dir8, Vec2> = (() => {
  const out = {} as Record<Dir8, Vec2>;
  DIRS_BY_ANGLE.forEach((d, i) => {
    const a = (i * Math.PI) / 4;
    out[d] = { x: Math.cos(a), y: Math.sin(a) };
  });
  return out;
})();

/** Nearest of the 8 screen directions for a screen-space vector. */
export function dirFromScreenVector(dx: number, dy: number, fallback: Dir8 = 'S'): Dir8 {
  if (Math.abs(dx) < 1e-9 && Math.abs(dy) < 1e-9) return fallback;
  const a = Math.atan2(dy, dx);
  const idx = ((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8;
  return DIRS_BY_ANGLE[idx]!;
}

/** Nearest of the 8 screen directions for a grid-space vector. */
export function dirFromGridVector(dgx: number, dgy: number, fallback: Dir8 = 'S'): Dir8 {
  const s = gridVecToScreen(dgx, dgy);
  // Undo the 2:1 squash so that the angle classification is made on the "ground plane".
  return dirFromScreenVector(s.x, s.y * 2, fallback);
}

/** Unit screen-space vector of a facing direction. */
export function dirToScreenVector(d: Dir8): Vec2 {
  return DIR_VECTORS[d];
}

/** Unit grid-space vector of a facing direction (as seen on the ground plane). */
export function dirToGridVector(d: Dir8): Vec2 {
  const v = DIR_VECTORS[d];
  return screenDirToGrid(v.x, v.y);
}

/** Mirror of a direction across the vertical screen axis (E <-> W). */
export function mirrorDir(d: Dir8): Dir8 {
  switch (d) {
    case 'E':
      return 'W';
    case 'W':
      return 'E';
    case 'NE':
      return 'NW';
    case 'NW':
      return 'NE';
    case 'SE':
      return 'SW';
    case 'SW':
      return 'SE';
    default:
      return d;
  }
}

/**
 * Depth key for painter's sorting: larger = drawn later (in front).
 * Uses the contact point (feet / base) in grid space.
 */
export function depthKey(gx: number, gy: number): number {
  return gx + gy;
}

/**
 * True if the pixel (px, py) of a TW x TH tile texture lies inside the diamond
 * (sampled at pixel centers). Tiles rasterized this way tessellate without gaps or overlaps.
 */
export function insideDiamond(px: number, py: number, w = TW, h = TH): boolean {
  const cx = w / 2;
  const cy = h / 2;
  return Math.abs(px + 0.5 - cx) / cx + Math.abs(py + 0.5 - cy) / cy <= 1;
}
