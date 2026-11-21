import type { LevelDef } from '../world/level';
import { LEVEL_1 } from './level1';

/** Ordered list of playable levels. Add new levels here. */
export const LEVELS: readonly LevelDef[] = [LEVEL_1];

export function levelByNumber(n: number): LevelDef | undefined {
  return LEVELS.find((l) => l.number === n);
}
