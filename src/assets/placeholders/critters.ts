import { dirToScreenVector, type Dir8 } from '../../iso/projection';
import type { AnimName } from '../manifest';
import { PixelBuffer, rgba } from './pixel';

/**
 * Parametric quadruped drawer used for every placeholder animal (Zampanò, Bagnaskiz, cats).
 * Everything is derived from the facing direction, so all 8 directions come for free.
 */

export interface CritterSpec {
  frameW: number;
  frameH: number;
  /** Ground contact y inside the frame (the sprite anchor). */
  groundY: number;
  bodyR: number;
  bodyLen: number;
  legLen: number;
  legW: number;
  headR: number;
  headLift: number;
  colors: {
    base: string;
    shade: string;
    deep: string;
    outline: string;
    eye: string;
    nose: string;
    mouth: string;
  };
  ears: 'floppy' | 'pug' | 'cat';
  tail: 'fluff' | 'curl' | 'long';
  /** Dark muzzle disc (pug). */
  muzzle?: string;
  /** Cloud-like bumps on the back (Maltese). */
  fluffy?: boolean;
  /** Tabby stripes. */
  stripes?: string;
  /** Headwear / accessory drawn on the head. */
  hat?: 'crown' | 'cap' | 'mitre' | 'turban' | 'hood' | 'helm' | 'veil' | 'bow' | 'bearEars';
  hatColor?: string;
  /** Coat marks. */
  marks?: 'scars' | 'patches' | 'spots';
  markColor?: string;
  /** Costume on the body: a rag cross sewn on the coat, or a tabard with a cross. */
  costume?: 'cross' | 'tabard';
  costumeColor?: string;
  /** Eye style. */
  eyes?: 'big' | 'sleepy' | 'blind';
  /** Shih-tzu topknot tie color. */
  topknot?: string;
}

export const ZAMPANO_SPEC: CritterSpec = {
  frameW: 40,
  frameH: 40,
  groundY: 36,
  bodyR: 7,
  bodyLen: 5,
  legLen: 3.5,
  legW: 3,
  headR: 6.6,
  headLift: 5.5,
  colors: {
    base: '#ffffff',
    shade: '#d9e2ef',
    deep: '#aebbd0',
    outline: '#2f3850',
    eye: '#111111',
    nose: '#111111',
    mouth: '#e0405a',
  },
  ears: 'floppy',
  tail: 'fluff',
  fluffy: true,
};

export const BAGNASKIZ_SPEC: CritterSpec = {
  frameW: 40,
  frameH: 40,
  groundY: 36,
  bodyR: 7.4,
  bodyLen: 5.2,
  legLen: 3.5,
  legW: 3,
  headR: 6.6,
  headLift: 5,
  colors: {
    base: '#e8c48e',
    shade: '#c99d62',
    deep: '#9c723e',
    outline: '#3a2414',
    eye: '#140c08',
    nose: '#140c08',
    mouth: '#d03a4a',
  },
  ears: 'pug',
  tail: 'curl',
  muzzle: '#3b2a20',
};

export const CAT_SPEC: CritterSpec = {
  frameW: 28,
  frameH: 28,
  groundY: 25,
  bodyR: 4.2,
  bodyLen: 4.2,
  legLen: 3.5,
  legW: 2,
  headR: 4.8,
  headLift: 4,
  colors: {
    base: '#f59a2e',
    shade: '#d07418',
    deep: '#a4560c',
    outline: '#3a1c06',
    eye: '#1a3a10',
    nose: '#ff8aa0',
    mouth: '#c0303a',
  },
  ears: 'cat',
  tail: 'long',
  stripes: '#b85a0a',
};

export interface Pose {
  bob: number;
  legPhase: number;
  stride: number;
  headDrop: number;
  headForward: number;
  squat: number;
  legLift: boolean;
  mouthOpen: boolean;
  ball: boolean;
  hurt: boolean;
  stretch: number;
  shakeX: number;
  droplets: boolean;
  earFlap: number;
}

const BASE_POSE: Pose = {
  bob: 0,
  legPhase: 0,
  stride: 0,
  headDrop: 0,
  headForward: 0,
  squat: 0,
  legLift: false,
  mouthOpen: false,
  ball: false,
  hurt: false,
  stretch: 0,
  shakeX: 0,
  droplets: false,
  earFlap: 0,
};

