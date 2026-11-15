import { CanvasSource, Sprite, Texture } from 'pixi.js';
import { pixelFont } from './pixelFont';

/**
 * Crisp pixel text with retro effects (outline, glow, drop shadow, per-span colors, justify).
 * The text is baked into a small canvas texture and only re-rendered when it changes.
 */

export interface PixelTextStyle {
  color: string;
  /** Integer upscale of the 8px font. */
  scale: number;
  outline: string | null;
  outlineWidth: number;
  /** Glow color (null = none). */
  glow: string | null;
  glowAlpha: number;
  shadow: string | null;
  align: 'left' | 'center' | 'right' | 'justify';
  /** Wrap width in px (0 = no wrap). */
  maxWidth: number;
  lineGap: number;
  letterSpacing: number;
}

export interface Span {
  text: string;
  color?: string;
}

export const DEFAULT_TEXT_STYLE: PixelTextStyle = {
  color: '#ffffff',
  scale: 1,
  outline: null,
  outlineWidth: 1,
  glow: null,
  glowAlpha: 0.35,
  shadow: null,
  align: 'left',
  maxWidth: 0,
  lineGap: 2,
  letterSpacing: 0,
};

interface Glyph {
  ch: string;
  color: string;
}

const tintCache = new Map<string, HTMLCanvasElement>();

function tintedGlyph(ch: string, color: string, scale: number): HTMLCanvasElement {
  const key = `${ch}|${color}|${scale}`;
  const hit = tintCache.get(key);
  if (hit) return hit;
  const font = pixelFont();
  const c = document.createElement('canvas');
  c.width = font.advance * scale;
  c.height = font.cellH * scale;
  const ctx = c.getContext('2d')!;
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(font.atlas, font.glyphX(ch), 0, font.advance, font.cellH, 0, 0, c.width, c.height);
  ctx.globalCompositeOperation = 'source-in';
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, c.width, c.height);
  if (tintCache.size > 2000) tintCache.clear();
  tintCache.set(key, c);
  return c;
}

/** Splits text into lines of glyphs, honoring '\n' and greedy word wrap. */
export function layoutLines(glyphs: Glyph[], maxChars: number): { line: Glyph[]; last: boolean }[] {
  const out: { line: Glyph[]; last: boolean }[] = [];
  const paragraphs: Glyph[][] = [[]];
  for (const g of glyphs) {
    if (g.ch === '\n') paragraphs.push([]);
    else paragraphs[paragraphs.length - 1]!.push(g);
  }
  for (const para of paragraphs) {
    if (maxChars <= 0) {
      out.push({ line: para, last: true });
      continue;
    }
    // Words with their glyphs.
    const words: Glyph[][] = [];
    let cur: Glyph[] = [];
    for (const g of para) {
      if (g.ch === ' ') {
        if (cur.length) words.push(cur);
        cur = [];
      } else cur.push(g);
    }
    if (cur.length) words.push(cur);
    let line: Glyph[] = [];
    const lines: Glyph[][] = [];
    for (const w of words) {
      const needed = line.length === 0 ? w.length : line.length + 1 + w.length;
      if (needed > maxChars && line.length > 0) {
        lines.push(line);
        line = [];
      }
      if (line.length > 0) line.push({ ch: ' ', color: w[0]!.color });
      line.push(...w);
    }
    lines.push(line);
    lines.forEach((l, k) => out.push({ line: l, last: k === lines.length - 1 }));
  }
  return out;
}

export class PixelText extends Sprite {
  private readonly canvas: HTMLCanvasElement;
  private readonly source: CanvasSource;
  private content: Span[] = [];
  private st: PixelTextStyle;
  private pad = 0;
  /** Size of the text body (without effect padding). */
  textWidth = 0;
  textHeight = 0;
  private originX = 0;
  private originY = 0;

  constructor(content: string | Span[], style: Partial<PixelTextStyle> = {}) {
    const canvas = document.createElement('canvas');
    canvas.width = 1;
    canvas.height = 1;
    const source = new CanvasSource({ resource: canvas });
    super(new Texture({ source }));
    this.canvas = canvas;
    this.source = source;
    this.st = { ...DEFAULT_TEXT_STYLE, ...style };
    this.roundPixels = true;
    this.content = toSpans(content);
    this.redraw();
  }

  get style(): Readonly<PixelTextStyle> {
    return this.st;
  }

  setText(content: string | Span[]): this {
    const spans = toSpans(content);
    if (sameSpans(spans, this.content)) return this;
    this.content = spans;
    this.redraw();
    return this;
  }

  setStyle(style: Partial<PixelTextStyle>): this {
    this.st = { ...this.st, ...style };
    this.redraw();
    return this;
  }

