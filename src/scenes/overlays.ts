import { Container, Graphics, Sprite } from 'pixi.js';
import { TITLE } from '../config';
import type { TitleGlitchFilter } from '../fx/titleGlitchFilter';
import { loadTitleArt, titleTexture, type TitleArt } from '../ui/titleArt';
import { textures } from '../core/assets';
import type { Game } from '../core/game';
import type { Scene } from '../core/scene';
import { formatScore, formatTime, type LevelStats } from '../systems/scoring';
import { Menu, type MenuItem } from '../ui/menu';
import { PixelText, type Span } from '../ui/pixelText';
import { logoTexture, logoWidth, type LogoStyle } from '../ui/logo';
import { C, retroBox } from '../ui/retro';
import { spriteName } from '../assets/manifest';
import type { LevelDef } from '../world/level';

/** Shared bits for the menu-like overlays. */
abstract class Overlay implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  protected readonly dim = new Graphics();
  protected w = 216;
  protected h = 400;
  protected time = 0;

  constructor(
    protected readonly game: Game,
    protected readonly dimAlpha: number,
  ) {
    this.root.addChild(this.dim);
  }

  resize(w: number, h: number): void {
    this.w = w;
    this.h = h;
    this.dim.clear().rect(0, 0, w, h).fill({ color: 0x000000, alpha: this.dimAlpha });
    this.layout();
  }

  protected abstract layout(): void;

  update(dt: number): void {
    this.time += dt;
  }
}

const big = (text: string, color: string, scale: number, extra: Partial<ConstructorParameters<typeof PixelText>[1]> = {}) =>
  new PixelText(text, { color, scale, outline: '#120818', glow: 'self', glowAlpha: 0.3, ...extra }).setOrigin(0.5, 0.5);

const LOGO_TEXT = 'SUPERVILLAINED';
const LOGO_STYLE: LogoStyle = { colors: ['#f2ffb0', '#d4ff3a', '#9ccc1a'], outline: '#120818', shadow: '#2a4a08', glow: '#d4ff3a' };

export interface TitleActions {
  newGame: () => void;
  cont: () => void;
  options: () => void;
  quit: () => void;
  /** Where Continue goes ("LEVEL 3: 3.2 ..."), or null when there is no saved story. */
  continueLabel: string | null;
  /** The background's glitch filter, animated by the title (mostly vertical bursts). */
  glitch?: TitleGlitchFilter;
}

/**
 * Title page over the blurred, glitching Green Zone: the SUPERVILLAINED logo and CRUSADER at the
 * top, Zampanò's portrait, NEW GAME / CONTINUE / OPTIONS / QUIT, SUPERVOID EDITIONS at the bottom.
 * (The "You've been supervillained" logo is kept for the end of each level: SupervillainedScene.)
 */
export class TitleScene extends Overlay {
  /** Zampanò's portrait (title art) over the buttons. */
  private readonly dog = new Sprite();
  private art: TitleArt | null = null;
  private burstLeft = 0;
  private nextBurst = 1;
  /** The logo: always one line (see ui/logo.ts). */
  private readonly title = new Sprite();
  private titleScale = 0;
  /** Edition title under the logo. */
  private readonly edition: PixelText;
  /** Where Continue goes. */
  private readonly best: PixelText;
  private readonly menu: Menu;
  /** Publisher line: the smallest crisp size of the pixel font (scale 1), dimmed. */
  private readonly footer = new PixelText('SUPERVOID EDITIONS', { color: '#8ad4ff', letterSpacing: 1 }).setOrigin(0.5, 1);

  constructor(
    game: Game,
    private readonly actions: TitleActions,
  ) {
    super(game, 0.15);
    this.edition = big('CRUSADER', C.hotPink, 1, { letterSpacing: 6, glow: C.hotPink, glowAlpha: 0.5 });
    const canContinue = actions.continueLabel !== null;
    this.best = new PixelText(canContinue ? actions.continueLabel! : '', {
      color: C.cyan,
      shadow: '#000000',
      align: 'center',
      maxWidth: 190,
    }).setOrigin(0.5, 0);
    this.menu = new Menu(
      [
        { label: 'NEW GAME', action: actions.newGame, color: C.red },
        // Always yellow: with no saved story, CONTINUE simply starts it (see Flow.toTitle).
        { label: 'CONTINUE', action: actions.cont, color: C.yellow },
        { label: 'OPTIONS', action: actions.options, color: C.cyan },
        { label: 'QUIT', action: actions.quit, color: C.pink },
      ],
      150,
      18,
      6,
    );
    if (canContinue) this.menu.selected = 1;
    this.dog.anchor.set(0.5, 0);
    this.root.addChild(this.title, this.edition, this.dog, this.best, this.menu.root, this.footer);
    void loadTitleArt().then((art) => {
      this.art = art;
      this.layout();
    });
  }

