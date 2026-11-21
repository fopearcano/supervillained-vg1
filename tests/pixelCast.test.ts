import { describe, expect, it } from 'vitest';
import { CHARACTERS, PLAYABLE_CHARACTER_KEYS, SPRITES, type CharacterKey } from '../src/assets/manifest';
import { CAST_SPECS } from '../src/assets/placeholders/cast';
import { SPEAKERS } from '../src/story/ui';

describe('dedicated campaign cast', () => {
  it('keeps the three church roles and Niketas distinct from reused crowd identities', () => {
    const roles = ['abbot', 'envoy', 'bishop', 'niketas', 'clerk', 'cook', 'sailmaker', 'fulk', 'householdWoman'] as const;
    const portraits = roles.map((role) => SPEAKERS[role]!.portrait);
    expect(new Set(portraits).size).toBe(roles.length);
    for (const key of portraits as CharacterKey[]) {
      expect(CHARACTERS[key].sheet).toBe(`sprites/pixel-cast/${key}.png`);
    }
    expect(SPEAKERS.niketas!.portrait).not.toBe(SPEAKERS.greek!.portrait);
    expect(SPEAKERS.householdWoman!.portrait).not.toBe(SPEAKERS.lady!.portrait);
  });

  it('has an emergency procedural fallback for every declared character', () => {
    for (const key of Object.keys(CHARACTERS)) {
      expect(CAST_SPECS[key], `missing fallback: ${key}`).toBeDefined();
    }
  });

  it('uses the matching Professor face while retaining the dog-eye-view legs', () => {
    expect(SPRITES.professorFace.file).toBe('sprites/pixel-cast/professorFace.png');
    expect([SPRITES.professorFace.w, SPRITES.professorFace.h]).toEqual([24, 24]);
    expect([SPRITES.legs.w, SPRITES.legs.h, SPRITES.legs.variants]).toEqual([28, 64, 4]);
  });
});

describe('additional player-ready dogs', () => {
  it('permits dog player skins without marking human NPCs as playable', () => {
    expect(PLAYABLE_CHARACTER_KEYS).toEqual([
      'zampano', 'zampanoCross', 'zampanoKnight', 'sbrimbrulon', 'sbrimbrulonKnight',
      'bagnaskiz', 'bagnaskizEmperor',
    ]);
  });

  it.each(['bagnaskiz', 'bagnaskizEmperor'] as const)('%s supplies every controller action with a native ground anchor', (key) => {
    const def = CHARACTERS[key];
    expect(Object.keys(def.anims)).toEqual([
      'idle', 'walk', 'run', 'sniff', 'pee', 'poop', 'eat', 'bark', 'fetch', 'hurt', 'sit', 'tired',
    ]);
    expect([def.frameW, def.frameH, def.anchorX, def.anchorY]).toEqual([40, 40, 20, 36]);
    // The full-colour 8-directions delivery (see bagnaskizAnimations.test.ts).
    expect(def.animSheets?.tired).toBe(key === 'bagnaskiz' ? 'sprites/bagnaskiz-tired.png' : 'sprites/bagnaskizArmoured-tired.png');
    for (const anim of ['pee', 'poop', 'bark', 'fetch'] as const) {
      expect(def.anims[anim]!.loop).toBe(false);
    }
    expect(def.anims.hurt!.loop).toBe(key === 'bagnaskiz');
  });
});

describe('playing as another dog (?as=)', () => {
  it("maps Zampanò's costumes to the dog's own, armour for armour", async () => {
    const { costumeFor, ARMOURED_SKINS } = await import('../src/assets/manifest');
    expect(costumeFor('zampano', 'zampanoKnight')).toBe('zampanoKnight');
    expect(costumeFor('sbrimbrulon', 'zampano')).toBe('sbrimbrulon');
    expect(costumeFor('sbrimbrulon', 'zampanoCross')).toBe('sbrimbrulon');
    expect(costumeFor('sbrimbrulon', 'zampanoKnight')).toBe('sbrimbrulonKnight');
    expect(costumeFor('bagnaskiz', 'zampano')).toBe('bagnaskiz');
    expect(costumeFor('bagnaskiz', 'zampanoKnight')).toBe('bagnaskizEmperor');
    // An explicit other dog stays as asked.
    expect(costumeFor('bagnaskiz', 'sbrimbrulonKnight')).toBe('sbrimbrulonKnight');
    for (const k of ['zampanoKnight', 'sbrimbrulonKnight', 'bagnaskizEmperor'] as const) expect(ARMOURED_SKINS.has(k)).toBe(true);
    expect(ARMOURED_SKINS.has('bagnaskizMarshal')).toBe(false);
  });
});
