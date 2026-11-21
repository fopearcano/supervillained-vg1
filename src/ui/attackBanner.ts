import { Container } from 'pixi.js';
import { ATTACK } from '../config';
import { PixelText } from './pixelText';
import { C } from './retro';

/**
 * "GREEN ZONE / UNDER ATTACK": a big flashing title when the attack starts, then a small
 * blinking reminder with a hint, and "ZONE SAVED!" when it ends.
 */
export class AttackBanner {
  readonly root = new Container();
  private readonly line1 = new PixelText('GREEN ZONE', { color: C.orange, scale: 2, outline: '#2a0a00', glow: 'self', glowAlpha: 0.4 }).setOrigin(0.5);
  private readonly line2 = new PixelText('UNDER ATTACK', { color: C.yellow, scale: 2, outline: '#2a0a00', glow: 'self', glowAlpha: 0.4 }).setOrigin(0.5);
  private readonly small = new PixelText('UNDER ATTACK!', { color: C.red, outline: '#000000', glow: 'self', glowAlpha: 0.4 }).setOrigin(0.5, 0);
  private readonly hint = new PixelText('', { color: C.white, shadow: '#000000' }).setOrigin(0.5, 0);
  private readonly saved = new PixelText('ZONE SAVED!', { color: C.green, scale: 2, outline: '#002a08', glow: 'self', glowAlpha: 0.4 }).setOrigin(0.5);
  private t = 0;
  private savedT = -1;
  private active = false;
  private w = 216;

  constructor() {
    this.root.addChild(this.line1, this.line2, this.small, this.hint, this.saved);
    this.root.visible = false;
  }

  layout(w: number, h: number): void {
    this.w = w;
    this.line1.position.set(Math.round(w / 2), Math.round(h * 0.36));
    this.line2.position.set(Math.round(w / 2), Math.round(h * 0.36 + 20));
    this.small.position.set(Math.round(w / 2), 58);
    this.hint.position.set(Math.round(w / 2), 70);
    this.saved.position.set(Math.round(w / 2), Math.round(h * 0.4));
  }

  start(): void {
    this.active = true;
    this.t = 0;
    this.savedT = -1;
  }

  end(): void {
    this.active = false;
    this.savedT = 0;
  }

  update(dt: number, hint: string | null): void {
    this.t += dt;
    if (this.savedT >= 0) this.savedT += dt;
    const showSaved = this.savedT >= 0 && this.savedT < 2;
    this.root.visible = this.active || showSaved;
    this.saved.visible = showSaved && Math.floor(this.savedT * 6) % 2 === 0;
    const big = this.active && this.t < ATTACK.TITLE_TIME;
    const flash = Math.floor(this.t * 7) % 2 === 0;
    this.line1.visible = big && flash;
    this.line2.visible = big && (flash || this.t > ATTACK.TITLE_TIME * 0.5);
    // Jitter like a broken signal.
    const j = big && Math.random() < 0.25 ? Math.round((Math.random() * 2 - 1) * 3) : 0;
    this.line1.x = Math.round(this.w / 2) + j;
    this.line2.x = Math.round(this.w / 2) - j;
    this.small.visible = this.active && !big && Math.floor(this.t * 3) % 2 === 0;
    this.hint.visible = this.active && !big && hint !== null;
    if (hint !== null) this.hint.setText(hint);
  }
}
