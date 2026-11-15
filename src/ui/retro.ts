import type { Graphics } from 'pixi.js';

/** Retro HUD colors (saturated neon, as in the video). */
export const C = {
  yellow: '#ffe23a',
  orange: '#ff9a1f',
  red: '#ff2a3a',
  pink: '#ff4fa8',
  magenta: '#e040ff',
  cyan: '#3ff0ff',
  green: '#4dff5a',
  white: '#ffffff',
  paleRose: '#ffd6f0',
  hotPink: '#ff5ad6',
  black: '#000000',
} as const;

export function hex(c: string): number {
  return parseInt(c.slice(1), 16);
}

/** 1px rectangle outline drawn with filled rects (always crisp). */
export function frameRect(g: Graphics, x: number, y: number, w: number, h: number, color: number, alpha = 1): void {
  g.rect(x, y, w, 1).fill({ color, alpha });
  g.rect(x, y + h - 1, w, 1).fill({ color, alpha });
  g.rect(x, y + 1, 1, h - 2).fill({ color, alpha });
  g.rect(x + w - 1, y + 1, 1, h - 2).fill({ color, alpha });
}

/**
 * The HUD box look from the video: dark translucent fill, an outer colored border and a second
 * border in another color just inside it (a "misregistered" double line).
 */
export function retroBox(
  g: Graphics,
  x: number,
  y: number,
  w: number,
  h: number,
  outer: string = C.red,
  inner: string = C.yellow,
  fillAlpha = 0.28,
): void {
  g.rect(x, y, w, h).fill({ color: 0x000000, alpha: fillAlpha });
  frameRect(g, x, y, w, h, hex(outer));
  frameRect(g, x + 1, y + 1, w - 1, h - 1, hex(inner), 0.9);
}

/** Hunger gradient: cyan → yellow → orange → red. */
export function hungerColor(t: number): number {
  const stops: Array<[number, number, number, number]> = [
    [0, 0x3f, 0xf0, 0xff],
    [0.45, 0xff, 0xe2, 0x3a],
    [0.75, 0xff, 0x8a, 0x1f],
    [1, 0xff, 0x2a, 0x3a],
  ];
  for (let k = 1; k < stops.length; k++) {
    const a = stops[k - 1]!;
    const b = stops[k]!;
    if (t <= b[0]) {
      const u = (t - a[0]) / (b[0] - a[0]);
      return (
        (Math.round(a[1] + (b[1] - a[1]) * u) << 16) | (Math.round(a[2] + (b[2] - a[2]) * u) << 8) | Math.round(a[3] + (b[3] - a[3]) * u)
      );
    }
  }
  return 0xff2a3a;
}
