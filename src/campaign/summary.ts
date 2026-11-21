import { ending, isComplete, type Ability, type CampaignState, type Ending, type MeterKey } from './state';
import type { ChapterDef } from './types';

/** What the COUCH card shows about a saved story (pure: from the state and the chapters). */
export interface ProgressSummary {
  /** At least one scene done. */
  started: boolean;
  done: number;
  total: number;
  levels: Array<{ number: number; done: number; total: number }>;
  /** The next unfinished scene, or null when the story is finished. */
  next: { level: number; id: string; title: string } | null;
  /** The ending his choices lead to, once the story is finished. */
  ending: Ending | null;
  meters: Record<MeterKey, number>;
  values: number;
  marvels: number;
  items: number;
  shards: number;
  coins: number;
  /** The costume he wears in the dream. */
  costume: 'knight' | 'cross' | null;
  abilities: Ability[];
  playTime: number;
  savedAt: number | null;
}

export function progressSummary(state: CampaignState, chapters: readonly ChapterDef[]): ProgressSummary {
  const levels = chapters.map((ch) => ({
    number: ch.number,
    done: ch.subLevels.filter((s) => isComplete(state, s.id)).length,
    total: ch.subLevels.length,
  }));
  const done = levels.reduce((n, l) => n + l.done, 0);
  const total = levels.reduce((n, l) => n + l.total, 0);
  let next: ProgressSummary['next'] = null;
  for (const ch of chapters) {
    const sub = ch.subLevels.find((s) => !isComplete(state, s.id));
    if (sub) {
      next = { level: ch.number, id: sub.id, title: sub.title };
      break;
    }
  }
  return {
    started: done > 0,
    done,
    total,
    levels,
    next,
    ending: next ? null : ending(state),
    meters: { ...state.meters },
    values: state.book.values.length,
    marvels: state.book.marvels.length,
    items: state.book.items.length,
    shards: state.book.shards.length,
    coins: state.coins,
    costume: state.abilities.includes('knight') ? 'knight' : state.abilities.includes('cross') ? 'cross' : null,
    abilities: [...state.abilities],
    playTime: state.playTime,
    savedAt: state.savedAt,
  };
}

/** "1H 05M", "12M", "45S". */
export function formatPlayTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}H ${String(m).padStart(2, '0')}M`;
  if (m > 0) return `${m}M`;
  return `${s}S`;
}

const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/** "17 NOV 18:52" this year, "17 NOV 2025" before (local time), or "NEVER". Fits the card. */
export function formatSavedAt(ms: number | null, now = Date.now()): string {
  if (ms === null) return 'NEVER';
  const d = new Date(ms);
  const day = `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  if (d.getFullYear() !== new Date(now).getFullYear()) return `${day} ${d.getFullYear()}`;
  return `${day} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