  /** Where (x, y) sits on the text body: 0,0 = top-left; 0.5,0.5 = center; 1,1 = bottom-right. */
  setOrigin(ox: number, oy = ox): this {
    this.originX = ox;
    this.originY = oy;
    this.updatePivot();
    return this;
  }

  private updatePivot(): void {
    this.pivot.set(Math.round(this.pad + this.textWidth * this.originX), Math.round(this.pad + this.textHeight * this.originY));
  }

  private redraw(): void {
    const font = pixelFont();
    const st = this.st;
    const s = Math.max(1, Math.round(st.scale));
    const adv = font.advance * s + st.letterSpacing;
    const lineH = font.cellH * s;
    const glyphs: Glyph[] = [];
    for (const span of this.content) for (const ch of span.text) glyphs.push({ ch, color: span.color ?? st.color });
    const maxChars = st.maxWidth > 0 ? Math.max(1, Math.floor((st.maxWidth + st.letterSpacing) / adv)) : 0;
    const lines = layoutLines(glyphs, maxChars);
    const naturalW = Math.max(0, ...lines.map((l) => l.line.length * adv - (l.line.length ? st.letterSpacing : 0)));
    const bodyW = st.align === 'justify' && st.maxWidth > 0 ? Math.max(naturalW, st.maxWidth) : naturalW;
    const bodyH = lines.length * lineH + Math.max(0, lines.length - 1) * st.lineGap;
    const glowR = st.glow ? 1 : 0;
    const pad = Math.max(st.outline ? st.outlineWidth : 0, glowR) + (st.shadow ? 1 : 0);
    this.pad = pad;
    this.textWidth = bodyW;
    this.textHeight = bodyH;
    const w = Math.max(1, bodyW + pad * 2);
    const h = Math.max(1, bodyH + pad * 2);

    if (this.canvas.width !== w || this.canvas.height !== h) this.source.resize(w, h);
    const ctx = this.canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;
    ctx.clearRect(0, 0, w, h);

    // Glyph positions.
    const placed: Array<{ g: Glyph; x: number; y: number }> = [];
    lines.forEach(({ line, last }, li) => {
      const lineW = line.length * adv - (line.length ? st.letterSpacing : 0);
      let x = 0;
      let extraPerGap: number[] = [];
      if (st.align === 'center') x = Math.floor((bodyW - lineW) / 2);
      else if (st.align === 'right') x = bodyW - lineW;
      else if (st.align === 'justify' && !last) {
        const gaps = line.reduce((n, g) => n + (g.ch === ' ' ? 1 : 0), 0);
        const extra = bodyW - lineW;
        if (gaps > 0 && extra > 0) {
          extraPerGap = Array.from({ length: gaps }, (_, k) => Math.floor((extra * (k + 1)) / gaps) - Math.floor((extra * k) / gaps));
        }
      }
      let gap = 0;
      const y = li * (lineH + st.lineGap);
      for (const g of line) {
        if (g.ch !== ' ') placed.push({ g, x: pad + x, y: pad + y });
        x += adv;
        if (g.ch === ' ' && extraPerGap.length) x += extraPerGap[gap++] ?? 0;
      }
    });

    const draw = (color: string | null, dx: number, dy: number, alpha = 1) => {
      ctx.globalAlpha = alpha;
      for (const p of placed) ctx.drawImage(tintedGlyph(p.g.ch, color ?? p.g.color, s), p.x + dx, p.y + dy);
    };
    if (st.glow) {
      // Soft pixel glow: orthogonal neighbors stronger than diagonals, 1px radius only
      // (a wider glow smears 8px text).
      const glowColor = st.glow === 'self' ? null : st.glow;
      for (const [dx, dy] of [
        [-1, -1],
        [1, -1],
        [-1, 1],
        [1, 1],
      ] as const)
        draw(glowColor, dx, dy, st.glowAlpha * 0.35);
      for (const [dx, dy] of [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ] as const)
        draw(glowColor, dx, dy, st.glowAlpha * 0.6);
    }
    if (st.shadow) draw(st.shadow, 1, 1);
    if (st.outline) {
      const ow = st.outlineWidth;
      for (let dy = -ow; dy <= ow; dy++) for (let dx = -ow; dx <= ow; dx++) if (dx || dy) draw(st.outline, dx, dy);
    }
    draw(null, 0, 0);
    ctx.globalAlpha = 1;
    this.source.update();
    this.updatePivot();
  }

  override destroy(): void {
    super.destroy({ texture: true, textureSource: true });
  }
}

function toSpans(content: string | Span[]): Span[] {
  return typeof content === 'string' ? [{ text: content }] : content;
}

function sameSpans(a: Span[], b: Span[]): boolean {
  if (a.length !== b.length) return false;
  for (let k = 0; k < a.length; k++) if (a[k]!.text !== b[k]!.text || a[k]!.color !== b[k]!.color) return false;
  return true;
}
