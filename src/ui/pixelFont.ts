import fontUrl from '../assets/fonts/PressStart2P.woff2?url';

/**
 * Bitmap font built at runtime from the bundled Press Start 2P (OFL). Each glyph is rendered once
 * at 8px and thresholded to pure 1-bit alpha, so text stays perfectly crisp at integer scales.
 */

export const FONT_FAMILY = 'PressStart2P';
const SIZE = 8;
const FIRST = 32;
const LAST = 126;

export class PixelFont {
  /** Advance per glyph (monospace) in px at scale 1. */
  readonly advance: number;
  /** Glyph cell height in px at scale 1. */
  readonly cellH: number;
  /** Atlas canvas: one cell per glyph, in a single row. */
  readonly atlas: HTMLCanvasElement;
  readonly loaded: boolean;

  private constructor(atlas: HTMLCanvasElement, advance: number, cellH: number, loaded: boolean) {
    this.atlas = atlas;
    this.advance = advance;
    this.cellH = cellH;
    this.loaded = loaded;
  }

  static async load(): Promise<PixelFont> {
    let loaded = false;
    try {
      const face = new FontFace(FONT_FAMILY, `url(${fontUrl})`);
      await face.load();
      document.fonts.add(face);
      loaded = true;
    } catch (err) {
      console.warn('[font] could not load Press Start 2P, falling back to monospace', err);
    }
    return PixelFont.build(loaded);
  }

  private static build(loaded: boolean): PixelFont {
    const count = LAST - FIRST + 1;
    const cw = 16;
    const ch = 16;
    const baseline = 12;
    const work = document.createElement('canvas');
    work.width = cw * count;
    work.height = ch;
    const ctx = work.getContext('2d', { willReadFrequently: true })!;
    ctx.fillStyle = '#ffffff';
    ctx.textBaseline = 'alphabetic';
    ctx.font = `${SIZE}px ${loaded ? FONT_FAMILY : 'monospace'}`;
    for (let k = 0; k < count; k++) ctx.fillText(String.fromCharCode(FIRST + k), k * cw + 4, baseline);
    const img = ctx.getImageData(0, 0, work.width, work.height);
    const d = img.data;
    let top = ch;
    let bottom = -1;
    for (let y = 0; y < ch; y++) {
      for (let x = 0; x < work.width; x++) {
        const a = d[(y * work.width + x) * 4 + 3]!;
        if (a >= 110) {
          top = Math.min(top, y);
          bottom = Math.max(bottom, y);
        }
      }
    }
    if (bottom < 0) {
      top = 4;
      bottom = 12;
    }
    // Press Start 2P caps sit on an 8px grid; keep the union box of all glyphs.
    const cellH = bottom - top + 1;
    const advance = SIZE;
    const atlas = document.createElement('canvas');
    atlas.width = advance * count;
    atlas.height = cellH;
    const actx = atlas.getContext('2d')!;
    const out = actx.createImageData(atlas.width, cellH);
    const o = out.data;
    for (let k = 0; k < count; k++) {
      for (let y = 0; y < cellH; y++) {
        for (let x = 0; x < advance; x++) {
          const sx = k * cw + 4 + x;
          const sy = top + y;
          const a = d[(sy * work.width + sx) * 4 + 3]!;
          const di = (y * atlas.width + k * advance + x) * 4;
          if (a >= 110) {
            o[di] = 255;
            o[di + 1] = 255;
            o[di + 2] = 255;
            o[di + 3] = 255;
          }
        }
      }
    }
    actx.putImageData(out, 0, 0);
    return new PixelFont(atlas, advance, cellH, loaded);
  }

  /** Atlas x of a character (unknown characters map to '?'). */
  glyphX(ch: string): number {
    let code = ch.charCodeAt(0);
    if (code < FIRST || code > LAST) code = 63;
    return (code - FIRST) * this.advance;
  }
}

let current: PixelFont | null = null;

export async function loadPixelFont(): Promise<PixelFont> {
  current = await PixelFont.load();
  return current;
}

export function pixelFont(): PixelFont {
  if (!current) throw new Error('Pixel font not loaded yet');
  return current;
}