  protected layout(): void {
    const { w, h } = this;
    // One line, as big as fits: triple size on wide screens, double on phones (186 px).
    const scale = [4, 3, 2, 1].find((sc) => logoWidth(LOGO_TEXT) * sc + 8 <= w) ?? 1;
    if (scale !== this.titleScale) {
      this.titleScale = scale;
      this.title.texture = logoTexture(LOGO_TEXT, scale, LOGO_STYLE);
      this.title.anchor.set(0.5);
    }
    const cx = Math.round(w / 2);
    // The stack, from the top: the title, CRUSADER, the portrait, the buttons, where CONTINUE goes.
    // Laid out from y = 0, then lowered into most of the free space above the footer.
    const halfTitle = Math.round(this.title.height / 2);
    let y = halfTitle + Math.round(this.title.height / 2) + 10;
    const editionY = y;
    y += 12;
    let dogY = y;
    if (this.art) {
      this.dog.texture = titleTexture(this.art.dog, Math.round(w * TITLE.DOG_WIDTH));
      dogY = y;
      y += this.dog.height + 6;
    }
    const menuY = y;
    y += this.menu.height + 5;
    const bestY = y;
    y += (this.actions.continueLabel ? this.best.textHeight : 0) + 6;
    const bottom = h - 16;
    const top0 = Math.max(18, halfTitle + 4);
    const free = Math.max(0, bottom - (top0 - halfTitle) - y);
    const off = top0 + Math.round(free * TITLE.LOWER);
    this.title.position.set(cx, off);
    this.edition.position.set(cx, off + editionY - halfTitle);
    this.dog.position.set(cx, off + dogY - halfTitle);
    this.menu.layout(w / 2, off + menuY - halfTitle);
    this.best.position.set(cx, off + bestY - halfTitle);
    this.footer.position.set(cx, h - 6);
  }

  override update(dt: number): void {
    super.update(dt);
    // Glitchy entrance: jitter for the first moments.
    const jitter = this.time < 0.9 ? Math.round((Math.random() * 2 - 1) * 4 * (1 - this.time / 0.9)) : 0;
    this.title.x = Math.round(this.w / 2) + jitter;
    this.edition.x = Math.round(this.w / 2) - jitter;
    this.edition.visible = this.time > 0.25;
    this.dog.visible = this.time > 0.35;
    this.menu.root.visible = this.time > 0.5;
    this.animateGlitch(dt);
    if (this.time > 0.6) this.menu.update(dt, this.game.input);
  }

  /** The background: an old dirty film that glitches now and then, mostly vertically. */
  private animateGlitch(dt: number): void {
    const f = this.actions.glitch;
    if (!f) return;
    const rnd = (r: readonly number[]) => r[0]! + Math.random() * (r[1]! - r[0]!);
    f.time = this.time;
    this.nextBurst -= dt;
    if (this.nextBurst <= 0) {
      this.nextBurst = rnd(TITLE.GLITCH_EVERY);
      this.burstLeft = rnd(TITLE.GLITCH_TIME);
    }
    this.burstLeft -= dt;
    // A burst flickers: its strength jumps around while it lasts.
    f.burst = this.burstLeft > 0 ? rnd(TITLE.GLITCH_BURST) : 0;
    f.idle = TITLE.GLITCH_IDLE;
    f.film = TITLE.FILM;
  }
}

const BRIEFING: Span[] = [
  { text: 'MAKE A WALK.\n', color: C.orange },
  { text: 'COLLECT ENOUGH TREATS TO COMPENSATE THE HUNGER.\n', color: C.green },
  {
    text: 'PEE ENOUGH TO COMPENSATE THE POOPS AS TOO MANY POOPS CAN ENDANGER THE ENVIRONMENT OF THE ZONE YOU ARE PLAYING IN.\n',
    color: C.red,
  },
  { text: 'CATS MEAN MONEY.\n', color: C.cyan },
  { text: "DON'T GET DISTRACTED BY THE BALLS.", color: C.yellow },
];

