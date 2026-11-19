import { Graphics, Sprite } from 'pixi.js';
import { textures } from '../../core/assets';
import { spriteName } from '../../assets/manifest';
import { PixelText } from '../../ui/pixelText';
import { C, frameRect, hex, retroBox } from '../../ui/retro';
import { STORY } from '../../config';
import type { Autopilot } from '../autopilot';
import type { StoryScene } from '../storyScene';
import { MiniGame, type MiniResult } from './miniGame';

/**
 * Beat games. Cues travel toward a hit line; press on the beat.
 *  - choice mode (3.3 the art of weeping): two gestures are offered on every beat; only the next
 *    one in the right order (kneel, weep, honour, shame, vengeance) moves the crowd.
 *  - single mode (4.1 Veni Creator): raise the banners on every beat.
 */
export interface RhythmOptions {
  mode: 'choice' | 'single';
  beats: number;
  bpm: number;
  /** Correct sequence (choice mode), cycled. */
  sequence?: string[];
  title: string;
  need: number;
  /** Single mode: the word on each cue (RAISE, ROW...), the objective and the feedback lines. */
  cue?: string;
  objective?: string;
  hit?: string;
  miss?: string;
}

const WINDOW = STORY.RHYTHM.WINDOW;

export class RhythmGame extends MiniGame {
  private readonly bg = new Graphics();
  private readonly lane = new Graphics();
  private readonly title: PixelText;
  private readonly status = new PixelText('', { color: C.white, shadow: '#000000', align: 'center' }).setOrigin(0.5);
  private readonly score = new PixelText('', { color: C.yellow, shadow: '#000000' }).setOrigin(0.5, 0);
  private readonly left = new PixelText('', { color: C.cyan, shadow: '#000000' }).setOrigin(0.5);
  private readonly right = new PixelText('', { color: C.cyan, shadow: '#000000' }).setOrigin(0.5);
  private readonly cues: PixelText[] = [];
  private readonly tears: Sprite[] = [];
  private beatTime: number;
  private hits = 0;
  private judged = new Set<number>();
  private feedback = 0;
  private feedbackText = '';
  private lastBeatSound = -1;
  /** For each beat (choice mode): which side holds the right gesture, and the decoy. */
  private readonly layoutBeats: Array<{ correct: string; decoy: string; side: 0 | 1 }> = [];

  constructor(private readonly o: RhythmOptions) {
    super();
    this.beatTime = 60 / o.bpm;
    this.title = new PixelText(o.title, { color: C.yellow, outline: '#120818', glow: 'self', glowAlpha: 0.3, align: 'center' }).setOrigin(0.5, 0);
    this.objective = o.objective ?? (o.mode === 'choice' ? 'PICK THE RIGHT GESTURE ON THE BEAT' : 'RAISE THE BANNERS ON THE BEAT');
    const seq = o.sequence ?? ['RAISE'];
    for (let k = 0; k < o.beats; k++) {
      const correct = seq[k % seq.length]!;
      let decoy = seq[(k + 2 + Math.floor(Math.random() * (seq.length - 1))) % seq.length]!;
      if (decoy === correct) decoy = seq[(k + 1) % seq.length]!;
      this.layoutBeats.push({ correct, decoy, side: Math.random() < 0.5 ? 0 : 1 });
      const t = new PixelText(o.mode === 'choice' ? '' : (o.cue ?? 'RAISE'), { color: C.white, outline: '#000000' }).setOrigin(0.5);
      this.cues.push(t);
    }
    for (let k = 0; k < 14; k++) {
      const s = new Sprite(textures.get(spriteName(o.mode === 'choice' ? 'tear' : 'banner', o.mode === 'choice' ? 0 : k % 2)));
      s.visible = false;
      this.tears.push(s);
    }
    this.root.addChild(this.bg, this.lane, ...this.tears, ...this.cues, this.title, this.score, this.status, this.left, this.right);
  }

