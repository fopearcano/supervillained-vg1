import type { Step } from '../story/step';
import type { ThemeKey } from '../story/maps';

/** One sub-level of the VG1 design ("what happens / play / source"). */
export interface SubLevelDef {
  /** '3.2' */
  id: string;
  title: string;
  /** Short "what happens", shown on the sub-level card. */
  happens: string;
  /** The conference episode (or board note) it is built on. */
  source: string;
  /** Black holes: sudden jumps to another crusade or dream; left with one value. */
  blackHole?: { where: string; value: string };
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
  music: 'chip' | 'medieval';
  subLevels: SubLevelDef[];
  /** The Professor's aside after the level. */
  professor: { text: string; after?: string };
}
