import { beforeEach, describe, expect, it } from 'vitest';
import { CHAPTERS } from '../src/campaign/chapters';
import { loadCampaign, markComplete, newCampaign, saveCampaign } from '../src/campaign/state';
import { formatPlayTime, formatSavedAt, progressSummary } from '../src/campaign/summary';

class MemoryStorage {
  private m = new Map<string, string>();
  getItem(k: string) {
    return this.m.has(k) ? this.m.get(k)! : null;
  }
  setItem(k: string, v: string) {
    this.m.set(k, v);
  }
  removeItem(k: string) {
    this.m.delete(k);
  }
}

const ALL = CHAPTERS.flatMap((c) => c.subLevels.map((s) => s.id));

describe('COUCH: progress summary', () => {
  it('a new story: nothing done, next is the Green Zone walk', () => {
    const s = progressSummary(newCampaign(), CHAPTERS);
    expect(s.started).toBe(false);
    expect(s.done).toBe(0);
    expect(s.total).toBe(43);
    expect(s.levels).toHaveLength(8);
    expect(s.next).toEqual({ level: 1, id: '1.0', title: CHAPTERS[0]!.subLevels[0]!.title });
    expect(s.ending).toBeNull();
    expect(s.costume).toBeNull();
    expect(s.savedAt).toBeNull();
  });

  it('half way: counts per level and the next unfinished scene', () => {
    const st = newCampaign();
    for (const id of ALL.slice(0, 7)) markComplete(st, id);
    st.abilities.push('cross');
    const s = progressSummary(st, CHAPTERS);
    expect(s.started).toBe(true);
    expect(s.done).toBe(7);
    expect(s.levels[0]).toEqual({ number: 1, done: CHAPTERS[0]!.subLevels.length, total: CHAPTERS[0]!.subLevels.length });
    expect(s.levels[1]!.done).toBe(7 - CHAPTERS[0]!.subLevels.length);
    expect(s.next?.id).toBe(ALL[7]);
    expect(s.costume).toBe('cross');
  });

  it('finished: no next scene, the ending is named', () => {
    const st = newCampaign();
    for (const id of ALL) markComplete(st, id);
    st.flags.oath = 'enforced';
    const s = progressSummary(st, CHAPTERS);
    expect(s.next).toBeNull();
    expect(s.ending).toBe('knight');
  });
});

describe('COUCH: play time and save date', () => {
  beforeEach(() => {
    (globalThis as { localStorage?: unknown }).localStorage = new MemoryStorage();
  });

  it('saving stamps the date; play time survives a reload; old saves get defaults', () => {
    const st = newCampaign();
    st.playTime = 125.5;
    saveCampaign(st, 1_700_000_000_000);
    const back = loadCampaign();
    expect(back.savedAt).toBe(1_700_000_000_000);
    expect(back.playTime).toBe(125.5);
    localStorage.setItem('supervillained:story', JSON.stringify({ version: 1, completed: ['1.0'] }));
    const old = loadCampaign();
    expect(old.playTime).toBe(0);
    expect(old.savedAt).toBeNull();
  });

  it('formats play time and the date', () => {
    expect(formatPlayTime(45)).toBe('45S');
    expect(formatPlayTime(12 * 60 + 5)).toBe('12M');
    expect(formatPlayTime(3600 + 5 * 60)).toBe('1H 05M');
    expect(formatSavedAt(null)).toBe('NEVER');
    const now = new Date(2026, 10, 20).getTime();
    expect(formatSavedAt(new Date(2026, 10, 17, 18, 52).getTime(), now)).toBe('17 NOV 18:52');
    expect(formatSavedAt(new Date(2025, 0, 3, 9, 5).getTime(), now)).toBe('3 JAN 2025');
  });
});

describe('names in the card texts', () => {
  it('colors whole-word names (and their possessive), not other words', async () => {
    const { withNames } = await import('../src/story/names');
    const spans = withNames("AND BARK AWAY BAGNASKIZ. ZAMPANO'S JACKET, PIERRE D'AMIENS.", '#fff', '#ff0');
    const yellow = spans.filter((s) => s.color === '#ff0').map((s) => s.text);
    expect(yellow).toEqual(['BAGNASKIZ', "ZAMPANO'S", 'PIERRE', "D'AMIENS"]);
    expect(spans.map((s) => s.text).join('')).toBe("AND BARK AWAY BAGNASKIZ. ZAMPANO'S JACKET, PIERRE D'AMIENS.");
  });
});
