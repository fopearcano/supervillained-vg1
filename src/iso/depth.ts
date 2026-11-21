/**
 * Painter's-algorithm ordering for isometric objects.
 *
 * Objects are sorted by the depth of their contact point (gx + gy). Ties are broken by
 * a per-object layer bias (e.g. flat decals before standing objects), then by gx, then
 * by a stable id so the order never flickers between frames.
 */

export interface Sortable {
  /** Contact point in grid space (feet / base of the object). */
  gx: number;
  gy: number;
  /** Small bias added to the depth (flat things < 0 < things on top). */
  depthBias: number;
  /** Stable unique id. */
  id: number;
}

const EPS = 1e-6;

export function compareDepth(a: Sortable, b: Sortable): number {
  const da = a.gx + a.gy + a.depthBias;
  const db = b.gx + b.gy + b.depthBias;
  if (Math.abs(da - db) > EPS) return da - db;
  if (Math.abs(a.gx - b.gx) > EPS) return a.gx - b.gx;
  return a.id - b.id;
}

/** Sorts in place (back to front) and returns the same array. */
export function sortByDepth<T extends Sortable>(items: T[]): T[] {
  return items.sort(compareDepth);
}

/** Screen-space axis-aligned rectangle. */
export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export function rectsOverlap(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

/**
 * True when `front` (a tall object) should be faded because it hides `subject`:
 * it is drawn after the subject and their screen rectangles overlap.
 */
export function occludes(front: Sortable, frontRect: Rect, subject: Sortable, subjectRect: Rect): boolean {
  return compareDepth(front, subject) > 0 && rectsOverlap(frontRect, subjectRect);
}
