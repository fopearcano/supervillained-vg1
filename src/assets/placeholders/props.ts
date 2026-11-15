import { Rng } from '../../core/rng';
import type { Palette } from '../../world/level';
import { PixelBuffer, mixHex, rgba } from './pixel';

/** Placeholder props: trees, bushes, poles, fountains, the exit flag. Colors follow the zone palette. */

export function drawTree(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(40, 60);
  const rng = new Rng(1000 + variant * 77);
  const [dark, mid, light] = pal.foliage;
  const trunk = rgba('#7a4e2a');
  const trunkDark = rgba('#4e2f16');
  const trunkLight = rgba('#9c6a3c');
  // Trunk
  const tx = 18;
  for (let y = 30; y <= 56; y++) {
    pb.set(tx, y, trunkDark);
    pb.set(tx + 1, y, trunk);
    pb.set(tx + 2, y, trunk);
    pb.set(tx + 3, y, trunkLight);
  }
  pb.set(tx - 1, 56, trunkDark);
  pb.set(tx + 4, 56, trunkDark);
  pb.set(tx - 1, 55, trunkDark);
  // Canopy: clustered discs, dark → mid → light for a sunlit look.
  const cy = 22 + (variant === 2 ? 2 : 0);
  const blobs: Array<[number, number, number]> = [];
  const count = 7 + variant;
  for (let k = 0; k < count; k++) {
    const a = (k / count) * Math.PI * 2 + rng.range(-0.3, 0.3);
    const r = rng.range(6, 9.5);
    blobs.push([20 + Math.cos(a) * r, cy + Math.sin(a) * r * 0.85, rng.range(6.5, 8.5)]);
  }
  blobs.push([20, cy, 10]);
  for (const [x, y, r] of blobs) pb.disc(x, y + 1.5, r, rgba(dark));
  for (const [x, y, r] of blobs) pb.disc(x - 1, y - 0.5, r - 1.8, rgba(mid));
  for (const [x, y, r] of blobs) if (y < cy + 2) pb.disc(x - 2, y - 2.5, r * 0.45, rgba(light));
  // Leaf specks
  for (let k = 0; k < 40; k++) {
    const x = rng.int(4, 36);
    const y = rng.int(6, 38);
    if (pb.get(x, y) !== 0) pb.set(x, y, rgba(rng.chance(0.5) ? dark : light));
  }
  pb.outline(rgba(mixHex(dark, '#000000', 0.55)));
  return pb;
}

export function drawForestTree(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(36, 56);
  const [fbase, fdark, flight] = pal.forest;
  const dark = mixHex(fdark, '#000000', 0.2);
  // Trunk
  for (let y = 40; y <= 52; y++) {
    pb.set(17, y, rgba('#3e2612'));
    pb.set(18, y, rgba('#5a3a1e'));
  }
  if (variant === 0) {
    // Conifer: stacked triangles
    for (let tier = 0; tier < 4; tier++) {
      const top = 4 + tier * 9;
      const h = 14;
      for (let y = 0; y < h; y++) {
        const half = Math.floor((y / h) * (7 + tier * 3));
        for (let x = -half; x <= half; x++) {
          const shade = x < -half / 3 ? fdark : x > half / 2 ? flight : fbase;
          pb.set(18 + x, top + y, rgba(shade));
        }
      }
    }
  } else {
    const rng = new Rng(500 + variant);
    for (let k = 0; k < 8; k++) pb.disc(18 + rng.range(-8, 8), 22 + rng.range(-12, 10), rng.range(6, 9), rgba(fdark));
    for (let k = 0; k < 6; k++) pb.disc(17 + rng.range(-6, 6), 20 + rng.range(-12, 6), rng.range(4, 6), rgba(fbase));
    for (let k = 0; k < 4; k++) pb.disc(15 + rng.range(-4, 4), 14 + rng.range(-6, 4), rng.range(2, 3), rgba(flight));
  }
  pb.outline(rgba(dark));
  return pb;
}

