import { describe, expect, it } from 'vitest';
import { ATTACK, BALL } from '../src/config';
import { AttackDirector, fleeDirection, inBarkCone, magnetPull } from '../src/systems/threatLogic';
import { parseAsciiMap, type LevelDef } from '../src/world/level';
import { GameMap } from '../src/world/map';

describe('bark cone', () => {
  it('hits targets in front within range', () => {
    expect(inBarkCone(0, 0, 1, 0, 2, 0, 2.8, 0.75)).toBe(true);
    expect(inBarkCone(0, 0, 1, 0, 2, 0.5, 2.8, 0.75)).toBe(true);
  });
  it('misses targets behind, to the side or too far', () => {
    expect(inBarkCone(0, 0, 1, 0, -2, 0, 2.8, 0.75)).toBe(false);
    expect(inBarkCone(0, 0, 1, 0, 0, 2, 2.8, 0.75)).toBe(false);
    expect(inBarkCone(0, 0, 1, 0, 3, 0, 2.8, 0.75)).toBe(false);
  });
  it('always hits when touching', () => {
    expect(inBarkCone(0, 0, 1, 0, -0.2, 0.1, 2.8, 0.75)).toBe(true);
  });
});

describe('ball magnet', () => {
  it('is zero outside, strongest at the ball and monotonic', () => {
    expect(magnetPull(BALL.MAGNET_RADIUS, BALL.MAGNET_RADIUS, BALL.MAGNET_STRENGTH)).toBe(0);
    expect(magnetPull(0, BALL.MAGNET_RADIUS, BALL.MAGNET_STRENGTH)).toBeCloseTo(BALL.MAGNET_STRENGTH, 9);
    let prev = Infinity;
    for (let d = 0; d < BALL.MAGNET_RADIUS; d += 0.25) {
      const p = magnetPull(d, BALL.MAGNET_RADIUS, BALL.MAGNET_STRENGTH);
      expect(p).toBeLessThanOrEqual(prev);
      prev = p;
    }
  });
  it('running escapes, walking near the ball does not', async () => {
    const { PLAYER } = await import('../src/config');
    expect(PLAYER.RUN_SPEED).toBeGreaterThan(BALL.MAGNET_STRENGTH);
    expect(magnetPull(0.6, BALL.MAGNET_RADIUS, BALL.MAGNET_STRENGTH)).toBeGreaterThan(PLAYER.WALK_SPEED);
  });
});

describe('flee direction', () => {
  const def = { id: 't' } as LevelDef;
  const map = new GameMap({ def, ...parseAsciiMap(['#########', '#S......#', '#.......#', '#.......#', '#......E#', '#########']) });
  it('runs away from the chaser', () => {
    const d = fleeDirection(map, 4.5, 2.5, 2.5, 2.5, { x: 0, y: 0 }, 0.22, () => 0.5);
    expect(d.x).toBeGreaterThan(0.5);
  });
  it('avoids walls', () => {
    const d = fleeDirection(map, 7.4, 2.5, 5.5, 2.5, { x: 1, y: 0 }, 0.22, () => 0.5);
    expect(map.circleBlocked(7.4 + d.x * 0.6, 2.5 + d.y * 0.6, 0.22)).toBe(false);
  });
});

describe('attack director', () => {
  it('starts when health drops below the threshold and ends only after the pug left and health recovered', () => {
    const a = new AttackDirector(ATTACK.HEALTH_THRESHOLD, null);
    expect(a.update(1, 1, 0, true)).toBe(null);
    expect(a.update(1, ATTACK.HEALTH_THRESHOLD - 0.01, 0, true)).toBe('start');
    expect(a.intensity(ATTACK.HEALTH_THRESHOLD - 0.01)).toBeGreaterThan(ATTACK.BASE_INTENSITY);
    // Pug still around → keeps going even if healthy.
    expect(a.update(1, 1, 0, false)).toBe(null);
    // Pug gone but zone still sick → keeps going.
    expect(a.update(1, ATTACK.HEALTH_THRESHOLD - 0.02, 0, true)).toBe(null);
    expect(a.update(1, 1, 0, true)).toBe('end');
    expect(a.intensity(0.5)).toBe(0);
  });

  it('respects the cooldown', () => {
    const a = new AttackDirector(0.95, null);
    a.update(1, 0.9, 0, true);
    a.update(1, 1, 0, true);
    expect(a.update(1, 0.9, 0, true)).toBe(null);
    expect(a.update(ATTACK.COOLDOWN - 2, 0.9, 0, true)).toBe(null);
    expect(a.update(1.5, 0.9, 0, true)).toBe('start');
  });

  it('fires the scripted attack once', () => {
    const a = new AttackDirector(0.95, 0.5);
    expect(a.update(1, 1, 0.4, true)).toBe(null);
    expect(a.update(1, 1, 0.55, true)).toBe('start');
    expect(a.update(1, 1, 0.6, true)).toBe('end');
    expect(a.update(ATTACK.COOLDOWN + 1, 1, 0.8, true)).toBe(null);
  });

  it('intensity grows with the deficit', () => {
    const a = new AttackDirector(0.95, null);
    a.update(1, 0.9, 0, false);
    expect(a.intensity(0.95)).toBeCloseTo(ATTACK.BASE_INTENSITY, 9);
    expect(a.intensity(0.95 - ATTACK.FULL_INTENSITY_DEFICIT)).toBeCloseTo(1, 9);
  });
});
