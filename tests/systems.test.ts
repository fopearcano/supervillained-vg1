import { describe, expect, it } from 'vitest';
import { BLADDER, DIGESTION, ENERGY, HUNGER, SCORE, TREAT, ZONE } from '../src/config';
import { LEVEL_1 } from '../src/levels/level1';
import { Bladder, Digestion, Energy, Hunger } from '../src/systems/needs';
import { placeTreats } from '../src/systems/placement';
import { finalHealth, formatScore, formatTime, starBonus, starsFromHealth, timeBonus } from '../src/systems/scoring';
import { loadLevel } from '../src/world/level';
import { GameMap } from '../src/world/map';
import { Ground } from '../src/world/tiles';

describe('hunger', () => {
  it('drains faster when running', () => {
    const idle = new Hunger();
    const run = new Hunger();
    idle.update(10, 'idle');
    run.update(10, 'run');
    expect(run.value).toBeLessThan(idle.value);
    expect(HUNGER.START - idle.value).toBeCloseTo(HUNGER.DRAIN_IDLE * 10, 6);
  });

  it('reports starvation once', () => {
    const h = new Hunger();
    h.value = 0.5;
    expect(h.update(1, 'walk')).toBe(true);
    expect(h.update(1, 'walk')).toBe(false);
  });

  it('feeding is clamped to the max', () => {
    const h = new Hunger();
    h.feed(TREAT.HUNGER);
    expect(h.value).toBe(HUNGER.MAX);
  });
});

describe('digestion', () => {
  it('warns when full, then makes a poop due after the warning', () => {
    const d = new Digestion();
    const treatsToFill = Math.ceil(DIGESTION.MAX / TREAT.DIGESTION);
    let ev = null;
    for (let k = 0; k < treatsToFill; k++) ev = d.add(TREAT.DIGESTION);
    expect(ev).toBe('warning');
    expect(d.update(DIGESTION.WARNING_TIME - 0.1)).toBe(null);
    expect(d.update(0.2)).toBe('poop');
    expect(d.due).toBe(true);
    d.done();
    expect(d.due).toBe(false);
    expect(d.meter).toBeLessThan(DIGESTION.MAX);
  });

  it('carries overflow into a second warning', () => {
    const d = new Digestion();
    d.add(DIGESTION.MAX);
    d.add(DIGESTION.MAX);
    d.update(DIGESTION.WARNING_TIME + 0.01);
    expect(d.done()).toBe('warning');
  });
});

describe('bladder', () => {
  it('uses charges and regenerates over time', () => {
    const b = new Bladder();
    for (let k = 0; k < BLADDER.START_CHARGES; k++) expect(b.use()).toBe(true);
    expect(b.use()).toBe(false);
    b.update(BLADDER.REGEN_TIME * 0.5);
    expect(b.regenFraction).toBeCloseTo(0.5, 6);
    b.update(BLADDER.REGEN_TIME * 0.5 + 0.001);
    expect(b.charges).toBe(1);
  });

  it('drinking refills instantly with a cooldown', () => {
    const b = new Bladder();
    b.use();
    b.use();
    expect(b.drink()).toBe(true);
    expect(b.charges).toBe(b.max);
    b.use();
    expect(b.drink()).toBe(false);
    b.update(BLADDER.DRINK_COOLDOWN + 0.01);
    expect(b.drink()).toBe(true);
  });
});

