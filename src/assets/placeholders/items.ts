import { dirToScreenVector, type Dir8 } from '../../iso/projection';
import { PixelBuffer, rgba } from './pixel';

/** Placeholder items, popups, particles and HUD icons. */

export function drawTreat(): PixelBuffer {
  // Bone: two knobs on each end joined by a shaft.
  const pb = new PixelBuffer(13, 8);
  const base = rgba('#fff0a8');
  const shade = rgba('#e7b84a');
  for (const x of [2, 10]) {
    pb.disc(x + 0.5, 2.5, 1.9, shade);
    pb.disc(x + 0.5, 5, 1.9, shade);
  }
  pb.rect(2, 3, 9, 2, shade);
  for (const x of [2, 10]) {
    pb.disc(x + 0.3, 2.2, 1.4, base);
    pb.disc(x + 0.3, 4.7, 1.3, base);
  }
  pb.rect(2, 3, 9, 1, base);
  pb.outline(rgba('#4a2c0a'));
  return pb;
}

export function drawBall(): PixelBuffer {
  const pb = new PixelBuffer(7, 7);
  pb.disc(3.5, 3.5, 3.3, rgba('#a6c020'));
  pb.disc(3.2, 3.1, 2.6, rgba('#dcf23a'));
  pb.set(1, 2, rgba('#ffffff'));
  pb.set(2, 3, rgba('#ffffff'));
  pb.set(3, 4, rgba('#ffffff'));
  pb.set(4, 4, rgba('#ffffff'));
  pb.set(5, 3, rgba('#ffffff'));
  return pb;
}

export function drawPoop(): PixelBuffer {
  const pb = new PixelBuffer(10, 9);
  const base = rgba('#8a5422');
  const light = rgba('#b8783a');
  const dark = rgba('#5a3210');
  pb.ellipse(5, 7, 4.6, 1.8, dark);
  pb.ellipse(5, 6.6, 4, 1.4, base);
  pb.ellipse(5, 4.6, 3.2, 1.5, base);
  pb.ellipse(5, 2.8, 2.1, 1.2, base);
  pb.set(5, 0, base);
  pb.set(3, 4, light);
  pb.set(4, 2, light);
  pb.set(3, 6, light);
  pb.outline(rgba('#2a1404'));
  return pb;
}

export function drawCoin(): PixelBuffer {
  const pb = new PixelBuffer(7, 7);
  pb.disc(3.5, 3.5, 3.4, rgba('#c07800'));
  pb.disc(3.3, 3.3, 2.6, rgba('#ffd23a'));
  pb.rect(3, 2, 1, 3, rgba('#fff3a0'));
  return pb;
}

export function drawRainbow(): PixelBuffer {
  // Pixel rainbow with two little clouds, like the pee popup in the video.
  const pb = new PixelBuffer(26, 14);
  const bands = ['#ff3b3b', '#ff9a1f', '#ffe23a', '#5ee03a', '#3bb8ff', '#a05aff'];
  const cx = 13;
  const cy = 13;
  for (let y = 0; y < 14; y++) {
    for (let x = 0; x < 26; x++) {
      const d = Math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.05);
      const band = Math.floor(12 - d);
      if (band >= 0 && band < bands.length) pb.set(x, y, rgba(bands[band]!));
    }
  }
  const cloud = rgba('#ffffff');
  const cloudShade = rgba('#d6e2f0');
  for (const x of [4, 22]) {
    pb.disc(x, 12, 2.6, cloudShade);
    pb.disc(x - 1.5, 11.4, 2, cloud);
    pb.disc(x + 1.5, 11.6, 2, cloud);
  }
  pb.outline(rgba('#3a2a60'));
  return pb;
}

export function drawThought(): PixelBuffer {
  // Speech bubble with a tiny poop inside: "I need to go!"
  const pb = new PixelBuffer(13, 14);
  pb.ellipse(6.5, 5.5, 6, 5, rgba('#ffffff'));
  pb.set(5, 11, rgba('#ffffff'));
  pb.set(6, 11, rgba('#ffffff'));
  pb.set(5, 12, rgba('#ffffff'));
  const base = rgba('#8a5422');
  pb.ellipse(6.5, 7.6, 3, 1, base);
  pb.ellipse(6.5, 6, 2.2, 1, base);
  pb.ellipse(6.5, 4.6, 1.3, 0.9, base);
  pb.set(6, 3, base);
  pb.outline(rgba('#1a1a2a'));
  return pb;
}

/** Bark sound-wave arc for a screen direction: `)` shapes, iso-squashed. */
export function drawWave(dir: Dir8): PixelBuffer {
  const pb = new PixelBuffer(16, 16);
  const v = dirToScreenVector(dir);
  const base = Math.atan2(v.y * 2, v.x);
  const c = rgba('#ffffff');
  for (let a = -0.9; a <= 0.9; a += 0.05) {
    const ang = base + a;
    const x = 8 + Math.cos(ang) * 6.5;
    const y = 8 + Math.sin(ang) * 6.5 * 0.6;
    pb.set(Math.round(x - 0.5), Math.round(y - 0.5), c);
  }
  return pb;
}

