import { hash2 } from '../../core/rng';
import { TH, TW, insideDiamond } from '../../iso/projection';
import type { Palette, Swatch } from '../../world/level';
import { PixelBuffer, mixHex, rgba } from './pixel';

/**
 * Placeholder art for the story campaign: extra ground tiles, story props (colored by the zone
 * palette) and a few special sprites. Same tiny rasterizer as the rest of the placeholders.
 */

const DEFAULTS: Record<string, Swatch> = {
  floor: ['#a8763e', '#7e5428', '#c8945a'],
  stone: ['#c8c0b0', '#a29a8a', '#e4ded2'],
  sand: ['#e8cc8a', '#c8a866', '#f6e2ac'],
  snow: ['#eef4fa', '#c8d6e6', '#ffffff'],
  deep: ['#1e4c9a', '#14366e', '#4a7cc8'],
  wall: ['#d8c8a8', '#a89878', '#f0e4c8'],
  roof: ['#c0503a', '#8a3424', '#e07454'],
  cloth: ['#d03030', '#9a2020', '#f06060'],
  dock: ['#8a6440', '#5e4228', '#a88058'],
  carpet: ['#a01c2c', '#6e1220', '#e0b040'],
};

export function swatch(pal: Palette, key: keyof typeof DEFAULTS): Swatch {
  return (pal as unknown as Record<string, Swatch | undefined>)[key] ?? DEFAULTS[key]!;
}

function fill(pb: PixelBuffer, color: (x: number, y: number) => number | null): void {
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) if (insideDiamond(x, y)) {
    const c = color(x, y);
    if (c !== null) pb.set(x, y, c);
  }
}

// ---------------------------------------------------------------- ground tiles

const mod = (n: number, d: number): number => ((n % d) + d) % d;

/** Low-frequency, material-shaped variation (avoids per-pixel television noise). */
function materialNoise(x: number, y: number, salt: number): number {
  return hash2(Math.floor(x / 4), Math.floor(y / 2), salt);
}