/** Pose of an animation frame. */
export function poseFor(anim: AnimName, frame: number): Pose {
  const p: Pose = { ...BASE_POSE };
  const q = (frame * Math.PI) / 2;
  switch (anim) {
    case 'idle':
      p.bob = frame % 2 ? 0.6 : 0;
      break;
    case 'walk':
      p.legPhase = q;
      p.stride = 1.6;
      p.bob = frame % 2 ? -0.7 : 0;
      break;
    case 'run':
      p.legPhase = q;
      p.stride = 2.6;
      p.bob = frame % 2 ? -1.2 : 0.2;
      p.stretch = frame % 2 ? 1 : -0.5;
      p.earFlap = frame % 2 ? -1 : 0;
      break;
    case 'sniff':
      p.headDrop = 3;
      p.headForward = 1 + (frame % 2) * 0.6;
      break;
    case 'pee':
      p.legLift = true;
      p.droplets = frame % 2 === 1;
      p.bob = 0.4;
      break;
    case 'poop':
      p.squat = frame % 2 ? 3 : 2.4;
      break;
    case 'eat':
      p.headDrop = frame % 2 ? 2.4 : 3.6;
      p.mouthOpen = frame % 2 === 0;
      break;
    case 'bark':
      p.mouthOpen = frame % 2 === 0;
      p.headForward = frame % 2 ? 0.4 : 1.2;
      p.bob = frame % 2 ? 0 : -0.8;
      p.earFlap = frame % 2 ? 0 : -1;
      break;
    case 'fetch':
      p.legPhase = q;
      p.stride = 2.4;
      p.bob = frame % 2 ? -1 : 0;
      p.ball = true;
      p.earFlap = frame % 2 ? -1 : 0;
      break;
    case 'hurt':
      p.hurt = true;
      p.shakeX = frame % 2 ? 1 : -1;
      p.bob = frame % 2 ? -1 : 0;
      break;
  }
  return p;
}

interface Pt {
  x: number;
  y: number;
}