export function drawSparkle(): PixelBuffer {
  const pb = new PixelBuffer(5, 5);
  const w = rgba('#ffffff');
  pb.set(2, 0, w);
  pb.set(2, 1, w);
  pb.set(0, 2, w);
  pb.set(1, 2, w);
  pb.set(2, 2, w);
  pb.set(3, 2, w);
  pb.set(4, 2, w);
  pb.set(2, 3, w);
  pb.set(2, 4, w);
  return pb;
}

export function drawTri(): PixelBuffer {
  const pb = new PixelBuffer(7, 6);
  const w = rgba('#ffffff');
  pb.line(0, 5, 3, 0, w);
  pb.line(3, 0, 6, 5, w);
  pb.line(0, 5, 6, 5, w);
  return pb;
}

export function drawCross(): PixelBuffer {
  const pb = new PixelBuffer(5, 5);
  const w = rgba('#ffffff');
  pb.line(0, 0, 4, 4, w);
  pb.line(4, 0, 0, 4, w);
  return pb;
}

export function drawRing(): PixelBuffer {
  const pb = new PixelBuffer(6, 6);
  const w = rgba('#ffffff');
  for (let a = 0; a < Math.PI * 2; a += 0.2) pb.set(Math.round(2.5 + Math.cos(a) * 2.5), Math.round(2.5 + Math.sin(a) * 2.5), w);
  return pb;
}

export function drawPixel(): PixelBuffer {
  const pb = new PixelBuffer(2, 2);
  pb.rect(0, 0, 2, 2, rgba('#ffffff'));
  return pb;
}

/** HUD star: variant 0 = full, 1 = half, 2 = empty. */
export function drawStar(variant: number): PixelBuffer {
  const pb = new PixelBuffer(11, 11);
  const fill = rgba('#ffe23a');
  const light = rgba('#fff7b0');
  const empty = rgba('#3a2a10', 150);
  const cx = 5.5;
  const cy = 5.8;
  const inside = (x: number, y: number) => {
    const px = x + 0.5 - cx;
    const py = y + 0.5 - cy;
    const a = Math.atan2(py, px) + Math.PI / 2;
    const r = Math.hypot(px, py);
    const k = ((a / (Math.PI * 2)) * 5) % 1;
    const tri = Math.abs(k - 0.5) * 2; // 1 at tips, 0 between
    const lim = 2.3 + tri * 3.2;
    return r <= lim;
  };
  for (let y = 0; y < 11; y++) {
    for (let x = 0; x < 11; x++) {
      if (!inside(x, y)) continue;
      let c = fill;
      if (variant === 2 || (variant === 1 && x >= 6)) c = empty;
      else if (x < 5 && y < 5) c = light;
      pb.set(x, y, c);
    }
  }
  pb.outline(rgba('#c0300a'));
  return pb;
}

/** Zampanò's face icon for the lives box. */
export function drawDogFace(): PixelBuffer {
  const pb = new PixelBuffer(17, 14);
  const W = rgba('#ffffff');
  const S = rgba('#d6deea');
  pb.disc(3.5, 7, 3.2, S);
  pb.disc(13.5, 7, 3.2, S);
  pb.disc(8.5, 6.5, 5.8, S);
  pb.disc(8.2, 6, 5.2, W);
  pb.disc(8.5, 2.5, 3, W);
  pb.rect(5, 5, 2, 2, rgba('#111111'));
  pb.rect(10, 5, 2, 2, rgba('#111111'));
  pb.rect(7, 8, 3, 2, rgba('#111111'));
  pb.rect(8, 10, 2, 2, rgba('#ff6a8a'));
  pb.outline(rgba('#2f3850'));
  return pb;
}

export function drawPeeIcon(): PixelBuffer {
  const pb = new PixelBuffer(9, 11);
  const Y = rgba('#ffe23a');
  const L = rgba('#fff7b0');
  pb.disc(4.5, 7, 3.5, Y);
  for (let y = 0; y < 5; y++) {
    const half = Math.floor(y / 2);
    pb.rect(4 - half, y + 1, 1 + half * 2, 1, Y);
  }
  pb.set(3, 6, L);
  pb.set(3, 7, L);
  pb.outline(rgba('#5a3a00'));
  return pb;
}

export function drawBarkIcon(): PixelBuffer {
  const pb = new PixelBuffer(13, 11);
  const W = rgba('#ffffff');
  for (const [r, x0] of [
    [3, 1],
    [5.5, 1],
    [8, 1],
  ] as const) {
    for (let a = -1; a <= 1; a += 0.08) pb.set(Math.round(x0 + Math.cos(a) * r), Math.round(5 + Math.sin(a) * r * 1.1), W);
  }
  return pb;
}

/** Pee charge droplet: variant 0 = full, 1 = empty. */
export function drawDrop(variant: number): PixelBuffer {
  const pb = new PixelBuffer(5, 7);
  const c = variant === 0 ? rgba('#ffe23a') : rgba('#40381a', 200);
  pb.disc(2.5, 4.5, 2.3, c);
  pb.set(2, 0, c);
  pb.rect(2, 1, 1, 2, c);
  pb.rect(1, 2, 3, 1, c);
  if (variant === 0) pb.set(1, 4, rgba('#fff7b0'));
  pb.outline(rgba('#3a2a00'));
  return pb;
}
