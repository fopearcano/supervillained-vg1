import { Rng } from '../core/rng';
import type { SpawnSettings } from '../world/level';
import type { GameMap } from '../world/map';
import { Ground } from '../world/tiles';

/**
 * Deterministic treat placement: walk along the path from start to exit and drop treats at
 * regular intervals, offset sideways onto free tiles near the path.
 */
export function placeTreats(map: GameMap, settings: SpawnSettings['treats'], seed: number): Array<{ x: number; y: number }> {
  const rng = new Rng(seed);
  const startDist = map.exitDistance[map.index(map.startTile.i, map.startTile.j)]!;
  // Path tiles ordered from start to exit.
  const path: Array<{ i: number; j: number; d: number }> = [];
  for (let j = 0; j < map.height; j++) {
    for (let i = 0; i < map.width; i++) {
      if (map.groundAt(i, j) !== Ground.Path) continue;
      const d = map.exitDistance[map.index(i, j)]!;
      if (d >= 0) path.push({ i, j, d });
    }
  }
  path.sort((a, b) => b.d - a.d);
  const out: Array<{ x: number; y: number }> = [];
  if (!path.length || settings.count <= 0) return out;
  const step = Math.max(1, (startDist - 4) / settings.count);
  let nextD = startDist - 3;
  for (const t of path) {
    if (out.length >= settings.count) break;
    if (t.d > nextD) continue;
    // Try a few candidate spots around this path tile.
    for (let attempt = 0; attempt < 12; attempt++) {
      const oi = t.i + rng.int(-settings.maxOffset, settings.maxOffset);
      const oj = t.j + rng.int(-settings.maxOffset, settings.maxOffset);
      if (!map.isWalkable(oi, oj)) continue;
      if (map.groundAt(oi, oj) === Ground.Water) continue;
      const x = oi + rng.range(0.3, 0.7);
      const y = oj + rng.range(0.3, 0.7);
      if (out.some((p) => Math.hypot(p.x - x, p.y - y) < settings.minSpacing)) continue;
      if (Math.hypot(map.start.x - x, map.start.y - y) < 2) continue;
      out.push({ x, y });
      nextD = t.d - step;
      break;
    }
  }
  return out;
}

/** Random walkable spot at a distance in [minD, maxD] from (x, y), or null. */
export function randomSpotNear(
  map: GameMap,
  x: number,
  y: number,
  minD: number,
  maxD: number,
  rng: Rng,
  accept: (i: number, j: number) => boolean = () => true,
): { x: number; y: number } | null {
  for (let attempt = 0; attempt < 40; attempt++) {
    const a = rng.range(0, Math.PI * 2);
    const d = rng.range(minD, maxD);
    const px = x + Math.cos(a) * d;
    const py = y + Math.sin(a) * d;
    const i = Math.floor(px);
    const j = Math.floor(py);
    if (!map.isWalkable(i, j) || !accept(i, j)) continue;
    if (map.groundAt(i, j) === Ground.Water) continue;
    return { x: i + 0.5, y: j + 0.5 };
  }
  return null;
}
