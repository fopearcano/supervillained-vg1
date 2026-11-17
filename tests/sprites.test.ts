import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { CHARACTERS, OLD_SPRITES_DIR, RUN_ICON, SHEET_DIRS, type CharacterDef } from '../src/assets/manifest';

/** Width and height from a PNG's IHDR. */
function pngSize(path: string): { w: number; h: number } {
  const b = readFileSync(join('public', path));
  expect(b.subarray(1, 4).toString('ascii')).toBe('PNG');
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

const defs = Object.values(CHARACTERS as Record<string, CharacterDef>);

describe('sprite sheets match the manifest layout', () => {
  it('new sheets: one row per (anim, direction), anims with a sheet of their own left out', () => {
    const withSheet = defs.filter((d) => d.sheet);
    expect(withSheet.map((d) => d.key).sort()).toEqual(['bagnaskiz', 'confusione', 'jack', 'sbrimbrulon', 'watson', 'zampano']);
    for (const d of withSheet) {
      const anims = Object.entries(d.anims).filter(([a]) => !d.animSheets?.[a as keyof typeof d.animSheets]);
      const { w, h } = pngSize(d.sheet!);
      expect(h, d.key).toBe(anims.length * SHEET_DIRS.length * d.frameH);
      expect(w, d.key).toBeGreaterThanOrEqual(Math.max(...anims.map(([, a]) => a.frames)) * d.frameW);
      for (const [anim, path] of Object.entries(d.animSheets ?? {})) {
        const s = pngSize(path!);
        expect(s.h, `${d.key} ${anim}`).toBe(SHEET_DIRS.length * d.frameH);
        expect(s.w, `${d.key} ${anim}`).toBe(d.anims[anim as keyof typeof d.anims]!.frames * d.frameW);
      }
    }
  });

  it('every replaced sheet keeps its old version (same layout, without the new-only anims)', () => {
    for (const d of defs.filter((x) => x.sheet)) {
      expect(d.oldSheet, d.key).toBe(`${OLD_SPRITES_DIR}/${d.key}.png`);
      const anims = Object.keys(d.anims).filter((a) => a !== 'tired');
      const { w, h } = pngSize(d.oldSheet!);
      expect(h, d.key).toBe(anims.length * SHEET_DIRS.length * d.frameH);
      expect(w, d.key).toBe(pngSize(d.sheet!).w);
    }
  });

  it('the RUN icon and its old version exist', () => {
    expect(pngSize(RUN_ICON)).toEqual({ w: 13, h: 11 });
    expect(pngSize(`${OLD_SPRITES_DIR}/runIcon.png`)).toEqual({ w: 7, h: 5 });
  });
});
