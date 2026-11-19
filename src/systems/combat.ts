import { COMBAT } from '../config';

/**
 * Fight rules, pure (tested): who is in the sword's arc, what a blow or a bark does to a foe,
 * a foe's swing (wind-up, blow, cooldown), whether the shield blocks it. Nobody dies: a foe with
 * no HP left is routed (runs off). The scene side is story/combat.ts.
 */

export interface Foe {
  hp: number;
  maxHp: number;
  /** Seconds left staggered (no moving, no swinging). */
  stun: number;
  /** Seconds before the next swing may start. */
  cooldown: number;
  /** Seconds left of a raised arm (0 = not swinging). */
  windup: number;
  routed: boolean;
}

export function newFoe(hp: number = COMBAT.FOE.HP): Foe {
  return { hp, maxHp: hp, stun: 0, cooldown: COMBAT.FOE.COOLDOWN * 0.5, windup: 0, routed: false };
}

/**
 * Is the target within `range` of the origin and within `halfAngle` of the facing (fx, fy)?
 * Anything nearly on top of the origin counts as in front.
 */
export function inArc(ox: number, oy: number, fx: number, fy: number, tx: number, ty: number, range: number, halfAngle: number): boolean {
  const dx = tx - ox;
  const dy = ty - oy;
  const d = Math.hypot(dx, dy);
  if (d > range) return false;
  if (d < 0.3) return true;
  const fl = Math.hypot(fx, fy) || 1;
  return (dx * fx + dy * fy) / (d * fl) >= Math.cos(halfAngle);
}

/**
 * A sword blow lands: HP down, the swing interrupted and its cooldown spent, staggered for `stun`
 * (it replaces what was left: the blow uses up the opening it was struck in).
 * A bark (`interrupt: false`) wounds and staggers, but a swing already coming still comes.
 */
export function damageFoe(f: Foe, damage: number, stun: number, interrupt = true): 'hit' | 'routed' | 'none' {
  if (f.routed) return 'none';
  f.hp = Math.max(0, f.hp - damage);
  if (interrupt) {
    f.stun = stun;
    f.windup = 0;
    f.cooldown = COMBAT.FOE.COOLDOWN - COMBAT.FOE.RECOVER;
  } else if (f.windup <= 0) f.stun = Math.max(f.stun, stun);
  if (f.hp <= 1e-6) {
    f.routed = true;
    return 'routed';
  }
  return 'hit';
}

/** Staggered without damage (a shield bash, a blocked blow): the swing is lost, not the recovery. */
export function staggerFoe(f: Foe, stun: number): void {
  if (f.routed) return;
  f.stun = Math.max(f.stun, stun);
  f.windup = 0;
  f.cooldown = Math.max(f.cooldown, COMBAT.FOE.COOLDOWN - COMBAT.FOE.RECOVER);
}

/**
 * One step of a foe's swing, `dist` tiles from Zampanò: 'windup' when it raises its arm,
 * 'strike' when the blow comes down (the caller checks reach and the shield).
 */
export function stepFoe(f: Foe, dt: number, dist: number): 'none' | 'windup' | 'strike' {
  if (f.routed) return 'none';
  f.cooldown = Math.max(0, f.cooldown - dt);
  if (f.stun > 0) {
    f.stun = Math.max(0, f.stun - dt);
    f.windup = 0;
    return 'none';
  }
  if (f.windup > 0) {
    f.windup -= dt;
    if (f.windup > 0) return 'none';
    f.windup = 0;
    f.cooldown = COMBAT.FOE.COOLDOWN;
    return 'strike';
  }
  if (dist <= COMBAT.FOE.ATTACK_RANGE && f.cooldown <= 0) {
    f.windup = COMBAT.FOE.WINDUP;
    return 'windup';
  }
  return 'none';
}

/**
 * Open to a sword blow: staggered, mid-swing (the blow interrupts it) or just after a swing.
 * A foe who parries (FightDef.parry) takes no damage from the sword otherwise.
 */
export function isOpen(f: Foe): boolean {
  if (f.routed) return false;
  return f.stun > 0 || f.windup > 0 || f.cooldown > COMBAT.FOE.COOLDOWN - COMBAT.FOE.RECOVER;
}

/** Does the raised shield (facing fx, fy) take a blow coming from (ax, ay)? */
export function shieldBlocks(px: number, py: number, fx: number, fy: number, ax: number, ay: number): boolean {
  return inArc(px, py, fx, fy, ax, ay, Infinity, COMBAT.SHIELD.HALF_ARC);
}
