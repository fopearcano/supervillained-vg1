import { Graphics, Sprite } from 'pixi.js';
import { textures } from '../../core/assets';
import { ensureCharacters } from '../../assets/build';
import { textureName } from '../../assets/manifest';
import { dreamSkin } from '../../campaign/state';
import { PixelText } from '../../ui/pixelText';
import { C, frameRect, hex, retroBox } from '../../ui/retro';
import type { StoryScene } from '../storyScene';
import { MiniGame, type MiniResult } from './miniGame';

/** Reads "pressed this step" for the common actions. */
function act(ctx: StoryScene): boolean {
  const i = ctx.game.input;
  return i.consume('bark') || i.consume('pee') || i.consume('confirm');
}

// ---------------------------------------------------------------------------- ladders

interface Falling {
  lane: number;
  y: number;
  kind: 'stone' | 'pitch';
  warn: number;
}

/**
 * Siege ladders (5.2 rehearsal, 7.2 the real thing): three ladders against the wall. Tap / UP to
 * climb a rung, LEFT / RIGHT (or tap the sides) to change ladder. Stones and pitch come down;
 * axe-men hold the parapet.
 */
export class LaddersGame extends MiniGame {
  private readonly g = new Graphics();
  private readonly hero: Sprite;
  private readonly info = new PixelText('', { color: C.white, shadow: '#000000', align: 'center' }).setOrigin(0.5, 0);
  private readonly axemen: Sprite[] = [];
  private lane = 1;
  private rung = 0;
  private slide = 0;
  private falling: Falling[] = [];
  private spawnT = 1;
  private hitT = 0;
  private axeLane = 0;
  private axeT = 0;

  constructor(
    private readonly rungs: number,
    private readonly hard: boolean,
    skin: string,
  ) {
    super();
    this.hidesStage = true;
    this.objective = hard ? 'CLIMB! AVOID STONES, PITCH AND THE AXE-MEN' : 'REHEARSAL: CLIMB THE LADDER, AVOID THE STONES';
    void ensureCharacters([skin, 'varangian']);
    this.hero = new Sprite(textures.get(textureName(skin as 'zampano', 'walk', 'N', 0)));
    this.hero.anchor.set(0.5, 0.9);
    this.root.addChild(this.g, this.hero, this.info);
    if (hard) {
      for (let k = 0; k < 2; k++) {
        const s = new Sprite(textures.get(textureName('varangian', 'idle', 'S', 0)));
        s.anchor.set(0.5, 0.9);
        this.axemen.push(s);
        this.root.addChild(s);
      }
    }
  }

  private laneX(l: number): number {
    return Math.round(this.w * (0.25 + l * 0.25));
  }