/** The rules, as in the video: big uppercase justified text with colored sentences. */
export class BriefingScene extends Overlay {
  private readonly text = new PixelText(BRIEFING, { align: 'justify', justifyLast: true, outline: '#120818', glow: 'self', glowAlpha: 0.25, lineGap: 3 });
  private readonly prompt: PixelText;
  private readonly hint: PixelText;

  constructor(
    game: Game,
    private readonly onGo: () => void,
  ) {
    super(game, 0.42);
    const touch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    this.prompt = big(touch ? 'TAP TO START' : 'PRESS SPACE', C.white, 1, { outline: '#000000' });
    this.hint = new PixelText(
      touch ? 'LEFT THUMB: MOVE\nBUTTONS: PEE / BARK / RUN' : 'WASD MOVE  SHIFT RUN\nSPACE PEE  J BARK  ESC MENU',
      { color: '#c8d0ff', shadow: '#000000', align: 'center', lineGap: 3, maxWidth: 190 },
    ).setOrigin(0.5, 0);
    this.root.addChild(this.text, this.prompt, this.hint);
  }

  protected layout(): void {
    const { w, h } = this;
    const top = 58;
    const bottom = h - 64;
    const maxW = w - 16;
    // Prefer the big 2x text like the video; fall back to 1x when it doesn't fit.
    this.text.setStyle({ scale: 2, maxWidth: maxW, lineGap: 2 });
    if (this.text.textHeight > bottom - top - 26) this.text.setStyle({ scale: 1, maxWidth: maxW, lineGap: 5 });
    this.text.setOrigin(0.5, 0);
    this.text.position.set(Math.round(w / 2), Math.round(top + Math.max(0, (bottom - top - 26 - this.text.textHeight) / 2)));
    this.prompt.position.set(Math.round(w / 2), Math.round(this.text.y + this.text.textHeight + 14));
    this.hint.position.set(Math.round(w / 2), Math.round(this.prompt.y + 10));
    this.hint.visible = this.hint.y + this.hint.textHeight < bottom + 20;
  }

  override update(dt: number): void {
    super.update(dt);
    this.prompt.visible = Math.floor(this.time * 2.5) % 2 === 0;
    const input = this.game.input;
    const taps = input.consumeTaps();
    if (this.time > 0.5 && (taps.length || input.consume('confirm'))) this.onGo();
  }
}

/** Pause menu (MENU button, Esc, or app sent to background). */
export class PauseScene extends Overlay {
  private readonly box = new Graphics();
  private readonly title = big('PAUSED', C.yellow, 2);
  private readonly menu: Menu;

  constructor(
    game: Game,
    private readonly actions: {
      resume: () => void;
      restart: () => void;
      toggleSound: () => void;
      quit: () => void;
      muted: () => boolean;
      volume: () => number;
      cycleVolume: () => void;
    },
  ) {
    super(game, 0.5);
    const items: MenuItem[] = [
      { label: 'RESUME', action: actions.resume, color: C.green },
      { label: 'RESTART', action: actions.restart, color: C.yellow },
      {
        label: () => (actions.muted() ? 'SOUND: OFF' : 'SOUND: ON'),
        action: () => {
          actions.toggleSound();
          this.menu.refreshLabels();
        },
        color: C.cyan,
      },
      {
        label: () => `VOLUME: ${Math.round(actions.volume() * 100)}%`,
        action: () => {
          actions.cycleVolume();
          this.menu.refreshLabels();
        },
        color: C.cyan,
      },
      { label: 'QUIT TO TITLE', action: actions.quit, color: C.pink },
    ];
    this.menu = new Menu(items, 132, 18, 6);
    this.root.addChild(this.box, this.title, this.menu.root);
  }

  protected layout(): void {
    const { w, h } = this;
    const bh = 36 + this.menu.height + 10;
    const top = Math.round(h / 2 - bh / 2);
    this.box.clear();
    retroBox(this.box, Math.round(w / 2 - 78), top, 156, bh, C.red, C.yellow, 0.6);
    this.title.position.set(Math.round(w / 2), top + 18);
    this.menu.layout(w / 2, top + 36);
  }

