import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Game } from '../core/game';
import type { Scene } from '../core/scene';
import { spriteName } from '../assets/manifest';
import type { CampaignState } from '../campaign/state';
import type { ChapterDef } from '../campaign/types';
import { Menu, type MenuItem } from '../ui/menu';
import { PixelText, type Span } from '../ui/pixelText';
import { C, retroBox } from '../ui/retro';

/** Full-screen card with stacked texts; tap to continue. */
export class StoryCardScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly bg = new Graphics();
  private readonly items: Array<{ t: PixelText | Sprite; gap: number }> = [];
  private readonly tap = new PixelText('TAP TO CONTINUE', { color: C.yellow, shadow: '#000000' }).setOrigin(0.5);
  private time = 0;

  constructor(
    private readonly game: Game,
    private readonly bgColor: number,
    lines: Array<{ text: string | Span[]; color?: string; scale?: number; gap?: number; align?: 'center' | 'justify' | 'left'; portrait?: boolean }>,
    private readonly onDone: () => void,
  ) {
    this.root.addChild(this.bg);
    for (const l of lines) {
      if (l.portrait) {
        const s = new Sprite(textures.get(spriteName('professorFace')));
        s.scale.set(2);
        s.anchor.set(0.5, 0);
        this.items.push({ t: s, gap: l.gap ?? 8 });
        this.root.addChild(s);
        continue;
      }
      const t = new PixelText(l.text, {
        color: l.color ?? C.white,
        scale: l.scale ?? 1,
        outline: (l.scale ?? 1) > 1 ? '#120818' : null,
        shadow: (l.scale ?? 1) > 1 ? null : '#000000',
        glow: (l.scale ?? 1) > 1 ? 'self' : null,
        glowAlpha: 0.3,
        align: l.align ?? 'center',
        lineGap: 4,
      }).setOrigin(0.5, 0);
      this.items.push({ t, gap: l.gap ?? 8 });
      this.root.addChild(t);
    }
    this.root.addChild(this.tap);
  }

  resize(w: number, h: number): void {
    this.bg.clear().rect(0, 0, w, h).fill(this.bgColor);
    let total = 0;
    for (const it of this.items) {
      if (it.t instanceof PixelText) it.t.setStyle({ maxWidth: w - 20 });
      total += (it.t instanceof PixelText ? it.t.textHeight : it.t.height) + it.gap;
    }
    let y = Math.max(16, Math.round(h * 0.45 - total / 2));
    for (const it of this.items) {
      it.t.position.set(Math.round(w / 2), y);
      y += (it.t instanceof PixelText ? it.t.textHeight : it.t.height) + it.gap;
    }
    this.tap.position.set(Math.round(w / 2), h - 24);
  }

  update(dt: number): void {
    this.time += dt;
    this.tap.visible = this.time > 0.8 && Math.floor(this.time * 2.5) % 2 === 0;
    const input = this.game.input;
    const taps = input.consumeTaps().length > 0;
    if (this.time > 0.6 && (taps || input.consume('confirm') || input.consume('bark') || input.consume('pee'))) this.onDone();
  }
}

