import { Texture } from 'pixi.js';

/**
 * The SUPERVILLAINED logo: a bold, narrow 6×7 pixel lettering in the spirit of the game font, so
 * the 14-letter title fits on ONE line at double size on a ~200-px-wide phone (186 px), and at
 * triple size on wider screens. Drawn once per scale into a canvas texture (crisp, nearest).
 */
const GLYPHS: Record<string, string[]> = {
  S: ['.#####', '##....', '##....', '.####.', '....##', '....##', '#####.'],
  U: ['##..##', '##..##', '##..##', '##..##', '##..##', '##..##', '.####.'],
  P: ['#####.', '##..##', '##..##', '#####.', '##....', '##....', '##....'],
  E: ['######', '##....', '##....', '#####.', '##....', '##....', '######'],
  R: ['#####.', '##..##', '##..##', '#####.', '##.##.', '##..##', '##..##'],
  V: ['##..##', '##..##', '##..##', '##..##', '.####.', '.####.', '..##..'],
  I: ['####', '.##.', '.##.', '.##.', '.##.', '.##.', '####'],
  L: ['##....', '##....', '##....', '##....', '##....', '##....', '######'],
  A: ['.####.', '##..##', '##..##', '######', '##..##', '##..##', '##..##'],
  N: ['##..##', '###.##', '######', '##.###', '##..##', '##..##', '##..##'],
  D: ['#####.', '##..##', '##..##', '##..##', '##..##', '##..##', '#####.'],
  ' ': ['...', '...', '...', '...', '...', '...', '...'],
};
const ROWS = 7;
const GAP = 1;

export interface LogoStyle {
  /** Top rows, middle and bottom row (a small vertical gradient). */
  colors: [string, string, string];
  outline: string;
  shadow: string;
  glow: string;
}

/** Width of `text` in font pixels (before scaling). */
export function logoWidth(text: string): number {
  let w = 0;
  for (const ch of text) w += (GLYPHS[ch]?.[0]?.length ?? 6) + GAP;
  return Math.max(0, w - GAP);
}

const cache = new Map<string, Texture>();

/** A crisp texture of `text` at an integer `scale`, with outline, drop shadow and soft glow. */
export function logoTexture(text: string, scale: number, style: LogoStyle): Texture {
  const key = `${text}|${scale}|${Object.values(style).join(',')}`;
  const hit = cache.get(key);
  if (hit) return hit;
  const pad = 3;
  const w = logoWidth(text) * scale + pad * 2;
  const h = ROWS * scale + pad * 2 + scale;
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d')!;
  // Collect the lit font pixels as logical-pixel rectangles.
  const rects: Array<{ x: number; y: number; row: number }> = [];
  let cx = 0;
  for (const ch of text) {
    const g = GLYPHS[ch] ?? GLYPHS[' ']!;
    g.forEach((line, row) => {
      for (let col = 0; col < line.length; col++) if (line[col] === '#') rects.push({ x: pad + (cx + col) * scale, y: pad + row * scale, row });
    });
    cx += g[0]!.length + GAP;
  }
  const fill = (color: string, grow: number, dx: number, dy: number, alpha = 1) => {
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    for (const r of rects) ctx.fillRect(r.x - grow + dx, r.y - grow + dy, scale + grow * 2, scale + grow * 2);
  };
  fill(style.glow, 2, 0, 0, 0.25);
  fill(style.shadow, 1, 0, scale, 1);
  fill(style.outline, 1, 0, 0, 1);
  ctx.globalAlpha = 1;
  for (const r of rects) {
    ctx.fillStyle = r.row <= 1 ? style.colors[0] : r.row === ROWS - 1 ? style.colors[2] : style.colors[1];
    ctx.fillRect(r.x, r.y, scale, scale);
  }
  const tex = Texture.from(canvas);
  cache.set(key, tex);
  return tex;
}