  /** Screen y of a rung, scrolling so Zampanò stays in the lower part of the screen. */
  private rungY(r: number): number {
    const step = 22;
    const base = this.h - 70;
    const scroll = Math.max(0, this.rung - 6) * step;
    return base - r * step + scroll;
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const input = ctx.game.input;
    const { w, h } = this;
    // Input: taps on the sides change ladder, in the middle climb.
    let climb = act(ctx) || input.consume('up');
    for (const t of input.consumeTaps()) {
      if (t.x < w * 0.3) this.lane = Math.max(0, this.lane - 1);
      else if (t.x > w * 0.7) this.lane = Math.min(2, this.lane + 1);
      else climb = true;
    }
    if (input.consume('left')) this.lane = Math.max(0, this.lane - 1);
    if (input.consume('right')) this.lane = Math.min(2, this.lane + 1);
    if (climb && this.hitT <= 0 && this.slide <= 0) {
      this.rung++;
      ctx.game.audio.play('click', { volume: 0.4, rate: 1 + (this.rung % 4) * 0.1 });
    }
    if (this.slide > 0) {
      this.slide -= dt;
      this.rung = Math.max(0, this.rung - dt * 10);
    }
    this.hitT -= dt;

    // Falling things
    this.spawnT -= dt;
    if (this.spawnT <= 0) {
      this.spawnT = (this.hard ? 0.75 : 1.2) * (0.7 + Math.random() * 0.6);
      this.falling.push({ lane: Math.floor(Math.random() * 3), y: -20, kind: this.hard && Math.random() < 0.35 ? 'pitch' : 'stone', warn: 0.6 });
    }
    const heroY = this.rungY(this.rung);
    for (let k = this.falling.length - 1; k >= 0; k--) {
      const f = this.falling[k]!;
      if (f.warn > 0) {
        f.warn -= dt;
        continue;
      }
      f.y += dt * (f.kind === 'pitch' ? 150 : 190);
      if (f.lane === this.lane && Math.abs(f.y - (heroY - 14)) < 12 && this.hitT <= 0) {
        this.hitT = 0.8;
        this.slide = 0.35;
        ctx.game.audio.play('hurt');
        ctx.notice(f.kind === 'pitch' ? 'PITCH!' : 'STONE!', C.red);
        this.falling.splice(k, 1);
        continue;
      }
      if (f.y > h + 20) this.falling.splice(k, 1);
    }
    // Axe-men hold the parapet: move between ladders near the top.
    const top = this.rungY(this.rungs);
    if (this.hard) {
      this.axeT -= dt;
      if (this.axeT <= 0) {
        this.axeT = 1.6;
        this.axeLane = Math.floor(Math.random() * 3);
      }
      this.axemen.forEach((s, k) => {
        const l = k === 0 ? this.axeLane : (this.axeLane + 2) % 3;
        s.position.set(this.laneX(l), top - 4);
        if (l === this.lane && this.rung > this.rungs - 2 && this.hitT <= 0) {
          this.hitT = 1;
          this.slide = 0.5;
          ctx.game.audio.play('hit');
          ctx.notice('AXE-MEN HOLD THE PARAPET', C.red);
        }
      });
    }

    // Draw: wall, ladders, falling things.
    const g = this.g;
    g.clear();
    g.rect(0, 0, w, h).fill(0x6a5a48);
    // Bricks scroll down as he climbs.
    const scroll = Math.max(0, this.rung - 6) * 22;
    const off = scroll % 10;
    const base = Math.floor(scroll / 10);
    for (let row = -2; row < h / 10 + 2; row++) {
      const y = Math.round(row * 10 + off);
      const shift = ((row - base) & 1) * 10;
      for (let x = -shift; x < w; x += 20) g.rect(x, y, 19, 9).fill(0x8a7660);
    }
    if (top > -10) {
      g.rect(0, top - 30, w, 26).fill(0x9a8670);
      for (let x = 0; x < w; x += 24) g.rect(x, top - 40, 14, 12).fill(0x9a8670);
    }
    for (let l = 0; l < 3; l++) {
      const x = this.laneX(l);
      g.rect(x - 10, Math.max(top - 6, 0), 2, h).fill(0x5a3a1c);
      g.rect(x + 8, Math.max(top - 6, 0), 2, h).fill(0x5a3a1c);
      for (let r = 0; r <= this.rungs; r++) {
        const y = this.rungY(r);
        if (y > -5 && y < h + 5) g.rect(x - 10, y, 20, 2).fill(0x7a5430);
      }
    }
    for (const f of this.falling) {
      const x = this.laneX(f.lane);
      if (f.warn > 0) {
        if (Math.floor(f.warn * 10) % 2) g.rect(x - 6, 2, 12, 3).fill(0xff3030);
        continue;
      }
      if (f.kind === 'stone') g.circle(x, f.y, 6).fill(0x9a9a9a).stroke({ width: 1, color: 0x3a3a3a });
      else g.ellipse(x, f.y, 5, 9).fill(0x1a1410);
    }
    this.hero.position.set(this.laneX(this.lane), heroY);
    this.hero.texture = textures.get(textureName(this.heroSkin(ctx) as 'zampano', 'walk', 'N', Math.floor(this.rung) % 4));
    this.hero.alpha = this.hitT > 0 && Math.floor(this.hitT * 12) % 2 ? 0.4 : 1;
    this.info.setText(`${Math.min(this.rungs, Math.floor(this.rung))}/${this.rungs}  TAP MIDDLE: CLIMB  SIDES: LADDER`);
    this.info.setStyle({ maxWidth: w - 16 });
    this.info.position.set(Math.round(w / 2), h - 28);
    frameRect(g, 4, h - 32, w - 8, 22, hex(C.yellow));
    return this.rung >= this.rungs ? 'won' : 'running';
  }

  private heroSkin(ctx: StoryScene): string {
    return dreamSkin(ctx.state);
  }
}

// ---------------------------------------------------------------------------- tug of war