  override update(dt: number): void {
    super.update(dt);
    const input = this.game.input;
    if (input.consume('menu') || input.consume('back')) {
      this.actions.resume();
      return;
    }
    this.menu.update(dt, input);
  }
}

export interface LevelResult {
  stats: LevelStats;
  health: number;
  stars: number;
  timeBonus: number;
  starBonus: number;
  total: number;
  newBest: boolean;
  coinsTotal: number;
  hasNext: boolean;
  /** Label of the NEXT button (CONTINUE when the story goes on). */
  nextLabel?: string;
}

/** End of level: stats, stars popping one by one, bonuses, NEXT / RETRY. */
export class LevelEndScene extends Overlay {
  private readonly box = new Graphics();
  private readonly title = big('GOOD BOY!', C.yellow, 2);
  private readonly subtitle: PixelText;
  private readonly lines: PixelText[] = [];
  private readonly stars: Sprite[] = [];
  private readonly bonus: PixelText;
  private readonly total: PixelText;
  private readonly best = big('NEW BEST!', C.green, 1);
  private readonly menu: Menu;
  private starsShown = 0;
  private skip = false;
  /** Callback fired when a star pops (sound hook). */
  onStar: ((k: number) => void) | null = null;

  constructor(
    game: Game,
    level: LevelDef,
    private readonly r: LevelResult,
    actions: { next: () => void; retry: () => void; quit: () => void },
  ) {
    super(game, 0.55);
    this.subtitle = big(`LEVEL ${level.number} COMPLETE`, C.cyan, 1);
    const s = r.stats;
    const rows: Array<[string, string, string]> = [
      ['TIME', formatTime(s.time), C.green],
      ['TREATS', String(s.treats), C.pink],
      ['PEES / POOPS', `${s.pees} / ${s.poops}`, C.yellow],
      ['COINS', `${s.coins}  (${r.coinsTotal})`, C.orange],
      ['ZONE HEALTH', `${Math.round(r.health * 100)}%`, C.green],
    ];
    for (const [k, v, color] of rows) {
      const t = new PixelText([
        { text: k.padEnd(14, ' '), color },
        { text: v.padStart(9, ' '), color: C.white },
      ], { shadow: '#000000' });
      this.lines.push(t);
    }
    for (let k = 0; k < 5; k++) {
      const st = new Sprite(textures.get(spriteName('star', 2)));
      st.anchor.set(0.5);
      st.scale.set(2);
      this.stars.push(st);
    }
    this.bonus = new PixelText(
      [
        { text: 'TIME BONUS'.padEnd(14, ' '), color: C.cyan },
        { text: `+${r.timeBonus}`.padStart(9, ' '), color: C.white },
        { text: '\n' },
        { text: 'STAR BONUS'.padEnd(14, ' '), color: C.cyan },
        { text: `+${r.starBonus}`.padStart(9, ' '), color: C.white },
      ],
      { shadow: '#000000', lineGap: 4 },
    );
    this.total = new PixelText([
      { text: 'SCORE'.padEnd(14, ' '), color: C.yellow },
      { text: formatScore(r.total).padStart(9, ' '), color: C.yellow },
    ], { shadow: '#000000', glow: 'self', glowAlpha: 0.3 });
    const items: MenuItem[] = [];
    if (r.hasNext) items.push({ label: r.nextLabel ?? 'NEXT', action: actions.next, color: C.green });
    items.push({ label: 'RETRY', action: actions.retry, color: C.yellow });
    if (!r.hasNext) items.push({ label: 'TITLE', action: actions.quit, color: C.pink });
    this.menu = new Menu(items, 120, 16, 5);
    this.root.addChild(this.box, this.title, this.subtitle, ...this.lines, ...this.stars, this.bonus, this.total, this.best, this.menu.root);
  }