  protected override onLayout(): void {
    const { w, h } = this;
    this.bg.clear().rect(0, 0, w, h).fill({ color: 0x000000, alpha: 0.35 });
    retroBox(this.bg, 6, h - 120, w - 12, 100, C.red, C.yellow, 0.6);
    this.title.position.set(Math.round(w / 2), 74);
    this.score.position.set(Math.round(w / 2), h - 114);
    this.status.position.set(Math.round(w / 2), h - 140);
    this.left.position.set(Math.round(w * 0.28), h - 40);
    this.right.position.set(Math.round(w * 0.72), h - 40);
    this.tears.forEach((s, k) => s.position.set(14 + ((k * 37) % (w - 28)), 100 + ((k * 53) % 120)));
  }

  start(ctx: StoryScene): void {
    ctx.setControls(false);
    this.time = -STORY.RHYTHM.START_DELAY;
  }

  /** Autopilot: one press per beat, with timing noise and the odd wrong gesture. */
  private plan: Array<{ at: number; side: 0 | 1; done: boolean }> | null = null;
  override pilot(_dt: number, ctx: StoryScene, p: Autopilot): void {
    if (!this.plan) {
      const sigma = 0.025 + (1 - p.policy.skill) * 0.12;
      this.plan = this.layoutBeats.map((b, k) => {
        const right = p.random() < 0.7 + 0.3 * p.policy.skill;
        return { at: this.beatAt(k) + p.gauss(sigma), side: (right ? b.side : 1 - b.side) as 0 | 1, done: false };
      });
    }
    for (const q of this.plan) {
      if (q.done || this.time < q.at) continue;
      q.done = true;
      p.press(ctx, this.o.mode === 'single' ? 'confirm' : q.side === 0 ? 'left' : 'right');
      break;
    }
  }

  private beatAt(k: number): number {
    return k * this.beatTime;
  }

  private judge(k: number, ok: boolean, ctx: StoryScene): void {
    this.judged.add(k);
    if (ok) {
      this.hits++;
      this.feedbackText = this.o.mode === 'choice' ? 'THEY WEEP BACK!' : (this.o.hit ?? 'ON THE BEAT!');
      ctx.game.audio.play(this.o.mode === 'choice' ? 'star' : 'treat');
      const t = this.tears[this.hits % this.tears.length]!;
      t.visible = true;
      t.alpha = 1;
      if (this.o.mode === 'choice') ctx.apply({ commozione: STORY.WEEP_HIT });
    } else {
      this.feedbackText = this.o.mode === 'choice' ? 'TOO DRY' : (this.o.miss ?? 'OFF BEAT');
      ctx.game.audio.play('empty');
    }
    this.feedback = 0.6;
  }

