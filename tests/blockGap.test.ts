import { describe, expect, it } from 'vitest';
import { blockGap } from '../src/campaign/chapters/helpers';
import { STORY } from '../src/config';
import type { StoryScene } from '../src/story/storyScene';

function scene(gx: number, gy: number) {
  const bounces: Array<[number, number]> = [];
  const ctx = { time: 0, player: { gx, gy, bounce: (x: number, y: number) => bounces.push([x, y]) } };
  return { ctx, bounces, s: ctx as unknown as StoryScene };
}

describe('someone standing in a gap', () => {
  const gap = { x0: 6.55, x1: 8.45, y0: 2, y1: 5 };

  it('leaves the player alone outside the gap', () => {
    const { s, bounces } = scene(6.4, 3.5);
    expect(blockGap(gap)(s)).toBe(false);
    expect(bounces).toEqual([]);
  });

  it('puts him back on the side he came from and bounces him away', () => {
    const west = scene(6.7, 3.5);
    expect(blockGap(gap)(west.s)).toBe(true);
    expect(west.ctx.player.gx).toBe(6.55);
    expect(west.bounces).toEqual([[-1, 0]]);
    const east = scene(8.3, 3.5);
    blockGap(gap)(east.s);
    expect(east.ctx.player.gx).toBe(8.45);
    expect(east.bounces).toEqual([[1, 0]]);
  });

  it('counts one bump per STORY.BUMP.EVERY seconds however long he pushes', () => {
    const { ctx, s, bounces } = scene(6.6, 3.5);
    const hold = blockGap(gap);
    let bumps = 0;
    // A second of pushing into the gap, every frame.
    for (let f = 0; f < 60; f++) {
      ctx.time = f / 60;
      ctx.player.gx = 6.6;
      if (hold(s)) bumps++;
    }
    expect(bounces.length).toBe(60);
    expect(bumps).toBe(Math.ceil(1 / STORY.BUMP.EVERY));
  });
});