  protected layout(): void {
    const { w, h } = this;
    const bw = Math.min(w - 8, 196);
    const bh = 222 + this.menu.height + 9;
    const top = Math.max(4, Math.round(h / 2 - bh / 2));
    const left = Math.round(w / 2 - bw / 2);
    this.box.clear();
    retroBox(this.box, left, top, bw, bh, C.yellow, C.red, 0.65);
    this.title.position.set(Math.round(w / 2), top + 16);
    this.subtitle.position.set(Math.round(w / 2), top + 34);
    const tx = Math.round(w / 2 - (23 * 8) / 2);
    this.lines.forEach((l, k) => l.position.set(tx, top + 48 + k * 13));
    this.stars.forEach((s, k) => s.position.set(Math.round(w / 2 + (k - 2) * 26), top + 130));
    this.bonus.position.set(tx, top + 156);
    this.total.position.set(tx, top + 186);
    this.best.position.set(Math.round(w / 2), top + 206);
    this.menu.layout(w / 2, top + 222);
  }

  override update(dt: number): void {
    super.update(dt);
    const input = this.game.input;
    const t = this.skip ? 99 : this.time;
    this.lines.forEach((l, k) => (l.visible = t > 0.3 + k * 0.15));
    // Stars pop one by one (half star included).
    const starStart = 1.2;
    const want = Math.min(5, Math.max(0, Math.floor((t - starStart) / 0.35) + 1));
    while (this.starsShown < want) {
      const k = this.starsShown++;
      const v = this.r.stars >= k + 1 ? 0 : this.r.stars >= k + 0.5 ? 1 : 2;
      this.stars[k]!.texture = textures.get(spriteName('star', v));
      this.stars[k]!.scale.set(v === 2 ? 2 : 3);
      if (v !== 2) this.onStar?.(k);
    }
    for (const s of this.stars) if (s.scale.x > 2) s.scale.set(Math.max(2, s.scale.x - dt * 8));
    const after = starStart + 5 * 0.35;
    this.bonus.visible = t > after;
    this.total.visible = t > after + 0.3;
    this.best.visible = this.r.newBest && t > after + 0.5 && Math.floor(this.time * 3) % 2 === 0;
    this.menu.root.visible = t > after + 0.6;
    if (!this.menu.root.visible) {
      if (input.consumeTaps().length || input.consume('confirm')) this.skip = true;
      return;
    }
    this.menu.update(dt, input);
  }
}

/** Game over: Retry / Quit. */
export class GameOverScene extends Overlay {
  private readonly title = big('GAME OVER', C.red, 2, { outline: '#ffffff' });
  private readonly msg: PixelText;
  private readonly score: PixelText;
  private readonly menu: Menu;

  constructor(game: Game, stats: LevelStats, actions: { retry: () => void; quit: () => void }) {
    super(game, 0.6);
    this.msg = new PixelText('ZAMPANO IS TOO HUNGRY\nTO GO ON...', { color: C.paleRose, align: 'center', lineGap: 4, shadow: '#000000' }).setOrigin(0.5, 0);
    this.score = big(`SCORE ${formatScore(stats.score)}`, C.cyan, 1);
    this.menu = new Menu(
      [
        { label: 'RETRY', action: actions.retry, color: C.yellow },
        { label: 'QUIT TO TITLE', action: actions.quit, color: C.pink },
      ],
      132,
      18,
      6,
    );
    this.root.addChild(this.title, this.msg, this.score, this.menu.root);
  }

  protected layout(): void {
    const { w, h } = this;
    this.title.position.set(Math.round(w / 2), Math.round(h * 0.3));
    this.msg.position.set(Math.round(w / 2), Math.round(h * 0.3 + 22));
    this.score.position.set(Math.round(w / 2), Math.round(h * 0.3 + 52));
    this.menu.layout(w / 2, Math.round(h * 0.3 + 72));
  }

  override update(dt: number): void {
    super.update(dt);
    const jitter = this.time < 1 && Math.random() < 0.3 ? Math.round((Math.random() * 2 - 1) * 3) : 0;
    this.title.x = Math.round(this.w / 2) + jitter;
    this.menu.root.visible = this.time > 0.8;
    if (this.menu.root.visible) this.menu.update(dt, this.game.input);
  }
}

/** OPTIONS from the title: sound, volume, text speed, replaying levels, the book. */
export class OptionsScene extends Overlay {
  private readonly heading = big('OPTIONS', C.yellow, 2);
  private readonly menu: Menu;

