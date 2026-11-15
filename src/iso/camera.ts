import { CAMERA, FX } from '../config';
import type { Rect } from './depth';

/**
 * 2D camera in screen space. Follows a target with exponential smoothing (a slight lag, like
 * the handheld camera in the video), adds a gentle sway and a decaying shake, and is clamped
 * to the map's screen bounds.
 */
export class Camera {
  x = 0;
  y = 0;
  prevX = 0;
  prevY = 0;
  viewW = 216;
  viewH = 400;
  /** World-space screen bounds of the map; null = unbounded. */
  bounds: Rect | null = null;
  private lookX = 0;
  private lookY = 0;
  private time = 0;
  private shakeAmp = 0;
  shakeX = 0;
  shakeY = 0;

  setView(w: number, h: number): void {
    this.viewW = w;
    this.viewH = h;
  }

  snapTo(x: number, y: number): void {
    const c = this.clamp(x, y + CAMERA.BIAS_Y);
    this.x = this.prevX = c.x;
    this.y = this.prevY = c.y;
    this.lookX = this.lookY = 0;
  }

  shake(amount: number): void {
    this.shakeAmp = Math.max(this.shakeAmp, amount);
  }

  /**
   * @param tx target x/y (screen space, e.g. Zampanò's feet)
   * @param vx velocity direction in screen space (unnormalized; used for look-ahead)
   */
  update(dt: number, tx: number, ty: number, vx: number, vy: number): void {
    this.prevX = this.x;
    this.prevY = this.y;
    this.time += dt;

    const len = Math.hypot(vx, vy);
    const lx = len > 1e-6 ? (vx / len) * CAMERA.LOOK_AHEAD : 0;
    const ly = len > 1e-6 ? (vy / len) * CAMERA.LOOK_AHEAD * 0.75 : 0;
    const lk = 1 - Math.exp(-CAMERA.LOOK_AHEAD_RATE * dt);
    this.lookX += (lx - this.lookX) * lk;
    this.lookY += (ly - this.lookY) * lk;

    const swayX = Math.sin(this.time * CAMERA.SWAY_SPEED * 2.1) * CAMERA.SWAY_AMPLITUDE;
    const swayY = Math.sin(this.time * CAMERA.SWAY_SPEED * 1.3 + 1.7) * CAMERA.SWAY_AMPLITUDE;

    const goalX = tx + this.lookX + swayX;
    const goalY = ty + this.lookY + CAMERA.BIAS_Y + swayY;
    const k = 1 - Math.exp(-CAMERA.FOLLOW_RATE * dt);
    const c = this.clamp(this.x + (goalX - this.x) * k, this.y + (goalY - this.y) * k);
    this.x = c.x;
    this.y = c.y;

    this.shakeAmp *= Math.exp(-dt * FX.SHAKE_DECAY);
    if (this.shakeAmp < 0.05) this.shakeAmp = 0;
    this.shakeX = (Math.random() * 2 - 1) * this.shakeAmp;
    this.shakeY = (Math.random() * 2 - 1) * this.shakeAmp;
  }

  clamp(x: number, y: number): { x: number; y: number } {
    const b = this.bounds;
    if (!b) return { x, y };
    return {
      x: clampAxis(x, b.x - CAMERA.BOUNDS_MARGIN, b.x + b.w + CAMERA.BOUNDS_MARGIN, this.viewW),
      y: clampAxis(y, b.y - CAMERA.BOUNDS_MARGIN, b.y + b.h + CAMERA.BOUNDS_MARGIN, this.viewH),
    };
  }

  /** Interpolated top-left corner of the view, rounded to whole pixels. */
  viewOrigin(alpha: number): { x: number; y: number } {
    const cx = this.prevX + (this.x - this.prevX) * alpha + this.shakeX;
    const cy = this.prevY + (this.y - this.prevY) * alpha + this.shakeY;
    return { x: Math.round(cx - this.viewW / 2), y: Math.round(cy - this.viewH / 2) };
  }

  /** Current view rectangle in world screen space (not interpolated). */
  viewRect(margin = 0): Rect {
    return {
      x: this.x - this.viewW / 2 - margin,
      y: this.y - this.viewH / 2 - margin,
      w: this.viewW + margin * 2,
      h: this.viewH + margin * 2,
    };
  }
}

/** Clamps a camera center so that a view of size `view` stays within [min, max]. */
export function clampAxis(c: number, min: number, max: number, view: number): number {
  const span = max - min;
  if (span <= view) return min + span / 2;
  return Math.min(max - view / 2, Math.max(min + view / 2, c));
}
