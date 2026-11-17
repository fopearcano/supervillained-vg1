import type { SpriteKey } from '../../assets/manifest';
import { STORY } from '../../config';
import { PropEntity } from '../../entities/prop';
import type { Behavior, Point } from '../../entities/actor';
import type { Step } from '../../story/step';
import type { StoryScene } from '../../story/storyScene';
import { walk, type Pickup, type PilotHint, type WalkState } from '../../story/walk';
import type { Autopilot } from '../../story/autopilot';
import { C } from '../../ui/retro';

/** Small helpers shared by the chapter scripts. */

export function at(ctx: StoryScene, ...markers: string[]): Point[] {
  return markers.map((m) => ctx.marker(m));
}

export function patrol(ctx: StoryScene, markers: string[], speed = 1.4, pause = 0.8): Behavior {
  return { kind: 'patrol', points: at(ctx, ...markers), speed, pause };
}

export function wander(ctx: StoryScene, center: string, radius: number, speed = 1): Behavior {
  return { kind: 'wander', center: ctx.marker(center), radius, speed };
}

export function near(ctx: StoryScene, name: string, radius: number): boolean {
  const a = ctx.actors.get(name);
  if (!a) return false;
  return Math.hypot(a.gx - ctx.player.gx, a.gy - ctx.player.gy) <= radius;
}

export function distTo(ctx: StoryScene, p: Point): number {
  return Math.hypot(p.x - ctx.player.gx, p.y - ctx.player.gy);
}

/** Zampanò's bark (sound, animation, popup). */
export function bark(ctx: StoryScene, text = 'WOOF!'): void {
  ctx.player.startAction('bark', 0.3);
  ctx.game.audio.play('bark');
  ctx.say(text, { x: ctx.player.gx, y: ctx.player.gy });
}

// ------------------------------------------------------------------ following someone

export interface FollowOptions {
  objective: string;
  /** Actor to follow (already on the stage). */
  leader: string;
  /** Markers the leader walks through, in order. */
  path: Array<string | Point>;
  speed?: number;
  /** Something said (or done) as the leader reaches each point. */
  onReach?: (ctx: StoryScene, index: number) => void;
  action?: string;
  onAction?: (ctx: StoryScene, w: WalkState) => void;
  pickups?: Pickup[];
  onUpdate?: (ctx: StoryScene, w: WalkState, dt: number) => void;
  caught?: 'restart' | ((ctx: StoryScene, w: WalkState) => Step[]);
  caughtText?: string;
  noRun?: boolean;
}

/**
 * He follows someone through the stage (his father into the study, Sbrimbrulon along the quay,
 * the bread seller, the bolt of cloth, the Doge's banner). The leader waits whenever Zampanò
 * falls behind; the walk ends when both have arrived.
 */
export function followLeader(o: FollowOptions): Step {
  const L = STORY.LEAD;
  let idx = 0;
  /** Path index the leader is walking to (-1: none, re-issue the order). */
  let current = -1;
  let waiting = false;
  return walk({
    objective: o.objective,
    action: o.action,
    onAction: o.onAction,
    pickups: o.pickups,
    need: 0,
    caught: o.caught,
    caughtText: o.caughtText,
    noRun: o.noRun,
    pilot: (ctx) => {
      // Stay a step behind the leader (never on top of where he is going).
      const a = ctx.actors.get(o.leader);
      if (!a) return null;
      const dx = ctx.player.gx - a.gx;
      const dy = ctx.player.gy - a.gy;
      const l = Math.hypot(dx, dy) || 1;
      return { target: { x: a.gx + (dx / l) * 1.1, y: a.gy + (dy / l) * 1.1 }, hold: l < 1.6 };
    },
    onUpdate: (ctx, w, dt) => {
      const a = ctx.actor(o.leader);
      const d = Math.hypot(a.gx - ctx.player.gx, a.gy - ctx.player.gy);
      if (idx < o.path.length) {
        const to = ctx.marker(o.path[idx]!);
        if (d > L.WAIT_DISTANCE) {
          if (!waiting) {
            waiting = true;
            current = -1;
            a.setBehavior({ kind: 'idle', face: 'player' });
          }
        } else {
          waiting = false;
          if (current !== idx) {
            current = idx;
            a.setBehavior({ kind: 'goto', to, speed: o.speed ?? L.SPEED });
          } else if (a.arrived || Math.hypot(a.gx - to.x, a.gy - to.y) < 0.5) {
            o.onReach?.(ctx, idx);
            idx++;
          }
        }
      } else if (d < L.ARRIVE) w.complete = true;
      o.onUpdate?.(ctx, w, dt);
    },
  });
}

// ------------------------------------------------------------------ acting in a lull

export interface LullOptions {
  objective: string;
  action: string;
  /** Where the noise comes from (an actor's name or a marker). */
  source: string | Point;
  /** What fills the air while nobody can be heard. */
  noise: string[];
  noiseColor?: string;
  noiseLabel?: string;
  /** Successful acts needed (one per lull). */
  need: number;
  /** Where he must stand to be heard (default: within LULL.RANGE of the source). */
  stand?: string | Point;
  range?: number;
  /** A good act: in a lull, close enough. */
  onGood: (ctx: StoryScene, w: WalkState, count: number) => void;
  /** Acting under the noise. */
  drowned?: string;
  actText?: string;
  /** Whether the autopilot acts at all (7.8: the silent player never does). */
  pilotActs?: (p: Autopilot) => boolean;
  onUpdate?: (ctx: StoryScene, w: WalkState, dt: number) => void;
}

