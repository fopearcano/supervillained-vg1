import { STORY } from '../config';
import type { Action } from '../core/input';
import type { Point } from '../entities/actor';
import type { StoryScene } from './storyScene';

/**
 * Story autopilot for automated playtests (`npm run playtest`, `?auto=1`).
 *
 * It plays through the same inputs a person uses: it presses confirm on dialogue, picks choices,
 * steers the movement vector along a path (avoiding what guards can see, hostile animals and
 * fire), and each mini-game supplies its own strategy. `skill` (0..1) adds human error: timing
 * noise in rhythm games, slower tapping, late reactions to scrambled controls.
 *
 * Steps opt in with an optional `pilot(dt, ctx, pilot)` method (see Step).
 */
export interface PilotPolicy {
  /** Which option to pick in a choice: first or last available, or random. */
  choice: 'first' | 'last' | 'random';
  /** 0 = clumsy, 1 = perfect. */
  skill: number;
  /** 7.8: enforce the oath (knight) or look away (alpha). */
  ending: 'knight' | 'alpha';
  seed?: number;
}

export const DEFAULT_POLICY: PilotPolicy = { choice: 'first', skill: 0.7, ending: 'knight' };

export interface NavOptions {
  run?: boolean;
  /** Extra cost of entering a tile (Infinity = never). */
  danger?: (i: number, j: number) => number;
  /** Stop within this distance of the target. */
  arrive?: number;
  /** Current control rotation (scrambled controls), radians. */
  scramble?: number;
  /** Wait instead of stepping into a dangerous tile when standing on a safe one. */
  cautious?: boolean;
}

const DIRS = [
  [1, 0, 1],
  [-1, 0, 1],
  [0, 1, 1],
  [0, -1, 1],
  [1, 1, 1.414],
  [1, -1, 1.414],
  [-1, 1, 1.414],
  [-1, -1, 1.414],
] as const;

export class Autopilot {
  private rngState: number;
  private timers = new Map<string, number>();
  private path: number[] = [];
  private pathTarget = '';
  private repathT = 0;
  private stuckT = 0;
  private stuckFrom: Point = { x: 0, y: 0 };
  private jitterT = 0;
  private jitter: Point = { x: 0, y: 0 };
  private seenAngle = 0;
  private angleChangedAt = 0;
  private clock = 0;

  constructor(readonly policy: PilotPolicy = DEFAULT_POLICY) {
    // Spread small seeds (1, 2, 3...) over the whole state space, then warm up.
    this.rngState = (Math.imul((policy.seed ?? 12345) + 0x9e3779b9, 2654435761) ^ 0x5bd1e995) >>> 0 || 1;
    for (let k = 0; k < 8; k++) this.random();
  }

  /** Deterministic pseudo-random in [0, 1). */
  random(): number {
    let x = this.rngState;
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    this.rngState = x >>> 0;
    return this.rngState / 4294967296;
  }