/** 7.7: Zampanò grabs Confusione's leg to stop him going into the hole. He is meant to lose. */
export class TugGame extends MiniGame {
  private readonly g = new Graphics();
  private readonly label = new PixelText('MASH TO HOLD HIM BACK!', { color: C.yellow, shadow: '#000000' }).setOrigin(0.5);
  private readonly hero: Sprite;
  private readonly friend: Sprite;
  private pos = 0;

  constructor() {
    super();
    this.objective = 'HOLD CONFUSIONE BACK';
    void ensureCharacters(['zampanoKnight', 'confusione']);
    this.hero = new Sprite(textures.get(textureName('zampanoKnight', 'run', 'E', 0)));
    this.friend = new Sprite(textures.get(textureName('confusione', 'run', 'E', 0)));
    this.hero.anchor.set(0.5, 0.9);
    this.friend.anchor.set(0.5, 0.9);
    this.root.addChild(this.g, this.hero, this.friend, this.label);
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const { w, h } = this;
    let pulls = ctx.game.input.consumeTaps().length;
    if (act(ctx)) pulls++;
    // He pulls harder and harder: the player cannot win.
    const force = 0.08 + this.time * 0.05;
    this.pos += force * dt - pulls * 0.035;
    this.pos = Math.max(-0.3, Math.min(1, this.pos));
    if (pulls) ctx.game.audio.play('click', { volume: 0.4 });
    const g = this.g;
    g.clear();
    g.rect(0, h * 0.5 - 40, w, 80).fill({ color: 0x000000, alpha: 0.5 });
    const holeX = w - 20;
    g.rect(holeX - 6, h * 0.5 - 30, 26, 50).fill(0x0a0606);
    const fx = Math.round(w * 0.5 + this.pos * (holeX - w * 0.5 - 10));
    this.friend.position.set(fx, h * 0.5 + 10);
    this.hero.position.set(fx - 34, h * 0.5 + 12);
    g.rect(fx - 30, h * 0.5 + 2, 24, 2).fill(0xd8c8a0);
    const bw = w - 40;
    g.rect(20, h * 0.5 + 40, bw, 6).fill(0x220808);
    g.rect(20, h * 0.5 + 41, Math.round(bw * Math.max(0, this.pos)), 4).fill(0xff3030);
    frameRect(g, 20, h * 0.5 + 40, bw, 6, hex(C.yellow));
    this.label.position.set(Math.round(w / 2), Math.round(h * 0.5 - 52));
    this.hero.texture = textures.get(textureName('zampanoKnight', 'run', 'E', Math.floor(this.time * 8) % 4));
    this.friend.texture = textures.get(textureName('confusione', 'run', 'E', Math.floor(this.time * 10) % 4));
    return this.pos >= 1 ? 'lost' : 'running';
  }
}

// ---------------------------------------------------------------------------- calm rescue

/** 4.2: Watson floats overboard. Rescue him by NOT panicking: stay still and the rope reaches him. */
export class CalmGame extends MiniGame {
  private readonly g = new Graphics();
  private readonly label = new PixelText('DO NOT PANIC. DO NOTHING.', { color: C.cyan, shadow: '#000000', align: 'center' }).setOrigin(0.5);
  private calm = 0;
  private panicT = 0;

  constructor() {
    super();
    this.objective = 'RESCUE WATSON BY NOT PANICKING';
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
    this.root.addChild(this.g, this.label);
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const input = ctx.game.input;
    const panicked = input.consumeTaps().length > 0 || act(ctx) || input.consume('up') || input.consume('down') || input.consume('left') || input.consume('right') || Math.hypot(input.move.x, input.move.y) > 0.1;
    if (panicked) {
      this.calm = Math.max(0, this.calm - 0.25);
      this.panicT = 0.8;
      ctx.notice('PANIC! HE DRIFTS AWAY', C.red);
    } else this.calm = Math.min(1, this.calm + dt * 0.14);
    this.panicT -= dt;
    const watson = ctx.actors.get('watson');
    if (watson && this.panicT > 0) watson.gx -= dt * 0.6;
    const { w, h } = this;
    const g = this.g;
    g.clear();
    const bw = w - 60;
    g.rect(30, h - 110, bw, 8).fill({ color: 0x000000, alpha: 0.6 });
    g.rect(31, h - 109, Math.round((bw - 2) * this.calm), 6).fill(0x5ac8ff);
    frameRect(g, 30, h - 110, bw, 8, hex(C.yellow));
    this.label.setText(this.panicT > 0 ? 'PANIC! STAY STILL...' : this.calm > 0.6 ? 'THE ROPE IS REACHING HIM...' : 'DO NOT PANIC. DO NOTHING.');
    this.label.position.set(Math.round(w / 2), h - 124);
    return this.calm >= 1 ? 'won' : 'running';
  }
}