export function drawStoryTile(pal: Palette, kind: string, variant: number): PixelBuffer {
  const pb = new PixelBuffer(TW, TH);
  const h = (x: number, y: number, s = 0) => hash2(x, y, 900 + variant * 17 + s);
  switch (kind) {
    case 'floor':
    case 'dock': {
      const colors = swatch(pal, kind);
      const [b, d, l] = colors.map((c) => rgba(c));
      const gap = rgba(mixHex(colors[1], '#000000', kind === 'dock' ? 0.55 : 0.28));
      const plankWidth = kind === 'floor' ? 10 : 8;
      const plankLength = kind === 'floor' ? 20 : 16;
      fill(pb, (x, y) => {
        // Isometric axes: a separates boards, b runs along their length.
        const a = x + 2 * y + variant * 3;
        const bAxis = x - 2 * y + 96;
        const across = mod(a, plankWidth);
        const board = Math.floor(a / plankWidth);
        const along = mod(bAxis + mod(board, 2) * Math.floor(plankLength / 2), plankLength);
        if (across === 0 || along === 0) return gap;
        if (across === 1 || along === 1) return kind === 'dock' ? d! : l!;
        // Nail heads at staggered joins, especially legible on broad dock boards.
        if (along <= 2 && (across === 2 || across === plankWidth - 2)) return gap;
        const grain = mod(bAxis + Math.floor(materialNoise(x, y, 930) * 5), 11);
        if (grain === 3 && h(x, y, 31) > 0.6) return d!;
        if (grain === 4 && h(x, y, 32) > 0.72) return l!;
        return b!;
      });
      break;
    }
    case 'stone':
    case 'wallBase': {
      const colors = swatch(pal, kind === 'stone' ? 'stone' : 'wall');
      const [b, d, l] = colors.map((c) => rgba(c));
      const mortar = rgba(mixHex(colors[1], '#000000', kind === 'wallBase' ? 0.42 : 0.18));
      fill(pb, (x, y) => {
        const size = kind === 'wallBase' ? 9 : 12;
        const a = x + 2 * y + variant * 3;
        const course = Math.floor(a / size);
        const u = mod(a, size);
        const v = mod(x - 2 * y + 96 + mod(course, 2) * Math.floor(size / 2), size);
        if (u === 0 || v === 0) return mortar;
        if (u === 1 || v === 1) return kind === 'wallBase' ? d! : l!;
        const patch = materialNoise(x, y, 950 + variant * 11);
        if (patch < 0.1 && h(x, y, 4) < 0.55) return d!;
        if (kind === 'stone' && patch > 0.9 && h(x, y, 5) < 0.5) return l!;
        return kind === 'wallBase' && h(x, y, 6) < 0.16 ? d! : b!;
      });
      break;
    }
    case 'sand': {
      const [b, d, l] = swatch(pal, 'sand').map((c) => rgba(c));
      fill(pb, (x, y) => {
        // Wind-combed ripples make desert routes directional; pebbles sit between bands.
        const ripple = mod(x + 3 * y + variant * 4, 13);
        const segment = hash2(Math.floor(x / 4), Math.floor(y / 2), 970);
        if (ripple === 0 && segment > 0.18) return l!;
        if (ripple === 1 && segment > 0.52) return d!;
        const patch = materialNoise(x, y, 971 + variant);
        if (patch < 0.09 && h(x, y, 8) < 0.42) return d!;
        return b!;
      });
      break;
    }
    case 'snow': {
      const [b, d, l] = swatch(pal, 'snow').map((c) => rgba(c));
      fill(pb, (x, y) => {
        const u = (x + 0.5 - TW / 2) / (TW / 2);
        const v = (y + 0.5 - TH / 2) / (TH / 2);
        const edge = Math.abs(u) + Math.abs(v);
        const drift = mod(x + 3 * y + variant * 5, 17);
        if (edge > 0.88) return d!;
        if (drift === 0 && materialNoise(x, y, 980) > 0.28) return l!;
        if (drift === 1 && h(x, y, 9) > 0.72) return d!;
        return materialNoise(x, y, 981 + variant) < 0.06 ? d! : b!;
      });
      break;
    }
    case 'deep': {
      const [b, d, l] = swatch(pal, 'deep').map((c) => rgba(c));
      fill(pb, (x, y) => {
        // No per-tile rim: open sea and lagoons should read as continuous bodies of water.
        const wave = mod(x + y * 3 + variant * 5, 14);
        if ((wave === 0 || wave === 1) && hash2(Math.floor(x / 3), y, 990) > 0.22) return l!;
        if (wave === 8 && h(x, y, 3) > 0.58) return d!;
        return b!;
      });
      break;
    }
    case 'carpet': {
      const [b, d, l] = swatch(pal, 'carpet').map((c) => rgba(c));
      fill(pb, (x, y) => {
        const u = (x + 0.5 - TW / 2) / (TW / 2);
        const v = (y + 0.5 - TH / 2) / (TH / 2);
        const e = Math.abs(u) + Math.abs(v);
        if (e > 0.9) return d!;
        if (e > 0.72) return l!;
        if (e > 0.64) return d!;
        // Repeating woven lozenges read as an authored court carpet across large halls.
        const a = mod(x + 2 * y + variant * 2, 8);
        const c = mod(x - 2 * y + 64 + variant * 2, 8);
        if ((a === 0 || c === 0) && e < 0.58) return d!;
        if ((a === 1 && c === 1) || (a === 7 && c === 7)) return l!;
        if (e < 0.18) return l!;
        return materialNoise(x, y, 1000 + variant) < 0.04 ? d! : b!;
      });
      break;
    }
  }
  return pb;
}

// ---------------------------------------------------------------- props

function outline(pb: PixelBuffer, color = '#1a1410'): PixelBuffer {
  pb.outline(rgba(color));
  return pb;
}

/** Iso box: top diamond (w x w/2) raised by `height`, left/right faces. Origin = bottom vertex. */
function isoBox(pb: PixelBuffer, cx: number, by: number, halfW: number, height: number, top: string, left: string, right: string): void {
  const T = rgba(top);
  const L = rgba(left);
  const R = rgba(right);
  const halfH = halfW / 2;
  // Faces drawn column by column (bottom edge follows the diamond's lower half).
  for (let x = -halfW; x < halfW; x++) {
    const dx = Math.abs(x + 0.5);
    const bottom = by - dx / 2;
    for (let y = 0; y < height; y++) pb.set(cx + x, Math.round(bottom - y), x < 0 ? L : R);
    // top diamond
    const topCenter = by - halfH - height;
    const span = halfH - dx / 2;
    for (let y = -span; y <= span; y++) pb.set(cx + x, Math.round(topCenter + y), T);
  }
}

