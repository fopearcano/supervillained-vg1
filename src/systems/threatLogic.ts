import { ATTACK } from '../config';
import type { GameMap } from '../world/map';

/**
 * Pure helpers for the threats & bonuses (no rendering), unit-tested.
 */

/** True if `target` is inside the bark cone (range + half-angle around the facing direction). */
export function inBarkCone(
  px: number,
  py: number,
  facingX: number,
  facingY: number,
  tx: number,
  ty: number,
  range: number,
  halfAngle: number,
): boolean {
  const dx = tx - px;
  const dy = ty - py;
  const d = Math.hypot(dx, dy);
  if (d > range) return false;
  if (d < 0.35) return true; // touching: always hit
  const fl = Math.hypot(facingX, facingY) || 1;
  const cos = (dx * facingX + dy * facingY) / (d * fl);
  return cos >= Math.cos(halfAngle);
}

/**
 * Ball magnet: pull speed (tiles/s) toward the ball at distance d.
 * Zero outside the radius, strongest at the ball.
 */
export function magnetPull(d: number, radius: number, strength: number): number {
  if (d >= radius) return 0;
  const t = 1 - d / radius;
  return strength * Math.pow(t, 0.6);
}

/**
 * Picks a flee direction for a critter at (x, y) running from (fromX, fromY): samples 16
 * directions, prefers moving away, keeps momentum and avoids blocked tiles a bit ahead.
 * Returns a unit grid vector, or {0,0} if cornered.
 */
export function fleeDirection(
  map: GameMap,
  x: number,
  y: number,
  fromX: number,
  fromY: number,
  current: { x: number; y: number },
  radius: number,
  random: () => number,
): { x: number; y: number } {
  let best = { x: 0, y: 0 };
  let bestScore = -Infinity;
  const d0 = Math.hypot(x - fromX, y - fromY);
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * Math.PI * 2;
    const dx = Math.cos(a);
    const dy = Math.sin(a);
    if (map.circleBlocked(x + dx * 0.6, y + dy * 0.6, radius) || map.circleBlocked(x + dx * 1.3, y + dy * 1.3, radius)) continue;
    const far = Math.hypot(x + dx * 2 - fromX, y + dy * 2 - fromY) - d0;
    const momentum = dx * current.x + dy * current.y;
    // Look further ahead: open space is better than a dead end.
    const open = map.circleBlocked(x + dx * 2.4, y + dy * 2.4, radius) ? -0.8 : 0;
    const score = far + momentum * 0.6 + open + random() * 0.4;
    if (score > bestScore) {
      bestScore = score;
      best = { x: dx, y: dy };
    }
  }
  return best;
}

export type AttackSignal = 'start' | 'end' | null;

/**
 * Decides when the "GREEN ZONE UNDER ATTACK" event starts and ends.
 * Starts when zone health drops below the threshold, or once at a scripted progress point.
 * Ends when Bagnaskiz has fled AND health is back above the threshold (with hysteresis).
 */
export class AttackDirector {
  state: 'calm' | 'attack' = 'calm';
  private cooldown = 0;
  private scriptedDone = false;
  /** Seconds since the attack started. */
  elapsed = 0;

  constructor(
    readonly threshold: number = ATTACK.HEALTH_THRESHOLD,
    readonly scriptedProgress: number | null = null,
  ) {}

  update(dt: number, health: number, progress: number, pugGone: boolean): AttackSignal {
    if (this.state === 'calm') {
      if (this.cooldown > 0) this.cooldown -= dt;
      const scripted = this.scriptedProgress !== null && !this.scriptedDone && progress >= this.scriptedProgress;
      const unhealthy = health < this.threshold && this.cooldown <= 0;
      if (scripted || unhealthy) {
        if (scripted) this.scriptedDone = true;
        this.state = 'attack';
        this.elapsed = 0;
        return 'start';
      }
      return null;
    }
    this.elapsed += dt;
    if (pugGone && health >= this.threshold + ATTACK.HYSTERESIS) {
      this.state = 'calm';
      this.cooldown = ATTACK.COOLDOWN;
      return 'end';
    }
    return null;
  }

  /** 0..1 strength of the visual effects for a given health. */
  intensity(health: number): number {
    if (this.state !== 'attack') return 0;
    const deficit = Math.max(0, this.threshold - health) / ATTACK.FULL_INTENSITY_DEFICIT;
    return Math.min(1, ATTACK.BASE_INTENSITY + (1 - ATTACK.BASE_INTENSITY) * deficit);
  }
}
