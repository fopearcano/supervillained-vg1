import { AUDIO } from '../config';
import { storage } from './storage';

/** Persistent player settings and records (localStorage, guarded). */

export type TextSpeed = 'slow' | 'normal' | 'fast' | 'instant';
export const TEXT_SPEEDS: readonly TextSpeed[] = ['slow', 'normal', 'fast', 'instant'];

export interface Settings {
  muted: boolean;
  volume: number;
  /** Story dialogue typewriter speed. */
  textSpeed: TextSpeed;
}

export interface LevelRecord {
  score: number;
  stars: number;
  time: number;
}

export function loadSettings(): Settings {
  const s = storage.get<Partial<Settings>>('settings', {});
  return {
    muted: typeof s.muted === 'boolean' ? s.muted : false,
    volume: typeof s.volume === 'number' ? Math.max(0, Math.min(1, s.volume)) : AUDIO.DEFAULT_VOLUME,
    textSpeed: TEXT_SPEEDS.includes(s.textSpeed as TextSpeed) ? (s.textSpeed as TextSpeed) : 'normal',
  };
}

export function saveSettings(s: Settings): void {
  storage.set('settings', s);
}

export function loadRecords(): Record<string, LevelRecord> {
  const r = storage.get<Record<string, LevelRecord>>('records', {});
  return r && typeof r === 'object' ? r : {};
}

export function bestFor(levelId: string): LevelRecord | null {
  return loadRecords()[levelId] ?? null;
}

/**
 * Saves a finished level. Keeps the best score, the best stars and the best time independently.
 * Returns true if the score is a new best.
 */
export function saveRecord(levelId: string, rec: LevelRecord): boolean {
  const all = loadRecords();
  const old = all[levelId];
  const newBest = !old || rec.score > old.score;
  all[levelId] = {
    score: Math.max(old?.score ?? 0, rec.score),
    stars: Math.max(old?.stars ?? 0, rec.stars),
    time: old ? Math.min(old.time, rec.time) : rec.time,
  };
  storage.set('records', all);
  return newBest;
}

/** Coins are saved for a future shop. */
export function loadCoins(): number {
  const c = storage.get<number>('coins', 0);
  return typeof c === 'number' && Number.isFinite(c) ? c : 0;
}

export function addCoins(n: number): number {
  const total = loadCoins() + Math.max(0, Math.floor(n));
  storage.set('coins', total);
  return total;
}