describe('scoring and stars', () => {
  it('maps health to half stars', () => {
    expect(starsFromHealth(1)).toBe(5);
    expect(starsFromHealth(ZONE.HEALTH_FULL_STARS)).toBe(5);
    expect(starsFromHealth(ZONE.HEALTH_ZERO_STARS)).toBe(0);
    expect(starsFromHealth(0.2)).toBe(0);
    const mid = (ZONE.HEALTH_ZERO_STARS + ZONE.HEALTH_FULL_STARS) / 2;
    expect(starsFromHealth(mid)).toBe(2.5);
    for (let h = 0.7; h <= 1; h += 0.01) expect((starsFromHealth(h) * 2) % 1).toBe(0);
  });

  it('penalizes PEES < POOPS at the end of the level', () => {
    expect(finalHealth(0.95, 3, 3)).toBe(0.95);
    expect(finalHealth(0.95, 5, 3)).toBe(0.95);
    expect(finalHealth(0.95, 1, 3)).toBeCloseTo(0.95 - 2 * ZONE.PEE_DEFICIT_PENALTY, 9);
  });

  it('computes bonuses', () => {
    expect(timeBonus(100, 150)).toBe(50 * SCORE.TIME_BONUS_PER_SECOND);
    expect(timeBonus(200, 150)).toBe(0);
    expect(starBonus(3.5)).toBe(Math.round(3.5 * SCORE.STAR_BONUS));
  });

  it('formats like the video HUD', () => {
    expect(formatTime(34)).toBe('00:34');
    expect(formatTime(87.9)).toBe('01:27');
    expect(formatScore(42)).toBe('0042');
    expect(formatScore(5134)).toBe('5134');
  });
});

describe('treat placement', () => {
  const map = new GameMap(loadLevel(LEVEL_1));
  const treats = placeTreats(map, LEVEL_1.spawns.treats, LEVEL_1.seed);

  it('places most of the requested treats, deterministically', () => {
    expect(treats.length).toBeGreaterThanOrEqual(LEVEL_1.spawns.treats.count * 0.8);
    expect(placeTreats(map, LEVEL_1.spawns.treats, LEVEL_1.seed)).toEqual(treats);
  });

  it('keeps them on walkable land near the path, spaced out', () => {
    for (const t of treats) {
      const i = Math.floor(t.x);
      const j = Math.floor(t.y);
      expect(map.isWalkable(i, j)).toBe(true);
      expect(map.groundAt(i, j)).not.toBe(Ground.Water);
      let nearPath = false;
      const r = LEVEL_1.spawns.treats.maxOffset;
      for (let b = -r; b <= r; b++) for (let a = -r; a <= r; a++) if (map.groundAt(i + a, j + b) === Ground.Path) nearPath = true;
      expect(nearPath).toBe(true);
    }
    for (let a = 0; a < treats.length; a++)
      for (let b = a + 1; b < treats.length; b++)
        expect(Math.hypot(treats[a]!.x - treats[b]!.x, treats[a]!.y - treats[b]!.y)).toBeGreaterThanOrEqual(LEVEL_1.spawns.treats.minSpacing);
  });

  it('spreads them along the whole walk', () => {
    const progress = treats.map((t) => map.progressAt(t.x, t.y));
    expect(Math.min(...progress)).toBeLessThan(0.15);
    expect(Math.max(...progress)).toBeGreaterThan(0.85);
  });
});

describe('Energy', () => {
  it('drains while running and empties after a full sprint', () => {
    const e = new Energy();
    const sprint = ENERGY.MAX / ENERGY.DRAIN_RUN;
    let event = null;
    for (let t = 0; t < sprint + 0.1; t += 0.05) event = e.update(0.05, 'run') ?? event;
    expect(event).toBe('empty');
    expect(e.value).toBe(0);
    expect(e.canRun).toBe(false);
  });

  it('stays tired until it recovers to MIN_TO_RUN', () => {
    const e = new Energy();
    e.value = 0.5;
    expect(e.update(1, 'run')).toBe('empty');
    const needed = ENERGY.MIN_TO_RUN / ENERGY.RECOVER_IDLE;
    expect(e.update(needed * 0.9, 'idle')).toBe(null);
    expect(e.canRun).toBe(false);
    expect(e.update(needed * 0.2, 'idle')).toBe('ready');
    expect(e.canRun).toBe(true);
  });

  it('recovers faster standing than walking, slower when hungry', () => {
    const idle = new Energy();
    const walk = new Energy();
    const hungry = new Energy();
    for (const e of [idle, walk, hungry]) e.value = 10;
    hungry.recovery = ENERGY.HUNGRY_RECOVERY;
    idle.update(1, 'idle');
    walk.update(1, 'walk');
    hungry.update(1, 'idle');
    expect(idle.value).toBeGreaterThan(walk.value);
    expect(hungry.value).toBeLessThan(idle.value);
    expect(idle.value).toBeLessThanOrEqual(ENERGY.MAX);
  });
});
