import { Container, Graphics } from 'pixi.js';
import { ensureCharacters } from '../assets/build';
import type { CharacterKey } from '../assets/manifest';
import { applyEffects, dreamSkin, fadeCommozione, saveCampaign, type CampaignState, type Effects } from '../campaign/state';
import type { ChapterDef, SubLevelDef } from '../campaign/types';
import type { Game } from '../core/game';
import type { Scene } from '../core/scene';
import { Actor, type Behavior, type Point, type Who } from '../entities/actor';
import { Particles } from '../fx/particles';
import { Popups } from '../fx/popups';
import { gridToScreen, type Dir8 } from '../iso/projection';
import { PixelText } from '../ui/pixelText';
import { C } from '../ui/retro';
import { TouchControls } from '../ui/touchControls';
import { parseAsciiMap } from '../world/level';
import { World } from '../world/world';
import { STORY_MAPS, THEMES, type MapKey } from './maps';
import { STORY } from '../config';
import type { Autopilot } from './autopilot';
import { ResumeStep, type Step } from './step';
import { CardLayer, DialogueBox, StoryHud } from './ui';

export interface StoryHooks {
  /** All steps done: the sub-level is complete. */
  onFinished(scene: StoryScene): void;
  onMenu(scene: StoryScene): void;
}

export interface StageOptions {
  skin?: 'plain' | 'dream';
  /** Forces a costume (e.g. the armour of the 1.1 dream). */
  skinKey?: 'zampano' | 'zampanoCross' | 'zampanoKnight';
  /** Where Zampanò starts (marker); default S. */
  at?: string;
  face?: Dir8;
}

const SPECIALS = new Set(['legs', 'fortune', 'falcon', 'stag']);

