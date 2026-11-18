import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  ART_VERSIONS,
  CHARACTERS,
  OLD_SPRITES_DIR,
  RUN_ICON,
  SHEET_DIRS,
  sheetSetFor,
  type AnimName,
  type CharacterDef,
} from '../src/assets/manifest';

/** Width and height from a PNG's IHDR. */
function pngSize(path: string): { w: number; h: number } {
  const b = readFileSync(join('public', path));
  expect(b.subarray(1, 4).toString('ascii')).toBe('PNG');
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

const defs = Object.values(CHARACTERS as Record<string, CharacterDef>);
const withSheets = defs.filter((d) => d.sheets?.length);

describe('sprite sheets match the manifest layout', () => {
  it('the characters with delivered art', () => {
    expect(withSheets.map((d) => d.key).sort()).toEqual(
      ['bagnaskiz', 'confusione', 'jack', 'sbrimbrulon', 'watson', 'zampano', 'zampanoCross', 'zampanoKnight'].sort(),
    );
  });

  it('every set: one row per (anim, direction), anims with a sheet of their own left out', () => {
    for (const d of withSheets) {
      for (const set of d.sheets!) {
        const own = set.animSheets ?? {};
        // The procedural art never had `tired` (it shows idle for it).
        const anims = (Object.keys(d.anims) as AnimName[]).filter((a) => !own[a] && !(set.since === 'old' && a === 'tired'));
        const { w, h } = pngSize(set.sheet);
        const label = `${d.key} ${set.since} ${set.sheet}`;
        expect(h, label).toBe(anims.length * SHEET_DIRS.length * d.frameH);
        expect(w, label).toBeGreaterThanOrEqual(Math.max(...anims.map((a) => d.anims[a]!.frames)) * d.frameW);
        for (const [anim, path] of Object.entries(own)) {
          const s = pngSize(path!);
          expect(s.h, `${label} ${anim}`).toBe(SHEET_DIRS.length * d.frameH);
          expect(s.w, `${label} ${anim}`).toBe(d.anims[anim as AnimName]!.frames * d.frameW);
        }
      }
    }
  });

  it('nothing replaced is lost: every character keeps its procedural art as the old version', () => {
    for (const d of withSheets) {
      expect(d.sheets![0], d.key).toEqual({ since: 'old', sheet: `${OLD_SPRITES_DIR}/${d.key}.png` });
    }
  });

  it('each art version shows the newest set introduced at or before it', () => {
    const z = CHARACTERS.zampano;
    expect(sheetSetFor(z, 'old')?.sheet).toBe('sprites/old/zampano.png');
    expect(sheetSetFor(z, 'v1')?.sheet).toBe('sprites/v1/zampano.png');
    expect(sheetSetFor(z, 'new')?.sheet).toBe('sprites/zampano.png');
    // The costumes had no sheet in update 1: it showed the procedural (old) art.
    expect(sheetSetFor(CHARACTERS.zampanoKnight, 'v1')?.sheet).toBe('sprites/old/zampanoKnight.png');
    // Update 2 did not change the band: NEW keeps update 1's sheets.
    expect(sheetSetFor(CHARACTERS.jack, 'new')?.sheet).toBe('sprites/jack.png');
    expect(sheetSetFor(CHARACTERS.santina, 'new')).toBeNull();
    expect(ART_VERSIONS).toEqual(['old', 'v1', 'new']);
  });

  it('the RUN icon and its old version exist', () => {
    expect(pngSize(RUN_ICON)).toEqual({ w: 13, h: 11 });
    expect(pngSize(`${OLD_SPRITES_DIR}/runIcon.png`)).toEqual({ w: 7, h: 5 });
  });
});
