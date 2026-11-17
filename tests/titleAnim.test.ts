import { Texture } from 'pixi.js';
import { describe, expect, it, vi } from 'vitest';

vi.mock('../assets/starting-page-images/Zampano-Samemala-2.gif?url', () => ({ default: 'zampano.gif' }));
const { frameAt } = await import('../src/ui/titleAnim');

describe('title animation timing', () => {
  const frames = [new Texture(), new Texture(), new Texture()];
  const anim = { frames, durations: [0.08, 0.04, 0.05], length: 0.17 };

  it('shows each frame for its own duration (GIF delays)', () => {
    expect(frameAt(anim, 0)).toBe(frames[0]);
    expect(frameAt(anim, 0.079)).toBe(frames[0]);
    expect(frameAt(anim, 0.081)).toBe(frames[1]);
    expect(frameAt(anim, 0.13)).toBe(frames[2]);
  });

  it('loops', () => {
    expect(frameAt(anim, 0.17 + 0.01)).toBe(frames[0]);
    expect(frameAt(anim, 0.17 * 10 + 0.1)).toBe(frames[1]);
  });
});