export function drawBush(pal: Palette, variant: number): PixelBuffer {
  const pb = new PixelBuffer(26, 18);
  const [dark, mid, light] = pal.foliage;
  const rng = new Rng(300 + variant * 13);
  const blobs: Array<[number, number, number]> = [
    [8, 10, 6],
    [17, 10, 6],
    [13, 7, 6.5],
  ];
  for (const [x, y, r] of blobs) pb.disc(x, y + 1, r, rgba(dark));
  for (const [x, y, r] of blobs) pb.disc(x - 0.6, y - 0.4, r - 1.5, rgba(mid));
  for (const [x, y, r] of blobs) pb.disc(x - 1.5, y - 2, r * 0.38, rgba(light));
  const flowers = pal.flowers;
  for (let k = 0; k < (variant === 1 ? 6 : 0); k++) {
    const x = rng.int(4, 21);
    const y = rng.int(4, 13);
    if (pb.get(x, y) !== 0) pb.set(x, y, rgba(flowers[k % flowers.length]!));
  }
  pb.outline(rgba(mixHex(dark, '#000000', 0.55)));
  return pb;
}

export function drawPole(): PixelBuffer {
  const pb = new PixelBuffer(12, 52);
  const pole = rgba('#3a4050');
  const poleLight = rgba('#6a7488');
  for (let y = 8; y <= 50; y++) {
    pb.set(5, y, pole);
    pb.set(6, y, poleLight);
  }
  pb.rect(4, 47, 4, 4, pole);
  pb.rect(5, 47, 1, 3, poleLight);
  // Lamp head
  pb.rect(2, 4, 8, 3, pole);
  pb.rect(3, 7, 6, 2, rgba('#fff3a0'));
  pb.rect(4, 2, 4, 2, pole);
  pb.set(4, 7, rgba('#ffffff'));
  pb.outline(rgba('#14161c'));
  return pb;
}

export function drawFountain(): PixelBuffer {
  const pb = new PixelBuffer(18, 26);
  const stone = rgba('#9aa4b4');
  const stoneDark = rgba('#6a7486');
  const stoneLight = rgba('#c8d0dc');
  // Pillar
  pb.rect(6, 8, 6, 14, stoneDark);
  pb.rect(7, 8, 4, 14, stone);
  pb.rect(8, 9, 1, 12, stoneLight);
  // Basin on top
  pb.ellipse(9, 7, 7, 3, stoneDark);
  pb.ellipse(9, 6.5, 6, 2.2, stone);
  pb.ellipse(9, 6.5, 4, 1.2, rgba('#4aa0ff'));
  // Spout
  pb.set(9, 3, rgba('#8fd0ff'));
  pb.set(9, 4, rgba('#4aa0ff'));
  pb.set(10, 2, rgba('#8fd0ff'));
  // Base
  pb.ellipse(9, 22, 6, 2.2, stoneDark);
  pb.outline(rgba('#2a303a'));
  return pb;
}

export function drawExitFlag(): PixelBuffer {
  const pb = new PixelBuffer(26, 40);
  const pole = rgba('#e8e8f0');
  for (let y = 2; y <= 38; y++) {
    pb.set(5, y, pole);
    pb.set(6, y, rgba('#a0a0b8'));
  }
  pb.disc(6, 2, 2, rgba('#ffd700'));
  // Checkered flag
  for (let y = 0; y < 12; y++) {
    for (let x = 0; x < 16; x++) {
      const wave = Math.round(Math.sin((x / 16) * Math.PI * 1.5) * 1.5);
      const on = (Math.floor(x / 4) + Math.floor(y / 4)) % 2 === 0;
      pb.set(7 + x, 4 + y + wave, rgba(on ? '#111111' : '#ffffff'));
    }
  }
  pb.outline(rgba('#1a1a24'));
  return pb;
}
