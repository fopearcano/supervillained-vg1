import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Emitter, GameEvents } from '../core/events';
import { FX } from '../config';
import { spriteName } from '../assets/manifest';
import type { Zampano } from '../entities/zampano';
import type { Camera } from '../iso/camera';
import { dirToScreenVector, gridToScreen } from '../iso/projection';
import { C } from '../ui/retro';
import { Particles } from './particles';
import { Popups } from './popups';

interface Ring {
  x: number;
  y: number;
  radius: number;
  t: number;
  dur: number;
  color: number;
}

const GEO_COLORS = [0xff9a1f, 0xb040ff, 0x6ad8ff, 0xff4fa8, 0xffe23a];

/**
 * Visual reactions to gameplay events: popups, particles, pee rings, the digestion bubble,
 * screen shake. Everything here is cosmetic.
 */
export class GameFx {
  readonly below = new Container();
  readonly above = new Container();
  readonly particles = new Particles();
  readonly popups = new Popups();
  private readonly rings: Ring[] = [];
  private readonly ringG = new Graphics();
  private readonly bubble: Sprite;
  private time = 0;
  private streamTimer = 0;

  constructor(
    events: Emitter<GameEvents>,
    private readonly player: Zampano,
    private readonly camera: Camera,
    private readonly bubbleState: () => number,
  ) {
    this.below.addChild(this.ringG);
    this.above.addChild(this.particles.root, this.popups.root);
    this.bubble = new Sprite(textures.get(spriteName('thought')));
    this.bubble.visible = false;
    this.bubble.scale.set(2);
    this.above.addChild(this.bubble);

    const at = (x: number, y: number, lift = 0) => {
      const s = gridToScreen(x, y);
      return { x: s.x, y: s.y - lift };
    };

    events.on('treat', (e) => {
      const p = at(e.x, e.y, 26);
      this.popups.icon('treat', p.x, p.y - 8, 3, FX.POPUP_TIME, -10);
      this.particles.burst(p.x, p.y, {
        count: 14,
        textures: ['tri', 'cross', 'ring', 'pixel'],
        colors: GEO_COLORS,
        speed: [40, 90],
        life: [0.5, 0.9],
        drag: 3,
        spread: 6,
      });
    });
    events.on('score', (e) => {
      const p = at(e.x, e.y, 34);
      const label = e.label ? `${e.label} +${e.amount}` : `+${e.amount}`;
      this.popups.text(label, p.x, p.y, { color: e.label ? C.yellow : C.cyan, glow: 'self', glowAlpha: 0.3 }, FX.SCORE_POPUP_TIME);
    });
    events.on('poop', (e) => {
      const p = at(e.x, e.y, 30);
      this.popups.icon('poop', p.x, p.y, 3, FX.POPUP_TIME, -8);
      const g = at(e.x, e.y);
      this.particles.burst(g.x, g.y, {
        count: 10,
        textures: ['pixel'],
        colors: [0x6e4a1c, 0x8f6a30, 0x4a2e0e],
        speed: [20, 50],
        life: [0.4, 0.7],
        gravity: 120,
        angle: [-Math.PI * 0.95, -Math.PI * 0.05],
      });
      this.camera.shake(FX.SHAKE_POOP);
      const label = e.surface === 'low' ? 'HIDDEN!' : e.surface === 'heavy' ? 'ON THE PATH!' : null;
      if (label) this.popups.text(label, p.x, p.y - 30, { color: e.surface === 'low' ? C.green : C.orange, glow: 'self' }, 1.2, -10);
    });
    events.on('pee', (e) => {
      const p = at(e.x, e.y, 30);
      this.popups.icon('rainbow', p.x, p.y, 2, FX.POPUP_TIME, -10);
      const g = at(e.x, e.y);
      this.rings.push({ x: g.x, y: g.y, radius: e.radius, t: 0, dur: e.marking ? 0.9 : 0.7, color: 0xfff36a });
      if (e.marking) this.rings.push({ x: g.x, y: g.y, radius: e.radius * 0.6, t: -0.15, dur: 0.8, color: 0x7aff4a });
      this.streamTimer = e.marking ? 0.85 : 0.65;
    });
    events.on('peeEmpty', (e) => {
      const p = at(e.x, e.y, 36);
      this.popups.text('EMPTY!', p.x, p.y, { color: C.orange, glow: 'self' }, 0.8, -14);
    });
    events.on('poopCleaned', (e) => {
      const g = at(e.x, e.y, 4);
      this.particles.burst(g.x, g.y, {
        count: 8,
        textures: ['sparkle'],
        colors: [0xffffff, 0xfff36a, 0x9dff7a],
        speed: [20, 50],
        life: [0.4, 0.8],
        drag: 3,
      });
    });
    events.on('drink', (e) => {
      const g = at(e.x, e.y, 6);
      this.particles.burst(g.x, g.y, {
        count: 10,
        textures: ['pixel'],
        colors: [0x8fd0ff, 0x3b8cff, 0xffffff],
        speed: [20, 55],
        life: [0.35, 0.6],
        gravity: 140,
        angle: [-Math.PI * 0.9, -Math.PI * 0.1],
      });
      const p = at(e.x, e.y, 36);
      this.popups.text('PEE REFILL!', p.x, p.y, { color: C.yellow, glow: 'self' }, 1, -14);
    });
    events.on('lifeLost', (e) => {
      const p = at(e.x, e.y, 38);
      this.popups.text(e.lives > 0 ? 'STARVING! -1' : 'STARVED!', p.x, p.y, { color: C.red, glow: 'self', scale: 1 }, 1.4, -10);
      this.camera.shake(FX.SHAKE_HURT);
    });
  }

  update(dt: number): void {
    this.time += dt;
    this.particles.update(dt);
    this.popups.update(dt);
    // Pee stream: little yellow drops falling from Zampanò.
    if (this.streamTimer > 0) {
      this.streamTimer -= dt;
      const s = gridToScreen(this.player.gx, this.player.gy);
      const back = dirToScreenVector(this.player.facing);
      this.particles.burst(s.x - back.x * 6, s.y - 8, {
        count: 1,
        textures: ['pixel'],
        colors: [0xffe23a, 0xfff36a],
        speed: [10, 25],
        life: [0.18, 0.3],
        gravity: 260,
        angle: [Math.PI * 0.3, Math.PI * 0.7],
      });
    }
    // Rings: iso ellipses expanding to the cleaned radius (grid circle → screen ellipse).
    const g = this.ringG;
    g.clear();
    for (let k = this.rings.length - 1; k >= 0; k--) {
      const r = this.rings[k]!;
      r.t += dt;
      if (r.t >= r.dur) {
        this.rings.splice(k, 1);
        continue;
      }
      if (r.t < 0) continue;
      const u = r.t / r.dur;
      const e = 1 - (1 - u) * (1 - u);
      const rx = r.radius * 16 * Math.SQRT2 * e;
      const ry = r.radius * 8 * Math.SQRT2 * e;
      g.ellipse(Math.round(r.x), Math.round(r.y), Math.max(1, rx), Math.max(1, ry)).stroke({ width: 1, color: r.color, alpha: 1 - u });
    }
    // Digestion warning bubble above Zampanò's head.
    const w = this.bubbleState();
    if (w >= 0) {
      const s = gridToScreen(this.player.gx, this.player.gy);
      this.bubble.visible = w > 1 || Math.floor(this.time * 8) % 2 === 0;
      this.bubble.position.set(Math.round(s.x + 6), Math.round(s.y - 34 - Math.abs(Math.sin(this.time * 6)) * 2));
    } else {
      this.bubble.visible = false;
    }
  }
}
