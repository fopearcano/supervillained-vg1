import type { Step } from '../story/step';
import type { ThemeKey } from '../story/maps';

/** One sub-level of the VG1 design ("what happens / play / source"). */
export interface SubLevelDef {
  /** '3.2' */
  id: string;
  title: string;
  /** Short "what happens", shown on the sub-level card. */
  happens: string;
  /** What it is built on: chronicle passages, the lecture, or "ADAPTATION" (docs/STORY-SOURCES.md). */
  source: string;
  /**
   * The Green Zone walk (1.0): this sub-level is the walk in the park (SPEC.md's level with this
   * number: treats, pee, poop, Bagnaskiz) instead of a story script.
   */
  greenZone?: number;
  /** Builds a fresh script every time the sub-level is played. */
  script: () => Step[];
}

/** A level (chapter) of the campaign. */
export interface ChapterDef {
  number: number;
  title: string;
  /** Shorter title for the story menu (fits the 216-px-wide screen). */
  menuTitle?: string;
  intro: string;
  cast: string;
  theme: ThemeKey;
  /** Music for the chapter. */
  music: 'greenzone' | 'level2' | 'level3' | 'level4' | 'medieval';
  subLevels: SubLevelDef[];
  /** The Professor's aside after the level. */
  professor: { text: string; after?: string };
}
