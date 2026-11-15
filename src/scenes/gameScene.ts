import { Container, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { Emitter, type GameEvents } from '../core/events';
import type { Game } from '../core/game';
import { hash2 } from '../core/rng';
import type { Scene } from '../core/scene';
import { OCCLUSION } from '../config';
import { buildLevelTextures } from '../assets/build';
import { PropEntity } from '../entities/prop';
import { Zampano } from '../entities/zampano';
import type { Entity } from '../entities/entity';
import { GameFx } from '../fx/gameFx';
import { Camera } from '../iso/camera';
import { compareDepth, occludes, rectsOverlap, type Rect } from '../iso/depth';
import { gridToScreen, gridVecToScreen } from '../iso/projection';
import { Rules } from '../systems/rules';
import { Hud, type RadarDot } from '../ui/hud';
import { PixelText } from '../ui/pixelText';
import { TouchControls } from '../ui/touchControls';
import { loadLevel, type LevelDef } from '../world/level';
import { GameMap } from '../world/map';
import { MapRenderer } from '../world/mapRenderer';
import { Ground } from '../world/tiles';

/** Callbacks the scene flow (title → briefing → game → end) plugs in. */
export interface GameSceneHooks {
  onComplete?(scene: GameScene): void;
  onGameOver?(scene: GameScene): void;
  onMenu?(scene: GameScene): void;
}

/** The gameplay scene: world, entities, rules, camera, HUD, effects. */
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
  readonly events = new Emitter<GameEvents>();
  readonly rules: Rules;
  readonly hud: Hud;
  readonly fx: GameFx;
  readonly controls: TouchControls;
  hooks: GameSceneHooks = {};
  /** When false, gameplay is frozen (title/briefing shown over the level). */
  active = true;
  private readonly exitRing: Sprite;
  private readonly exitLabel: PixelText;
  private time = 0;
  private endNotified = false;

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
    this.addEntity(new PropEntity('exitFlag', 0, ex.x + 0.25, ex.y - 0.25, null, true));
    this.exitLabel = new PixelText('EXIT', { color: '#fff36a', outline: '#000000', glow: 'self' }).setOrigin(0.5, 1);
    this.fxLayer.addChild(this.exitLabel);

    this.player = new Zampano(this.map.start.x, this.map.start.y);
    this.player.face('N');
    this.addEntity(this.player);

    this.rules = new Rules(this, levelDef);
    this.fx = new GameFx(this.events, this.player, this.camera, () => this.rules.poopWarning);
    this.decalLayer.addChild(this.fx.below);
    this.fxLayer.addChild(this.fx.above);

    this.camera.bounds = this.walkableBounds(4);
    this.hud = new Hud(game.input);
    this.controls = new TouchControls(game.input);
    this.uiLayer.addChild(this.controls.root, this.hud.root);

    this.events.on('levelComplete', () => {
      this.controls.setEnabled(false);
    });
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
        if ((near && h < 0.42) || (!near && h < 0.1)) {
          this.addEntity(new PropEntity('forestTree', hash2(i, j, 22) < 0.5 ? 0 : 1, i + 0.5, j + 0.5, null, true));
        }
      }
    }
  }

  enter(): void {
    const s = gridToScreen(this.player.gx, this.player.gy);
    this.camera.snapTo(s.x, s.y);
    this.setControlsEnabled(this.active);
  }

  setControlsEnabled(on: boolean): void {
    this.controls.setEnabled(on);
    this.hud.setMenuEnabled(on);
  }

  resize(w: number, h: number): void {
    this.camera.setView(w, h);
    this.game.input.joystickZone = { x: 0, y: 60, w: w * 0.62, h: h - 60 };
    this.controls.setLayout({ peeX: w - 60, peeY: h - 50, peeR: 15, barkX: w - 23, barkY: h - 60, barkR: 17 });
    this.hud.layout(w, h);
  }

  update(dt: number): void {
    this.time += dt;
    for (const e of this.entities) e.savePrev();
    const input = this.game.input;
    if (this.active) {
      if (input.consume('menu') && this.rules.state === 'playing') this.hooks.onMenu?.(this);
      this.rules.update(dt, input);
    } else {
      this.player.setIntent(0, 0);
    }
    for (const e of this.entities) if (e !== this.player) e.update(dt);
    this.map.update(dt);
    const ps = gridToScreen(this.player.gx, this.player.gy);
    const vs = gridVecToScreen(this.player.vx, this.player.vy);
    this.camera.update(dt, ps.x, ps.y - 10, vs.x, vs.y);
    this.fx.update(dt);

    if (!this.endNotified && this.rules.state !== 'playing' && this.rules.endedFor > 1.1) {
      this.endNotified = true;
      if (this.rules.state === 'complete') this.hooks.onComplete?.(this);
      else this.hooks.onGameOver?.(this);
    }
  }

  render(alpha: number, frameDt: number): void {
    const origin = this.camera.viewOrigin(alpha);
    this.worldRoot.position.set(-origin.x, -origin.y);
    const view: Rect = { x: origin.x, y: origin.y, w: this.camera.viewW, h: this.camera.viewH };
    this.mapRenderer.update(frameDt, view);
    this.exitRing.alpha = 0.5 + 0.5 * Math.sin(this.time * 5);
    const lp = gridToScreen(this.map.exit.x, this.map.exit.y);
    this.exitLabel.position.set(Math.round(lp.x), Math.round(lp.y - 44 + Math.sin(this.time * 3) * 2));

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
    this.controls.setPeeCharges(this.rules.bladder.charges, this.rules.bladder.max, this.rules.bladder.regenFraction);
    this.hud.update(this.hudState(), frameDt);
  }

  private hudState() {
    const st = this.rules.stats;
    const p = this.player;
    const radar: RadarDot[] = [];
    const rel = (x: number, y: number) => gridVecToScreen(x - p.gx, y - p.gy);
    for (const t of this.rules.treats) {
      const d = rel(t.gx, t.gy);
      if (Math.abs(d.x) < 260 && Math.abs(d.y) < 260) radar.push({ dx: d.x, dy: d.y, color: 0xff3b6b });
    }
    for (const poop of this.rules.poops) {
      const d = rel(poop.gx, poop.gy);
      if (!poop.cleaned) radar.push({ dx: d.x, dy: d.y, color: 0x8a5422 });
    }
    const exit = rel(this.map.exit.x, this.map.exit.y);
    return {
      pees: st.pees,
      poops: st.poops,
      treats: st.treats,
      stars: this.rules.stars,
      lives: st.lives,
      hunger: this.rules.hunger.fraction,
      score: st.score,
      time: st.time,
      zoneName: this.levelDef.zoneName,
      level: this.levelDef.number,
      radar,
      exit: { dx: exit.x, dy: exit.y },
    };
  }

  exit(): void {
    for (const e of this.entities) e.alive = false;
    this.events.clear();
  }

  /** Debug/test summary. */
  debugState(): Record<string, unknown> {
    const st = this.rules.stats;
    return {
      player: { gx: +this.player.gx.toFixed(2), gy: +this.player.gy.toFixed(2), facing: this.player.facing, state: this.player.state },
      health: +this.map.health().toFixed(4),
      stars: this.rules.stars,
      hunger: +this.rules.hunger.value.toFixed(1),
      charges: this.rules.bladder.charges,
      progress: +this.map.progressAt(this.player.gx, this.player.gy).toFixed(3),
      state: this.rules.state,
      stats: { ...st, time: +st.time.toFixed(1) },
      treatsLeft: this.rules.treats.length,
    };
  }

  /** Debug/test helper: teleport Zampanò. */
  teleport(gx: number, gy: number): void {
    this.player.setPosition(gx, gy);
    const s = gridToScreen(gx, gy);
    this.camera.snapTo(s.x, s.y);
  }
}
