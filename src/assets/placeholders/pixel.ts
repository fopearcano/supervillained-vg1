/**
 * Tiny software rasterizer used to generate the placeholder pixel art at runtime.
 * Works on a Uint32Array view of an ImageData (ABGR little-endian), so it is fast even on phones.
 */

export type Color = number;

const parseCache = new Map<string, number>();

/** Packs '#rrggbb' (+ alpha 0..255) into the ImageData's native ABGR uint32. */
export function rgba(hex: string, a = 255): Color {
  const key = hex + a;
  const hit = parseCache.get(key);
  if (hit !== undefined) return hit;
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  const c = ((a & 255) << 24) | (b << 16) | (g << 8) | r;
  const out = c >>> 0;
  parseCache.set(key, out);
  return out;
}

export const CLEAR: Color = 0;

/** Mixes two '#rrggbb' colors (t = 0 -> a, 1 -> b). */
export function mixHex(a: string, b: string, t: number): string {
  const pa = parseInt(a.slice(1), 16);
  const pb = parseInt(b.slice(1), 16);
  const ch = (shift: number) => {
    const x = (pa >> shift) & 255;
    const y = (pb >> shift) & 255;
    return Math.round(x + (y - x) * t);
  };
  const v = (ch(16) << 16) | (ch(8) << 8) | ch(0);
  return '#' + v.toString(16).padStart(6, '0');
}

export function alphaOf(c: Color): number {
  return (c >>> 24) & 255;
}

export class PixelBuffer {
  readonly w: number;
  readonly h: number;
  readonly data: Uint32Array;

  constructor(w: number, h: number) {
    this.w = w;
    this.h = h;
    this.data = new Uint32Array(w * h);
  }

  set(x: number, y: number, c: Color): void {
    x |= 0;
    y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.data[y * this.w + x] = c;
  }

  get(x: number, y: number): Color {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return 0;
    return this.data[y * this.w + x]!;
  }

  /** Sets only where the destination is already opaque (paint "inside" a shape). */
  setIfOpaque(x: number, y: number, c: Color): void {
    if (alphaOf(this.get(x | 0, y | 0)) > 0) this.set(x, y, c);
  }

  rect(x: number, y: number, w: number, h: number, c: Color): void {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c);
  }

  /** Filled circle sampled at pixel centers; (cx, cy) may be fractional. */
  disc(cx: number, cy: number, r: number, c: Color): void {
    this.ellipse(cx, cy, r, r, c);
  }

  ellipse(cx: number, cy: number, rx: number, ry: number, c: Color): void {
    const x0 = Math.floor(cx - rx - 1);
    const x1 = Math.ceil(cx + rx + 1);
    const y0 = Math.floor(cy - ry - 1);
    const y1 = Math.ceil(cy + ry + 1);
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const dx = (x + 0.5 - cx) / rx;
        const dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) this.set(x, y, c);
      }
    }
  }

  line(x0: number, y0: number, x1: number, y1: number, c: Color): void {
    x0 |= 0;
    y0 |= 0;
    x1 |= 0;
    y1 |= 0;
    const dx = Math.abs(x1 - x0);
    const dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1;
    const sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      this.set(x0, y0, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  /** Adds a 1px outline around opaque pixels (4-neighborhood, or 8 with `diagonal`). */
  outline(c: Color, diagonal = false): void {
    const src = this.data.slice();
    const w = this.w;
    const h = this.h;
    const opaque = (x: number, y: number) => x >= 0 && y >= 0 && x < w && y < h && alphaOf(src[y * w + x]!) > 0;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (opaque(x, y)) continue;
        let n = opaque(x + 1, y) || opaque(x - 1, y) || opaque(x, y + 1) || opaque(x, y - 1);
        if (!n && diagonal) n = opaque(x + 1, y + 1) || opaque(x - 1, y - 1) || opaque(x + 1, y - 1) || opaque(x - 1, y + 1);
        if (n) this.data[y * w + x] = c;
      }
    }
  }

  /** Copies another buffer on top (opaque pixels only), optionally mirrored horizontally. */
  blit(src: PixelBuffer, dx: number, dy: number, flipX = false): void {
    for (let y = 0; y < src.h; y++) {
      for (let x = 0; x < src.w; x++) {
        const c = src.data[y * src.w + (flipX ? src.w - 1 - x : x)]!;
        if (alphaOf(c) > 0) this.set(dx + x, dy + y, c);
      }
    }
  }

  flippedX(): PixelBuffer {
    const out = new PixelBuffer(this.w, this.h);
    out.blit(this, 0, 0, true);
    return out;
  }

  /** Replaces every opaque pixel's color, keeping alpha (used for tinted silhouettes). */
  silhouette(c: Color): PixelBuffer {
    const out = new PixelBuffer(this.w, this.h);
    for (let k = 0; k < this.data.length; k++) if (alphaOf(this.data[k]!) > 0) out.data[k] = c;
    return out;
  }

  toCanvas(): HTMLCanvasElement {
    const canvas = document.createElement('canvas');
    canvas.width = this.w;
    canvas.height = this.h;
    const ctx = canvas.getContext('2d')!;
    const img = ctx.createImageData(this.w, this.h);
    new Uint32Array(img.data.buffer).set(this.data);
    ctx.putImageData(img, 0, 0);
    return canvas;
  }
}