/** Level select: eight levels, progress, shards, the book. */
export class StoryMenuScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly bg = new Graphics();
  private readonly title = new PixelText('THE DREAM OF THE CROSS', { color: C.yellow, outline: '#120818', glow: 'self', glowAlpha: 0.3 }).setOrigin(0.5, 0);
  private readonly sub = new PixelText('SUPERVILLAINED - STORY', { color: '#9aa4c0', shadow: '#000000' }).setOrigin(0.5, 0);
  private readonly menu: Menu;
  private readonly meters = new PixelText('', { color: C.white, shadow: '#000000', align: 'center', lineGap: 3 }).setOrigin(0.5, 0);
  private time = 0;

  constructor(
    private readonly game: Game,
    state: CampaignState,
    chapters: readonly ChapterDef[],
    actions: {
      play: (chapter: ChapterDef) => void;
      cont: () => void;
      book: () => void;
      reset: () => void;
      back: () => void;
      unlocked: (chapter: ChapterDef) => boolean;
    },
  ) {
    const items: MenuItem[] = [{ label: state.completed.length ? 'CONTINUE' : 'BEGIN THE DREAM', action: actions.cont, color: C.green }];
    for (const ch of chapters) {
      const done = ch.subLevels.filter((s) => state.completed.includes(s.id)).length;
      const open = actions.unlocked(ch);
      items.push({
        label: open ? `${ch.number} ${(ch.menuTitle ?? ch.title).toUpperCase()} ${done}/${ch.subLevels.length}` : `${ch.number} ? ? ?`,
        action: () => (open ? actions.play(ch) : this.game.audio.play('empty')),
        color: !open ? '#5a5a6a' : done === ch.subLevels.length ? C.cyan : C.yellow,
      });
    }
    items.push({ label: 'MERAVIGLIA BOOK', action: actions.book, color: C.pink });
    items.push({ label: 'RESET STORY', action: actions.reset, color: '#8a8aa0' });
    items.push({ label: 'BACK', action: actions.back, color: C.white });
    this.menu = new Menu(items, 200, 14, 3);
    const m = state.meters;
    this.meters.setText(`COMMOZIONE ${m.commozione}  GRACE ${m.grace}\nSUPERVILLAIN ${m.supervillain}  COINS ${state.coins}`);
    this.root.addChild(this.bg, this.title, this.sub, this.meters, this.menu.root);
  }

  resize(w: number, h: number): void {
    this.bg.clear().rect(0, 0, w, h).fill(0x140a24);
    for (let k = 0; k < 40; k++) this.bg.rect((k * 53) % w, (k * 97) % h, 1, 1).fill({ color: 0xffffff, alpha: 0.5 });
    this.title.position.set(Math.round(w / 2), 10);
    this.sub.position.set(Math.round(w / 2), 22);
    this.meters.position.set(Math.round(w / 2), 34);
    this.menu.layout(w / 2, 58);
  }

  update(dt: number): void {
    this.time += dt;
    if (this.time > 0.3) this.menu.update(dt, this.game.input);
  }
}

/** Story pause menu. */
export class StoryPauseScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly dim = new Graphics();
  private readonly box = new Graphics();
  private readonly title = new PixelText('PAUSED', { color: C.yellow, scale: 2, outline: '#120818', glow: 'self', glowAlpha: 0.3 }).setOrigin(0.5);
  private readonly menu: Menu;

  constructor(
    private readonly game: Game,
    private readonly actions: { resume: () => void; restart: () => void; book: () => void; sound: () => void; muted: () => boolean; skip: () => void; menu: () => void },
  ) {
    this.menu = new Menu(
      [
        { label: 'RESUME', action: actions.resume, color: C.green },
        { label: 'RESTART SCENE', action: actions.restart, color: C.yellow },
        { label: 'SKIP SCENE', action: actions.skip, color: '#9aa4c0' },
        { label: 'MERAVIGLIA BOOK', action: actions.book, color: C.pink },
        {
          label: () => (actions.muted() ? 'SOUND: OFF' : 'SOUND: ON'),
          action: () => {
            actions.sound();
            this.menu.refreshLabels();
          },
          color: C.cyan,
        },
        { label: 'STORY MENU', action: actions.menu, color: C.white },
      ],
      140,
      16,
      4,
    );
    this.root.addChild(this.dim, this.box, this.title, this.menu.root);
  }

  resize(w: number, h: number): void {
    this.dim.clear().rect(0, 0, w, h).fill({ color: 0x000000, alpha: 0.55 });
    const bh = 36 + this.menu.height + 10;
    const top = Math.round(h / 2 - bh / 2);
    this.box.clear();
    retroBox(this.box, Math.round(w / 2 - 80), top, 160, bh, C.red, C.yellow, 0.65);
    this.title.position.set(Math.round(w / 2), top + 16);
    this.menu.layout(w / 2, top + 32);
  }

  update(dt: number): void {
    const input = this.game.input;
    if (input.consume('menu') || input.consume('back')) {
      this.actions.resume();
      return;
    }
    this.menu.update(dt, input);
  }
}

