import { describe, expect, it } from 'vitest';
import { POLLUTION } from '../src/config';
import { parseAsciiMap, type LevelDef } from '../src/world/level';
import { GameMap } from '../src/world/map';

function mapOf(rows: string[]): GameMap {
  const def = { id: 't' } as LevelDef;
  return new GameMap({ def, ...parseAsciiMap(rows) });
}

const rows = ['##########', '#S.......#', '#........#', '#...T....#', '#........#', '#=====...#', '#,,,B...E#', '##########'];

describe('collision', () => {
  it('blocks the forest border', () => {
    const m = mapOf(rows);
    expect(m.circleBlocked(1.1, 1.5, 0.25)).toBe(true);
    expect(m.circleBlocked(1.5, 1.5, 0.25)).toBe(false);
  });

  it('slides along walls instead of stopping', () => {
    const m = mapOf(rows);
    // Moving diagonally into the top wall keeps the x motion.
    const r = m.moveCircle(3.5, 1.3, 0.1, -0.1, 0.25);
    expect(r.x).toBeGreaterThan(3.5);
    expect(r.y).toBeGreaterThanOrEqual(1.25);
  });

  it('pushes out of tree trunks', () => {
    const m = mapOf(rows);
    const r = m.moveCircle(4.5, 2.95, 0, 0.3, 0.25);
    expect(Math.hypot(r.x - 4.5, r.y - 3.5)).toBeGreaterThanOrEqual(0.25 + 0.32 - 1e-6);
  });

  it('bushes are walkable', () => {
    const m = mapOf(rows);
    expect(m.isWalkable(4, 6)).toBe(true);
    expect(m.isWalkable(4, 3)).toBe(false);
  });
});

describe('pollution and zone health', () => {
  it('starts fully clean', () => {
    const m = mapOf(rows);
    expect(m.health()).toBe(1);
    expect(m.playableCount).toBeGreaterThan(30);
  });

  it('stamping pollutes tiles and lowers health; cleaning restores it', () => {
    const m = mapOf(rows);
    const n = m.stampDirt(3.5, 2.5, 1.6, 1);
    expect(n).toBeGreaterThan(3);
    expect(m.health()).toBeCloseTo((m.playableCount - n) / m.playableCount, 9);
    expect(m.dirtAt(3.5, 2.5)).toBeGreaterThanOrEqual(POLLUTION.CLEAN_THRESHOLD);
    const cleaned = m.clean(3.5, 2.5, 2.2);
    expect(cleaned).toBe(n);
    expect(m.health()).toBe(1);
    expect(m.fresh.size).toBeGreaterThan(0);
  });

  it('never counts a tile twice', () => {
    const m = mapOf(rows);
    const a = m.stampDirt(3.5, 2.5, 1.6, 1);
    const b = m.stampDirt(3.5, 2.5, 1.6, 1);
    expect(b).toBe(0);
    expect(m.cleanCount).toBe(m.playableCount - a);
  });

  it('classifies poop surfaces', () => {
    const m = mapOf(rows);
    expect(m.poopSurfaceAt(2.5, 5.5)).toBe('heavy');
    expect(m.poopSurfaceAt(1.5, 6.5)).toBe('low');
    expect(m.poopSurfaceAt(4.5, 6.5)).toBe('low');
    expect(m.poopSurfaceAt(6.5, 2.5)).toBe('medium');
  });
});
