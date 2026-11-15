import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { Emitter, type GameEvents } from '../core/events';
import type { Game } from '../core/game';
import { hash2 } from '../core/rng';
import type { Scene } from '../core/scene';
import { BALL, OCCLUSION } from '../config';
import { buildLevelTextures } from '../assets/build';
import { PropEntity } from '../entities/prop';
import { Zampano } from '../entities/zampano';
import type { Entity } from '../entities/entity';
import { GameFx } from '../fx/gameFx';
import { Camera } from '../iso/camera';
import { compareDepth, occludes, rectsOverlap, type Rect } from '../iso/depth';
import { gridToScreen, gridVecToScreen } from '../iso/projection';
import { Rules } from '../systems/rules';
import { Threats } from '../systems/threats';
import { GlitchFilter } from '../fx/glitchFilter';
import { AttackBanner } from '../ui/attackBanner';
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
  readonly threats: Threats;
  readonly hud: Hud;
  readonly banner = new AttackBanner();
  private readonly attackFilter = new GlitchFilter();
  /** Smoothed visual intensity of the "under attack" effects. */
  private attackFx = 0;
  private burst = 0;
  readonly fx: GameFx;
  readonly controls: TouchControls;
  hooks: GameSceneHooks = {};
  /** When false, gameplay is frozen (title/briefing shown over the level). */
  active = true;
  private readonly exitRing: Sprite;
  private readonly magnetG = new Graphics();
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
    this.threats = new Threats(this, this.rules, levelDef);
    this.fx = new GameFx(this.events, this.player, this.camera, () => this.rules.poopWarning);
    this.decalLayer.addChild(this.fx.below, this.magnetG);
    this.fxLayer.addChild(this.fx.above);

    this.camera.bounds = this.walkableBounds(4);
    this.hud = new Hud(game.input);
    this.controls = new TouchControls(game.input);
    this.uiLayer.addChild(this.controls.root, this.hud.root, this.banner.root);

    this.events.on('levelComplete', () => {
      this.controls.setEnabled(false);
    });
    this.events.on('attackStart', () => {
      this.banner.start();
      this.burst = 0.6;
    });
    this.events.on('attackEnd', () => this.banner.end());
    this.events.on('barkHit', () => (this.burst = Math.max(this.burst, 0.15)));
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
    this.banner.layout(w, h);
  }

  update(dt: number): void {
    this.time += dt;
    for (const e of this.entities) e.savePrev();
    const input = this.game.input;
    if (this.active) {
      if (input.consume('menu') && this.rules.state === 'playing') this.hooks.onMenu?.(this);
      this.rules.update(dt, input);
      if (this.rules.state === 'playing') this.threats.update(dt, input);
    } else {
      this.player.setIntent(0, 0);
    }
    for (const e of this.entities) if (e !== this.player) e.update(dt);
    this.map.update(dt);
    const ps = gridToScreen(this.player.gx, this.player.gy);
    const vs = gridVecToScreen(this.player.vx, this.player.vy);
    this.camera.update(dt, ps.x, ps.y - 10, vs.x, vs.y);
    this.fx.update(dt);
    this.updateAttackFx(dt);

    if (!this.endNotified && this.rules.state !== 'playing' && this.rules.endedFor > 1.1) {
      this.endNotified = true;
      if (this.rules.state === 'complete') this.hooks.onComplete?.(this);
      else this.hooks.onGameOver?.(this);
    }
  }

  /** Sepia palette shift + glitch bursts on the world while the zone is under attack. */
  private updateAttackFx(dt: number): void {
    const target = this.threats.director.intensity(this.map.health());
    const rate = target > this.attackFx ? 2.5 : 0.8;
    this.attackFx += (target - this.attackFx) * Math.min(1, rate * dt);
    if (this.attackFx < 0.005 && target === 0) this.attackFx = 0;
    if (this.burst > 0) this.burst -= dt;
    else if (this.attackFx > 0 && Math.random() < 0.006 + 0.02 * this.attackFx) this.burst = 0.08 + Math.random() * 0.15;
    const f = this.attackFilter;
    f.time = this.time;
    f.sepia = Math.min(0.9, this.attackFx * 0.95);
    f.scanlines = this.attackFx * 0.35;
    f.glitch = this.burst > 0 ? 0.35 + this.attackFx * 0.5 : 0;
    f.rgb = this.burst > 0 ? 2 + this.attackFx * 2 : this.attackFx > 0.5 ? 1 : 0;
    f.flash = 0;
    if (!this.active) return;
    const want = this.attackFx > 0;
    const has = this.worldRoot.filters?.length === 1 && this.worldRoot.filters[0] === f;
    if (want && !has) this.worldRoot.filters = [f];
    else if (!want && has) this.worldRoot.filters = [];
    const pug = this.threats.pug;
    const hint =
      pug && pug.active
        ? this.game.input.usingTouch
          ? 'BARK AT BAGNASKIZ!'
          : 'BARK (J) AT BAGNASKIZ!'
        : this.map.health() < this.threats.director.threshold
          ? 'PEE TO HEAL THE ZONE!'
          : null;
    this.banner.update(dt, hint);
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
    this.drawMagnetFields();
    this.controls.update();
    this.controls.setPeeCharges(this.rules.bladder.charges, this.rules.bladder.max, this.rules.bladder.regenFraction);
    this.controls.setBarkReady(this.threats.barkReadiness);
    this.hud.update(this.hudState(), frameDt);
  }

  /** Pulsing rings converging on nearby balls: shows the magnet pull area. */
  private drawMagnetFields(): void {
    const g = this.magnetG;
    g.clear();
    for (const b of this.threats.balls) {
      const d = Math.hypot(b.gx - this.player.gx, b.gy - this.player.gy);
      if (d > BALL.MAGNET_RADIUS * 1.8 || b.age > BALL.LIFETIME) continue;
      const c = gridToScreen(b.gx, b.gy);
      for (let k = 0; k < 2; k++) {
        const u = 1 - ((this.time * 0.8 + k * 0.5) % 1);
        const r = BALL.MAGNET_RADIUS * u;
        g.ellipse(Math.round(c.x), Math.round(c.y), r * 16 * Math.SQRT2, r * 8 * Math.SQRT2).stroke({
          width: 1,
          color: 0xdcf23a,
          alpha: 0.55 * (1 - u) + 0.1,
        });
      }
    }
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
    for (const c of this.threats.cats) {
      const d = rel(c.gx, c.gy);
      radar.push({ dx: d.x, dy: d.y, color: 0x3ff0ff, size: 3 });
    }
    for (const b of this.threats.balls) {
      const d = rel(b.gx, b.gy);
      radar.push({ dx: d.x, dy: d.y, color: 0xffe23a, size: 2 });
    }
    const pug = this.threats.pug;
    if (pug) {
      const d = rel(pug.gx, pug.gy);
      radar.push({ dx: d.x, dy: d.y, color: 0xff7a1f, size: 4, blink: true });
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
      attack: this.threats.director.state,
      pug: this.threats.pug ? { state: this.threats.pug.state, hits: this.threats.pug.hits } : null,
      cats: this.threats.cats.length,
      balls: this.threats.balls.length,
    };
  }

  /** Debug/test helper: teleport Zampanò. */
  teleport(gx: number, gy: number): void {
    this.player.setPosition(gx, gy);
    const s = gridToScreen(gx, gy);
    this.camera.snapTo(s.x, s.y);
  }
}
