import { Container, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { hash2 } from '../core/rng';
import { POLLUTION } from '../config';
import { TILE_VARIANTS } from '../assets/manifest';
import { TH, TW, gridToScreen } from '../iso/projection';
import type { Rect } from '../iso/depth';
import type { GameMap } from './map';
import { Ground } from './tiles';

const CHUNK = 8;

interface Chunk {
  container: Container;
  overlays: Container;
  bounds: Rect;
}

interface TileOverlay {
  dirt: Sprite | null;
  fresh: Sprite | null;
}

/**
 * Draws the ground: chunked tile sprites (culled per chunk), pollution overlays and the
 * "re-greened" highlight. Reads `map.changed` every frame to update only what changed.
 */
export class MapRenderer {
  readonly root = new Container();
  private readonly chunks: Chunk[] = [];
  private readonly chunkOf: Int32Array;
  private readonly base: (Sprite | null)[];
  private readonly overlays = new Map<number, TileOverlay>();
  private readonly water: Sprite[] = [];
  private readonly deep: Sprite[] = [];
  private waterTime = 0;
  /** Map bounds in screen space. */
  readonly bounds: Rect;

  constructor(private readonly map: GameMap) {
    const n = map.width * map.height;
    this.chunkOf = new Int32Array(n).fill(-1);
    this.base = new Array(n).fill(null);
    const cw = Math.ceil(map.width / CHUNK);
    const ch = Math.ceil(map.height / CHUNK);
    // Chunks in back-to-front order (by cx + cy).
    const order: Array<[number, number]> = [];
    for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) order.push([cx, cy]);
    order.sort((a, b) => a[0] + a[1] - (b[0] + b[1]) || a[0] - b[0]);
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    for (const [cx, cy] of order) {
      const container = new Container();
      const overlays = new Container();
      const tiles: Array<[number, number]> = [];
      for (let j = cy * CHUNK; j < Math.min(map.height, (cy + 1) * CHUNK); j++) {
        for (let i = cx * CHUNK; i < Math.min(map.width, (cx + 1) * CHUNK); i++) tiles.push([i, j]);
      }
      tiles.sort((a, b) => a[0] + a[1] - (b[0] + b[1]));
      let bx0 = Infinity;
      let by0 = Infinity;
      let bx1 = -Infinity;
      let by1 = -Infinity;
      for (const [i, j] of tiles) {
        const sprite = this.makeTile(i, j);
        if (!sprite) continue;
        container.addChild(sprite);
        const k = map.index(i, j);
        this.base[k] = sprite;
        this.chunkOf[k] = this.chunks.length;
        const top = gridToScreen(i, j);
        bx0 = Math.min(bx0, top.x - TW / 2);
        bx1 = Math.max(bx1, top.x + TW / 2);
        by0 = Math.min(by0, top.y - 6);
        by1 = Math.max(by1, top.y + TH);
      }
      container.addChild(overlays);
      if (container.children.length > 1) {
        this.root.addChild(container);
        const bounds = { x: bx0, y: by0, w: bx1 - bx0, h: by1 - by0 };
        this.chunks.push({ container, overlays, bounds });
        minX = Math.min(minX, bx0);
        minY = Math.min(minY, by0);
        maxX = Math.max(maxX, bx1);
        maxY = Math.max(maxY, by1);
      } else {
        container.destroy();
      }
    }
    this.bounds = { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
  }

  private makeTile(i: number, j: number): Sprite | null {
    const g = this.map.groundAt(i, j);
    const h = hash2(i, j, 1);
    let name: string;
    switch (g) {
      case Ground.Void:
        return null;
      case Ground.Grass:
        name = `grass_${h < 0.1 ? 3 : Math.floor(hash2(j, i, 2) * 3)}`;
        break;
      case Ground.TallGrass:
        name = `tallGrass_${Math.floor(h * TILE_VARIANTS.tallGrass)}`;
        break;
      case Ground.Path: {
        const notPath = (a: number, b: number) => this.map.groundAt(a, b) !== Ground.Path;
        const mask = (notPath(i, j - 1) ? 1 : 0) | (notPath(i + 1, j) ? 2 : 0) | (notPath(i, j + 1) ? 4 : 0) | (notPath(i - 1, j) ? 8 : 0);
        name = `path_${mask}_${Math.floor(h * TILE_VARIANTS.path)}`;
        break;
      }
      case Ground.Water:
        name = 'water_0';
        break;
      case Ground.Forest:
        name = `forest_${Math.floor(h * TILE_VARIANTS.forest)}`;
        break;
      case Ground.Floor:
        name = `floor_${Math.floor(h * 3)}`;
        break;
      case Ground.Stone:
        name = `stone_${Math.floor(h * 3)}`;
        break;
      case Ground.Sand:
        name = `sand_${Math.floor(h * 3)}`;
        break;
      case Ground.Snow:
        name = `snow_${Math.floor(h * 3)}`;
        break;
      case Ground.Deep:
        name = 'deep_0';
        break;
      case Ground.Dock:
        name = `dock_${Math.floor(h * 3)}`;
        break;
      case Ground.Carpet:
        name = `carpet_${Math.floor(h * 3)}`;
        break;
      case Ground.Wall:
        name = 'wallBase_0';
        break;
      default:
        return null;
    }
    const s = new Sprite(textures.get(name));
    const p = gridToScreen(i, j);
    s.position.set(p.x, p.y);
    if (g === Ground.Water) this.water.push(s);
    if (g === Ground.Deep) this.deep.push(s);
    return s;
  }

  /** Culls chunks outside the view and applies pollution changes. */
  update(dt: number, view: Rect): void {
    for (const c of this.chunks) {
      const b = c.bounds;
      c.container.visible = b.x < view.x + view.w && b.x + b.w > view.x && b.y < view.y + view.h && b.y + b.h > view.y;
    }
    this.waterTime += dt;
    const wf = Math.floor(this.waterTime / 0.6) % 2;
    const wt = textures.get(`water_${wf}`);
    for (const s of this.water) if (s.texture !== wt) s.texture = wt;
    const dt2 = textures.get(`deep_${Math.floor(this.waterTime / 0.8) % 2}`);
    for (const s of this.deep) if (s.texture !== dt2) s.texture = dt2;

    if (this.map.changed.size) {
      for (const k of this.map.changed) this.refreshTile(k);
      this.map.changed.clear();
    }
  }

  private refreshTile(k: number): void {
    const chunkIdx = this.chunkOf[k]!;
    const baseSprite = this.base[k];
    if (chunkIdx < 0 || !baseSprite) return;
    const chunk = this.chunks[chunkIdx]!;
    const dirt = this.map.dirt[k]!;
    const freshT = this.map.fresh.get(k) ?? 0;
    let ov = this.overlays.get(k);
    if (!ov) {
      ov = { dirt: null, fresh: null };
      this.overlays.set(k, ov);
    }
    // Dead-grass tint on the base tile + blotchy brown overlay.
    const t = Math.min(1, dirt * 1.3);
    baseSprite.tint = lerpColor(0xffffff, 0xb0784a, t);
    if (dirt > POLLUTION.VISIBLE) {
      if (!ov.dirt) {
        const i = k % this.map.width;
        const j = (k - i) / this.map.width;
        ov.dirt = new Sprite(textures.get(`dirt_${Math.floor(hash2(i, j, 9) * TILE_VARIANTS.dirt)}`));
        ov.dirt.position.copyFrom(baseSprite.position);
        chunk.overlays.addChild(ov.dirt);
      }
      ov.dirt.alpha = POLLUTION.OVERLAY_MIN_ALPHA + (POLLUTION.OVERLAY_MAX_ALPHA - POLLUTION.OVERLAY_MIN_ALPHA) * dirt;
    } else if (ov.dirt) {
      ov.dirt.destroy();
      ov.dirt = null;
    }
    if (freshT > 0) {
      if (!ov.fresh) {
        ov.fresh = new Sprite(textures.get('fresh_0'));
        ov.fresh.position.copyFrom(baseSprite.position);
        chunk.overlays.addChild(ov.fresh);
      }
      ov.fresh.alpha = 0.85 * Math.min(1, freshT / POLLUTION.FRESH_TIME) ** 1.5;
    } else if (ov.fresh) {
      ov.fresh.destroy();
      ov.fresh = null;
    }
    if (!ov.dirt && !ov.fresh) this.overlays.delete(k);
  }
}

function lerpColor(a: number, b: number, t: number): number {
  const ar = (a >> 16) & 255;
  const ag = (a >> 8) & 255;
  const ab = a & 255;
  const br = (b >> 16) & 255;
  const bg = (b >> 8) & 255;
  const bb = b & 255;
  return (
    (Math.round(ar + (br - ar) * t) << 16) | (Math.round(ag + (bg - ag) * t) << 8) | Math.round(ab + (bb - ab) * t)
  );
}
