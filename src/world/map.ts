import { POLLUTION, POOP } from '../config';
import type { LevelData } from './level';
import { Ground, PROP_INFO, isGroundWalkable, type PoopSurface, type PropInfo, type PropKind } from './tiles';

export interface MapProp {
  id: number;
  kind: PropKind;
  i: number;
  j: number;
  /** Grid-space center of the tile. */
  x: number;
  y: number;
  info: PropInfo;
}

export interface MoveResult {
  x: number;
  y: number;
  blocked: boolean;
}

/**
 * Runtime map: ground, props, collision queries and the per-tile pollution ("dirt") field that
 * drives zone health.
 */
export class GameMap {
  readonly width: number;
  readonly height: number;
  readonly ground: Uint8Array;
  readonly props: MapProp[] = [];
  /** Tile index -> prop index, or -1. */
  readonly propIndex: Int32Array;
  /** Pollution per tile, 0 (clean) .. 1 (fully polluted). */
  readonly dirt: Float32Array;
  /** 1 if the tile counts towards zone health. */
  readonly playable: Uint8Array;
  playableCount = 0;
  cleanCount = 0;
  /** Tiles whose dirt changed since the renderer last looked (tile indices). */
  readonly changed = new Set<number>();
  /** Tiles showing the "re-greened" highlight: tile index -> remaining seconds. */
  readonly fresh = new Map<number, number>();
  /** Steps (4-connected) from each tile to the exit; -1 if unreachable. */
  readonly exitDistance: Int32Array;
  readonly start: { x: number; y: number };
  readonly exit: { x: number; y: number };
  readonly startTile: { i: number; j: number };
  readonly exitTile: { i: number; j: number };

  constructor(level: LevelData) {
    this.width = level.width;
    this.height = level.height;
    this.ground = level.ground.slice();
    const n = this.width * this.height;
    this.propIndex = new Int32Array(n).fill(-1);
    this.dirt = new Float32Array(n);
    this.playable = new Uint8Array(n);
    level.props.forEach((p, id) => {
      const prop: MapProp = { id, kind: p.kind, i: p.i, j: p.j, x: p.i + 0.5, y: p.j + 0.5, info: PROP_INFO[p.kind] };
      this.props.push(prop);
      this.propIndex[p.j * this.width + p.i] = id;
    });
    for (let k = 0; k < n; k++) {
      const g = this.ground[k] as Ground;
      const pi = this.propIndex[k]!;
      const solidProp = pi >= 0 && this.props[pi]!.info.solid;
      if (isGroundWalkable(g) && g !== Ground.Water && !solidProp) {
        this.playable[k] = 1;
        this.playableCount++;
      }
    }
    this.cleanCount = this.playableCount;
    this.startTile = { ...level.start };
    this.exitTile = { ...level.exit };
    this.start = { x: level.start.i + 0.5, y: level.start.j + 0.5 };
    this.exit = { x: level.exit.i + 0.5, y: level.exit.j + 0.5 };
    this.exitDistance = this.bfs(level.exit.i, level.exit.j);
  }

  inBounds(i: number, j: number): boolean {
    return i >= 0 && j >= 0 && i < this.width && j < this.height;
  }

  index(i: number, j: number): number {
    return j * this.width + i;
  }

  groundAt(i: number, j: number): Ground {
    if (!this.inBounds(i, j)) return Ground.Void;
    return this.ground[j * this.width + i] as Ground;
  }

  propAt(i: number, j: number): MapProp | null {
    if (!this.inBounds(i, j)) return null;
    const pi = this.propIndex[j * this.width + i]!;
    return pi >= 0 ? this.props[pi]! : null;
  }

  /** Ground blocks movement (forest border, void, outside the map). */
  isBlockedTile(i: number, j: number): boolean {
    return !isGroundWalkable(this.groundAt(i, j));
  }

  /** A character can stand on the tile center. */
  isWalkable(i: number, j: number): boolean {
    if (this.isBlockedTile(i, j)) return false;
    const p = this.propAt(i, j);
    return !(p && p.info.solid);
  }