  constructor(
    game: Game,
    actions: {
      toggleSound: () => void;
      muted: () => boolean;
      cycleVolume: () => void;
      volume: () => number;
      cycleTextSpeed: () => void;
      textSpeed: () => string;
      toggleArt: () => void;
      art: () => string;
      levels: () => void;
      book: () => void;
      back: () => void;
    },
  ) {
    // Nearly opaque: the title's own buttons must not show through.
    super(game, 0.94);
    this.menu = new Menu(
      [
        {
          label: () => (actions.muted() ? 'SOUND: OFF' : 'SOUND: ON'),
          action: () => {
            actions.toggleSound();
            this.menu.refreshLabels();
          },
          color: C.cyan,
        },
        {
          label: () => `VOLUME: ${Math.round(actions.volume() * 100)}%`,
          action: () => {
            actions.cycleVolume();
            this.menu.refreshLabels();
          },
          color: C.cyan,
        },
        {
          label: () => `TEXT: ${actions.textSpeed()}`,
          action: () => {
            actions.cycleTextSpeed();
            this.menu.refreshLabels();
          },
          color: C.cyan,
        },
        {
          label: () => `ART: ${actions.art()}`,
          action: () => {
            actions.toggleArt();
            this.menu.refreshLabels();
          },
          color: C.cyan,
        },
        { label: 'LEVELS (REPLAY)', action: actions.levels, color: C.yellow },
        { label: 'MERAVIGLIA BOOK', action: actions.book, color: C.pink },
        { label: 'BACK', action: actions.back, color: C.white },
      ],
      160,
      18,
      6,
    );
    this.root.addChild(this.heading, this.menu.root);
  }

  protected layout(): void {
    const { w, h } = this;
    this.heading.position.set(Math.round(w / 2), Math.round(h * 0.22));
    this.menu.layout(w / 2, Math.round(h * 0.32));
  }

  override update(dt: number): void {
    super.update(dt);
    if (this.time > 0.25) this.menu.update(dt, this.game.input);
  }
}

/** A yes/no question (NEW GAME over a saved story). */
export class ConfirmScene extends Overlay {
  private readonly heading: PixelText;
  private readonly text: PixelText;
  private readonly menu: Menu;

  constructor(game: Game, title: string, text: string, actions: { yes: () => void; no: () => void; yesLabel?: string; noLabel?: string }) {
    super(game, 0.92);
    this.heading = big(title, C.yellow, 1);
    this.text = new PixelText(text, { color: C.white, shadow: '#000000', align: 'center', maxWidth: 180, lineGap: 3 }).setOrigin(0.5, 0);
    this.menu = new Menu(
      [
        { label: actions.yesLabel ?? 'YES', action: actions.yes, color: C.green },
        { label: actions.noLabel ?? 'NO', action: actions.no, color: C.pink },
      ],
      140,
      18,
      6,
    );
    this.menu.selected = 1;
    this.root.addChild(this.heading, this.text, this.menu.root);
  }

  protected layout(): void {
    const { w, h } = this;
    this.heading.position.set(Math.round(w / 2), Math.round(h * 0.32));
    this.text.position.set(Math.round(w / 2), Math.round(h * 0.32 + 16));
    this.menu.layout(w / 2, Math.round(h * 0.32 + 30 + this.text.textHeight));
  }

  override update(dt: number): void {
    super.update(dt);
    if (this.time > 0.25) this.menu.update(dt, this.game.input);
  }
}

/** QUIT in a browser tab (a web page cannot close its own tab): a goodbye card, tap to go back. */
export class GoodbyeScene extends Overlay {
  private readonly heading = big('THANKS FOR PLAYING', C.yellow, 1);
  private readonly text = new PixelText('YOU CAN CLOSE THIS TAB NOW.\nTAP TO GO BACK TO THE TITLE.', { color: C.white, shadow: '#000000', align: 'center', lineGap: 4 }).setOrigin(0.5, 0);

  constructor(
    game: Game,
    private readonly onBack: () => void,
  ) {
    super(game, 0.85);
    this.root.addChild(this.heading, this.text);
  }

  protected layout(): void {
    const { w, h } = this;
    this.heading.position.set(Math.round(w / 2), Math.round(h * 0.42));
    this.text.position.set(Math.round(w / 2), Math.round(h * 0.42 + 18));
  }

  override update(dt: number): void {
    super.update(dt);
    const input = this.game.input;
    if (this.time > 0.5 && (input.consumeTaps().length || input.consume('confirm') || input.consume('back'))) this.onBack();
  }
}