  update(dt: number, ctx: StoryScene): MiniResult {
    const input = ctx.game.input;
    const { w, h } = this;
    const lineY = h - 70;
    const speed = STORY.RHYTHM.CUE_SPEED;
    // Metronome
    const beatIdx = Math.floor(this.time / this.beatTime);
    if (beatIdx >= 0 && beatIdx !== this.lastBeatSound && beatIdx < this.o.beats) {
      this.lastBeatSound = beatIdx;
      ctx.game.audio.play('click', { volume: 0.5 });
    }
    // Which beat is closest now?
    const near = Math.round(this.time / this.beatTime);
    const dtBeat = this.time - this.beatAt(near);
    const inWindow = near >= 0 && near < this.o.beats && Math.abs(dtBeat) <= WINDOW && !this.judged.has(near);
    // Input
    let pressed: 0 | 1 | -1 = -1;
    const taps = input.consumeTaps();
    for (const t of taps) if (t.y > h - 120) pressed = this.o.mode === 'single' ? 0 : t.x < w / 2 ? 0 : 1;
    if (input.consume('left')) pressed = 0;
    if (input.consume('right')) pressed = 1;
    if (input.consume('confirm') || input.consume('bark') || input.consume('pee') || input.consume('up')) pressed = this.o.mode === 'single' ? 0 : pressed;
    if (pressed >= 0) {
      if (inWindow) {
        const b = this.layoutBeats[near]!;
        this.judge(near, this.o.mode === 'single' || pressed === b.side, ctx);
      } else {
        this.feedbackText = 'TOO EARLY';
        this.feedback = 0.4;
      }
    }
    // Missed beats
    for (let k = 0; k < this.o.beats; k++) if (!this.judged.has(k) && this.time - this.beatAt(k) > WINDOW) this.judge(k, false, ctx);

    // Draw lane + cues
    const g = this.lane;
    g.clear();
    g.rect(10, lineY - 1, w - 20, 2).fill(hex(C.yellow));
    const pulse = Math.abs(dtBeat) < 0.08 ? 3 : 0;
    frameRect(g, w / 2 - 12 - pulse, lineY - 12 - pulse, 24 + pulse * 2, 24 + pulse * 2, hex(C.red));
    this.cues.forEach((t, k) => {
      const y = lineY - (this.beatAt(k) - this.time) * speed;
      t.visible = y > 90 && y < h && !this.judged.has(k);
      const b = this.layoutBeats[k]!;
      if (this.o.mode === 'choice') t.setText(b.side === 0 ? `${b.correct} | ${b.decoy}` : `${b.decoy} | ${b.correct}`);
      t.position.set(Math.round(w / 2), Math.round(y));
    });
    // Current choice labels on the two buttons
    if (this.o.mode === 'choice') {
      const k = Math.max(0, Math.min(this.o.beats - 1, near));
      const b = this.layoutBeats[k]!;
      this.left.setText(`< ${b.side === 0 ? b.correct : b.decoy}`);
      this.right.setText(`${b.side === 1 ? b.correct : b.decoy} >`);
    } else {
      this.left.setText('TAP ON THE BEAT');
      this.right.setText('');
    }
    this.score.setText(`${this.hits}/${this.o.beats}`);
    this.feedback -= dt;
    this.status.setText(this.feedback > 0 ? this.feedbackText : this.o.mode === 'choice' ? `ORDER: ${(this.o.sequence ?? []).join(' > ')}` : '');
    this.status.setStyle({ maxWidth: w - 16 });
    for (const s of this.tears) if (s.visible) s.y += dt * 20;

    if (this.time > this.beatAt(this.o.beats - 1) + 0.8) return this.hits >= this.o.need ? 'won' : 'lost';
    return 'running';
  }
}

export const WEEPING = ['KNEEL', 'WEEP', 'HONOUR', 'SHAME', 'VENGEANCE'];

export function weeping(round: number): RhythmGame {
  const W = STORY.WEEPING;
  return new RhythmGame({ mode: 'choice', beats: W.BEATS, bpm: round === 1 ? W.BPM_ROUND1 : W.BPM_ROUND2, sequence: WEEPING, title: round === 1 ? 'THE ENVOYS WEEP' : 'THE DOGE TAKES THE CROSS', need: W.NEED });
}

/** 4.1: raise shields and banners as the clergy sing; a sailor quietly sets him right. */
export function parade(): RhythmGame {
  const P = STORY.PARADE;
  return new RhythmGame({
    mode: 'single',
    beats: P.BEATS,
    bpm: P.BPM,
    title: 'VENI CREATOR',
    need: P.NEED,
    objective: 'RAISE SHIELDS AND BANNERS ON THE BEAT',
    miss: 'THE SAILOR SETS HIM RIGHT',
  });
}

/** 4.3: rowing the galleys into the harbor of Zara, on the eve of Saint Martin. */
export function rowing(): RhythmGame {
  const P = STORY.PARADE;
  return new RhythmGame({
    mode: 'single',
    beats: P.BEATS,
    bpm: P.BPM - 8,
    title: 'INTO THE HARBOR',
    need: P.NEED,
    cue: 'ROW',
    objective: 'ROW ON THE BEAT',
    hit: 'STROKE!',
    miss: 'OUT OF TIME',
  });
}