// ---------------------------------------------------------------------------- catapult

/** 6.1: the count of Eu's toy catapult. Tap when the power is right; break the glasses. */
export class CatapultGame extends MiniGame {
  private readonly g = new Graphics();
  private readonly label = new PixelText('TAP TO FIRE', { color: C.yellow, shadow: '#000000' }).setOrigin(0.5);
  private glasses = [true, true, true, true, true];
  private shots = 4;
  private shot: { x: number; y: number; vx: number; vy: number } | null = null;
  private power = 0;
  private broken = 0;
  private end = 0;

  constructor() {
    super();
    this.hidesStage = true;
    this.objective = 'BREAK THE GLASSES WITH THE LITTLE CATAPULT';
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
    this.root.addChild(this.g, this.label);
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const { w, h } = this;
    const ground = h * 0.62;
    const tableX = w * 0.55;
    if (!this.shot && this.shots > 0) {
      this.power = (Math.sin(this.time * 3) + 1) / 2;
      const fired = ctx.game.input.consumeTaps().length > 0 || act(ctx);
      if (fired) {
        this.shots--;
        const p = 0.35 + this.power * 0.75;
        this.shot = { x: 30, y: ground - 14, vx: 150 * p, vy: -170 * p };
        ctx.game.audio.play('ball');
      }
    }
    if (this.shot) {
      const s = this.shot;
      s.vy += 260 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      const tableTop = ground - 26;
      for (let k = 0; k < this.glasses.length; k++) {
        const gx = tableX + 8 + k * 12;
        if (this.glasses[k] && Math.abs(s.x - gx) < 6 && s.y > tableTop - 12 && s.y < tableTop) {
          this.glasses[k] = false;
          this.broken++;
          ctx.game.audio.play('hit');
          ctx.notice('DELIGHTFUL!', C.green);
        }
      }
      if (s.y > ground || s.x > w) this.shot = null;
    }
    const g = this.g;
    g.clear();
    g.rect(0, 0, w, h).fill(0xdfe8f2);
    g.rect(0, ground, w, h - ground).fill(0xeef4fa);
    // Catapult
    g.rect(20, ground - 6, 22, 6).fill(0x7a5430);
    g.rect(28, ground - 18, 3, 12).fill(0x5a3a1c);
    // Table with white linen and glasses
    g.rect(tableX, ground - 26, 70, 4).fill(0xffffff);
    g.rect(tableX + 4, ground - 22, 3, 22).fill(0x8a6a4a);
    g.rect(tableX + 62, ground - 22, 3, 22).fill(0x8a6a4a);
    this.glasses.forEach((on, k) => {
      const x = tableX + 6 + k * 12;
      if (on) g.rect(x, ground - 36, 5, 10).fill({ color: 0xa8e0f0, alpha: 0.9 }).stroke({ width: 1, color: 0x5a8aa0 });
      else g.rect(x - 1, ground - 28, 7, 2).fill(0x8ac0d0);
    });
    if (this.shot) g.circle(this.shot.x, this.shot.y, 2.5).fill(0x4a4a4a);
    // Power bar
    const bw = w - 60;
    g.rect(30, h - 80, bw, 8).fill(0x222222);
    g.rect(31, h - 79, Math.round((bw - 2) * this.power), 6).fill(0xff7a1f);
    frameRect(g, 30, h - 80, bw, 8, hex(C.red));
    retroBox(g, 6, 70, w - 12, 18, C.yellow, C.red, 0.4);
    this.label.setText(`SHOTS ${this.shots}  GLASSES ${this.broken}/5`);
    this.label.position.set(Math.round(w / 2), 79);
    if (this.shots === 0 && !this.shot) {
      this.end += dt;
      if (this.end > 0.8) return this.broken >= 1 ? 'won' : 'lost';
    }
    return 'running';
  }
}