/** The Meraviglia book: meters, values, marvels, things brought home, remembered lines. */
export class BookScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly bg = new Graphics();
  private readonly title = new PixelText('MERAVIGLIA', { color: C.yellow, scale: 2, outline: '#3a2410', glow: 'self', glowAlpha: 0.25 }).setOrigin(0.5, 0);
  private readonly body = new PixelText('', { color: '#3a2410', lineGap: 3 });
  private readonly foot = new PixelText('', { color: '#6a4a20' }).setOrigin(0.5, 0);
  private pages: Span[][] = [];
  private page = 0;
  private h = 400;
  private time = 0;

  constructor(
    private readonly game: Game,
    private readonly state: CampaignState,
    private readonly onClose: () => void,
  ) {
    this.root.addChild(this.bg, this.title, this.body, this.foot);
  }

  private build(): void {
    const s = this.state;
    const lines: Span[][] = [];
    const head = (t: string) => lines.push([{ text: t, color: '#8a2a10' }]);
    const item = (t: string) => lines.push([{ text: `- ${t}` }]);
    head('THE METERS');
    item(`COMMOZIONE ${s.meters.commozione}`);
    item(`SUPERVILLAIN ${s.meters.supervillain}${s.meters.supervillain >= 100 ? ' (FULL)' : ''}`);
    item(`GRACE ${s.meters.grace}`);
    item(`STANDING ${s.meters.standing}`);
    lines.push([{ text: '' }]);
    head('VALUES LEARNED');
    if (!s.book.values.length) item('NONE YET');
    for (const v of s.book.values) item(v.toUpperCase());
    lines.push([{ text: '' }]);
    head('MARVELS SEEN');
    if (!s.book.marvels.length) item('NONE YET');
    for (const v of s.book.marvels) item(v.toUpperCase());
    lines.push([{ text: '' }]);
    head('BROUGHT HOME');
    if (!s.book.items.length) item('NOTHING YET');
    for (const v of s.book.items) item(v.toUpperCase());
    lines.push([{ text: '' }]);
    head('MEMORY SHARDS');
    if (!s.book.shards.length) item('NONE YET');
    for (const v of s.book.shards) item(v.toUpperCase());
    lines.push([{ text: '' }]);
    head('REMEMBERED (IT MADE NO SENSE)');
    if (!s.book.remembered.length) item('NOTHING YET');
    for (const v of s.book.remembered) item(`"${v.toUpperCase()}"`);
    const per = Math.max(6, Math.floor((this.h - 80) / 11));
    this.pages = [];
    for (let k = 0; k < lines.length; k += per) {
      const chunk = lines.slice(k, k + per);
      const spans: Span[] = [];
      chunk.forEach((l, i) => {
        spans.push(...l);
        if (i < chunk.length - 1) spans.push({ text: '\n' });
      });
      this.pages.push(spans);
    }
    this.page = Math.min(this.page, this.pages.length - 1);
  }

  private show(): void {
    this.body.setText(this.pages[this.page] ?? []);
    this.foot.setText(`PAGE ${this.page + 1}/${this.pages.length}  TAP: NEXT`);
  }

  resize(w: number, h: number): void {
    this.h = h;
    this.bg.clear().rect(0, 0, w, h).fill(0x1a0e06);
    this.bg.rect(4, 4, w - 8, h - 8).fill(0xf0dcb0);
    this.bg.rect(4, 4, w - 8, 2).fill(0xc8a060);
    this.title.position.set(Math.round(w / 2), 10);
    this.body.position.set(12, 40);
    this.body.setStyle({ maxWidth: w - 24 });
    this.foot.position.set(Math.round(w / 2), h - 18);
    this.build();
    this.show();
  }

  update(dt: number): void {
    this.time += dt;
    const input = this.game.input;
    if (input.consume('menu') || input.consume('back')) {
      this.onClose();
      return;
    }
    const tap = input.consumeTaps().length > 0 || input.consume('confirm') || input.consume('down') || input.consume('right');
    if (this.time > 0.3 && tap) {
      if (this.page < this.pages.length - 1) {
        this.page++;
        this.show();
        this.game.audio.play('click');
      } else this.onClose();
    }
  }
}