  /** True if a circle overlaps a blocked tile square or a solid prop. */
  circleBlocked(x: number, y: number, r: number): boolean {
    const i0 = Math.floor(x - r - 1);
    const i1 = Math.floor(x + r + 1);
    const j0 = Math.floor(y - r - 1);
    const j1 = Math.floor(y + r + 1);
    for (let j = j0; j <= j1; j++) {
      for (let i = i0; i <= i1; i++) {
        if (this.isBlockedTile(i, j)) {
          const cx = Math.max(i, Math.min(x, i + 1));
          const cy = Math.max(j, Math.min(y, j + 1));
          const dx = x - cx;
          const dy = y - cy;
          if (dx * dx + dy * dy < r * r) return true;
        } else {
          const p = this.propAt(i, j);
          if (p && p.info.solid) {
            const rr = r + p.info.radius;
            const dx = x - p.x;
            const dy = y - p.y;
            if (dx * dx + dy * dy < rr * rr) return true;
          }
        }
      }
    }
    return false;
  }

  /**
   * Moves a circle by (dx, dy) with sliding: blocked tile squares stop the motion per axis and
   * solid props (trunks, poles) push the circle out radially so it slides around them.
   */
  moveCircle(x: number, y: number, dx: number, dy: number, r: number): MoveResult {
    let blocked = false;
    let nx = x + dx;
    let ny = y + dy;
    // Radial push-out from solid props first (smooth sliding around round obstacles).
    const pushed = this.pushOutOfProps(nx, ny, r);
    if (!this.circleBlocked(pushed.x, pushed.y, r)) {
      return { x: pushed.x, y: pushed.y, blocked: pushed.moved };
    }
    // Fall back to per-axis movement against tile squares.
    nx = x + dx;
    if (this.circleBlocked(nx, y, r)) {
      nx = x;
      blocked = true;
    }
    ny = y + dy;
    if (this.circleBlocked(nx, ny, r)) {
      ny = y;
      blocked = true;
    }
    return { x: nx, y: ny, blocked };
  }

  private pushOutOfProps(x: number, y: number, r: number): { x: number; y: number; moved: boolean } {
    let moved = false;
    const i0 = Math.floor(x - r - 1);
    const i1 = Math.floor(x + r + 1);
    const j0 = Math.floor(y - r - 1);
    const j1 = Math.floor(y + r + 1);
    for (let j = j0; j <= j1; j++) {
      for (let i = i0; i <= i1; i++) {
        const p = this.propAt(i, j);
        if (!p || !p.info.solid) continue;
        const rr = r + p.info.radius;
        const dx = x - p.x;
        const dy = y - p.y;
        const d2 = dx * dx + dy * dy;
        if (d2 < rr * rr) {
          const d = Math.sqrt(d2) || 1e-4;
          x = p.x + (dx / d) * (rr + 1e-4);
          y = p.y + (dy / d) * (rr + 1e-4);
          moved = true;
        }
      }
    }
    return { x, y, moved };
  }

  /** How bad a poop is at a position: bushes/tall grass = low, path = heavy, grass = medium. */
  poopSurfaceAt(x: number, y: number): PoopSurface {
    const i = Math.floor(x);
    const j = Math.floor(y);
    const p = this.propAt(i, j);
    if (p && p.kind === 'bush') return 'low';
    const g = this.groundAt(i, j);
    if (g === Ground.TallGrass) return 'low';
    if (g === Ground.Path) return 'heavy';
    return 'medium';
  }

  poopFootprint(surface: PoopSurface): { radius: number; strength: number } {
    return surface === 'low' ? POOP.LOW : surface === 'heavy' ? POOP.HEAVY : POOP.MEDIUM;
  }

  isWaterAt(x: number, y: number): boolean {
    return this.groundAt(Math.floor(x), Math.floor(y)) === Ground.Water;
  }

  /** Nearest prop matching the predicate within maxDist (center to position). */
  nearestProp(x: number, y: number, maxDist: number, pred: (p: MapProp) => boolean): MapProp | null {
    let best: MapProp | null = null;
    let bestD = maxDist;
    const r = Math.ceil(maxDist) + 1;
    const ci = Math.floor(x);
    const cj = Math.floor(y);
    for (let j = cj - r; j <= cj + r; j++) {
      for (let i = ci - r; i <= ci + r; i++) {
        const p = this.propAt(i, j);
        if (!p || !pred(p)) continue;
        const d = Math.hypot(p.x - x, p.y - y) - p.info.radius;
        if (d <= bestD) {
          bestD = d;
          best = p;
        }
      }
    }
    return best;
  }