export function drawStoryProp(pal: Palette, kind: string, variant: number): PixelBuffer {
  const [wb, wd, wl] = swatch(pal, 'wall');
  const [rb, rd] = swatch(pal, 'roof');
  const [cb, cd, cl] = swatch(pal, 'cloth');
  const [sb, sd, sl] = swatch(pal, 'stone');
  const [fb, fd, fl] = swatch(pal, 'floor');
  const [gb, gd, gl] = pal.foliage;
  switch (kind) {
    case 'column': {
      const pb = new PixelBuffer(16, 52);
      pb.rect(2, 44, 12, 5, rgba(sd));
      pb.rect(4, 8, 8, 37, rgba(sb));
      for (const x of [5, 8, 11]) pb.rect(x, 9, 1, 35, rgba(sd));
      pb.rect(4, 8, 2, 37, rgba(sl));
      pb.rect(1, 3, 14, 5, rgba(sb));
      pb.rect(2, 2, 12, 1, rgba(sl));
      return outline(pb);
    }
    case 'desk': {
      const pb = new PixelBuffer(40, 30);
      isoBox(pb, 20, 28, 18, 10, fl, fb, fd);
      pb.rect(13, 8, 7, 4, rgba('#f4f0e0'));
      pb.rect(22, 9, 6, 3, rgba('#e8e2d0'));
      pb.line(26, 4, 29, 10, rgba('#f8f8f8'));
      return outline(pb);
    }
    case 'shelf': {
      const pb = new PixelBuffer(32, 48);
      pb.rect(4, 4, 24, 42, rgba(fd));
      pb.rect(6, 6, 20, 38, rgba(mixHex(fd, '#000000', 0.4)));
      const books = ['#c03030', '#3050c0', '#30a050', '#d0a030', '#8030a0', '#e0e0d0'];
      for (let row = 0; row < 4; row++) {
        const y = 8 + row * 9;
        pb.rect(6, y + 7, 20, 2, rgba(fb));
        for (let k = 0; k < 6; k++) {
          const hgt = 5 + Math.floor(hash2(k, row, 4) * 3);
          pb.rect(7 + k * 3, y + 7 - hgt, 2, hgt, rgba(books[(k + row) % books.length]!));
        }
      }
      return outline(pb);
    }
    case 'house': {
      const pb = new PixelBuffer(40, 58);
      isoBox(pb, 20, 56, 18, 26, wl, wb, wd);
      // Pitched roof.
      const R = rgba(variant ? rd : rb);
      const R2 = rgba(variant ? rb : rd);
      for (let y = 0; y < 16; y++) {
        const half = Math.round(y * 1.25);
        for (let x = -half; x <= half; x++) pb.set(20 + x, 6 + y, x < 0 ? R : R2);
      }
      pb.rect(10, 38, 4, 8, rgba('#4a2c18'));
      pb.rect(24, 34, 4, 4, rgba('#2a3a5a'));
      pb.rect(31, 31, 3, 4, rgba('#2a3a5a'));
      return outline(pb);
    }
    case 'tent': {
      const pb = new PixelBuffer(40, 40);
      const A = rgba(variant ? cl : cb);
      const B = rgba('#f4f0e4');
      const D = rgba(cd);
      for (let y = 0; y < 26; y++) {
        const half = Math.round(y * 0.72);
        for (let x = -half; x <= half; x++) pb.set(20 + x, 8 + y, x < 0 ? (Math.floor((x - 20) / 3) % 2 ? A : B) : Math.floor(x / 3) % 2 ? D : B);
      }
      pb.rect(18, 26, 4, 8, rgba('#2a1c14'));
      pb.line(20, 2, 20, 9, rgba('#4a3420'));
      pb.rect(21, 2, 5, 3, A);
      return outline(pb);
    }
    case 'galley': {
      const pb = new PixelBuffer(72, 60);
      const H = rgba('#6a4224');
      const HL = rgba('#8a5a34');
      for (let x = 4; x < 68; x++) {
        const t = (x - 36) / 32;
        const depth = Math.round(9 * (1 - t * t));
        for (let y = 0; y < depth; y++) pb.set(x, 42 + y - Math.round(Math.abs(t) * 6), y < 2 ? HL : H);
      }
      for (let k = 0; k < 7; k++) pb.line(12 + k * 8, 46, 8 + k * 8, 54, rgba('#d8c8a0'));
      for (let k = 0; k < 6; k++) pb.disc(14 + k * 9, 41, 2.2, rgba(k % 2 ? cb : '#f0f0f0'));
      pb.rect(35, 6, 2, 36, rgba('#4a2c18'));
      const S = rgba(variant ? '#f0e8d0' : cl);
      for (let y = 0; y < 22; y++) for (let x = -12 + Math.round(y / 6); x <= 12 - Math.round(y / 6); x++) pb.set(36 + x, 9 + y, S);
      for (let k = -2; k <= 2; k++) {
        pb.set(36 + k * 2, 19, rgba('#d42424'));
        pb.set(36, 19 + k * 2, rgba('#d42424'));
      }
      return outline(pb);
    }
    case 'rock': {
      const pb = new PixelBuffer(24, 18);
      pb.ellipse(12, 11, 10, 6, rgba(sd));
      pb.ellipse(10, 9, 7, 5, rgba(sb));
      pb.ellipse(9, 7, 3, 2, rgba(sl));
      return outline(pb);
    }
    case 'statue': {
      const pb = new PixelBuffer(20, 50);
      pb.rect(3, 34, 14, 14, rgba(sd));
      pb.rect(4, 34, 4, 14, rgba(sb));
      const Bz = rgba('#8a7a4a');
      const Bl = rgba('#b8a868');
      pb.ellipse(10, 24, 4, 8, Bz);
      pb.disc(10, 12, 3.5, Bl);
      pb.line(6, 20, 3, 14, Bz);
      pb.line(14, 20, 17, 24, Bz);
      return outline(pb);
    }
    case 'crate': {
      const pb = new PixelBuffer(20, 20);
      isoBox(pb, 10, 18, 8, 8, fl, fb, fd);
      pb.line(3, 12, 9, 15, rgba(fd));
      pb.line(11, 15, 17, 12, rgba(fd));
      return outline(pb);
    }
    case 'palm': {
      const pb = new PixelBuffer(36, 56);
      for (let y = 18; y < 54; y++) {
        const x = 18 + Math.round(Math.sin(y / 9) * 1.5);
        pb.rect(x - 1, y, 3, 1, rgba(y % 4 === 0 ? '#5a3a1c' : '#8a5a2c'));
      }
      const G = rgba(gb);
      const Gd = rgba(gd);
      for (const [dx, dy] of [
        [-14, 4],
        [14, 4],
        [-10, -6],
        [10, -6],
        [0, -10],
        [-16, 10],
        [16, 10],
      ] as const) {
        pb.line(18, 18, 18 + dx, 18 + dy, G);
        pb.line(18, 19, 18 + dx, 19 + dy, Gd);
      }
      return outline(pb, '#10240c');
    }
    case 'altar': {
      const pb = new PixelBuffer(28, 26);
      isoBox(pb, 14, 24, 12, 9, sl, sb, sd);
      pb.rect(5, 8, 18, 3, rgba('#f4f4f0'));
      pb.rect(8, 2, 1, 6, rgba('#f8f0d0'));
      pb.set(8, 1, rgba('#ffd040'));
      pb.rect(19, 2, 1, 6, rgba('#f8f0d0'));
      pb.set(19, 1, rgba('#ffd040'));
      pb.rect(13, 1, 2, 7, rgba('#e8c048'));
      pb.rect(11, 3, 6, 2, rgba('#e8c048'));
      return outline(pb);
    }
    case 'stall': {
      const pb = new PixelBuffer(36, 40);
      isoBox(pb, 18, 38, 14, 10, fl, fb, fd);
      for (let x = 2; x < 34; x++) pb.rect(x, 6 + Math.round(Math.abs(x - 18) / 4), 1, 6, rgba(Math.floor(x / 4) % 2 ? cb : '#f4f0e4'));
      pb.rect(4, 12, 1, 18, rgba('#4a2c18'));
      pb.rect(31, 12, 1, 18, rgba('#4a2c18'));
      for (let k = 0; k < 5; k++) pb.disc(10 + k * 4, 22, 1.6, rgba(['#e04040', '#f0c030', '#60c040', '#f08030', '#a040c0'][k]!));
      return outline(pb);
    }
    case 'throne': {
      const pb = new PixelBuffer(28, 40);
      const Gd = rgba('#e8c048');
      const Pu = rgba('#7a2aa0');
      pb.rect(6, 2, 16, 26, Gd);
      pb.rect(8, 4, 12, 22, Pu);
      isoBox(pb, 14, 38, 12, 8, '#9a3ac0', '#6a1a90', '#5a1080');
      pb.disc(14, 2, 2.5, Gd);
      return outline(pb);
    }
    case 'vine': {
      const pb = new PixelBuffer(26, 24);
      pb.disc(9, 13, 7, rgba(gd));
      pb.disc(17, 13, 7, rgba(gd));
      pb.disc(13, 9, 7, rgba(gb));
      pb.disc(11, 7, 3, rgba(gl));
      for (let k = 0; k < 6; k++) pb.disc(6 + k * 3, 14 + (k % 2) * 3, 1.4, rgba(k % 2 ? '#6a2a8a' : '#8a4aa8'));
      return outline(pb, '#0c2a0c');
    }
    case 'gate': {
      const pb = new PixelBuffer(64, 66);
      for (const tx of [10, 54]) {
        pb.rect(tx - 8, 12, 16, 50, rgba(wb));
        pb.rect(tx - 8, 12, 5, 50, rgba(wl));
        for (let k = 0; k < 3; k++) pb.rect(tx - 8 + k * 6, 8, 4, 4, rgba(wb));
      }
      pb.rect(18, 22, 28, 40, rgba(wd));
      pb.rect(18, 22, 28, 4, rgba(wl));
      for (let y = 0; y < 30; y++) {
        const half = y < 10 ? Math.round(Math.sqrt(100 - (10 - y) * (10 - y)) * 1.1) : 11;
        for (let x = -half; x <= half; x++) pb.set(32 + x, 32 + y, rgba('#2a1e14'));
      }
      pb.rect(26, 52, 12, 10, rgba(variant ? '#f0e090' : '#3a2a18'));
      return outline(pb);
    }
    case 'wicket': {
      // A painted garden gate: two posts and bars (a ball fits between them).
      const pb = new PixelBuffer(30, 24);
      const post = rgba('#f4f0e8');
      const bar = rgba('#7aa8d8');
      for (const x of [2, 25]) {
        pb.rect(x, 4, 3, 18, post);
        pb.rect(x, 3, 3, 1, rgba('#c8c0b0'));
      }
      pb.rect(5, 8, 20, 2, bar);
      pb.rect(5, 17, 20, 2, bar);
      for (let x = 7; x < 25; x += 4) pb.rect(x, 8, 2, 11, bar);
      return outline(pb, '#2a3040');
    }
    case 'bones': {
      const pb = new PixelBuffer(22, 10);
      const W = rgba('#f0ece0');
      for (const ox of [2, 12]) {
        pb.disc(ox + 1.5, 3, 1.6, W);
        pb.line(ox + 3, 4, ox + 8, 4, W);
        pb.line(ox + 5, 2, ox + 5, 7, W);
        pb.line(ox + 8, 4, ox + 9, 8, W);
      }
      return outline(pb, '#6a6050');
    }
    case 'table': {
      const pb = new PixelBuffer(40, 24);
      isoBox(pb, 20, 22, 18, 6, '#ffffff', '#e4e8ee', '#c8ccd4');
      for (const [x, y] of [
        [12, 7],
        [18, 5],
        [24, 7],
        [28, 9],
      ] as const) {
        pb.rect(x, y - 3, 2, 3, rgba('#a8e0f0'));
        pb.set(x, y - 3, rgba('#ffffff'));
      }
      pb.disc(16, 10, 2, rgba('#c84040'));
      return outline(pb, '#4a4a54');
    }
    case 'wallBlock': {
      const pb = new PixelBuffer(32, 40);
      isoBox(pb, 16, 39, 16, 24, wl, wb, wd);
      const M = rgba(mixHex(wd, '#000000', 0.25));
      for (let y = 22; y < 38; y += 6) {
        pb.line(1, y, 15, y + 7, M);
        pb.line(17, y + 7, 31, y, M);
      }
      if (variant === 1) for (let k = 0; k < 4; k++) pb.rect(3 + k * 8, 2 + Math.abs(k - 1.5) * 2, 4, 3, rgba(wl));
      return pb;
    }
  }
  return new PixelBuffer(4, 4);
}

