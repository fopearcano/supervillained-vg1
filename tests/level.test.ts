import { describe, expect, it } from 'vitest';
import { LEVELS } from '../src/levels';
import { LevelFormatError, loadLevel, parseAsciiMap } from '../src/world/level';
import { GameMap } from '../src/world/map';
import { Ground } from '../src/world/tiles';

const tiny = ['#####', '#S.T#', '#=B,#', '#W.E#', '#####'];

describe('ASCII level parser', () => {
  it('parses ground, props and markers', () => {
    const m = parseAsciiMap(tiny);
    expect(m.width).toBe(5);
    expect(m.height).toBe(5);
    expect(m.start).toEqual({ i: 1, j: 1 });
    expect(m.exit).toEqual({ i: 3, j: 3 });
    expect(m.ground[0]).toBe(Ground.Forest);
    expect(m.ground[2 * 5 + 1]).toBe(Ground.Path);
    expect(m.ground[3 * 5 + 1]).toBe(Ground.Water);
    expect(m.ground[2 * 5 + 3]).toBe(Ground.TallGrass);
    expect(m.props.map((p) => p.kind).sort()).toEqual(['bush', 'tree']);
  });

  it('rejects unknown symbols with a position', () => {
    expect(() => parseAsciiMap(['S?E'])).toThrow(/row 0, column 1/);
  });

  it('requires exactly one start and one exit', () => {
    expect(() => parseAsciiMap(['...E'])).toThrow(LevelFormatError);
    expect(() => parseAsciiMap(['S..'])).toThrow(LevelFormatError);
    expect(() => parseAsciiMap(['SSE'])).toThrow(/Duplicate start/);
  });

  it('pads short rows with void', () => {
    const m = parseAsciiMap(['S.E', '.']);
    expect(m.width).toBe(3);
    expect(m.ground[1 * 3 + 2]).toBe(Ground.Void);
  });
});

describe('shipped levels', () => {
  for (const def of LEVELS) {
    it(`${def.id} loads and the exit is reachable from the start`, () => {
      const level = loadLevel(def);
      const map = new GameMap(level);
      const d = map.exitDistance[map.index(level.start.i, level.start.j)]!;
      expect(d).toBeGreaterThan(50);
      expect(map.playableCount).toBeGreaterThan(500);
      expect(map.progressAt(map.start.x, map.start.y)).toBe(0);
      expect(map.progressAt(map.exit.x, map.exit.y)).toBe(1);
    });
  }
});