  /**
   * Stamps pollution around (cx, cy). Dirt never decreases here (max blend).
   * @returns number of tiles that went from clean to polluted.
   */
  stampDirt(cx: number, cy: number, radius: number, strength: number): number {
    let newlyPolluted = 0;
    this.forTilesInRadius(cx, cy, radius, (k, d) => {
      if (!this.playable[k]) return;
      const t = d / radius;
      const amount = strength * (1 - 0.55 * t * t);
      const old = this.dirt[k]!;
      if (amount <= old) return;
      this.dirt[k] = amount;
      this.changed.add(k);
      if (old < POLLUTION.CLEAN_THRESHOLD && amount >= POLLUTION.CLEAN_THRESHOLD) {
        this.cleanCount--;
        newlyPolluted++;
      }
    });
    return newlyPolluted;
  }

  /**
   * Cleans and re-greens every tile within the radius.
   * @returns number of tiles that went from polluted to clean.
   */
  clean(cx: number, cy: number, radius: number): number {
    let cleaned = 0;
    this.forTilesInRadius(cx, cy, radius, (k) => {
      if (!this.playable[k]) return;
      const old = this.dirt[k]!;
      if (old > 0) {
        if (old >= POLLUTION.CLEAN_THRESHOLD) {
          this.cleanCount++;
          cleaned++;
        }
        this.dirt[k] = 0;
        this.changed.add(k);
      }
      this.fresh.set(k, POLLUTION.FRESH_TIME);
      this.changed.add(k);
    });
    return cleaned;
  }

  /** Fraction of playable tiles that are clean (0..1). */
  health(): number {
    return this.playableCount > 0 ? this.cleanCount / this.playableCount : 1;
  }

  dirtAt(x: number, y: number): number {
    const i = Math.floor(x);
    const j = Math.floor(y);
    return this.inBounds(i, j) ? this.dirt[this.index(i, j)]! : 0;
  }

  /** Advances visual timers (fresh highlight). */
  update(dt: number): void {
    for (const [k, t] of this.fresh) {
      const nt = t - dt;
      if (nt <= 0) this.fresh.delete(k);
      else this.fresh.set(k, nt);
      this.changed.add(k);
    }
  }

  forTilesInRadius(cx: number, cy: number, radius: number, fn: (k: number, d: number, i: number, j: number) => void): void {
    const i0 = Math.max(0, Math.floor(cx - radius));
    const i1 = Math.min(this.width - 1, Math.floor(cx + radius));
    const j0 = Math.max(0, Math.floor(cy - radius));
    const j1 = Math.min(this.height - 1, Math.floor(cy + radius));
    for (let j = j0; j <= j1; j++) {
      for (let i = i0; i <= i1; i++) {
        const d = Math.hypot(i + 0.5 - cx, j + 0.5 - cy);
        if (d <= radius) fn(j * this.width + i, d, i, j);
      }
    }
  }

  /** Level progress 0 (start) .. 1 (exit) based on walking distance to the exit. */
  progressAt(x: number, y: number): number {
    const i = Math.floor(x);
    const j = Math.floor(y);
    if (!this.inBounds(i, j)) return 0;
    const d = this.exitDistance[this.index(i, j)]!;
    const d0 = this.exitDistance[this.index(this.startTile.i, this.startTile.j)]!;
    if (d < 0 || d0 <= 0) return 0;
    return Math.max(0, Math.min(1, 1 - d / d0));
  }

  /** 4-connected BFS distances over walkable tiles. */
  bfs(si: number, sj: number): Int32Array {
    const n = this.width * this.height;
    const dist = new Int32Array(n).fill(-1);
    const queue = new Int32Array(n);
    let head = 0;
    let tail = 0;
    const s = this.index(si, sj);
    dist[s] = 0;
    queue[tail++] = s;
    while (head < tail) {
      const k = queue[head++]!;
      const i = k % this.width;
      const j = (k - i) / this.width;
      const nd = dist[k]! + 1;
      const nbs = [
        [i + 1, j],
        [i - 1, j],
        [i, j + 1],
        [i, j - 1],
      ] as const;
      for (const [a, b] of nbs) {
        if (!this.isWalkable(a, b)) continue;
        const nk = this.index(a, b);
        if (dist[nk] !== -1) continue;
        dist[nk] = nd;
        queue[tail++] = nk;
      }
    }
    return dist;
  }
}
