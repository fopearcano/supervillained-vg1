import type { ChapterDef } from '../types';
import { CH1 } from './ch1';
import { CH2 } from './ch2';
import { CH3 } from './ch3';
import { CH4 } from './ch4';
import { CH5 } from './ch5';
import { CH6 } from './ch6';
import { CH7 } from './ch7';
import { CH8 } from './ch8';

/** The eight levels of the VG1 design, in order. */
export const CHAPTERS: readonly ChapterDef[] = [CH1, CH2, CH3, CH4, CH5, CH6, CH7, CH8];

export function findSubLevel(id: string): { chapter: ChapterDef; index: number } | null {
  for (const chapter of CHAPTERS) {
    const index = chapter.subLevels.findIndex((s) => s.id === id);
    if (index >= 0) return { chapter, index };
  }
  return null;
}
