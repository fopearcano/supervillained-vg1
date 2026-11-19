import { Container } from 'pixi.js';
import { buildLevelTextures } from '../assets/build';
import type { PlayableCharacterKey, SpriteKey } from '../assets/manifest';
import { OCCLUSION } from '../config';
import { hash2 } from '../core/rng';
import type { Entity } from '../entities/entity';
import { PropEntity } from '../entities/prop';
import { Zampano } from '../entities/zampano';
import { Camera } from '../iso/camera';
import { compareDepth, occludes, rectsOverlap, type Rect } from '../iso/depth';
import { gridToScreen, gridVecToScreen } from '../iso/projection';
import type { LevelData, Palette } from './level';
import { GameMap } from './map';
import { MapRenderer } from './mapRenderer';
import { Ground, PROP_SPRITE, type PropKind } from './tiles';

export interface WorldOptions {
  /** Decorative trees on forest border tiles. */
  forest?: boolean;
  /** Player-ready dog skin; the campaign currently selects Zampanò's costumes. */
  playerSkin?: PlayableCharacterKey;
}

/**
 * A playable isometric world: map + ground renderer + depth-sorted entities + camera.
 * Shared by the arcade level (GameScene) and every story sub-level (StoryScene).
 */
export class World {
  readonly root = new Container();
  readonly decalLayer = new Container();
  readonly objectLayer = new Container();
  readonly fxLayer = new Container();
  readonly map: GameMap;
  readonly mapRenderer: MapRenderer;
  readonly camera = new Camera();
  readonly entities: Entity[] = [];
  readonly player: Zampano;
  /** Entity the camera follows (default: Zampanò). */
  cameraTarget: Entity | null = null;
  /** Extra vertical camera offset (px). */
  cameraLift = 10;

  constructor(
    readonly level: LevelData,
    readonly palette: Palette,
    opts: WorldOptions = {},
  ) {
    buildLevelTextures(palette);
    this.map = new GameMap(level);
    this.mapRenderer = new MapRenderer(this.map);
    this.objectLayer.sortableChildren = true;
    this.root.addChild(this.mapRenderer.root, this.decalLayer, this.objectLayer, this.fxLayer);

    for (const p of this.map.props) {
      const sprite = PROP_SPRITE[p.kind];
      const v = Math.floor(hash2(p.i, p.j, 3) * sprite.variants);
      const e = new PropEntity(sprite.key as SpriteKey, v, p.x, p.y, p, p.info.tall);
      if (p.kind === 'bush' || p.kind === 'vine') e.depthBias = 0.1;
      this.addEntity(e);
    }
    this.spawnWallBlocks();
    if (opts.forest !== false) this.spawnForest();

    this.player = new Zampano(this.map.start.x, this.map.start.y, opts.playerSkin ?? 'zampano');
    this.player.face('N');
    this.addEntity(this.player);
    this.camera.bounds = this.walkableBounds(4);
  }

  addEntity(e: Entity): void {
    this.entities.push(e);
    this.objectLayer.addChild(e.view);
  }

  removeEntity(e: Entity): void {
    const i = this.entities.indexOf(e);
    if (i >= 0) this.entities.splice(i, 1);
    e.destroy();
  }

  /** Screen-space bounds of the walkable area, grown by `marginTiles`. */
  walkableBounds(marginTiles: number): Rect {
    let x0 = Infinity;
    let y0 = Infinity;
    let x1 = -Infinity;
    let y1 = -Infinity;
    const m = this.map;
    for (let j = 0; j < m.height; j++) {
      for (let i = 0; i < m.width; i++) {
        if (!m.isWalkable(i, j)) continue;
        const c = gridToScreen(i + 0.5, j + 0.5);
        x0 = Math.min(x0, c.x);
        x1 = Math.max(x1, c.x);
        y0 = Math.min(y0, c.y);
        y1 = Math.max(y1, c.y);
      }
    }
    const mx = marginTiles * 16;
    const my = marginTiles * 8;
    const b = this.mapRenderer.bounds;
    const x = Math.max(b.x, x0 - mx);
    const y = Math.max(b.y, y0 - my - 40);
    return { x, y, w: Math.min(b.x + b.w, x1 + mx) - x, h: Math.min(b.y + b.h, y1 + my + 40) - y };
  }