// ---------------------------------------------------------------- specials

export function drawSpecial(kind: string, variant: number): PixelBuffer {
  switch (kind) {
    case 'legs': {
      // The Professor, seen by a dog: tweed trousers and slippers, pacing.
      const pb = new PixelBuffer(28, 64);
      const T = rgba('#6a6658');
      const Td = rgba('#4e4a40');
      const Sl = rgba('#7a2030');
      const phase = [0, 3, 0, -3][variant]!;
      for (const [side, off] of [
        [-1, phase],
        [1, -phase],
      ] as const) {
        const x0 = 14 + side * 5 + off;
        for (let y = 0; y < 52; y++) {
          const lean = Math.round((off * (52 - y)) / 52);
          pb.rect(x0 - 4 - lean + off, y, 8, 1, y < 2 ? Td : side < 0 ? Td : T);
        }
        pb.ellipse(x0 + side * 2, 58, 6, 3.5, Sl);
      }
      pb.rect(4, 0, 20, 4, rgba('#3a3630'));
      return outline(pb);
    }
    case 'fortune': {
      const pb = new PixelBuffer(26, 66);
      const R = rgba('#e8c048');
      const Rd = rgba('#b08a28');
      for (let y = 18; y < 64; y++) {
        const half = Math.round(4 + (y - 18) * 0.18);
        for (let x = -half; x <= half; x++) pb.set(13 + x, y, x < -half / 3 ? Rd : R);
      }
      pb.disc(13, 12, 5, rgba('#f4d8c0'));
      pb.ellipse(13, 9, 7, 5, rgba('#9a6ad0'));
      pb.ellipse(13, 14, 4, 3, rgba('#f4d8c0'));
      pb.rect(11, 13, 1, 1, rgba('#222222'));
      pb.rect(15, 13, 1, 1, rgba('#222222'));
      const up = variant === 1;
      pb.line(9, 22, up ? 2 : 3, up ? 10 : 34, R);
      pb.line(17, 22, up ? 24 : 23, up ? 10 : 34, R);
      pb.disc(up ? 2 : 3, up ? 9 : 35, 2.5, rgba('#f4d8c0'));
      pb.disc(up ? 24 : 23, up ? 9 : 35, 2.5, rgba('#f4d8c0'));
      return outline(pb, '#3a2a10');
    }
    case 'falcon': {
      const pb = new PixelBuffer(18, 12);
      const B = rgba('#7a5a3a');
      pb.ellipse(9, 7, 4, 2.5, B);
      pb.disc(13, 5.5, 2, B);
      pb.set(15, 5, rgba('#f0c030'));
      if (variant === 0) {
        pb.line(8, 6, 2, 1, B);
        pb.line(10, 6, 14, 0, B);
      } else {
        pb.line(8, 7, 1, 10, B);
        pb.line(10, 7, 16, 11, B);
      }
      return outline(pb);
    }
    case 'stag': {
      const pb = new PixelBuffer(48, 46);
      const B = rgba('#a06a3a');
      const Bd = rgba('#7a4a24');
      pb.ellipse(22, 28, 12, 6, B);
      for (const x of [13, 17, 27, 31]) pb.rect(x, 32, 2, 10, Bd);
      pb.line(32, 25, 37, 15, B);
      pb.line(33, 25, 38, 15, B);
      pb.ellipse(39, 13, 4, 3, B);
      for (const dx of [-3, 3]) {
        pb.line(38 + dx, 10, 38 + dx * 2, 2, rgba('#e8d8b0'));
        pb.line(38 + dx * 2, 5, 38 + dx * 3, 3, rgba('#e8d8b0'));
      }
      const W = rgba('#ffffff');
      for (let k = 0; k < 4; k++) pb.line(20 - k * 3, 24, 6 - k * 2, 6 + k * 2, W);
      pb.set(41, 12, rgba('#111111'));
      return outline(pb);
    }
    case 'shard': {
      const pb = new PixelBuffer(9, 13);
      for (let y = 0; y < 12; y++) {
        const half = y < 6 ? Math.floor(y / 1.5) : Math.floor((12 - y) / 2);
        for (let x = -half; x <= half; x++) pb.set(4 + x, y, rgba(x < 0 ? '#9af0ff' : x === 0 ? '#ffffff' : '#4ac0e8'));
      }
      return outline(pb, '#10406a');
    }
    case 'relic': {
      const pb = new PixelBuffer(12, 12);
      pb.rect(1, 4, 10, 7, rgba('#c89a30'));
      pb.rect(1, 4, 10, 2, rgba('#f0d060'));
      pb.rect(5, 1, 2, 4, rgba('#f0d060'));
      pb.rect(4, 2, 4, 1, rgba('#f0d060'));
      pb.set(5, 7, rgba('#e02040'));
      return outline(pb, '#4a3008');
    }
    case 'bowl': {
      const pb = new PixelBuffer(14, 8);
      pb.rect(1, 2, 12, 5, rgba('#8a96b0'));
      pb.rect(2, 7, 10, 1, rgba('#5a6478'));
      pb.rect(2, 2, 10, 2, rgba('#5ac8ff'));
      pb.rect(3, 2, 3, 1, rgba('#d8f4ff'));
      return outline(pb, '#2a3040');
    }
    case 'banner': {
      const pb = new PixelBuffer(12, 26);
      pb.rect(1, 2, 1, 24, rgba('#5a3a1c'));
      const R = rgba(variant ? '#3050c0' : '#c02828');
      for (let y = 0; y < 12; y++) for (let x = 0; x < 8; x++) pb.set(2 + x, 3 + y + (variant && x > 4 ? 1 : 0), R);
      pb.rect(5, 5, 1, 7, rgba('#f0f0f0'));
      pb.rect(3, 7, 5, 1, rgba('#f0f0f0'));
      return outline(pb);
    }
    case 'flame': {
      const pb = new PixelBuffer(16, 22);
      const s = [0, 1.5, -1][variant]!;
      pb.ellipse(8, 15, 6, 6, rgba('#e03a10'));
      pb.ellipse(8 + s, 11, 4.5, 7, rgba('#f07a18'));
      pb.ellipse(8 - s * 0.5, 13, 2.5, 5, rgba('#ffd040'));
      pb.set(Math.round(8 + s * 2), 2, rgba('#f07a18'));
      return pb;
    }
    case 'professorFace': {
      const pb = new PixelBuffer(24, 24);
      pb.ellipse(12, 13, 9, 10, rgba('#f0c8a8'));
      pb.ellipse(12, 5, 9, 4, rgba('#c8c8c8'));
      pb.ellipse(12, 19, 7, 5, rgba('#d8d8d8'));
      pb.ellipse(12, 15, 3, 1.5, rgba('#f0c8a8'));
      for (const x of [8, 16]) {
        pb.disc(x, 11, 3, rgba('#3a3030'));
        pb.disc(x, 11, 2, rgba('#e8f4fa'));
        pb.set(x, 11, rgba('#222222'));
      }
      pb.rect(10, 11, 4, 1, rgba('#3a3030'));
      pb.rect(10, 17, 4, 1, rgba('#8a4a4a'));
      return outline(pb, '#3a2a20');
    }
    case 'bee': {
      const pb = new PixelBuffer(5, 4);
      pb.rect(0, 1, 5, 2, rgba('#f0c020'));
      pb.rect(2, 1, 1, 2, rgba('#202020'));
      pb.rect(1, 0, 2, 1, rgba('#e0f0ff'));
      return pb;
    }
    case 'tear': {
      const pb = new PixelBuffer(5, 7);
      pb.disc(2.5, 4.5, 2.3, rgba('#5ac8ff'));
      pb.rect(2, 0, 1, 3, rgba('#5ac8ff'));
      pb.set(1, 4, rgba('#d8f4ff'));
      return outline(pb, '#10406a');
    }
    case 'mask': {
      const pb = new PixelBuffer(9, 7);
      pb.ellipse(4.5, 3.5, 4.4, 2.6, rgba('#e02030'));
      pb.rect(2, 3, 2, 1, rgba('#000000'));
      pb.rect(5, 3, 2, 1, rgba('#000000'));
      return outline(pb, '#3a0008');
    }
    case 'halo': {
      const pb = new PixelBuffer(9, 7);
      pb.ellipse(4.5, 3.5, 4.4, 2.8, rgba('#ffd040'));
      pb.ellipse(4.5, 3.5, 2.6, 1.2, rgba('#000000', 0));
      return outline(pb, '#6a4a00');
    }
  }
  return new PixelBuffer(2, 2);
}