/** Runs one sub-level's script over an isometric stage (or a mini-game). */
export class StoryScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  readonly stageLayer = new Container();
  readonly gameLayer = new Container();
  readonly uiLayer = new Container();
  readonly worldFx = new Container();
  readonly hud: StoryHud;
  readonly dialogue = new DialogueBox();
  readonly cards = new CardLayer();
  readonly controls: TouchControls;
  readonly particles = new Particles();
  readonly popups = new Popups();
  readonly overlayG = new Graphics();
  world: World | null = null;
  mapKey: MapKey | null = null;
  readonly actors = new Map<string, Actor>();
  /** Screen-space change notices (+5 COMMOZIONE...). */
  private readonly notices: Array<{ t: PixelText; life: number }> = [];
  private queue: Step[] = [];
  private current: Step | null = null;
  private finished = false;
  w = 216;
  h = 400;
  time = 0;
  /** Seconds the scene has been paused by a modal (used by steps for timers). */
  locked = false;
  /** False for replays: nothing this scene changes is saved. */
  persist = true;
  /** False when the scene is restarted from the pause menu: the feeling already faded once. */
  fade = true;
  /** Automated playtest driver (null in normal play). */
  pilot: Autopilot | null = null;
  /** Playtest counters: how often the player had to start a walk or mini-game again. */
  readonly metrics = { restarts: 0, caught: 0, nerveBroken: 0, ran: 0, miniRetries: 0, minis: [] as string[], choices: [] as string[] };

  constructor(
    readonly game: Game,
    readonly state: CampaignState,
    readonly chapter: ChapterDef,
    readonly sub: SubLevelDef,
    private readonly hooks: StoryHooks,
  ) {
    this.hud = new StoryHud(game.input);
    this.controls = new TouchControls(game.input);
    this.root.addChild(this.stageLayer, this.gameLayer, this.uiLayer);
    this.uiLayer.addChild(this.overlayG, this.controls.root, this.hud.root, this.dialogue.root, this.cards.root);
    this.hud.setTitle(sub.id, sub.title);
    this.controls.setEnabled(false);
    this.controls.configure({ pee: false, action: 'BARK' });
  }

  // ------------------------------------------------------------------ lifecycle

  enter(): void {
    this.queue = this.sub.script();
    // The feeling fades between dream scenes: wonder and weeping have to keep filling it.
    const lost = this.fade ? fadeCommozione(this.state, this.chapter.number) : 0;
    if (lost) {
      if (this.persist) saveCampaign(this.state);
      this.notice(`-${lost} COMMOZIONE: THE FEELING FADES`, '#9aa4c0', 2.5);
    }
    this.next();
  }

  exit(): void {
    this.current?.stop?.(this);
    this.current = null;
    this.worldFx.removeFromParent();
    if (this.pilot) this.game.input.override = null;
    this.world?.destroy();
    this.world = null;
  }

  resize(w: number, h: number): void {
    this.w = w;
    this.h = h;
    this.hud.layout(w, h);
    this.dialogue.layout(w, h);
    this.cards.layout(w, h);
    this.world?.camera.setView(w, h);
    this.game.input.joystickZone = { x: 0, y: 70, w: w * 0.62, h: h - 70 };
    this.controls.setLayout({ peeX: w - 60, peeY: h - 50, peeR: 15, barkX: w - 26, barkY: h - 40, barkR: 19 });
  }

  // ------------------------------------------------------------------ steps

  private next(): void {
    this.current?.stop?.(this);
    this.current = null;
    this.game.input.clearPending();
    this.world?.player.setIntent(0, 0);
    const step = this.queue.shift();
    if (!step) {
      if (!this.finished) {
        this.finished = true;
        this.hooks.onFinished(this);
      }
      return;
    }
    this.current = step;
    step.start(this);
  }

  /** Runs `steps` now, then resumes the current step. */
  interrupt(steps: Step[]): void {
    const cur = this.current;
    this.current = null;
    this.setControls(false);
    this.queue.unshift(...steps, ...(cur ? [new ResumeStep(cur)] : []));
    this.next();
  }

  /** Inserts steps to run right after the current one. */
  insert(steps: Step[]): void {
    this.queue.unshift(...steps);
  }

  // ------------------------------------------------------------------ stage

  /** Builds the isometric stage from a story map. Zampanò wears his dream costume by default. */
  setStage(key: MapKey, opts: StageOptions = {}): World {
    // The FX layers belong to the scene: take them out before the old world is destroyed.
    this.worldFx.removeFromParent();
    this.world?.destroy();
    this.actors.clear();
    const def = STORY_MAPS[key];
    const level = parseAsciiMap(def.rows, { base: def.base, requireExit: false });
    const skin = opts.skinKey ?? (opts.skin === 'plain' ? 'zampano' : dreamSkin(this.state));
    ensureCharactersNow([skin]);
    const world = new World(level, THEMES[def.theme], { playerSkin: skin, forest: true });
    this.world = world;
    this.mapKey = key;
    world.fxLayer.addChild(this.worldFx);
    this.worldFx.removeChildren();
    this.worldFx.addChild(this.particles.root, this.popups.root);
    this.stageLayer.removeChildren();
    this.stageLayer.addChild(world.root);
    world.camera.setView(this.w, this.h);
    if (opts.at) {
      const p = this.marker(opts.at);
      world.player.setPosition(p.x, p.y);
    }
    if (opts.face) world.player.face(opts.face);
    world.snapCamera();
    return world;
  }

  /** Grid center of a marker digit, 'S', 'E', or an explicit [x, y]. */
  marker(m: string | Point): Point {
    if (typeof m !== 'string') return m;
    const lvl = this.world?.level;
    if (!lvl) return { x: 0, y: 0 };
    if (m === 'S') return { x: lvl.start.i + 0.5, y: lvl.start.j + 0.5 };
    if (m === 'E') return { x: lvl.exit.i + 0.5, y: lvl.exit.j + 0.5 };
    const p = lvl.markers[m];
    if (!p) throw new Error(`marker ${m} missing on map ${this.mapKey}`);
    return { x: p.i + 0.5, y: p.j + 0.5 };
  }

  addActor(name: string, who: Who, at: string | Point, behavior?: Behavior, face?: Dir8): Actor {
    if (!this.world) throw new Error('addActor without a stage');
    if (!SPECIALS.has(who)) ensureCharactersNow([who as CharacterKey]);
    const p = this.marker(at);
    this.removeActor(name);
    const a = new Actor(name, who, p.x, p.y);
    if (behavior) a.setBehavior(behavior);
    if (face) a.face(face);
    this.actors.set(name, a);
    this.world.addEntity(a);
    return a;
  }

  actor(name: string): Actor {
    const a = this.actors.get(name);
    if (!a) throw new Error(`no actor ${name}`);
    return a;
  }

  removeActor(name: string): void {
    const a = this.actors.get(name);
    if (!a) return;
    this.actors.delete(name);
    this.world?.removeEntity(a);
  }

  get player() {
    return this.world!.player;
  }

  /** Lets the joystick / action button drive Zampanò (walk steps). */
  setControls(on: boolean, action = 'BARK'): void {
    this.controlsWanted = on;
    this.controlsAction = action;
    this.controls.configure({ pee: false, action });
    this.controls.setEnabled(on);
    if (!on) {
      this.game.input.joystick.active = false;
      this.world?.player.setIntent(0, 0);
    }
  }

  private controlsWanted = false;
  private controlsAction = 'BARK';

  /** Pause menu opened: freeze input without forgetting what the step wanted. */
  suspendControls(): void {
    this.controls.setEnabled(false);
    this.game.input.joystick.active = false;
    this.world?.player.setIntent(0, 0);
    this.hud.setMenuEnabled(false);
  }

  resumeAfterPause(): void {
    this.game.input.clearPending();
    this.hud.setMenuEnabled(true);
    if (this.controlsWanted) this.setControls(true, this.controlsAction);
  }

  requestMenu(): void {
    this.hooks.onMenu(this);
  }

  // ------------------------------------------------------------------ effects & feedback

  /** Applies campaign effects, shows what changed and saves. */
  apply(fx: Effects): void {
    const changes = applyEffects(this.state, fx);
    if (this.persist) saveCampaign(this.state);
    changes.forEach((c, k) => this.notice(c.label, c.positive ? C.green : C.red, k * 0.25));
  }

  notice(text: string, color: string = C.yellow, delay = 0): void {
    const t = new PixelText(text, { color, outline: '#000000', align: 'center', maxWidth: this.w - 16 }).setOrigin(0.5, 0);
    t.position.set(Math.round(this.w / 2), 84);
    t.visible = false;
    this.uiLayer.addChild(t);
    this.notices.push({ t, life: 2 + delay });
  }

  /** A text popup above a world position (grid). */
  say(text: string, at: Point, color: string = C.white): void {
    const s = gridToScreen(at.x, at.y);
    this.popups.text(text, s.x, s.y - 40, { color, glow: 'self', glowAlpha: 0.3, align: 'center', maxWidth: Math.min(150, this.w - 24) }, 1.2, -16);
  }

  flash(color = 0xffffff, alpha = 0.9): void {
    this.flashColor = color;
    this.flashAlpha = alpha;
  }
  private flashColor = 0xffffff;
  private flashAlpha = 0;

  shake(amount: number): void {
    this.world?.camera.shake(amount);
  }

  // ------------------------------------------------------------------ loop

  update(dt: number): void {
    this.time += dt;
    const input = this.game.input;
    if (input.consume('menu') || input.consume('back')) {
      this.hooks.onMenu(this);
      return;
    }
    this.dialogue.cps = STORY.TEXT_CPS[this.game.settings.textSpeed];
    this.world?.beginStep();
    if (this.pilot) {
      this.pilot.beginStep(dt, this);
      this.current?.pilot?.(dt, this, this.pilot);
    }
    if (this.current && this.current.update(dt, this) === 'done') this.next();
    if (this.world) {
      this.world.player.updateMovement(dt, this.world.map);
      for (const a of this.actors.values()) a.step(dt, this.world.map, this.world.player);
      this.world.endStep(dt);
    }
    this.particles.update(dt);
    this.popups.update(dt);
    this.dialogue.update(dt);
    this.cards.update(dt);
    for (let k = this.notices.length - 1; k >= 0; k--) {
      const n = this.notices[k]!;
      n.life -= dt;
      if (n.life <= 0) {
        n.t.destroy();
        this.notices.splice(k, 1);
      }
    }
    let y = 84;
    for (const n of this.notices) {
      n.t.visible = n.life < 2;
      if (!n.t.visible) continue;
      n.t.y = Math.round(y - (2 - n.life) * 3);
      n.t.alpha = Math.min(1, n.life * 2);
      y += n.t.textHeight + 4;
    }
    this.flashAlpha = Math.max(0, this.flashAlpha - dt * 2.5);
  }

  render(alpha: number, frameDt: number): void {
    this.world?.render(alpha, frameDt);
    this.controls.update();
    this.hud.update(frameDt, this.state);
    const g = this.overlayG;
    g.clear();
    if (this.flashAlpha > 0) g.rect(0, 0, this.w, this.h).fill({ color: this.flashColor, alpha: this.flashAlpha });
  }

  /** Automation (story smoke test): ends the current step at once and starts the next. */
  debugSkip(): void {
    if (this.current && !this.finished) this.next();
  }

  /** Debug summary for automation. */
  debugState(): Record<string, unknown> {
    const p = this.world?.player;
    return {
      sub: this.sub.id,
      finished: this.finished,
      time: +this.time.toFixed(2),
      metrics: this.metrics,
      step: this.current?.constructor.name ?? null,
      queue: this.queue.length,
      player: p ? { gx: +p.gx.toFixed(2), gy: +p.gy.toFixed(2) } : null,
      meters: { ...this.state.meters },
    };
  }
}

/** Generates placeholder sprites for characters right away (sheets load asynchronously). */
function ensureCharactersNow(keys: CharacterKey[]): void {
  void ensureCharacters(keys);
}
