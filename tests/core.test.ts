import { describe, expect, it } from 'vitest';
import { CAMERA, DISPLAY } from '../src/config';
import { computeViewport } from '../src/core/display';
import { FixedStep } from '../src/core/loop';
import { Rng, hash2 } from '../src/core/rng';
import { Camera, clampAxis } from '../src/iso/camera';

describe('fixed timestep', () => {
  it('accumulates partial frames', () => {
    const f = new FixedStep(1 / 60, 0.25, 5);
    expect(f.advance(1 / 120).steps).toBe(0);
    const r = f.advance(1 / 120);
    expect(r.steps).toBe(1);
    expect(r.alpha).toBeCloseTo(0, 6);
  });

  it('caps steps per frame and drops the backlog', () => {
    const f = new FixedStep(1 / 60, 0.25, 5);
    expect(f.advance(0.2).steps).toBe(5);
    expect(f.advance(0).steps).toBe(0);
  });

  it('ignores negative elapsed time', () => {
    const f = new FixedStep(1 / 60, 0.25, 5);
    expect(f.advance(-1).steps).toBe(0);
  });
});

describe('viewport', () => {
  it('uses an integer scale and a logical width in range', () => {
    for (const [w, h, dpr] of [
      [412, 915, 2.625],
      [360, 800, 3],
      [390, 844, 3],
      [1280, 720, 1],
      [1920, 1080, 2],
      [768, 1024, 2],
    ]) {
      const v = computeViewport(w!, h!, dpr!);
      expect(Number.isInteger(v.scale)).toBe(true);
      expect(v.width).toBeGreaterThanOrEqual(DISPLAY.MIN_WIDTH - 40);
      expect(v.width).toBeLessThanOrEqual(DISPLAY.MAX_WIDTH);
      expect(v.width / v.height).toBeLessThanOrEqual(DISPLAY.MAX_ASPECT + 0.01);
      expect(v.cssWidth).toBeLessThanOrEqual(w! + 0.001);
      expect(v.cssHeight).toBeLessThanOrEqual(h! + 0.001);
    }
  });
});

describe('camera', () => {
  it('clamps to bounds and centers small maps', () => {
    expect(clampAxis(0, 0, 1000, 200)).toBe(100);
    expect(clampAxis(990, 0, 1000, 200)).toBe(900);
    expect(clampAxis(500, 0, 100, 200)).toBe(50);
  });

  it('follows its target with lag', () => {
    const c = new Camera();
    c.setView(200, 400);
    c.snapTo(0, 0);
    for (let k = 0; k < 10; k++) c.update(1 / 60, 100, 0, 0, 0);
    expect(c.x).toBeGreaterThan(10);
    expect(c.x).toBeLessThan(100);
    for (let k = 0; k < 600; k++) c.update(1 / 60, 100, 0, 0, 0);
    // Within the handheld sway amplitude.
    expect(Math.abs(c.x - 100)).toBeLessThanOrEqual(CAMERA.SWAY_AMPLITUDE + 0.01);
  });
});

describe('rng', () => {
  it('is deterministic', () => {
    const a = new Rng(42);
    const b = new Rng(42);
    for (let k = 0; k < 10; k++) expect(a.next()).toBe(b.next());
    expect(hash2(3, 4, 5)).toBe(hash2(3, 4, 5));
    expect(hash2(3, 4, 5)).not.toBe(hash2(4, 3, 5));
  });
});
