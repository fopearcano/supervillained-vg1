import { Graphics } from 'pixi.js';
import { PixelText } from '../../ui/pixelText';
import { C, frameRect, hex } from '../../ui/retro';
import { STORY } from '../../config';
import type { Autopilot } from '../autopilot';
import type { StoryScene } from '../storyScene';
import { MiniGame, type MiniResult } from './miniGame';

interface Button {
  x: number;
  y: number;
  w: number;
  h: number;
  t: PixelText;
  id: string;
}

/** Tappable text buttons (shared by the word games). */
abstract class WordGame extends MiniGame {
  protected readonly g = new Graphics();
  protected buttons: Button[] = [];
  protected readonly head = new PixelText('', { color: C.yellow, shadow: '#000000', align: 'center', lineGap: 3 }).setOrigin(0.5, 0);
  protected readonly body = new PixelText('', { color: '#3a2410', lineGap: 4 });

  constructor() {
    super();
    this.hidesStage = true;
    this.root.addChild(this.g, this.head, this.body);
  }

  protected clearButtons(): void {
    for (const b of this.buttons) b.t.destroy();
    this.buttons = [];
  }

  protected button(id: string, label: string, x: number, y: number, w: number, color: string = C.cyan): void {
    const t = new PixelText(label, { color, shadow: '#000000', maxWidth: w - 8, align: 'center' }).setOrigin(0.5);
    const h = Math.max(16, t.textHeight + 8);
    t.position.set(Math.round(x + w / 2), Math.round(y + h / 2));
    this.root.addChild(t);
    this.buttons.push({ x, y, w, h, t, id });
  }

  protected drawButtons(): void {
    for (const b of this.buttons) {
      this.g.rect(b.x, b.y, b.w, b.h).fill({ color: 0x000000, alpha: 0.6 });
      frameRect(this.g, b.x, b.y, b.w, b.h, hex(C.red));
      frameRect(this.g, b.x + 1, b.y + 1, b.w - 1, b.h - 1, hex(C.yellow), 0.9);
    }
  }

