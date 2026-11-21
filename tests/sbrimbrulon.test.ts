import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { animationDuration, animationFrame } from '../src/assets/animationTiming';
import { CHARACTERS, SHEET_DIRS } from '../src/assets/manifest';

const keys = ['sbrimbrulon', 'sbrimbrulonKnight'] as const;
const actions = ['idle', 'walk', 'run', 'sniff', 'pee', 'poop', 'eat', 'bark', 'fetch', 'hurt', 'sit', 'tired'];
const size = (path: string) => {
  const bytes = readFileSync(join('public', path));
  expect(bytes.subarray(0, 8)).toEqual(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
};

describe('complete Sbrimbrulòn normal and armoured delivery', () => {
  it('has matching twelve-action layouts, native anchors and separate tired atlases', () => {
    for (const key of keys) {
      const def = CHARACTERS[key];
      expect(Object.keys(def.anims)).toEqual(actions);
      expect([def.frameW, def.frameH, def.anchorX, def.anchorY]).toEqual([40, 40, 20, 36]);
      expect(size(def.sheet!)).toEqual([320, 11 * SHEET_DIRS.length * 40]);
      expect(size(def.animSheets!.tired!)).toEqual([80, 320]);
    }
    expect(CHARACTERS.sbrimbrulonKnight.anims).toEqual(CHARACTERS.sbrimbrulon.anims);
  });

  it('loops both eight-frame idles at authored holds', () => {
    for (const key of keys) {
      const { idle, sit } = CHARACTERS[key].anims;
      expect(animationFrame(idle!, 0.099)).toBe(0);
      expect(animationFrame(idle!, 0.100)).toBe(1);
      for (const clip of [idle!, sit!]) {
        expect(clip.frames).toBe(8);
        expect(animationFrame(clip, animationDuration(clip) + 0.005)).toBe(0);
      }
    }
  });

  it('holds the last frame of authored one-shots until the caller resumes behavior', () => {
    for (const key of keys) {
      for (const action of ['pee', 'poop', 'bark', 'fetch', 'hurt'] as const) {
        const clip = CHARACTERS[key].anims[action]!;
        expect(clip.loop).toBe(false);
        expect(animationFrame(clip, animationDuration(clip) + 0.01)).toBe(clip.frames - 1);
      }
    }
  });
});
