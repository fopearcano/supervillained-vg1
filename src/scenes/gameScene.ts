import { Container, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Game } from '../core/game';
import { hash2 } from '../core/rng';
import type { Scene } from '../core/scene';
import { OCCLUSION } from '../config';
import { buildLevelTextures } from '../assets/build';
import { PropEntity } from '../entities/prop';
import { Zampano } from '../entities/zampano';
import type { Entity } from '../entities/entity';
import { Camera } from '../iso/camera';
import { compareDepth, occludes, rectsOverlap, type Rect } from '../iso/depth';
import { gridToScreen } from '../iso/projection';
import { loadLevel, type LevelDef } from '../world/level';
import { GameMap } from '../world/map';
import { MapRenderer } from '../world/mapRenderer';
import { Ground } from '../world/tiles';
import { TouchControls } from '../ui/touchControls';
import { PixelText } from '../ui/pixelText';

/** The gameplay scene: world, entities, camera, HUD. */
export class GameScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  readonly worldRoot = new Container();
  readonly decalLayer = new Container();
  readonly objectLayer = new Container();
  readonly fxLayer = new Container();
  readonly uiLayer = new Container();
  readonly map: GameMap;
  readonly mapRenderer: MapRenderer;
  readonly camera = new Camera();
  readonly player: Zampano;
  readonly entities: Entity[] = [];
  readonly controls: TouchControls;
  private readonly exitRing: Sprite;
  private readonly exitLabel: PixelText;
  private time = 0;

  constructor(
    readonly game: Game,
    readonly levelDef: LevelDef,
  ) {
    const level = loadLevel(levelDef);
    buildLevelTextures(levelDef.palette);
    this.map = new GameMap(level);
    this.mapRenderer = new MapRenderer(this.map);
    this.objectLayer.sortableChildren = true;
    this.worldRoot.addChild(this.mapRenderer.root, this.decalLayer, this.objectLayer, this.fxLayer);
    this.root.addChild(this.worldRoot, this.uiLayer);

    // Props from the level + decorative forest along the border.
    for (const p of this.map.props) {
      const variants = p.kind === 'tree' ? 3 : p.kind === 'bush' ? 2 : 1;
      const v = Math.floor(hash2(p.i, p.j, 3) * variants);
      const e = new PropEntity(p.kind, v, p.x, p.y, p, p.kind !== 'fountain');
      if (p.kind === 'bush') e.depthBias = 0.1;
      this.addEntity(e);
    }
    this.spawnForest();

    // Exit: flag + glowing ring + label.
    const ex = this.map.exit;
    this.exitRing = new Sprite(textures.get('exitRing_0'));
    const ep = gridToScreen(this.map.exitTile.i, this.map.exitTile.j);
    this.exitRing.position.set(ep.x, ep.y);
    this.decalLayer.addChild(this.exitRing);
    const flag = new PropEntity('exitFlag', 0, ex.x + 0.25, ex.y - 0.25, null, true);
    this.addEntity(flag);
    this.exitLabel = new PixelText('EXIT', { color: '#fff36a', outline: '#000000', glow: 'self' }).setOrigin(0.5, 1);
    const lp = gridToScreen(ex.x, ex.y);
    this.exitLabel.position.set(Math.round(lp.x), Math.round(lp.y - 44));
    this.fxLayer.addChild(this.exitLabel);

    this.player = new Zampano(this.map.start.x, this.map.start.y);
    this.player.face('N');
    this.addEntity(this.player);

    this.camera.bounds = this.walkableBounds(4);
    this.controls = new TouchControls(game.input);
    this.uiLayer.addChild(this.controls.root);
  }

  /** Screen-space bounds of the walkable area, grown by `marginTiles`. */
  private walkableBounds(marginTiles: number): Rect {
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
    return { x, y, w: Math.min(b.x + b.w, x1 + mx) - x, h: Math.min(b.y + b.h, y1 + my) - y };
  }

  addEntity(e: Entity): void {
    this.entities.push(e);
    this.objectLayer.addChild(e.view);
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
        if ((near && h < 0.42) || (!near && h < 0.1)) {
          const e = new PropEntity('forestTree', hash2(i, j, 22) < 0.5 ? 0 : 1, i + 0.5, j + 0.5, null, true);
          this.addEntity(e);
        }
      }
    }
  }

  enter(): void {
    const s = gridToScreen(this.player.gx, this.player.gy);
    this.camera.snapTo(s.x, s.y);
    this.controls.setEnabled(true);
  }

  resize(w: number, h: number): void {
    this.camera.setView(w, h);
    this.game.input.joystickZone = { x: 0, y: 64, w: w * 0.62, h: h - 64 };
    this.controls.setLayout({ peeX: w - 58, peeY: h - 60, peeR: 15, barkX: w - 24, barkY: h - 86, barkR: 17 });
  }

  update(dt: number): void {
    this.time += dt;
    for (const e of this.entities) e.savePrev();
    const input = this.game.input;
    this.player.setIntent(input.move.x, input.move.y);
    this.player.updateMovement(dt, this.map);
    for (const e of this.entities) if (e !== this.player) e.update(dt);
    this.map.update(dt);
    const ps = gridToScreen(this.player.gx, this.player.gy);
    const vs = gridToScreen(this.player.vx, this.player.vy);
    const v0 = gridToScreen(0, 0);
    this.camera.update(dt, ps.x, ps.y - 10, vs.x - v0.x, vs.y - v0.y);
  }

  render(alpha: number, frameDt: number): void {
    const origin = this.camera.viewOrigin(alpha);
    this.worldRoot.position.set(-origin.x, -origin.y);
    const view: Rect = { x: origin.x, y: origin.y, w: this.camera.viewW, h: this.camera.viewH };
    this.mapRenderer.update(frameDt, view);
    this.exitRing.alpha = 0.5 + 0.5 * Math.sin(this.time * 5);
    this.exitLabel.y = Math.round(gridToScreen(this.map.exit.x, this.map.exit.y).y - 44 + Math.sin(this.time * 3) * 2);

    // Cull, depth-sort and fade occluders.
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
    this.controls.update();
  }

  exit(): void {
    for (const e of this.entities) e.alive = false;
  }

  /** Debug/test summary. */
  debugState(): Record<string, unknown> {
    return {
      player: { gx: +this.player.gx.toFixed(2), gy: +this.player.gy.toFixed(2), facing: this.player.facing, state: this.player.state },
      health: +this.map.health().toFixed(4),
      progress: +this.map.progressAt(this.player.gx, this.player.gy).toFixed(3),
    };
  }

  /** Debug/test helper: teleport Zampanò. */
  teleport(gx: number, gy: number): void {
    this.player.setPosition(gx, gy);
    const s = gridToScreen(gx, gy);
    this.camera.snapTo(s.x, s.y);
  }
}