/**
 * A voice (a preacher, trumpets, a looting crowd) fills the air, then pauses. Only what he does
 * in the pause is heard (2.3, 3.3, 7.8: "the player learns to wait for another voice").
 */
export function lullWalk(o: LullOptions): Step {
  const L = STORY.LULL;
  const rand = (r: readonly number[]) => r[0]! + Math.random() * (r[1]! - r[0]!);
  let talking = true;
  let phaseT = rand(L.TALK) * 0.6;
  let phraseT = 0;
  let k = 0;
  let good = 0;
  let usedThisLull = false;
  const sourceAt = (ctx: StoryScene): Point => {
    if (typeof o.source === 'string' && ctx.actors.has(o.source)) {
      const a = ctx.actor(o.source);
      return { x: a.gx, y: a.gy };
    }
    return ctx.marker(o.source as string | Point);
  };
  const standAt = (ctx: StoryScene): Point => (o.stand ? ctx.marker(o.stand) : sourceAt(ctx));
  const range = o.range ?? L.RANGE;
  return walk({
    objective: o.objective,
    action: o.action,
    need: 0,
    pilot: (ctx, w, p): PilotHint => {
      const s = standAt(ctx);
      const d = distTo(ctx, s);
      const acts = o.pilotActs?.(p) ?? true;
      return { target: s, hold: d < range - 0.6, act: acts && w.data.lull === true && !usedThisLull && d < range - 0.4 };
    },
    onAction: (ctx, w) => {
      if (distTo(ctx, standAt(ctx)) > range) {
        bark(ctx, 'WOOF?');
        ctx.notice('TOO FAR: NOBODY HEARS HIM', C.orange);
        return;
      }
      bark(ctx, o.actText ?? 'WOOF!');
      if (talking) {
        ctx.notice(o.drowned ?? 'LOST UNDER THE NOISE. WAIT FOR A LULL', C.orange);
        return;
      }
      if (usedThisLull) return;
      usedThisLull = true;
      good++;
      o.onGood(ctx, w, good);
    },
    onUpdate: (ctx, w, dt) => {
      phaseT -= dt;
      if (phaseT <= 0) {
        talking = !talking;
        usedThisLull = false;
        phaseT = rand(talking ? L.TALK : L.QUIET);
        phraseT = 0;
      }
      if (talking) {
        phraseT -= dt;
        if (phraseT <= 0) {
          phraseT = L.PHRASE_EVERY;
          ctx.say(o.noise[k++ % o.noise.length]!, sourceAt(ctx), o.noiseColor ?? C.orange);
        }
      }
      w.data.lull = !talking;
      ctx.hud.setMode(
        talking
          ? { label: o.noiseLabel ?? 'NOISE', value: Math.min(1, phaseT / L.TALK[1]), color: 0xff7a1f }
          : { label: 'A LULL: NOW!', value: Math.min(1, phaseT / L.QUIET[1]), color: 0x5ac8ff },
      );
      ctx.hud.setObjective(`${o.objective} (${good}/${o.need})`);
      if (good >= o.need) w.complete = true;
      o.onUpdate?.(ctx, w, dt);
    },
  });
}

// ------------------------------------------------------------------ heard, not seen

/** A sound popping up at a (moving) place every STORY.HEAR_EVERY seconds: for hidden goals. */
export function sounder(text: string, color: string = C.cyan, every: number = STORY.HEAR_EVERY) {
  let t = 0;
  return (ctx: StoryScene, where: Point, dt: number): void => {
    t -= dt;
    if (t > 0) return;
    t = every;
    ctx.say(text, where, color);
  };
}

// ------------------------------------------------------------------ objects on the stage

/** A loose object on the stage (the red ball, the water bowl, a crate): returned so it can move. */
export function placeObject(ctx: StoryScene, key: SpriteKey, where: string | Point, tint?: number): PropEntity {
  const p = ctx.marker(where);
  const e = new PropEntity(key, 0, p.x, p.y, null, false);
  if (tint !== undefined) e.sprite.tint = tint;
  ctx.world!.addEntity(e);
  return e;
}

/** The walkable tile center nearest to a point (for things that land where a script puts them). */
export function walkableNear(ctx: StoryScene, p: Point, maxR = 6): Point {
  const map = ctx.world!.map;
  const i0 = Math.floor(p.x);
  const j0 = Math.floor(p.y);
  for (let r = 0; r <= maxR; r++) {
    let best: Point | null = null;
    let bd = Infinity;
    for (let j = j0 - r; j <= j0 + r; j++) {
      for (let i = i0 - r; i <= i0 + r; i++) {
        if (Math.max(Math.abs(i - i0), Math.abs(j - j0)) !== r || !map.isWalkable(i, j)) continue;
        const d = Math.hypot(i + 0.5 - p.x, j + 0.5 - p.y);
        if (d < bd) [best, bd] = [{ x: i + 0.5, y: j + 0.5 }, d];
      }
    }
    if (best) return best;
  }
  return { x: ctx.player.gx, y: ctx.player.gy };
}
