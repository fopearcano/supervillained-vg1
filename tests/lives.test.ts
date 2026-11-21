import { describe, expect, it } from 'vitest';
import { LIVES } from '../src/config';
import { clampLives, livesSpeed, nextLives } from '../src/systems/lives';

describe('lives for speed (the title counter)', () => {
  it('runs from the start value to 9, then back', () => {
    expect(LIVES.START).toBe(2);
    expect(nextLives(2)).toBe(3);
    expect(nextLives(8)).toBe(9);
    expect(nextLives(9)).toBe(2);
    expect(nextLives(2, -1)).toBe(9);
    expect(nextLives(5, -1)).toBe(4);
  });

  it('keeps saved values in range', () => {
    expect(clampLives(0)).toBe(2);
    expect(clampLives(42)).toBe(9);
    expect(clampLives(Number.NaN)).toBe(2);
  });

  it('every extra life costs speed', () => {
    expect(livesSpeed(2)).toBe(1);
    expect(livesSpeed(3)).toBeCloseTo(0.95);
    expect(livesSpeed(9)).toBeCloseTo(0.65);
  });
});
