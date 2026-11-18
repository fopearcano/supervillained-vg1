import { beforeEach, describe, expect, it } from 'vitest';
import { addCoins, bestFor, loadCoins, loadSettings, saveRecord, saveSettings } from '../src/core/settings';
import { storage } from '../src/core/storage';

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

describe('storage without localStorage', () => {
  it('falls back silently', () => {
    const g = globalThis as { localStorage?: unknown };
    const saved = g.localStorage;
    delete g.localStorage;
    expect(storage.get('x', 42)).toBe(42);
    expect(() => storage.set('x', 1)).not.toThrow();
    g.localStorage = saved;
  });

  it('survives a throwing localStorage', () => {
    const g = globalThis as { localStorage?: unknown };
    g.localStorage = {
      getItem() {
        throw new Error('denied');
      },
      setItem() {
        throw new Error('quota');
      },
    };
    expect(storage.get('x', 'fallback')).toBe('fallback');
    expect(() => storage.set('x', 1)).not.toThrow();
  });
});

describe('settings, records and coins', () => {
  beforeEach(() => {
    (globalThis as { localStorage?: unknown }).localStorage = new MemoryStorage();
  });

  it('persists mute, volume, text speed and lives', () => {
    expect(loadSettings().muted).toBe(false);
    expect(loadSettings().textSpeed).toBe('normal');
    expect(loadSettings().lives).toBe(2);
    saveSettings({ muted: true, volume: 0.3, textSpeed: 'fast', lives: 5 });
    expect(loadSettings()).toEqual({ muted: true, volume: 0.3, textSpeed: 'fast', lives: 5 });
  });

  it('falls back to normal text speed for unknown values', () => {
    localStorage.setItem('supervillained:settings', JSON.stringify({ textSpeed: 'warp' }));
    expect(loadSettings().textSpeed).toBe('normal');
  });

  it('keeps the best score, best stars and best time', () => {
    expect(saveRecord('l1', { score: 1000, stars: 3, time: 120 })).toBe(true);
    expect(saveRecord('l1', { score: 800, stars: 4.5, time: 100 })).toBe(false);
    expect(bestFor('l1')).toEqual({ score: 1000, stars: 4.5, time: 100 });
    expect(saveRecord('l1', { score: 1500, stars: 2, time: 200 })).toBe(true);
    expect(bestFor('l1')?.score).toBe(1500);
    expect(bestFor('nope')).toBeNull();
  });

  it('accumulates coins', () => {
    expect(loadCoins()).toBe(0);
    addCoins(5);
    expect(addCoins(10)).toBe(15);
    expect(loadCoins()).toBe(15);
  });

  it('ignores corrupted data', () => {
    localStorage.setItem('supervillained:coins', '"lots"');
    localStorage.setItem('supervillained:settings', '{not json');
    expect(loadCoins()).toBe(0);
    expect(loadSettings().muted).toBe(false);
  });
});
