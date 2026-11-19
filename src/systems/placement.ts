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
  // A canonical shortest route makes a readable breadcrumb trail even through broad plazas,
  // where sorting every same-distance path tile could put all food on a parallel lane.
  const path: Array<{ i: number; j: number; d: number }> = [];
  let ci = map.startTile.i;
  let cj = map.startTile.j;
  for (let guard = 0; guard <= map.width * map.height; guard++) {
    const d = map.exitDistance[map.index(ci, cj)]!;
    if (d < 0) break;
    if (map.groundAt(ci, cj) !== Ground.Water) path.push({ i: ci, j: cj, d });
    if (d === 0) break;
    const next = ([
      [ci + 1, cj],
      [ci - 1, cj],
      [ci, cj + 1],
      [ci, cj - 1],
    ] as const).find(([i, j]) => map.isWalkable(i, j) && map.exitDistance[map.index(i, j)] === d - 1);
    if (!next) break;
    [ci, cj] = next;
  }
  const out: Array<{ x: number; y: number }> = [];
  if (!path.length || settings.count <= 0) return out;
  const step = Math.max(1, (startDist - 4) / settings.count);
  let nextD = startDist - 3;
  while (out.length < settings.count && nextD > 1) {
    // Pick near the requested progress slice on that canonical route.
    const candidates = [...path]
      .sort((a, b) => Math.abs(a.d - nextD) - Math.abs(b.d - nextD))
      .slice(0, 28);
    let placed = false;
    for (const t of candidates) {
      for (let attempt = 0; attempt < 8; attempt++) {
        // The first attempt is visibly on the gravel; later attempts add organic side placement.
        const oi = t.i + (attempt === 0 ? 0 : rng.int(-settings.maxOffset, settings.maxOffset));
        const oj = t.j + (attempt === 0 ? 0 : rng.int(-settings.maxOffset, settings.maxOffset));
        if (!map.isWalkable(oi, oj) || map.groundAt(oi, oj) === Ground.Water) continue;
        const x = oi + rng.range(0.35, 0.65);
        const y = oj + rng.range(0.35, 0.65);
        if (out.some((p) => Math.hypot(p.x - x, p.y - y) < settings.minSpacing)) continue;
        if (Math.hypot(map.start.x - x, map.start.y - y) < 2) continue;
        out.push({ x, y });
        placed = true;
        break;
      }
      if (placed) break;
    }
    nextD -= step;
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
