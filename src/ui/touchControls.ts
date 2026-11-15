import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Input } from '../core/input';
import { INPUT } from '../config';
import { spriteName } from '../assets/manifest';
import { PixelText } from './pixelText';

export interface ButtonLayout {
  peeX: number;
  peeY: number;
  peeR: number;
  barkX: number;
  barkY: number;
  barkR: number;
}

/**
 * Floating virtual joystick + PEE / BARK buttons with the pee-charge indicator.
 */
export class TouchControls {
  readonly root = new Container();
  private readonly joy = new Graphics();
  private readonly peeBtn = new Container();
  private readonly barkBtn = new Container();
  private readonly peeG = new Graphics();
  private readonly barkG = new Graphics();
  private readonly drops: Sprite[] = [];
  private readonly regen = new Graphics();
  private layout: ButtonLayout = { peeX: 0, peeY: 0, peeR: 15, barkX: 0, barkY: 0, barkR: 17 };
  private charges = 0;
  private maxCharges = 3;
  private regenFrac = 0;
  private barkReady = 1;

  constructor(private readonly input: Input) {
    const peeIcon = new Sprite(textures.get(spriteName('peeIcon')));
    const peeLabel = new PixelText('PEE', { color: '#ffe23a', shadow: '#000000' }).setOrigin(0.5, 0);
    peeLabel.y = 6;
    peeIcon.y = -3;
    this.peeBtn.addChild(this.peeG, peeIcon, peeLabel, this.regen);
    const barkIcon = new Sprite(textures.get(spriteName('barkIcon')));
    const barkLabel = new PixelText('BARK', { color: '#3ff0ff', shadow: '#000000' }).setOrigin(0.5, 0);
    barkLabel.y = 7;
    barkIcon.y = -4;
    this.barkBtn.addChild(this.barkG, barkIcon, barkLabel);
    for (let k = 0; k < 3; k++) {
      const d = new Sprite(textures.get(spriteName('drop', 0)));
      this.drops.push(d);
      this.peeBtn.addChild(d);
    }
    this.root.addChild(this.joy, this.peeBtn, this.barkBtn);
  }

  setLayout(l: ButtonLayout): void {
    this.layout = l;
    this.peeBtn.position.set(l.peeX, l.peeY);
    this.barkBtn.position.set(l.barkX, l.barkY);
    this.input.setButton({ id: 'pee', action: 'pee', x: l.peeX, y: l.peeY, r: l.peeR + 4, enabled: true });
    this.input.setButton({ id: 'bark', action: 'bark', x: l.barkX, y: l.barkY, r: l.barkR + 4, enabled: true });
    // Charge droplets on an arc above-left of the PEE button.
    this.drops.forEach((d, k) => {
      const a = Math.PI * (1.05 + k * 0.22);
      d.position.set(Math.round(Math.cos(a) * (l.peeR + 6)), Math.round(Math.sin(a) * (l.peeR + 6)));
    });
    this.redrawButtons();
  }

  setEnabled(on: boolean): void {
    this.root.visible = on;
    for (const id of ['pee', 'bark']) {
      const b = this.input.buttons.get(id);
      if (b) b.enabled = on;
    }
    this.input.joystickEnabled = on;
  }

  setPeeCharges(charges: number, max: number, regenFrac: number): void {
    if (charges === this.charges && max === this.maxCharges && Math.abs(regenFrac - this.regenFrac) < 0.02) return;
    this.charges = charges;
    this.maxCharges = max;
    this.regenFrac = regenFrac;
    this.drops.forEach((d, k) => {
      d.visible = k < max;
      d.texture = textures.get(spriteName('drop', k < charges ? 0 : 1));
    });
    this.redrawButtons();
  }

  setBarkReady(frac: number): void {
    if (Math.abs(frac - this.barkReady) < 0.05) return;
    this.barkReady = frac;
    this.redrawButtons();
  }

  private redrawButtons(): void {
    const l = this.layout;
    const pressedPee = this.input.buttons.get('pee')?.pressed ?? false;
    const pressedBark = this.input.buttons.get('bark')?.pressed ?? false;
    drawButton(this.peeG, l.peeR, 0xffe23a, 0xff3b3b, pressedPee, this.charges > 0 ? 1 : 0.35);
    drawButton(this.barkG, l.barkR, 0x3ff0ff, 0xb040ff, pressedBark, 0.4 + 0.6 * this.barkReady);
    this.regen.clear();
    if (this.charges < this.maxCharges && this.regenFrac > 0) {
      this.regen.arc(0, 0, l.peeR + 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * this.regenFrac).stroke({ width: 1, color: 0xffe23a, alpha: 0.9 });
    }
  }

  private lastPressed = '';

  update(): void {
    const j = this.input.joystick;
    this.joy.clear();
    if (j.active) {
      const R = INPUT.JOYSTICK_RADIUS;
      this.joy.circle(Math.round(j.baseX), Math.round(j.baseY), R).fill({ color: 0x000000, alpha: 0.18 }).stroke({ width: 1, color: 0xffe23a, alpha: 0.8 });
      this.joy.circle(Math.round(j.baseX), Math.round(j.baseY), R - 3).stroke({ width: 1, color: 0xff3b3b, alpha: 0.5 });
      const dx = j.knobX - j.baseX;
      const dy = j.knobY - j.baseY;
      const len = Math.hypot(dx, dy);
      const k = len > R ? R / len : 1;
      this.joy
        .circle(Math.round(j.baseX + dx * k), Math.round(j.baseY + dy * k), 8)
        .fill({ color: 0x3ff0ff, alpha: 0.55 })
        .stroke({ width: 1, color: 0xffffff, alpha: 0.9 });
    }
    const pressed = `${this.input.buttons.get('pee')?.pressed}|${this.input.buttons.get('bark')?.pressed}`;
    if (pressed !== this.lastPressed) {
      this.lastPressed = pressed;
      this.redrawButtons();
    }
  }
}

function drawButton(g: Graphics, r: number, ring: number, ring2: number, pressed: boolean, alpha: number): void {
  g.clear();
  g.circle(0, 0, r).fill({ color: pressed ? ring : 0x000000, alpha: pressed ? 0.45 : 0.28 });
  g.circle(0, 0, r).stroke({ width: 1, color: ring, alpha });
  g.circle(1, 1, r - 2).stroke({ width: 1, color: ring2, alpha: alpha * 0.8 });
}
