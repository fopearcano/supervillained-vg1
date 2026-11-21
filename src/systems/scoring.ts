import { SCORE, ZONE } from '../config';

/** Zone health → stars (0..5, in half-star steps). */
export function starsFromHealth(health: number): number {
  const t = (health - ZONE.HEALTH_ZERO_STARS) / (ZONE.HEALTH_FULL_STARS - ZONE.HEALTH_ZERO_STARS);
  const raw = Math.max(0, Math.min(1, t)) * 5;
  // Floor to half stars (a small epsilon so 100% health shows 5 full stars).
  return Math.floor(raw * 2 + 1e-6) / 2;
}

/** End-of-level health: penalty when PEES < POOPS. */
export function finalHealth(health: number, pees: number, poops: number): number {
  const deficit = Math.max(0, poops - pees);
  return Math.max(0, health - deficit * ZONE.PEE_DEFICIT_PENALTY);
}

export function timeBonus(timeSeconds: number, parTime: number): number {
  return Math.max(0, Math.floor(parTime - timeSeconds)) * SCORE.TIME_BONUS_PER_SECOND;
}

export function starBonus(stars: number): number {
  return Math.round(stars * SCORE.STAR_BONUS);
}

/** Running totals of a level attempt. */
export interface LevelStats {
  score: number;
  pees: number;
  poops: number;
  treats: number;
  coins: number;
  marks: number;
  lives: number;
  /** Seconds, counting up (includes penalties). */
  time: number;
  barkHits: number;
}

export function newStats(lives: number): LevelStats {
  return { score: 0, pees: 0, poops: 0, treats: 0, coins: 0, marks: 0, lives, time: 0, barkHits: 0 };
}

export function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

export function formatScore(score: number): string {
  return String(Math.max(0, Math.floor(score))).padStart(4, '0');
}
