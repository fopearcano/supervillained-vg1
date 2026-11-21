import { Container, Graphics } from 'pixi.js';
import { PixelText } from './pixelText';
import { frameRect, hex } from './retro';

/** Ink colors on the paper cards of the title page (GLOSSARY, COUCH). */
export const INK = '#1c1626';
export const FADED = '#6a6478';
export const PAPER = 0xf3ecd8;

/**
 * Width of the text itself (a PixelText's sprite is padded and rounded up to 16 px; a bold
 * container is its text plus the 1-px offset copy).
 */
export function textW(o: Container): number {
  if (o instanceof PixelText) return o.textWidth;
  const first = o.children[0];
  return first instanceof PixelText ? first.textWidth + 1 : o.width;
}

/** Height of the text itself (see textW). */
export function textH(o: Container): number {
  if (o instanceof PixelText) return o.textHeight;
  const first = o.children[0];
  return first instanceof PixelText ? first.textHeight : o.height;
}

/** Faux bold: the text twice, one pixel apart. */
export function bold(text: string, color: string, scale = 1, maxWidth = 0): Container {
  const c = new Container();
  for (const dx of [0, 1]) {
    const t = new PixelText(text, { color, scale, maxWidth, lineGap: 3 });
    t.x = dx;
    c.addChild(t);
  }
  return c;
}

/** A floating paper card: a drop shadow, paper, a double frame in the accent colors. */
export function drawPaperCard(g: Graphics, x: number, y: number, w: number, h: number, accent: string, accentInk: string): void {
  g.clear();
  g.rect(x + 3, y + 3, w, h).fill({ color: 0x000000, alpha: 0.45 });
  g.rect(x, y, w, h).fill({ color: PAPER });
  frameRect(g, x, y, w, h, hex(accent));
  frameRect(g, x + 2, y + 2, w - 4, h - 4, hex(accentInk), 0.6);
}

/** A small framed text button on a card (CLOSE). Returns its height. */
export function drawCardButton(g: Graphics, label: PixelText, x: number, y: number, accent: string, accentInk: string): { w: number; h: number } {
  const w = Math.round(label.textWidth) + 16;
  const h = 15;
  label.position.set(x + 8, y + 4);
  g.clear();
  g.rect(x, y, w, h).fill({ color: hex(accent), alpha: 0.18 });
  frameRect(g, x, y, w, h, hex(accentInk));
  return { w, h };
}
