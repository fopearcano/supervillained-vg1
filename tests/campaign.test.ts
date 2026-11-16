import { readFileSync, readdirSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { CHAPTERS, findSubLevel } from '../src/campaign/chapters';
import { homeObject, KNOWN_MARVELS } from '../src/campaign/home';
import { applyEffects, canSpend, companions, dreamSkin, ending, endingNotes, fadeCommozione, graceTier, METER_MAX, newCampaign, spend, unshakeable } from '../src/campaign/state';
import { STORY } from '../src/config';
import { optionView } from '../src/story/steps';
import { CHAPTER_TITLES, shardName } from '../src/campaign/titles';
import { STORY_MAPS, THEMES } from '../src/story/maps';
import { parseAsciiMap } from '../src/world/level';

describe('campaign state rules', () => {
  it('clamps meters and reports real changes only', () => {
    const s = newCampaign();
    const changes = applyEffects(s, { commozione: 500, grace: -500 });
    expect(s.meters.commozione).toBe(METER_MAX);
    expect(s.meters.grace).toBe(0);
    expect(changes.map((c) => c.label)).toEqual(['+80 COMMOZIONE', '-70 GRACE']);
    expect(applyEffects(s, { commozione: 10 })).toEqual([]);
  });

  it('keeps the book unique and labels in uppercase', () => {
    const s = newCampaign();
    const first = applyEffects(s, { marvel: ['THE DROMONS', 'THE DROMONS'], value: 'Forms matter', item: 'A relic' });
    expect(s.book.marvels).toEqual(['THE DROMONS']);
    expect(first.map((c) => c.label)).toEqual(['MARVEL: THE DROMONS', 'GOT: A RELIC', 'VALUE: FORMS MATTER']);
    expect(applyEffects(s, { value: 'Forms matter' })).toEqual([]);
  });

  it('spends commozione only when he is moved enough', () => {
    const s = newCampaign();
    expect(canSpend(s, 'commozione', 21)).toBe(false);
    expect(spend(s, 'commozione', 21)).toBe(false);
    expect(spend(s, 'commozione', 20)).toBe(true);
    expect(s.meters.commozione).toBe(0);
  });

  it('decides the ending at 7.8 and the costume from unlocks', () => {
    const s = newCampaign();
    expect(ending(s)).toBe('alpha');
    applyEffects(s, { flags: { oath: 'enforced' } });
    expect(ending(s)).toBe('knight');
    expect(dreamSkin(s)).toBe('zampano');
    applyEffects(s, { unlock: 'cross' });
    expect(dreamSkin(s)).toBe('zampanoCross');
    applyEffects(s, { unlock: 'knight' });
    expect(dreamSkin(s)).toBe('zampanoKnight');
    expect(unshakeable(s)).toBe(false);
    applyEffects(s, { supervillain: 200 });
    expect(unshakeable(s)).toBe(true);
  });
});

describe('meters with consequences', () => {
  it('fades Commozione only in the dream levels (2-7), never below zero', () => {
    const s = newCampaign();
    expect(fadeCommozione(s, 1)).toBe(0);
    expect(fadeCommozione(s, 3)).toBe(STORY.COMMOZIONE_FADE);
    expect(s.meters.commozione).toBe(20 - STORY.COMMOZIONE_FADE);
    expect(fadeCommozione(s, 8)).toBe(0);
    s.meters.commozione = 1;
    expect(fadeCommozione(s, 5)).toBe(1);
    expect(s.meters.commozione).toBe(0);
  });

  it('lets Standing decide who walks beside him', () => {
    const s = newCampaign();
    s.meters.standing = 20;
    expect(companions(s, 'vanguard')).toEqual(['sbrim']);
    expect(companions(s, 'lawn')).toEqual(['conf']);
    s.meters.standing = STORY.FOLLOW.SAINT_POL;
    expect(companions(s, 'vanguard')).toEqual(['sbrim', 'stpol']);
    s.meters.standing = 100;
    expect(companions(s, 'vanguard')).toEqual(['sbrim', 'stpol', 'flanders']);
    expect(companions(s, 'lawn')).toEqual(['conf', 'sbrim', 'watson']);
  });

  it('shows Grace on the altar and in the ending', () => {
    const s = newCampaign();
    s.meters.grace = STORY.GRACE.HIGH;
    expect(graceTier(s)).toBe('high');
    s.meters.grace = STORY.GRACE.LOW;
    expect(graceTier(s)).toBe('mid');
    s.meters.grace = 0;
    expect(graceTier(s)).toBe('low');
    expect(endingNotes(s)[0]).toMatch(/CHEW TOYS/);
    expect(endingNotes(s)).toHaveLength(2);
  });

  it('locks costly choices when he is unmoved, and shows the cost', () => {
    const s = newCampaign();
    s.meters.commozione = 5;
    const o = { label: 'WE DEFY YOU.', cost: 10 };
    expect(optionView(o, s)).toEqual({ label: 'WE DEFY YOU.', locked: 'TOO UNMOVED: NEEDS 10 COMMOZIONE' });
    s.meters.commozione = 10;
    expect(optionView(o, s)).toEqual({ label: 'WE DEFY YOU.  (-10 COMMOZIONE)' });
    expect(optionView({ label: 'FREE' }, s)).toEqual({ label: 'FREE' });
  });
});

describe('VG1 campaign data', () => {
  it('has the eight levels in order with their titles', () => {
    expect(CHAPTERS.map((c) => c.number)).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(CHAPTERS.map((c) => c.title)).toEqual([...CHAPTER_TITLES]);
    expect(shardName(7)).toBe('LEVEL 7: CONSTANTINOPLE');
  });

  it('numbers sub-levels n.1, n.2 ... with unique ids (42 in all)', () => {
    const ids = CHAPTERS.flatMap((c) => c.subLevels.map((s) => s.id));
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids.length).toBe(42);
    for (const c of CHAPTERS) c.subLevels.forEach((s, k) => expect(s.id).toBe(`${c.number}.${k + 1}`));
    expect(findSubLevel('7.3')?.chapter.number).toBe(7);
    expect(findSubLevel('9.1')).toBeNull();
  });

  it('gives every sub-level a script, a "what happens" and a source', () => {
    for (const c of CHAPTERS) {
      expect(c.professor.text.length).toBeGreaterThan(10);
      expect(THEMES[c.theme]).toBeDefined();
      for (const s of c.subLevels) {
        expect(s.happens, s.id).toBe(s.happens.toUpperCase());
        expect(s.source.length, s.id).toBeGreaterThan(5);
        const steps = s.script();
        expect(steps.length, s.id).toBeGreaterThan(1);
        // Scripts are rebuilt every time they are played.
        expect(s.script()).not.toBe(steps);
        if (s.title.startsWith('Black hole')) expect(s.blackHole?.value, s.id).toBeTruthy();
      }
    }
  });

  it('parses every story map and its theme', () => {
    for (const [key, def] of Object.entries(STORY_MAPS)) {
      const m = parseAsciiMap(def.rows, { base: def.base, requireExit: false });
      expect(m.width, key).toBe(def.rows[0]!.length);
      expect(THEMES[def.theme], key).toBeDefined();
    }
  });

  it('turns every marvel the dream can award into an object at home (8.2)', () => {
    const dir = 'src/campaign/chapters';
    const awarded = new Set<string>();
    for (const f of readdirSync(dir)) {
      const src = readFileSync(`${dir}/${f}`, 'utf8');
      for (const m of src.matchAll(/marvel: '([^']+)'/g)) awarded.add(m[1]!);
    }
    expect(awarded.size).toBeGreaterThan(10);
    for (const m of awarded) expect(KNOWN_MARVELS, m).toContain(m);
    expect(homeObject('THE HIPPODROME')).toBe('THE RUG (IT IS A RACETRACK)');
    expect(homeObject('THE MOON')).toBe('A SOUVENIR OF MOON');
  });
});