export function drawCritter(spec: CritterSpec, dir: Dir8, pose: Pose): PixelBuffer {
  const pb = new PixelBuffer(spec.frameW, spec.frameH);
  const c = spec.colors;
  const BASE = rgba(c.base);
  const SHADE = rgba(c.shade);
  const DEEP = rgba(c.deep);
  const EYE = rgba(c.eye);
  const NOSE = rgba(c.nose);
  const MOUTH = rgba(c.mouth);
  const f = dirToScreenVector(dir);
  const fx = f.x;
  const fy = f.y;
  // Ground-plane perpendicular, projected (y squashed).
  const px = -fy;
  const py = fx * 0.55;
  const len = spec.bodyLen + pose.stretch;
  const ax = fx * len;
  const ay = fy * len * 0.55;
  const cx = spec.frameW / 2 + pose.shakeX;
  const groundY = spec.groundY;
  const bodyY = groundY - spec.legLen - spec.bodyR + 1.5 + pose.bob;
  const body: Pt = { x: cx, y: bodyY };
  const rear: Pt = { x: cx - ax, y: bodyY - ay + pose.squat };
  const front: Pt = { x: cx + ax, y: bodyY + ay };
  const head: Pt = {
    x: front.x + fx * (spec.headR * 0.55 + pose.headForward),
    y: front.y + fy * (spec.headR * 0.3) - spec.headLift + pose.headDrop,
  };
  const facingCamera = fy > 0.3;
  const facingAway = fy < -0.3;

  // --- parts -------------------------------------------------------------------------------
  const drawLegs = () => {
    const legs: Array<{ base: Pt; phase: number; rearLeg: boolean; side: number }> = [];
    for (const rearLeg of [true, false]) {
      for (const side of [-1, 1]) {
        const anchor = rearLeg ? rear : front;
        legs.push({
          base: { x: anchor.x * 0.7 + body.x * 0.3 + px * side * 2.2, y: anchor.y + py * side * 2.2 },
          phase: pose.legPhase + (rearLeg ? Math.PI : 0) + (side > 0 ? Math.PI : 0),
          rearLeg,
          side,
        });
      }
    }
    // Far legs first.
    legs.sort((a, b) => a.base.y - b.base.y);
    for (const leg of legs) {
      const swing = Math.sin(leg.phase) * pose.stride;
      const lift = Math.max(0, Math.cos(leg.phase)) * (pose.stride > 0 ? 1.2 : 0);
      const footX = leg.base.x + fx * swing;
      const groundOff = leg.base.y - bodyY;
      const footY = groundY + groundOff * 0.6 - lift;
      if (pose.legLift && leg.rearLeg && leg.side === (fx >= 0 ? -1 : 1)) {
        // Raised hind leg (marking pose): sticks out sideways/backwards.
        const tipX = footX - fx * 3 + px * leg.side * 2;
        const tipY = bodyY - 1;
        pb.line(Math.round(footX), Math.round(bodyY + 2), Math.round(tipX), Math.round(tipY), SHADE);
        pb.line(Math.round(footX) + 1, Math.round(bodyY + 2), Math.round(tipX) + 1, Math.round(tipY), SHADE);
        continue;
      }
      const top = Math.round(leg.base.y + spec.bodyR * 0.3);
      const bottom = Math.round(footY);
      const x0 = Math.round(footX - spec.legW / 2);
      for (let y = top; y <= bottom; y++) {
        for (let x = 0; x < spec.legW; x++) pb.set(x0 + x, y, y >= bottom ? DEEP : SHADE);
      }
    }
  };

  const drawBody = () => {
    const steps = 5;
    // Wider when seen from the front/back: the shoulders/haunches face the camera.
    const rx = spec.bodyR * (1 + 0.28 * Math.abs(fy));
    const ry = spec.bodyR * 0.92;
    const at = (t: number): Pt => ({ x: rear.x + (front.x - rear.x) * t, y: rear.y + (front.y - rear.y) * t });
    for (let k = 0; k < steps; k++) {
      const p = at(k / (steps - 1));
      pb.ellipse(p.x, p.y + 0.7, rx, ry, SHADE);
    }
    for (let k = 0; k < steps; k++) {
      const p = at(k / (steps - 1));
      pb.ellipse(p.x - 0.4, p.y - 0.8, rx - 1.1, ry - 1.1, BASE);
    }
    if (spec.fluffy) {
      // Cloud bumps along the back and the flanks.
      for (const t of [0.15, 0.5, 0.85]) {
        const p = at(t);
        pb.disc(p.x, p.y - ry * 0.75, spec.bodyR * 0.5, BASE);
      }
      for (const side of [-1, 1]) {
        const p = at(0.5);
        pb.disc(p.x + px * side * rx * 0.8, p.y + py * side * 2 - 0.5, spec.bodyR * 0.55, BASE);
      }
      // A few shade curls for texture.
      const c0 = at(0.4);
      pb.set(Math.round(c0.x - 2), Math.round(c0.y + ry - 2), SHADE);
      pb.set(Math.round(c0.x + 3), Math.round(c0.y + ry - 3), SHADE);
      pb.set(Math.round(c0.x), Math.round(c0.y + 1), SHADE);
    }
    if (spec.stripes) {
      const S = rgba(spec.stripes);
      for (const t of [0.2, 0.45, 0.7]) {
        const p = at(t);
        const x = Math.round(p.x);
        const y = Math.round(p.y - ry + 1);
        pb.setIfOpaque(x, y, S);
        pb.setIfOpaque(x, y + 1, S);
        pb.setIfOpaque(x + 1, y + 1, S);
      }
    }
    drawBodyExtras(at, rx, ry);
  };

  const drawBodyExtras = (at: (t: number) => Pt, rx: number, ry: number) => {
    if (spec.marks) {
      const M = rgba(spec.markColor ?? c.deep);
      const mid = at(0.45);
      if (spec.marks === 'patches') {
        pb.ellipse(mid.x - fx * 2 - 1, mid.y - ry * 0.4, 3.2, 2.2, M);
      } else if (spec.marks === 'spots') {
        for (const [dx, dy] of [
          [-3, -2],
          [2, -3],
          [0, 1],
          [4, 0],
          [-4, 1],
        ] as const)
          pb.setIfOpaque(Math.round(mid.x + dx), Math.round(mid.y + dy), M), pb.setIfOpaque(Math.round(mid.x + dx + 1), Math.round(mid.y + dy), M);
      } else {
        // Scars: short pink slashes.
        const S = rgba(spec.markColor ?? '#ff9aa8');
        pb.line(Math.round(mid.x - 3), Math.round(mid.y - 3), Math.round(mid.x), Math.round(mid.y), S);
        pb.line(Math.round(mid.x + 2), Math.round(mid.y - 2), Math.round(mid.x + 4), Math.round(mid.y + 1), S);
      }
    }
    if (spec.costume) {
      const mid = at(0.5);
      const cy = Math.round(mid.y - ry * 0.15);
      const cx = Math.round(mid.x - fx * 1.5);
      if (spec.costume === 'tabard') {
        const T = rgba(spec.costumeColor ?? '#f4f4f8');
        for (let y = -Math.round(ry * 0.6); y <= Math.round(ry * 0.5); y++)
          for (let x = -Math.round(rx * 0.75); x <= Math.round(rx * 0.75); x++) pb.setIfOpaque(cx + x, cy + y, T);
      }
      const R = rgba('#d42424');
      for (let k = -2; k <= 2; k++) {
        pb.setIfOpaque(cx + k, cy, R);
        pb.setIfOpaque(cx, cy + k, R);
      }
    }
  };

  const drawTail = () => {
    const tb: Pt = {
      x: rear.x - fx * spec.bodyR * 0.8,
      y: rear.y - fy * spec.bodyR * 0.4 - spec.bodyR * 0.6 + (facingCamera ? 3 : 0),
    };
    if (spec.tail === 'fluff') {
      pb.disc(tb.x, tb.y - 1 - (pose.squat > 0 ? 1.5 : 0), 2.8, SHADE);
      pb.disc(tb.x - 0.3, tb.y - 1.6 - (pose.squat > 0 ? 1.5 : 0), 2.2, BASE);
    } else if (spec.tail === 'curl') {
      const D = rgba(c.deep);
      const r = 2;
      const ty = tb.y - 1.5;
      for (let a = 0; a < Math.PI * 1.7; a += 0.3) pb.set(Math.round(tb.x + Math.cos(a) * r), Math.round(ty + Math.sin(a) * r), D);
    } else {
      // Long cat tail, curving upward.
      let x = tb.x;
      let y = tb.y + 1;
      const sx = -fx >= 0 ? 1 : -1;
      for (let k = 0; k < 7; k++) {
        pb.set(Math.round(x), Math.round(y), SHADE);
        pb.set(Math.round(x), Math.round(y) + 1, SHADE);
        x += sx * (k < 3 ? 0.9 : 0.4);
        y -= k < 3 ? 0.5 : 1;
      }
    }
  };

  const drawEars = (near: boolean) => {
    for (const side of [-1, 1]) {
      const sy = py * side;
      const isNear = sy > 0 || (Math.abs(sy) < 0.01 && side > 0);
      if (isNear !== near) continue;
      if (spec.ears === 'floppy') {
        const ex = head.x + px * side * (spec.headR * 0.95) - fx * 1.2;
        const ey = head.y + sy * 2 + 2.2 + pose.earFlap;
        pb.ellipse(ex, ey, spec.headR * 0.42, spec.headR * 0.62, SHADE);
        pb.ellipse(ex - 0.3, ey - 0.6, spec.headR * 0.32, spec.headR * 0.5, BASE);
      } else if (spec.ears === 'pug') {
        const D = rgba(spec.muzzle ?? c.deep);
        const ex = head.x + px * side * (spec.headR * 0.7) - fx * 0.5;
        const ey = head.y - spec.headR * 0.6 + sy;
        pb.disc(ex, ey, 1.7, D);
      } else {
        const ex = head.x + px * side * (spec.headR * 0.6) - fx * 0.3;
        const ey = head.y - spec.headR * 0.55 + sy * 0.5;
        // Pointy ear: triangle, 4px tall.
        for (let k = 0; k < 4; k++) {
          const half = k < 2 ? 1 : 0;
          for (let w = -half; w <= half; w++) pb.set(Math.round(ex + w), Math.round(ey - k), k === 0 ? SHADE : k === 3 ? DEEP : BASE);
        }
      }
    }
  };

  const drawHead = () => {
    drawEars(false);
    const hrx = spec.headR * (spec.fluffy ? 1.12 : 1.05);
    const hry = spec.headR;
    pb.ellipse(head.x, head.y + 0.7, hrx, hry, SHADE);
    pb.ellipse(head.x - 0.3, head.y - 0.3, hrx - 1, hry - 1, BASE);
    if (spec.fluffy) {
      // Fluffy crown: two soft bumps instead of a point.
      for (const side of [-1, 1]) pb.disc(head.x + side * hrx * 0.45 - fx * 0.5, head.y - hry * 0.62, spec.headR * 0.48, BASE);
    }
    if (!facingAway && spec.muzzle) {
      const M = rgba(spec.muzzle);
      pb.ellipse(head.x + fx * spec.headR * 0.5, head.y + 1.6 + fy * 0.4, spec.headR * 0.55, spec.headR * 0.42, M);
    }
    drawEars(true);
    drawFace();
    drawHat(hrx, hry);
  };

  const drawHat = (hrx: number, hry: number) => {
    if (spec.topknot) {
      const K = rgba(spec.topknot);
      pb.disc(head.x - fx * 0.5, head.y - hry - 0.5, 1.8, rgba(c.base));
      pb.rect(Math.round(head.x - fx * 0.5) - 1, Math.round(head.y - hry + 0.5), 3, 1, K);
    }
    if (!spec.hat) return;
    const H = rgba(spec.hatColor ?? '#e8c048');
    const top = head.y - hry;
    const hx = head.x - fx * 0.4;
    switch (spec.hat) {
      case 'crown': {
        pb.rect(Math.round(hx - 4), Math.round(top), 9, 2, H);
        for (const dx of [-4, 0, 4]) pb.rect(Math.round(hx + dx), Math.round(top - 2), 1, 2, H);
        pb.set(Math.round(hx), Math.round(top + 0.5), rgba('#e02040'));
        break;
      }
      case 'cap': {
        // Venetian ducal cap (corno): rounded with a raised back peak.
        pb.ellipse(hx, top + 1, hrx * 0.8, 2.6, H);
        pb.disc(hx - fx * 2.5, top - 1.5, 2.2, H);
        pb.rect(Math.round(hx - hrx * 0.8), Math.round(top + 2), Math.round(hrx * 1.6), 1, rgba('#ffffff'));
        break;
      }
      case 'mitre': {
        for (let y = 0; y < 8; y++) {
          const half = Math.max(1, 3.5 - y * 0.35);
          for (let x = -half; x <= half; x++) pb.set(Math.round(hx + x), Math.round(top + 1 - y), y % 4 === 2 ? rgba('#e8c048') : H);
        }
        break;
      }
      case 'turban': {
        pb.ellipse(hx, top + 0.5, hrx * 0.9, 3.4, H);
        pb.ellipse(hx - 0.5, top - 0.5, hrx * 0.6, 2.2, rgba('#ffffff'));
        pb.set(Math.round(hx), Math.round(top + 1), rgba('#e02040'));
        break;
      }
      case 'hood': {
        pb.ellipse(head.x - fx * 1.2, head.y - hry * 0.35, hrx + 1.2, hry * 0.8, H);
        if (!facingAway) pb.ellipse(head.x + fx * 1.5, head.y + 0.8, hrx * 0.7, hry * 0.6, rgba(c.base));
        drawFace();
        break;
      }
      case 'helm': {
        pb.ellipse(hx, top + 2.5, hrx * 0.95, hry * 0.6, H);
        pb.ellipse(hx - 1, top + 1.5, hrx * 0.6, hry * 0.3, rgba('#e4ecf4'));
        if (!facingAway) pb.rect(Math.round(head.x + fx * hrx * 0.4), Math.round(top + 2), 1, 5, rgba('#5a6070'));
        break;
      }
      case 'veil': {
        pb.ellipse(head.x - fx * 2, head.y - hry * 0.3, hrx + 1, hry * 0.7, H);
        pb.ellipse(head.x - fx * 4, head.y + 3, hrx * 0.7, hry * 0.9, H);
        if (!facingAway) {
          pb.ellipse(head.x + fx * 1.5, head.y + 0.8, hrx * 0.7, hry * 0.6, rgba(c.base));
          drawFace();
        }
        break;
      }
      case 'bow': {
        const bx = head.x + (fx >= 0 ? -1 : 1) * hrx * 0.5;
        pb.disc(bx - 2, top + 1, 1.8, H);
        pb.disc(bx + 2, top + 1, 1.8, H);
        pb.set(Math.round(bx), Math.round(top + 1), rgba('#ffffff'));
        break;
      }
      case 'bearEars': {
        pb.ellipse(head.x - fx, head.y - hry * 0.2, hrx + 1.5, hry * 0.9, H);
        for (const side of [-1, 1]) pb.disc(head.x + side * hrx * 0.7, top, 2.2, H);
        if (!facingAway) {
          pb.ellipse(head.x + fx * 1.5, head.y + 1, hrx * 0.65, hry * 0.55, rgba(c.base));
          drawFace();
        }
        break;
      }
    }
  };

  const drawFace = () => {
    const showFace = !facingAway;
    const noseX = head.x + fx * spec.headR * 0.82;
    const noseY = head.y + 1.2 + fy * 0.8;
    if (showFace) {
      const sep = 3.4 * Math.abs(fy) * (spec.headR / 6.6) + 0.2;
      const ex = head.x + fx * 2.6 * (spec.headR / 6.6);
      const ey = head.y - 1.2;
      const eyes = Math.abs(fy) < 0.2 ? [ex] : [ex - sep, ex + sep];
      for (const x of eyes) {
        const X = Math.round(x - 0.5);
        const Y = Math.round(ey - 0.5);
        if (pose.hurt) {
          pb.set(X - 1, Y - 1, EYE);
          pb.set(X + 1, Y + 1, EYE);
          pb.set(X + 1, Y - 1, EYE);
          pb.set(X - 1, Y + 1, EYE);
          pb.set(X, Y, EYE);
        } else if (spec.eyes === 'blind') {
          pb.rect(X, Y, 2, 2, rgba('#dce8f0'));
          pb.set(X + 1, Y + 1, rgba('#9aa8b8'));
        } else if (spec.eyes === 'sleepy') {
          pb.rect(X, Y + 1, 2, 1, EYE);
        } else if (spec.eyes === 'big') {
          pb.rect(X, Y - 1, 2, 3, EYE);
          pb.set(X, Y - 1, rgba('#ffffff'));
        } else {
          pb.rect(X, Y, 2, 2, EYE);
          if (spec.ears === 'pug') pb.set(X, Y, rgba('#ffffff'));
        }
      }
    }
    if (showFace || Math.abs(fx) > 0.5) {
      const NX = Math.round(noseX - 0.5);
      const NY = Math.round(noseY - 0.5);
      if (spec.ears === 'cat') pb.set(NX, NY, NOSE);
      else pb.rect(NX, NY, 2, 2, NOSE);
      if (pose.mouthOpen && showFace) {
        pb.rect(NX, NY + 2, 2, 2, MOUTH);
        pb.set(NX - 1, NY + 2, rgba(c.outline));
      }
      if (pose.ball) {
        const B = rgba('#d6f03a');
        const BS = rgba('#a6c020');
        pb.disc(noseX + fx * 1.5, noseY + 2.5, 2.2, BS);
        pb.disc(noseX + fx * 1.5 - 0.3, noseY + 2.2, 1.6, B);
      }
    }
  };

  const drawDroplets = () => {
    if (!pose.droplets) return;
    const Y = rgba('#ffe23a');
    const x = rear.x - fx * 2;
    for (let k = 0; k < 3; k++) pb.set(Math.round(x - fx * k), Math.round(bodyY + 3 + k * 1.5), Y);
  };

  // --- paint order: far parts first --------------------------------------------------------
  if (facingAway) {
    drawLegs();
    drawHead();
    drawBody();
    drawTail();
  } else if (facingCamera) {
    drawTail();
    drawLegs();
    drawBody();
    drawHead();
  } else {
    drawTail();
    drawLegs();
    drawBody();
    drawHead();
  }
  drawDroplets();
  pb.outline(rgba(c.outline));
  return pb;
}

/** Soft ground shadow (ellipse). */
export function drawShadow(w: number, h: number, alpha = 80): PixelBuffer {
  const pb = new PixelBuffer(w, h);
  pb.ellipse(w / 2, h / 2, w / 2, h / 2, rgba('#000000', alpha));
  return pb;
}