  /** Decorative trees on forest tiles near the playable area (and a few deeper ones). */
  private spawnForest(): void {
    const m = this.map;
    for (let j = 0; j < m.height; j++) {
      for (let i = 0; i < m.width; i++) {
        if (m.groundAt(i, j) !== Ground.Forest) continue;
        let near = false;
        for (let b = -2; b <= 2 && !near; b++) for (let a = -2; a <= 2 && !near; a++) if (m.isWalkable(i + a, j + b)) near = true;
        const h = hash2(i, j, 21);
        if ((near && h < 0.42) || (!near && h < 0.05)) {
          this.addEntity(new PropEntity('forestTree', hash2(i, j, 22) < 0.5 ? 0 : 1, i + 0.5, j + 0.5, null, true));
        }
      }
    }
  }

  /** Wall tiles are drawn as depth-sorted blocks (only those next to walkable ground). */
  private spawnWallBlocks(): void {
    const m = this.map;
    for (let j = 0; j < m.height; j++) {
      for (let i = 0; i < m.width; i++) {
        if (m.groundAt(i, j) !== Ground.Wall) continue;
        let near = false;
        for (let b = -2; b <= 2 && !near; b++) for (let a = -2; a <= 2 && !near; a++) if (m.isWalkable(i + a, j + b)) near = true;
        if (!near) continue;
        const e = new PropEntity('wallBlock', Math.floor(hash2(i, j, 5) * 2), i + 0.5, j + 0.5, null, true);
        this.addEntity(e);
      }
    }
  }

  snapCamera(): void {
    const t = this.cameraTarget ?? this.player;
    const s = gridToScreen(t.gx, t.gy);
    this.camera.snapTo(s.x, s.y - this.cameraLift);
  }

  /** Call at the start of every logic step. */
  beginStep(): void {
    for (const e of this.entities) e.savePrev();
  }

  /** Updates non-player entities, the pollution field and the camera. */
  endStep(dt: number): void {
    for (const e of this.entities) if (e !== this.player) e.update(dt);
    this.map.update(dt);
    const t = this.cameraTarget ?? this.player;
    const ps = gridToScreen(t.gx, t.gy);
    const vs = t === this.player ? gridVecToScreen(this.player.vx, this.player.vy) : { x: 0, y: 0 };
    this.camera.update(dt, ps.x, ps.y - this.cameraLift, vs.x, vs.y);
  }

  /** Positions the world, culls, depth-sorts and fades occluders. Returns the view rect. */
  render(alpha: number, frameDt: number): Rect {
    const origin = this.camera.viewOrigin(alpha);
    this.root.position.set(-origin.x, -origin.y);
    const view: Rect = { x: origin.x, y: origin.y, w: this.camera.viewW, h: this.camera.viewH };
    this.mapRenderer.update(frameDt, view);
    const cullView: Rect = { x: view.x - 24, y: view.y - 24, w: view.w + 48, h: view.h + 72 };
    const visible: Entity[] = [];
    const playerRect = this.player.screenRect();
    for (const e of this.entities) {
      const r = e.screenRect();
      const on = rectsOverlap(r, cullView);
      e.view.visible = on;
      if (!on) continue;
      visible.push(e);
      if (e.fadeable) {
        e.fadeTarget = occludes(e, r, this.player, playerRect) ? OCCLUSION.FADED_ALPHA : 1;
        e.fade += (e.fadeTarget - e.fade) * Math.min(1, frameDt * OCCLUSION.FADE_RATE);
      }
      e.sync(alpha);
    }
    visible.sort(compareDepth);
    for (let k = 0; k < visible.length; k++) {
      const v = visible[k]!.view;
      if (v.zIndex !== k) v.zIndex = k;
    }
    return view;
  }

  teleport(gx: number, gy: number): void {
    this.player.setPosition(gx, gy);
    this.snapCamera();
  }

  /** Prop sprite key of a prop kind (re-exported for convenience). */
  static spriteOf(kind: PropKind): string {
    return PROP_SPRITE[kind].key;
  }

  destroy(): void {
    for (const e of this.entities) e.alive = false;
    this.root.destroy({ children: true });
  }
}
