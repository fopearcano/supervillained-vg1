import { describe, expect, it } from 'vitest';
import { buildGreenZoneRows, LEVEL_1 } from '../src/levels/level1';
import { STORY_MAPS } from '../src/story/maps';
import { loadLevel, parseAsciiMap, type LevelData } from '../src/world/level';
import { GameMap } from '../src/world/map';
import { Ground } from '../src/world/tiles';

function reachableTiles(level: Omit<LevelData, 'def'>): { map: GameMap; distance: Int32Array } {
  const map = new GameMap(level);
  return { map, distance: map.bfs(level.start.i, level.start.j) };
}

function walkableMaterials(level: Omit<LevelData, 'def'>): Set<Ground> {
  const materials = new Set<Ground>();
  const map = new GameMap(level);
  for (let j = 0; j < map.height; j++) {
    for (let i = 0; i < map.width; i++) {
      if (map.isWalkable(i, j)) materials.add(map.groundAt(i, j));
    }
  }
  return materials;
}

describe('shipped map topology', () => {
  it('keeps player-path story markers reachable and intentional enclaves explicit', () => {
    const unreachable: string[] = [];
    for (const [key, def] of Object.entries(STORY_MAPS)) {
      const level = parseAsciiMap(def.rows, { base: def.base, requireExit: false });
      const { map, distance } = reachableTiles(level);
      expect(map.isWalkable(level.start.i, level.start.j), `${key}: start`).toBe(true);

      for (const [marker, point] of Object.entries(level.markers)) {
        expect(map.isWalkable(point.i, point.j), `${key}: marker ${marker} is blocked`).toBe(true);
        if (distance[map.index(point.i, point.j)]! < 0) unreachable.push(`${key}:${marker}`);
      }
    }
    // These markers deliberately represent actors or destinations in gated/off-deck enclaves;
    // scripts place them directly rather than asking the player to walk there.
    expect(unreachable).toEqual(['ship:5', 'ship:6', 'neighborhood:0', 'neighborhood:9']);
  });

  it('uses multiple playable materials in maps whose mechanics cross distinct terrain', () => {
    const layeredMaps = ['lawn', 'darkwood', 'venice', 'island', 'road', 'city', 'shattered', 'neighborhood'] as const;
    for (const key of layeredMaps) {
      const def = STORY_MAPS[key];
      const level = parseAsciiMap(def.rows, { base: def.base, requireExit: false });
      expect(walkableMaterials(level).size, key).toBeGreaterThanOrEqual(2);
    }
  });

  it('keeps the Green Zone long, connected, varied, and wider than a single corridor', () => {
    const generated = buildGreenZoneRows();
    expect(generated).toEqual(buildGreenZoneRows());
    expect(generated.length).toBeGreaterThanOrEqual(80);
    expect(new Set(generated.map((row) => row.length))).toEqual(new Set([generated.length]));

    const level = loadLevel(LEVEL_1);
    const map = new GameMap(level);
    const distanceFromStart = map.bfs(level.start.i, level.start.j);
    const shortest = map.exitDistance[map.index(level.start.i, level.start.j)]!;
    expect(shortest).toBeGreaterThan(100);

    let reachable = 0;
    let walkable = 0;
    let offRoute = 0;
    const materials = new Set<Ground>();
    for (let j = 0; j < map.height; j++) {
      for (let i = 0; i < map.width; i++) {
        if (map.isWalkable(i, j)) walkable++;
        const k = map.index(i, j);
        const fromStart = distanceFromStart[k]!;
        const toExit = map.exitDistance[k]!;
        if (fromStart < 0 || toExit < 0) continue;
        reachable++;
        materials.add(map.groundAt(i, j));
        // Tiles this far from every shortest route represent optional spaces and alternate loops,
        // rather than merely a two-tile-wide rendering of the main corridor.
        if (fromStart + toExit >= shortest + 10) offRoute++;
      }
    }

    expect(reachable).toBe(walkable);
    expect(materials.size).toBeGreaterThanOrEqual(4);
    expect(offRoute).toBeGreaterThan(60);
    expect(map.props.filter((prop) => prop.kind === 'fountain').length).toBeGreaterThanOrEqual(3);
  });
});
