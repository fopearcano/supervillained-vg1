import { LIVES } from '../config';

/** Lives chosen on the title, kept within START..MAX. */
export function clampLives(n: number): number {
  return Number.isFinite(n) ? Math.max(LIVES.START, Math.min(LIVES.MAX, Math.round(n))) : LIVES.START;
}

/** The next value of the title's counter: one more life, back to START after MAX. */
export function nextLives(n: number, step = 1): number {
  const span = LIVES.MAX - LIVES.START + 1;
  return LIVES.START + ((((clampLives(n) - LIVES.START + step) % span) + span) % span);
}

/** His speed in the Green Zone walk with this many lives: each one above START costs SPEED_COST. */
export function livesSpeed(n: number): number {
  return 1 - (clampLives(n) - LIVES.START) * LIVES.SPEED_COST;
}