  /** Gaussian noise (Box-Muller). */
  gauss(sigma: number): number {
    const u = Math.max(1e-9, this.random());
    const v = this.random();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v) * sigma;
  }

  /** Called by StoryScene before the current step updates. */
  beginStep(dt: number, ctx: StoryScene): void {
    this.clock += dt;
    for (const [k, t] of this.timers) this.timers.set(k, t - dt);
    ctx.game.input.override = { x: 0, y: 0 };
  }

  press(ctx: StoryScene, action: Action): void {
    ctx.game.input.trigger(action);
  }

  /** Presses `action` at most once every `seconds` (per key). */
  every(ctx: StoryScene, key: string, seconds: number, action: Action): boolean {
    if ((this.timers.get(key) ?? 0) > 0) return false;
    this.timers.set(key, seconds);
    this.press(ctx, action);
    return true;
  }

  /** True once every `seconds` (per key), without pressing anything. */
  tick(key: string, seconds: number): boolean {
    if ((this.timers.get(key) ?? 0) > 0) return false;
    this.timers.set(key, seconds);
    return true;
  }

  tap(ctx: StoryScene, x: number, y: number): void {
    ctx.game.input.pushTap(x, y);
  }

  private seenPrompts = new Map<string, number>();

  /** Picks an option; a prompt seen again (a loop) gets the next option this time. */
  pickFor(prompt: string, n: number): number {
    const seen = this.seenPrompts.get(prompt) ?? 0;
    this.seenPrompts.set(prompt, seen + 1);
    return (this.pickIndex(n) + seen) % Math.max(1, n);
  }

  pickIndex(n: number): number {
    if (n <= 1) return 0;
    if (this.policy.choice === 'first') return 0;
    if (this.policy.choice === 'last') return n - 1;
    return Math.floor(this.random() * n);
  }

  /** Grid-space intent → screen-space stick vector, with magnitude. */
  private stick(ctx: StoryScene, dx: number, dy: number, mag: number, scramble: number): void {
    let sx = dx - dy;
    let sy = (dx + dy) / 2;
    const l = Math.hypot(sx, sy);
    if (l < 1e-6) return;
    sx = (sx / l) * mag;
    sy = (sy / l) * mag;
    // Scrambled controls rotate the stick by +angle; a person needs a moment to notice.
    if (scramble !== this.seenAngle) {
      this.seenAngle = scramble;
      this.angleChangedAt = this.clock;
    }
    const react = 0.5 + (1 - this.policy.skill) * 1.2;
    const known = this.clock - this.angleChangedAt >= react ? scramble : 0;
    if (known) {
      const c = Math.cos(-known);
      const s = Math.sin(-known);
      [sx, sy] = [sx * c - sy * s, sx * s + sy * c];
    }
    ctx.game.input.override = { x: sx, y: sy };
  }

  /** Steers Zampanò toward `target` along a path. Returns true when there. */
  navigate(ctx: StoryScene, target: Point, o: NavOptions = {}): boolean {
    const world = ctx.world;
    if (!world) return false;
    const map = world.map;
    const p = ctx.player;
    const arrive = o.arrive ?? 0.35;
    if (Math.hypot(target.x - p.gx, target.y - p.gy) <= arrive) return true;
    const mag = o.run ? STORY.PILOT.RUN_MAG : STORY.PILOT.WALK_MAG;
    // Stuck: wiggle for a moment.
    if (this.jitterT > 0) {
      this.jitterT -= 1 / 60;
      this.stick(ctx, this.jitter.x, this.jitter.y, mag, o.scramble ?? 0);
      return false;
    }
    this.stuckT += 1 / 60;
    if (this.stuckT > STORY.PILOT.STUCK_TIME) {
      const moved = Math.hypot(p.gx - this.stuckFrom.x, p.gy - this.stuckFrom.y);
      this.stuckT = 0;
      this.stuckFrom = { x: p.gx, y: p.gy };
      if (moved < 0.3) {
        const a = this.random() * Math.PI * 2;
        this.jitter = { x: Math.cos(a), y: Math.sin(a) };
        this.jitterT = 0.6;
        this.path = [];
      }
    }
    const ti = Math.floor(target.x);
    const tj = Math.floor(target.y);
    const key = `${ti},${tj}`;
    this.repathT -= 1 / 60;
    if (key !== this.pathTarget || this.repathT <= 0 || !this.path.length) {
      this.pathTarget = key;
      this.repathT = 0.25;
      this.path = this.findPath(ctx, Math.floor(p.gx), Math.floor(p.gy), ti, tj, o.danger);
    }
    // Next waypoint: the first path tile whose center is not under us.
    let wp: Point = target;
    while (this.path.length) {
      const k = this.path[0]!;
      const i = k % map.width;
      const j = (k - i) / map.width;
      const c = { x: i + 0.5, y: j + 0.5 };
      if (Math.hypot(c.x - p.gx, c.y - p.gy) < 0.45 && this.path.length > 1) {
        this.path.shift();
        continue;
      }
      wp = this.path.length === 1 ? target : c;
      if (o.cautious && o.danger) {
        const here = o.danger(Math.floor(p.gx), Math.floor(p.gy));
        const there = o.danger(i, j);
        if (here < 1 && there >= 1) return false; // wait for the guard to look away
      }
      break;
    }
    this.stick(ctx, wp.x - p.gx, wp.y - p.gy, mag, o.scramble ?? 0);
    return false;
  }

  /** Dijkstra over walkable tiles (8-connected, no corner cutting), cost 1 + danger. */
  findPath(ctx: StoryScene, si: number, sj: number, ti: number, tj: number, danger?: (i: number, j: number) => number): number[] {
    const map = ctx.world!.map;
    const W = map.width;
    const n = W * map.height;
    if (!map.inBounds(si, sj) || !map.inBounds(ti, tj)) return [];
    const dist = new Float64Array(n).fill(Infinity);
    const prev = new Int32Array(n).fill(-1);
    const done = new Uint8Array(n);
    const memo = new Float64Array(n).fill(NaN);
    const cost = (a: number, b: number): number => {
      if (!danger) return 0;
      const k = map.index(a, b);
      if (Number.isNaN(memo[k]!)) memo[k] = danger(a, b);
      return memo[k]!;
    };
    const s = map.index(si, sj);
    const t = map.index(ti, tj);
    dist[s] = 0;
    // Small maps (≤ 72×72): a simple O(n²)-worst array scan is fast enough, kept by a bucket list.
    const open: number[] = [s];
    while (open.length) {
      let bi = 0;
      for (let k = 1; k < open.length; k++) if (dist[open[k]!]! < dist[open[bi]!]!) bi = k;
      const u = open[bi]!;
      open[bi] = open[open.length - 1]!;
      open.pop();
      if (done[u]) continue;
      done[u] = 1;
      if (u === t) break;
      const ui = u % W;
      const uj = (u - ui) / W;
      for (const [di, dj, c] of DIRS) {
        const a = ui + di;
        const b = uj + dj;
        if (!map.isWalkable(a, b)) continue;
        if (di && dj && (!map.isWalkable(ui + di, uj) || !map.isWalkable(ui, uj + dj))) continue;
        const extra = cost(a, b);
        if (extra === Infinity && map.index(a, b) !== t) continue;
        const v = map.index(a, b);
        const nd = dist[u]! + c + (extra === Infinity ? 0 : extra);
        if (nd < dist[v]!) {
          dist[v] = nd;
          prev[v] = u;
          open.push(v);
        }
      }
    }
    if (prev[t] === -1 && s !== t) return [t];
    const out: number[] = [];
    for (let k = t; k !== -1 && k !== s; k = prev[k]!) out.push(k);
    return out.reverse();
  }
}
