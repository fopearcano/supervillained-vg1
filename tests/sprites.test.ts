import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { CHARACTERS, RUN_ICON, SHEET_DIRS, type AnimName, type CharacterDef } from '../src/assets/manifest';

/** Width and height from a PNG's IHDR. */
function pngSize(path: string): { w: number; h: number } {
  const b = readFileSync(join('public', path));
  expect(b.subarray(1, 4).toString('ascii')).toBe('PNG');
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

const defs = Object.values(CHARACTERS as Record<string, CharacterDef>);
const withSheet = defs.filter((d) => d.sheet);

describe('sprite sheets match the manifest layout', () => {
  it('the characters with delivered art', () => {
    expect(withSheet.map((d) => d.key).sort()).toEqual(
      ['bagnaskiz', 'confusione', 'jack', 'sbrimbrulon', 'watson', 'zampano', 'zampanoCross', 'zampanoKnight'].sort(),
    );
  });

  it('one row per (anim, direction), anims with a sheet of their own left out', () => {
    for (const d of withSheet) {
      const own = d.animSheets ?? {};
      const anims = (Object.keys(d.anims) as AnimName[]).filter((a) => !own[a]);
      const { w, h } = pngSize(d.sheet!);
      expect(h, d.key).toBe(anims.length * SHEET_DIRS.length * d.frameH);
      expect(w, d.key).toBeGreaterThanOrEqual(Math.max(...anims.map((a) => d.anims[a]!.frames)) * d.frameW);
      for (const [anim, path] of Object.entries(own)) {
        const s = pngSize(path!);
        expect(s.h, `${d.key} ${anim}`).toBe(SHEET_DIRS.length * d.frameH);
        expect(s.w, `${d.key} ${anim}`).toBe(d.anims[anim as AnimName]!.frames * d.frameW);
      }
    }
  });

  it('the RUN icon exists', () => {
    expect(pngSize(RUN_ICON)).toEqual({ w: 13, h: 11 });
  });
});