  /** Index of the tapped button (or keyboard selection), else null. */
  protected tapped(ctx: StoryScene): string | null {
    for (const tap of ctx.game.input.consumeTaps()) {
      const b = this.buttons.find((q) => tap.x >= q.x && tap.x <= q.x + q.w && tap.y >= q.y && tap.y <= q.y + q.h);
      if (b) return b.id;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------- letter

/** The barons' writing table: slot 1 either pleads necessity or names the debt outright. */
const SLOTS: Array<{ before: string; options: string[] }> = [
  { before: 'HOLY FATHER, AT ZARA WE ', options: ['WERE COMPELLED', 'TOOK THE CITY', 'CORRECTED THE CITY', 'STAYED A WHILE'] },
  { before: ', BY ', options: ['NECESSITY', 'OUR DEBT TO VENICE', 'THE WINTER', 'A MISUNDERSTANDING'] },
  { before: '. WE ARE ', options: ['PENITENT', 'DEEPLY SORRY', 'AVAILABLE FOR PENANCE', 'STILL PILGRIMS'] },
];

/** The version read aloud names the city and the debt outright. */
const NAMES_THE_DEBT = 1;

/**
 * 5.4: assemble the barons' account from the words on their writing table and read it aloud.
 * "Necessity" or the debt named outright; the reply that comes back from Rome has two versions
 * (Villehardouin: the pilgrims absolved; Clari 15: everyone, the Venetians too).
 */
export class LetterGame extends MiniGame {
  private readonly g = new Graphics();
  private readonly text = new PixelText('', { color: '#3a2410', lineGap: 4 });
  private readonly answer = new PixelText('', { color: '#8a1a10', lineGap: 4, align: 'justify' });
  private readonly picks = [0, 0, 0];
  private sent = 0;
  private phase: 'write' | 'answer' = 'write';
  private buttons: Array<{ id: string; x: number; y: number; w: number; h: number; t: PixelText }> = [];

  constructor() {
    super();
    this.hidesStage = true;
    this.objective = "ASSEMBLE THE BARONS' ACCOUNT (TAP A WORD TO CHANGE IT)";
    this.root.addChild(this.g, this.text, this.answer);
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
    this.rebuild();
  }

  private rebuild(): void {
    for (const b of this.buttons) b.t.destroy();
    this.buttons = [];
    const { w } = this;
    const add = (id: string, label: string, y: number, color: string) => {
      const t = new PixelText(label, { color, shadow: '#000000', maxWidth: w - 40, align: 'center' }).setOrigin(0.5);
      const h = t.textHeight + 8;
      t.position.set(Math.round(w / 2), Math.round(y + h / 2));
      this.root.addChild(t);
      this.buttons.push({ id, x: 16, y, w: w - 32, h, t });
      return h;
    };
    let y = 200;
    if (this.phase === 'write') {
      SLOTS.forEach((s, k) => {
        y += add(`slot${k}`, `< ${s.options[this.picks[k]!]} >`, y, C.cyan) + 4;
      });
      add('send', 'READ IT ALOUD AND SEND IT', y + 6, C.yellow);
    } else {
      y = 320;
      y += add('again', 'WRITE IT AGAIN', y, C.cyan) + 4;
      add('accept', 'HEAR THE ANSWER OUT', y, C.green);
    }
  }

  update(_dt: number, ctx: StoryScene): MiniResult {
    const { w } = this;
    let pick: string | null = null;
    for (const tap of ctx.game.input.consumeTaps()) {
      const b = this.buttons.find((q) => tap.x >= q.x && tap.x <= q.x + q.w && tap.y >= q.y && tap.y <= q.y + q.h);
      if (b) pick = b.id;
    }
    if (ctx.game.input.consume('confirm')) pick = this.phase === 'write' ? 'send' : 'accept';
    if (pick) ctx.game.audio.play('click');
    if (pick?.startsWith('slot')) {
      const k = Number(pick.slice(4));
      this.picks[k] = (this.picks[k]! + 1) % SLOTS[k]!.options.length;
      this.rebuild();
    } else if (pick === 'send') {
      this.sent++;
      this.phase = 'answer';
      ctx.game.audio.play('star');
      this.rebuild();
    } else if (pick === 'again') {
      this.phase = 'write';
      this.rebuild();
    } else if (pick === 'accept') {
      ctx.apply({ flags: { letter: this.picks[1] === NAMES_THE_DEBT ? 'named' : 'necessity' } });
      return 'won';
    }

    const g = this.g;
    g.clear();
    g.rect(0, 0, w, this.h).fill(0x1a0e06);
    g.rect(8, 76, w - 16, 116).fill(0xf0dcb0);
    for (const b of this.buttons) {
      g.rect(b.x, b.y, b.w, b.h).fill({ color: 0x000000, alpha: 0.65 });
      frameRect(g, b.x, b.y, b.w, b.h, hex(C.red));
    }
    const letter = SLOTS.map((s, k) => `${s.before}${s.options[this.picks[k]!]}`).join('') + '.';
    this.text.setText(letter);
    this.text.setStyle({ maxWidth: w - 32 });
    this.text.position.set(16, 84);
    this.answer.visible = this.phase === 'answer';
    this.answer.setText(
      `LETTER ${this.sent}. THE ENVOYS COME BACK FROM ROME. THE MARSHAL SAYS THE POPE HAS ABSOLVED THE PILGRIMS. THE CAMP SAYS THE LETTERS ABSOLVE EVERYONE, THE VENETIANS TOO. ZAMPANO HEARS BOTH ON THE SAME DAY.`,
    );
    this.answer.setStyle({ maxWidth: w - 32 });
    this.answer.position.set(16, 200);
    return 'running';
  }

  /** Autopilot: change one word, then seal, send and accept. */
  override pilot(_dt: number, ctx: StoryScene, p: Autopilot): void {
    if (!p.tick('letter', 0.8)) return;
    const word = this.buttons.find((b) => b.id === 'slot0');
    if (this.phase === 'write' && this.picks[0] === 0 && word) p.tap(ctx, word.x + word.w / 2, word.y + word.h / 2);
    else p.press(ctx, 'confirm');
  }
}

// ---------------------------------------------------------------------------- rumour

const RUMOUR = [
  'YOUNG ALEXIOS, SON OF THE DEPOSED EMPEROR ISAAC II',
  '"HELP ME PUT MY FATHER BACK ON HIS THRONE"',
  '"TWO HUNDRED THOUSAND MARKS"',
  '"FOOD FOR THE WHOLE HOST FOR A YEAR"',
  '"TEN THOUSAND MEN FOR EGYPT, FIVE HUNDRED KNIGHTS FOR LIFE"',
  '"AND THE GREEK CHURCH WILL OBEY ROME"',
];

const GARBLE: Record<number, string> = {
  0: 'ALEXIOS... ISAAC... DEPOSED?',
  1: '...FATHER... THRONE... HELP?',
  2: '...TWO HUNDRED... THOUSAND?',
  3: '...FOOD... A WHOLE YEAR?',
  4: '...MEN... EGYPT... KNIGHTS?',
  5: '...GREEKS... CHURCH... ROME?',
};

/** 6.2: piece together young Alexios's offer (Villehardouin pp. 23-24), garbled on its way from the council tent. */
export class RumourGame extends WordGame {
  private order: number[] = [];
  private placed: number[] = [];
  private arrived = 0;
  private arriveT = 0;

  constructor() {
    super();
    this.objective = 'PUT THE GARBLED NEWS IN ORDER';
    const idx = RUMOUR.map((_, k) => k);
    for (let k = idx.length - 1; k > 0; k--) {
      const j = Math.floor(Math.random() * (k + 1));
      [idx[k], idx[j]] = [idx[j]!, idx[k]!];
    }
    this.order = idx;
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
  }

  private rebuild(): void {
    this.clearButtons();
    const { w } = this;
    let y = 220;
    this.order.slice(0, this.arrived).forEach((k) => {
      if (this.placed.includes(k)) return;
      this.button(String(k), GARBLE[k]!, 10, y, w - 20);
      y += this.buttons[this.buttons.length - 1]!.h + 4;
    });
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const { w, h } = this;
    this.arriveT -= dt;
    if (this.arrived < RUMOUR.length && this.arriveT <= 0) {
      this.arriveT = STORY.RUMOUR.ARRIVE_EVERY;
      this.arrived++;
      ctx.game.audio.play('click');
      this.rebuild();
    }
    const id = this.tapped(ctx);
    if (id !== null) {
      const k = Number(id);
      if (k === this.placed.length) {
        this.placed.push(k);
        ctx.game.audio.play('treat');
      } else {
        ctx.notice('GARBLED: THAT CAME LATER', C.red);
        ctx.game.audio.play('empty');
      }
      this.rebuild();
    }
    const g = this.g;
    g.clear();
    g.rect(0, 0, w, h).fill(0x0e1420);
    g.rect(8, 76, w - 16, 136).fill(0xf0dcb0);
    this.drawButtons();
    this.head.setText("ALEXIOS'S PROMISE, AS IT REACHED HIM");
    this.head.position.set(Math.round(w / 2), 64);
    this.body.setText(this.placed.map((k, n) => `${n + 1}. ${RUMOUR[k]}`).join('\n') || 'TAP THE PIECES IN THE ORDER THEY HAPPENED...');
    this.body.setStyle({ maxWidth: w - 32 });
    this.body.position.set(16, 84);
    return this.placed.length === RUMOUR.length ? 'won' : 'running';
  }

  /** Autopilot: read for a moment, then tap the piece that comes next (sometimes the wrong one). */
  override pilot(_dt: number, ctx: StoryScene, p: Autopilot): void {
    if (!p.tick('rumour', 0.9 - p.policy.skill * 0.4)) return;
    const right = this.buttons.find((b) => b.id === String(this.placed.length));
    const wrong = this.buttons.find((b) => b.id !== String(this.placed.length));
    const b = wrong && p.random() > 0.75 + 0.25 * p.policy.skill ? wrong : right;
    if (b) p.tap(ctx, b.x + b.w / 2, b.y + b.h / 2);
  }
}
