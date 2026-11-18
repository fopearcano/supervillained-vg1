import { describe, expect, it } from 'vitest';
import { DIGESTION, HUNGER, PLAYER, TREAT } from '../src/config';
import { LEVEL_1 } from '../src/levels/level1';
import { Hunger } from '../src/systems/needs';
import { placeTreats } from '../src/systems/placement';
import { loadLevel } from '../src/world/level';
import { GameMap } from '../src/world/map';

/**
 * Balancing sanity check: a simple bot walks Level 1 from S to E at walking speed, following the
 * BFS gradient to the exit and detouring to treats within `greed` tiles.
 */
function simulate(greed: number) {
  const map = new GameMap(loadLevel(LEVEL_1));
  const treats = placeTreats(map, LEVEL_1.spawns.treats, LEVEL_1.seed);
  const hunger = new Hunger();
  let x = map.start.x;
  let y = map.start.y;
  let t = 0;
  let eaten = 0;
  let minHunger: number = HUNGER.MAX;
  const dt = 0.05;
  while (t < 400) {
    if (Math.hypot(x - map.exit.x, y - map.exit.y) < 0.8) break;
    let tx: number;
    let ty: number;
    const near = treats.filter((p) => Math.hypot(p.x - x, p.y - y) < greed).sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];
    if (near) {
      tx = near.x;
      ty = near.y;
    } else {
      const i = Math.floor(x);
      const j = Math.floor(y);
      const here = map.exitDistance[map.index(i, j)]!;
      let best = { i, j, d: here < 0 ? Infinity : here };
      for (const [a, b] of [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ] as const) {
        if (!map.isWalkable(i + a, j + b)) continue;
        const d = map.exitDistance[map.index(i + a, j + b)]!;
        if (d >= 0 && d < best.d) best = { i: i + a, j: j + b, d };
      }
      tx = best.i + 0.5;
      ty = best.j + 0.5;
    }
    const dx = tx - x;
    const dy = ty - y;
    const len = Math.hypot(dx, dy);
    const step = Math.min(len, PLAYER.WALK_SPEED * dt);
    if (len > 1e-6) {
      x += (dx / len) * step;
      y += (dy / len) * step;
    }
    for (let k = treats.length - 1; k >= 0; k--) {
      if (Math.hypot(treats[k]!.x - x, treats[k]!.y - y) < TREAT.PICKUP_RADIUS) {
        treats.splice(k, 1);
        hunger.feed(TREAT.HUNGER);
        eaten++;
      }
    }
    hunger.update(dt, 'walk');
    minHunger = Math.min(minHunger, hunger.value);
    t += dt;
  }
  return { time: t, eaten, minHunger, poops: Math.floor((eaten * TREAT.DIGESTION) / DIGESTION.MAX) };
}

describe('level 1 balance (bot)', () => {
  it('the shortest walk takes most of a minute, and not eating at all is not viable', () => {
    const r = simulate(0);
    // Most of a minute even at the faster walk (3.9 tiles/s); hunger per tile stays the same.
    expect(r.time).toBeGreaterThan(40);
    expect(r.time).toBeLessThan(110);
    expect(HUNGER.START - HUNGER.DRAIN_WALK * r.time).toBeLessThan(0);
  });

  it('eating treats along the way keeps Zampanò alive, at the cost of a few poops', () => {
    const r = simulate(2.5);
    expect(r.minHunger).toBeGreaterThan(0);
    expect(r.eaten).toBeGreaterThanOrEqual(4);
    expect(r.poops).toBeGreaterThanOrEqual(1);
    expect(r.poops).toBeLessThanOrEqual(8);
    expect(r.time).toBeLessThan(LEVEL_1.parTime);
  });
});
